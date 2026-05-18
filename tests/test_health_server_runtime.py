import json
import socket
import subprocess
import tempfile
import time
import unittest
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT_PATH = ROOT / 'scripts' / 'health-server.sh'


def _free_port() -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
        sock.bind(("127.0.0.1", 0))
        return sock.getsockname()[1]


class HealthServerRuntimeTests(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.port = _free_port()
        self.temp_root = Path(self.temp_dir.name)
        self.script_copy = self.temp_root / 'health-server.sh'
        self.pid_file = self.temp_root / 'openclaw-health.pid'
        self.log_file = self.temp_root / 'openclaw-health.log'
        self.python_file = self.temp_root / 'health-server-runtime.py'

        text = SCRIPT_PATH.read_text(encoding='utf-8')
        text = text.replace('PID_FILE="/tmp/openclaw-health.pid"', f'PID_FILE="{self.pid_file}"')
        text = text.replace('LOG_FILE="/tmp/openclaw-health.log"', f'LOG_FILE="{self.log_file}"')
        text = text.replace('/tmp/health-server.py', str(self.python_file))
        text = text.replace('pgrep -f "health-server.py"', f'pgrep -f "{self.python_file}"')
        text = text.replace('pkill -f "health-server.py"', f'pkill -f "{self.python_file}"')
        self.script_copy.write_text(text, encoding='utf-8')
        self.script_copy.chmod(0o755)

    def tearDown(self):
        try:
            subprocess.run(
                ['bash', str(self.script_copy), 'stop'],
                cwd=ROOT,
                env={
                    'PATH': '/usr/bin:/bin:/usr/sbin:/sbin',
                    'HEALTH_PORT': str(self.port),
                    'HOME': self.temp_dir.name,
                },
                capture_output=True,
                text=True,
                timeout=10,
            )
        except Exception:
            pass
        self.temp_dir.cleanup()

    def _get_json(self, path: str, retries: int = 30) -> dict:
        last_error = None
        for _ in range(retries):
            try:
                with urllib.request.urlopen(f'http://127.0.0.1:{self.port}{path}', timeout=2) as response:
                    return json.loads(response.read().decode('utf-8'))
            except Exception as exc:  # pragma: no cover - retry path
                last_error = exc
                time.sleep(0.1)
        raise AssertionError(f'health server did not respond on {path}: {last_error}')

    def test_health_server_starts_and_exposes_health_payload(self):
        start = subprocess.run(
            ['bash', str(self.script_copy), 'start'],
            cwd=ROOT,
            env={
                'PATH': '/usr/bin:/bin:/usr/sbin:/sbin',
                'HEALTH_PORT': str(self.port),
                'HOME': self.temp_dir.name,
            },
            capture_output=True,
            text=True,
            timeout=15,
        )
        if start.returncode != 0:
            raise AssertionError(f'health server start failed\nSTDOUT:\n{start.stdout}\nSTDERR:\n{start.stderr}')

        payload = self._get_json('/health')
        self.assertEqual(payload['services']['gateway']['port'], 13145)
        self.assertEqual(payload['services']['workbench']['port'], 19000)
        self.assertEqual(payload['services']['quota_enforcer']['port'], 13147)
        self.assertIn(payload['status'], {'healthy', 'degraded', 'unhealthy'})


if __name__ == '__main__':
    unittest.main()

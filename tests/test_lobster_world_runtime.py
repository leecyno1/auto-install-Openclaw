import json
import os
import socket
import subprocess
import tempfile
import time
import unittest
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT_PATH = ROOT / 'scripts' / 'lobster-world.sh'


def _free_port() -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
        sock.bind(("127.0.0.1", 0))
        return sock.getsockname()[1]


class LobsterWorldRuntimeTests(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.port = _free_port()
        self.temp_root = Path(self.temp_dir.name)
        self.script_copy = self.temp_root / 'lobster-world.sh'
        self.pid_file = self.temp_root / 'lobster-world.pid'
        self.log_file = self.temp_root / 'lobster-world.log'

        text = SCRIPT_PATH.read_text(encoding='utf-8')
        text = text.replace(
            'ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"',
            f'ROOT_DIR="{ROOT}"',
        )
        text = text.replace('PID_FILE="/tmp/lobster-world-${PORT}.pid"', f'PID_FILE="{self.pid_file}"')
        text = text.replace('LOG_FILE="/tmp/lobster-world-${PORT}.log"', f'LOG_FILE="{self.log_file}"')
        self.script_copy.write_text(text, encoding='utf-8')
        self.script_copy.chmod(0o755)

    def tearDown(self):
        try:
            subprocess.run(
                ['bash', str(self.script_copy), 'stop'],
                cwd=ROOT,
                env={
                    'PATH': '/usr/bin:/bin:/usr/sbin:/sbin',
                    'STAR_BACKEND_PORT': str(self.port),
                    'HOME': self.temp_dir.name,
                },
                capture_output=True,
                text=True,
                timeout=15,
            )
        except Exception:
            pass
        self.temp_dir.cleanup()

    def _get_json(self, path: str, retries: int = 60) -> dict:
        last_error = None
        for _ in range(retries):
            try:
                with urllib.request.urlopen(f'http://127.0.0.1:{self.port}{path}', timeout=2) as response:
                    return json.loads(response.read().decode('utf-8'))
            except Exception as exc:
                last_error = exc
                time.sleep(0.2)
        raise AssertionError(f'lobster world did not respond on {path}: {last_error}')

    def test_lobster_world_starts_with_system_python_and_exposes_health(self):
        env = {
            'PATH': '/usr/bin:/bin:/usr/sbin:/sbin',
            'STAR_BACKEND_PORT': str(self.port),
            'STAR_BACKEND_HOST': '127.0.0.1',
            'HOME': self.temp_dir.name,
        }
        start = subprocess.Popen(
            ['bash', str(self.script_copy), 'start'],
            cwd=ROOT,
            env=env,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )

        start_returncode = None
        start_stdout = ''
        start_stderr = ''
        for _ in range(120):
            if start.poll() is not None:
                start_returncode = start.returncode
                start_stdout, start_stderr = start.communicate()
                break
            try:
                health = self._get_json('/health', retries=1)
                self.assertEqual(health['status'], 'ok')
                break
            except AssertionError:
                time.sleep(0.25)
        else:
            start.kill()
            start_stdout, start_stderr = start.communicate()
            raise AssertionError(
                f'lobster world did not become healthy in time\nSTDOUT:\n{start_stdout}\nSTDERR:\n{start_stderr}'
            )

        if start_returncode not in (None, 0):
            raise AssertionError(
                f'lobster world start failed\nSTDOUT:\n{start_stdout}\nSTDERR:\n{start_stderr}'
            )

        health = self._get_json('/health')
        self.assertEqual(health['status'], 'ok')

        status = subprocess.run(
            ['bash', str(self.script_copy), 'status'],
            cwd=ROOT,
            env=env,
            capture_output=True,
            text=True,
            timeout=15,
        )
        self.assertEqual(status.returncode, 0, status.stderr)
        self.assertIn('[OK] Running:', status.stdout)

        stop = subprocess.run(
            ['bash', str(self.script_copy), 'stop'],
            cwd=ROOT,
            env=env,
            capture_output=True,
            text=True,
            timeout=15,
        )
        self.assertEqual(stop.returncode, 0, stop.stderr)
        self.assertIn('[OK] Lobster World stopped', stop.stdout)


if __name__ == '__main__':
    unittest.main()

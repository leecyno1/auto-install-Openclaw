import json
import multiprocessing
import os
import socket
import tempfile
import time
import unittest
import urllib.request
from importlib import util
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = ROOT / 'scripts' / 'gateway-quota-enforcer.py'

spec = util.spec_from_file_location('gateway_quota_enforcer', MODULE_PATH)
quota_enforcer = util.module_from_spec(spec) if spec and spec.loader else None
if spec and spec.loader:
    spec.loader.exec_module(quota_enforcer)


def _free_port() -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
        sock.bind(("127.0.0.1", 0))
        return sock.getsockname()[1]


def _serve_quota_enforcer(port: int, state_file: str, pid_file: str, log_file: str) -> None:
    assert quota_enforcer is not None
    os.environ['OPENCLAW_MEDIA_QUOTA_STATE_FILE'] = state_file
    os.environ['OPENCLAW_RULE_PROFILE'] = 'medium'
    os.environ['OPENCLAW_RULE_MAX_IMAGE_REQUESTS'] = '20'
    os.environ['OPENCLAW_RULE_MAX_VIDEO_REQUESTS'] = '1'
    os.environ['OPENCLAW_RULE_MAX_REQUESTS'] = '300'
    quota_enforcer.PID_FILE = pid_file
    quota_enforcer.QUOTA_LOG_FILE = log_file
    quota_enforcer.start_server(bind='127.0.0.1', port=port)


class QuotaEnforcerRuntimeTests(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.state_file = str(Path(self.temp_dir.name) / 'quota-state.json')
        self.pid_file = str(Path(self.temp_dir.name) / 'quota-enforcer.pid')
        self.log_file = str(Path(self.temp_dir.name) / 'quota-enforcer.log')
        self.port = _free_port()
        self.process = multiprocessing.Process(
            target=_serve_quota_enforcer,
            args=(self.port, self.state_file, self.pid_file, self.log_file),
            daemon=True,
        )
        self.process.start()

    def tearDown(self):
        if self.process.is_alive():
            self.process.terminate()
            self.process.join(timeout=5)
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
        raise AssertionError(f'quota enforcer did not respond on {path}: {last_error}')

    def test_quota_enforcer_exposes_health_and_status_endpoints(self):
        self.assertIsNotNone(quota_enforcer)
        health = self._get_json('/health')
        status = self._get_json('/quota/status')

        self.assertEqual(health['status'], 'ok')
        self.assertEqual(health['service'], 'quota-enforcer')
        self.assertTrue(status['ok'])
        self.assertEqual(status['service'], 'quota-enforcer')
        self.assertEqual(status['image']['limit'], 20)
        self.assertEqual(status['video']['limit'], 1)
        self.assertEqual(status['text']['limit'], 300)


if __name__ == '__main__':
    unittest.main()

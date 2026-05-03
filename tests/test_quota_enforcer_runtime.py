import json
import multiprocessing
import os
import socket
import tempfile
import time
import unittest
import urllib.request
import urllib.error
from importlib import util
from http.server import HTTPServer, BaseHTTPRequestHandler
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


def _serve_gateway(port: int, hit_file: str) -> None:
    class GatewayHandler(BaseHTTPRequestHandler):
        protocol_version = 'HTTP/1.1'

        def _send_json(self, status_code: int, payload: dict) -> None:
            body = json.dumps(payload).encode('utf-8')
            self.send_response(status_code)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def do_POST(self):
            length = int(self.headers.get('Content-Length', '0'))
            if length:
                self.rfile.read(length)
            with open(hit_file, 'a', encoding='utf-8') as handle:
                handle.write(self.path + '\n')
            self._send_json(200, {'ok': True, 'path': self.path})

        def log_message(self, *_args):
            return

    HTTPServer(('127.0.0.1', port), GatewayHandler).serve_forever()


def _serve_quota_enforcer(port: int, gateway_port: int, state_file: str, pid_file: str, log_file: str, max_requests: str = '300') -> None:
    assert quota_enforcer is not None
    os.environ['OPENCLAW_MEDIA_QUOTA_STATE_FILE'] = state_file
    os.environ['OPENCLAW_RULE_PROFILE'] = 'medium'
    os.environ['OPENCLAW_RULE_MAX_IMAGE_REQUESTS'] = '20'
    os.environ['OPENCLAW_RULE_MAX_VIDEO_REQUESTS'] = '1'
    os.environ['OPENCLAW_RULE_MAX_REQUESTS'] = max_requests
    quota_enforcer.PID_FILE = pid_file
    quota_enforcer.QUOTA_LOG_FILE = log_file
    quota_enforcer.QUOTA_GATEWAY_HOST = '127.0.0.1'
    quota_enforcer.QUOTA_GATEWAY_PORT = gateway_port
    quota_enforcer.start_server(bind='127.0.0.1', port=port)


class QuotaEnforcerRuntimeTests(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.state_file = str(Path(self.temp_dir.name) / 'quota-state.json')
        self.pid_file = str(Path(self.temp_dir.name) / 'quota-enforcer.pid')
        self.log_file = str(Path(self.temp_dir.name) / 'quota-enforcer.log')
        self.hit_file = str(Path(self.temp_dir.name) / 'gateway-hits.log')
        self.port = _free_port()
        self.gateway_port = _free_port()
        self.gateway_process = multiprocessing.Process(
            target=_serve_gateway,
            args=(self.gateway_port, self.hit_file),
            daemon=True,
        )
        self.gateway_process.start()
        self.process = multiprocessing.Process(
            target=_serve_quota_enforcer,
            args=(self.port, self.gateway_port, self.state_file, self.pid_file, self.log_file),
            daemon=True,
        )
        self.process.start()

    def tearDown(self):
        if self.process.is_alive():
            self.process.terminate()
            self.process.join(timeout=5)
        if self.gateway_process.is_alive():
            self.gateway_process.terminate()
            self.gateway_process.join(timeout=5)
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

    def _post_json(self, path: str, payload: dict) -> tuple[int, dict]:
        data = json.dumps(payload).encode('utf-8')
        req = urllib.request.Request(
            f'http://127.0.0.1:{self.port}{path}',
            data=data,
            headers={'Content-Type': 'application/json'},
            method='POST',
        )
        try:
            with urllib.request.urlopen(req, timeout=3) as response:
                return response.status, json.loads(response.read().decode('utf-8'))
        except urllib.error.HTTPError as exc:
            return exc.code, json.loads(exc.read().decode('utf-8'))

    def test_text_post_is_counted_and_blocked_after_limit(self):
        if self.process.is_alive():
            self.process.terminate()
            self.process.join(timeout=5)
        self.process = multiprocessing.Process(
            target=_serve_quota_enforcer,
            args=(self.port, self.gateway_port, self.state_file, self.pid_file, self.log_file, '1'),
            daemon=True,
        )
        self.process.start()
        self._get_json('/health')

        first_status, first_payload = self._post_json('/v1/chat/completions', {'model': 'test', 'messages': [{'role': 'user', 'content': 'hi'}]})
        second_status, second_payload = self._post_json('/v1/chat/completions', {'model': 'test', 'messages': [{'role': 'user', 'content': 'hi'}]})

        self.assertEqual(first_status, 200)
        self.assertTrue(first_payload['ok'])
        self.assertEqual(second_status, 429)
        self.assertEqual(second_payload['category'], 'text')
        hits = Path(self.hit_file).read_text(encoding='utf-8').strip().splitlines()
        self.assertEqual(hits.count('/v1/chat/completions'), 1)

    def test_image_post_is_counted_by_requested_units(self):
        self._get_json('/health')
        first_status, _first_payload = self._post_json('/v1/images/generations', {'model': 'test-image', 'prompt': 'x', 'n': 10})
        second_status, _second_payload = self._post_json('/v1/images/generations', {'model': 'test-image', 'prompt': 'x', 'n': 10})
        status, payload = self._post_json('/v1/images/generations', {'model': 'test-image', 'prompt': 'x', 'n': 10})
        self.assertEqual(first_status, 200)
        self.assertEqual(second_status, 200)
        self.assertEqual(status, 429)
        self.assertEqual(payload['category'], 'image')
        self.assertEqual(payload['requestedUnits'], 10)

    def test_music_path_is_treated_as_text_not_invalid_media(self):
        self._get_json('/health')
        status, payload = self._post_json('/v1/music/generations', {'model': 'music-model', 'prompt': 'x'})
        self.assertEqual(status, 200)
        self.assertTrue(payload['ok'])
        status_payload = self._get_json('/quota/status')
        self.assertEqual(status_payload['text']['used'], 1)

    def test_upstream_unreachable_returns_502_and_releases_quota(self):
        self._get_json('/health')
        if self.gateway_process.is_alive():
            self.gateway_process.terminate()
            self.gateway_process.join(timeout=5)
        status, payload = self._post_json('/v1/chat/completions', {'model': 'test', 'messages': [{'role': 'user', 'content': 'hi'}]})
        self.assertEqual(status, 502)
        self.assertEqual(payload['error'], 'gateway_unreachable')
        status_payload = self._get_json('/quota/status')
        self.assertEqual(status_payload['text']['used'], 0)
        self.assertEqual(status_payload['text']['pending'], 0)


if __name__ == '__main__':
    unittest.main()

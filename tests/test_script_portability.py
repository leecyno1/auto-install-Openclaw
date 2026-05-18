import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PREFLIGHT = ROOT / 'scripts' / 'preflight-check.sh'


class ScriptPortabilityTests(unittest.TestCase):
    def test_preflight_uses_discoverable_unittest_invocation(self):
        text = PREFLIGHT.read_text(encoding='utf-8')
        self.assertNotIn('python3 -m unittest tests/test_', text)
        self.assertIn("python3 -m unittest discover -s tests -p 'test_media_quota.py'", text)
        self.assertIn("python3 -m unittest discover -s tests -p 'test_quota_enforcer_runtime.py'", text)
        self.assertIn("python3 -m unittest discover -s tests -p 'test_dual_engine_smoke.py'", text)


if __name__ == '__main__':
    unittest.main()

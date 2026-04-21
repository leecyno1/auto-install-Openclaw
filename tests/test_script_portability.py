import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PREFLIGHT = ROOT / 'scripts' / 'preflight-check.sh'
REFRESH = ROOT / 'scripts' / 'refresh_default_skills.py'


class ScriptPortabilityTests(unittest.TestCase):
    def test_preflight_uses_discoverable_unittest_invocation(self):
        text = PREFLIGHT.read_text(encoding='utf-8')
        self.assertNotIn('python3 -m unittest tests/test_', text)
        self.assertIn("python3 -m unittest discover -s tests -p 'test_media_quota.py'", text)
        self.assertIn("python3 -m unittest discover -s tests -p 'test_quota_enforcer_runtime.py'", text)
        self.assertIn("python3 -m unittest discover -s tests -p 'test_dual_engine_smoke.py'", text)

    def test_refresh_default_skills_does_not_pin_author_home_path(self):
        text = REFRESH.read_text(encoding='utf-8')
        self.assertNotIn("/Users/lichengyin/.codex/skills", text)
        self.assertIn("Path.home() / '.codex' / 'skills'", text)
        self.assertIn('def display_path(path: Path) -> str:', text)
        self.assertIn("f'- 扫描目录: `{display_path(SKILLS_DIR)}`'", text)
        self.assertIn('return display_path(root), candidate, \'local\'', text)
        self.assertIn('def load_doc_source_hints() -> dict[str, str]:', text)
        self.assertIn('docs/upstream-sources.md', text)


if __name__ == '__main__':
    unittest.main()

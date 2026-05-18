import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LINT_SHELL = ROOT / 'scripts' / 'lint-shell.sh'
WORKFLOW = ROOT / '.github' / 'workflows' / 'shell-preflight.yml'


class ShellLintContractTests(unittest.TestCase):
    def test_lint_shell_supports_strict_mode_for_ci_or_release_hosts(self):
        text = LINT_SHELL.read_text(encoding='utf-8')
        self.assertIn('strict_shell_tools="${OPENCLAW_STRICT_SHELL_TOOLS:-${CI:-0}}"', text)
        self.assertIn('require_tool_or_warn()', text)
        self.assertIn('fail "$tool not installed (strict mode). $install_hint"', text)
        self.assertIn('warn "$tool not installed, skipped"', text)

    def test_ci_workflow_installs_shellcheck_and_shfmt_before_preflight(self):
        text = WORKFLOW.read_text(encoding='utf-8')
        self.assertIn('sudo apt-get install -y shellcheck shfmt', text)
        self.assertIn('./scripts/preflight-check.sh', text)


if __name__ == '__main__':
    unittest.main()

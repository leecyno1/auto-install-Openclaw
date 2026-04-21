import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
README = ROOT / 'README.md'
INSTALL = ROOT / 'install.sh'
CONFIG_MENU = ROOT / 'config-menu.sh'


class ReadmeLauncherAlignmentTests(unittest.TestCase):
    def test_readme_primary_lobster_setup_commands_match_launcher_surface(self):
        readme_text = README.read_text(encoding='utf-8')
        install_text = INSTALL.read_text(encoding='utf-8')

        documented = set(re.findall(r'lobster-setup (install|config|repair|workbench|status|doctor|engine|backup|help)\b', readme_text))
        self.assertEqual(
            documented,
            {'install', 'config', 'repair', 'workbench', 'status', 'doctor', 'engine', 'backup', 'help'},
        )

        self.assertIn('print_lobster_setup_help()', install_text)
        self.assertIn(
            '用法: lobster-setup {install|config|repair|workbench|status|doctor|engine|migrate|backup|help}',
            install_text,
        )
        self.assertIn('local launcher="$LOBSTER_BIN_DIR/lobster-setup"', install_text)
        self.assertIn('local compat_launcher="$LOBSTER_BIN_DIR/openclaw-setup"', install_text)
        self.assertIn('openclaw-setup ...         # 兼容旧命令，等价转发到 lobster-setup', install_text)

        for command in ('config', 'repair', 'workbench', 'status', 'doctor', 'engine', 'backup'):
            self.assertIn(f'lobster-setup {command}', readme_text)

    def test_readme_guided_flow_prefers_lobster_setup_over_raw_config_commands(self):
        readme_text = README.read_text(encoding='utf-8')
        self.assertIn('安装后执行 `lobster-setup config`', readme_text)
        self.assertIn('对历史服务器执行 `lobster-setup repair`', readme_text)
        self.assertIn('需要可视化界面时执行 `lobster-setup workbench`', readme_text)

    def test_readme_direct_helper_paths_match_installer_surface(self):
        readme_text = README.read_text(encoding='utf-8')
        install_text = INSTALL.read_text(encoding='utf-8')

        self.assertIn('bash ~/.openclaw/config-menu.sh', readme_text)
        self.assertIn('~/.openclaw/lobster-world.sh start', readme_text)
        self.assertIn('~/.openclaw/health-server.sh status', readme_text)
        self.assertIn('python3 ~/.openclaw/scripts/gateway-quota-enforcer.py status', readme_text)

        self.assertIn('$CONFIG_DIR/config-menu.sh', install_text)
        self.assertIn('$CONFIG_DIR/lobster-world.sh', install_text)
        self.assertIn('$CONFIG_DIR/health-server.sh', install_text)
        self.assertIn('$CONFIG_DIR/scripts/gateway-quota-enforcer.py', install_text)

    def test_readme_lists_supported_config_menu_shortcuts(self):
        readme_text = README.read_text(encoding='utf-8')
        self.assertIn('bash ~/.openclaw/config-menu.sh --model-only', readme_text)
        self.assertIn('bash ~/.openclaw/config-menu.sh --official-channels-only', readme_text)
        self.assertIn('bash ~/.openclaw/config-menu.sh --engine-menu', readme_text)
        self.assertIn('bash ~/.openclaw/config-menu.sh --repair-config', readme_text)
        self.assertIn('bash ~/.openclaw/config-menu.sh --repair-pairing', readme_text)
        self.assertIn('bash ~/.openclaw/config-menu.sh --install-pixel-house', readme_text)

    def test_config_menu_help_shortcuts_align_with_readme_shortcuts(self):
        readme_text = README.read_text(encoding='utf-8')
        config_menu_text = CONFIG_MENU.read_text(encoding='utf-8')
        expected_shortcuts = (
            '--model-only',
            '--official-channels-only',
            '--repair-config',
            '--repair-pairing',
            '--install-pixel-house',
            '--engine-menu',
        )
        for shortcut in expected_shortcuts:
            self.assertIn(shortcut, config_menu_text)
            self.assertIn(f'bash ~/.openclaw/config-menu.sh {shortcut}', readme_text)

    def test_config_menu_mentions_health_and_quota_helpers_under_pixel_house(self):
        config_menu_text = (ROOT / 'config-menu.sh').read_text(encoding='utf-8')
        self.assertIn('13146 健康检查', config_menu_text)
        self.assertIn('13147 配额强制', config_menu_text)
        self.assertIn('安装/修复像素小屋时会同步接线并启动这两个辅助服务', config_menu_text)


if __name__ == '__main__':
    unittest.main()

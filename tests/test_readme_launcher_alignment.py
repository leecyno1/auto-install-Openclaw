import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
README = ROOT / 'README.md'
INSTALL = ROOT / 'install.sh'
CONFIG_MENU = ROOT / 'config-menu.sh'


class ReadmeLauncherAlignmentTests(unittest.TestCase):
    def test_readme_homepage_is_promotional_and_skill_table_first(self):
        readme_text = README.read_text(encoding='utf-8')
        self.assertIn('photo/dasheng-openclaw-promo.png', readme_text)
        self.assertIn('Featured-大圣之怒', readme_text)
        self.assertIn('一键安装 OpenClaw / Hermes，把模型、Skills、规则、像素小屋和网站联动收束到一个可重复部署的入口。', readme_text)
        self.assertIn('## 全部技能', readme_text)
        self.assertIn('| 档位 | Skill | 分类 | 评分 | 依赖 | 一句话说明 | 手册 | 原仓库 |', readme_text)
        self.assertLess(readme_text.index('photo/dasheng-openclaw-promo.png'), readme_text.index('Featured-大圣之怒'))
        self.assertLess(readme_text.index('Featured-大圣之怒'), readme_text.index('## 全部技能'))
        self.assertLess(readme_text.index('## 全部技能'), readme_text.index('## 模块概览'))

    def test_readme_primary_lobster_setup_commands_match_launcher_surface(self):
        readme_text = README.read_text(encoding='utf-8')
        install_text = INSTALL.read_text(encoding='utf-8')

        documented = set(re.findall(r'openclaw-setup (install|config|repair|workbench|status|doctor|engine|backup|help)\b', readme_text))
        self.assertEqual(
            documented,
            {'install', 'config', 'repair', 'workbench', 'status', 'doctor', 'engine', 'backup', 'help'},
        )

        self.assertIn('print_lobster_setup_help()', install_text)
        self.assertIn(
            '用法: openclaw-setup {install|config|repair|workbench|status|doctor|engine|migrate|backup|help}',
            install_text,
        )
        self.assertIn('openclaw-setup repair minimax', install_text)
        self.assertIn('bash "\\$config_menu" --repair-minimax', install_text)
        self.assertIn('如果只是 MiniMax Provider 重复或代理 URL 替换未生效', install_text)
        self.assertIn('local launcher="$LOBSTER_BIN_DIR/openclaw-setup"', install_text)
        self.assertIn('local compat_launcher="$LOBSTER_BIN_DIR/lobster-setup"', install_text)
        self.assertIn('lobster-setup ...          # 兼容旧命令，等价转发到 openclaw-setup', install_text)

        for command in ('config', 'repair', 'workbench', 'status', 'doctor', 'engine', 'backup'):
            self.assertIn(f'openclaw-setup {command}', readme_text)
        self.assertIn('openclaw-setup repair minimax', readme_text)

    def test_readme_guided_flow_prefers_openclaw_setup_over_raw_config_commands(self):
        readme_text = README.read_text(encoding='utf-8')
        self.assertIn('安装后执行 `openclaw-setup config`', readme_text)
        self.assertIn('对历史服务器执行 `openclaw-setup repair`', readme_text)
        self.assertIn('`openclaw-setup repair minimax`', readme_text)
        self.assertIn('需要可视化界面时执行 `openclaw-setup workbench`', readme_text)

    def test_readme_lists_dual_engine_install_and_auto_install_commands(self):
        readme_text = README.read_text(encoding='utf-8')
        self.assertIn('install-openclaw.sh', readme_text)
        self.assertIn('install-hermes.sh', readme_text)
        self.assertIn('--engine openclaw', readme_text)
        self.assertIn('--engine hermes', readme_text)
        self.assertIn('--engine both', readme_text)
        self.assertIn('install-openclaw.sh | bash -s -- --auto-confirm-all', readme_text)
        self.assertIn('install-hermes.sh | bash -s -- --auto-confirm-all', readme_text)
        self.assertIn('--auto-confirm-all --engine openclaw', readme_text)
        self.assertIn('--auto-confirm-all --engine hermes', readme_text)
        self.assertIn('--auto-confirm-all --engine both', readme_text)

    def test_readme_direct_helper_paths_match_installer_surface(self):
        readme_text = README.read_text(encoding='utf-8')
        install_text = INSTALL.read_text(encoding='utf-8')

        self.assertIn('bash ~/.openclaw/config-menu.sh', readme_text)
        self.assertIn('~/.openclaw/lobster-world.sh start', readme_text)
        self.assertIn('~/.openclaw/health-server.sh status', readme_text)
        self.assertNotIn('python3 ~/.openclaw/scripts/gateway-quota-enforcer.py status', readme_text)

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
        self.assertIn('bash ~/.openclaw/config-menu.sh --repair-minimax', readme_text)
        self.assertNotIn('bash ~/.openclaw/config-menu.sh --repair-' + 'pairing', readme_text)
        self.assertIn('bash ~/.openclaw/config-menu.sh --install-pixel-house', readme_text)

    def test_config_menu_help_shortcuts_align_with_readme_shortcuts(self):
        readme_text = README.read_text(encoding='utf-8')
        config_menu_text = CONFIG_MENU.read_text(encoding='utf-8')
        expected_shortcuts = (
            '--model-only',
            '--official-channels-only',
            '--repair-config',
            '--repair-minimax',
            '--install-pixel-house',
            '--engine-menu',
            '--remote-local-control',
        )
        for shortcut in expected_shortcuts:
            self.assertIn(shortcut, config_menu_text)
            self.assertIn(f'bash ~/.openclaw/config-menu.sh {shortcut}', readme_text)
        self.assertIn('openclaw-setup config --model-only', config_menu_text)
        self.assertIn('openclaw-setup config --official-channels-only', config_menu_text)
        self.assertIn('openclaw-setup config --engine-menu', config_menu_text)
        self.assertIn('openclaw-setup repair', config_menu_text)
        self.assertIn('openclaw-setup repair minimax', readme_text)

    def test_readme_documents_remote_local_control_as_optional(self):
        readme_text = README.read_text(encoding='utf-8')
        self.assertIn('openclaw-setup config --remote-local-control', readme_text)
        self.assertIn('bootstrap-local --cloud', readme_text)
        self.assertIn('install-tunnel-service --cloud', readme_text)
        self.assertIn('--local-user YOUR_LOCAL_LOGIN_USER', readme_text)
        self.assertIn('configure-local --pairing-file', readme_text)
        self.assertIn('OPENCLAW_REMOTE_LOCAL_PAIRING_FILE', readme_text)
        self.assertIn('desktop-write-article', readme_text)
        self.assertIn('反向 SSH', readme_text)
        self.assertIn('可选', readme_text)

    def test_config_menu_mentions_health_without_default_quota_proxy_under_pixel_house(self):
        config_menu_text = (ROOT / 'config-menu.sh').read_text(encoding='utf-8')
        self.assertIn('13146 健康检查', config_menu_text)
        self.assertNotIn('13147 配额强制', config_menu_text)
        self.assertIn('安装/修复像素小屋时会同步接线并启动健康检查服务', config_menu_text)

    def test_readme_does_not_recommend_legacy_pairing_or_13147_public_entry(self):
        readme_text = README.read_text(encoding='utf-8')
        self.assertNotIn('dashboard-pairing', readme_text)
        self.assertNotIn('repair-pairing', readme_text)
        self.assertNotIn('外部统一限流入口', readme_text)
        self.assertNotIn('外部统一入口', readme_text)
        self.assertNotIn('OPENCLAW_PUBLIC_API_URL=http://127.0.0.1:13147', readme_text)


if __name__ == '__main__':
    unittest.main()

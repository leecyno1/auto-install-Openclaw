import os
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CONFIG_MENU = ROOT / 'config-menu.sh'


class ConfigMenuShortcutsRuntimeTests(unittest.TestCase):
    def test_config_menu_shortcuts_route_without_interactive_tty(self):
        with tempfile.TemporaryDirectory() as td:
            home = Path(td)
            config_dir = home / '.openclaw'
            backup_dir = config_dir / 'backups'
            config_dir.mkdir(parents=True)
            backup_dir.mkdir(parents=True)
            script_copy = home / 'config-menu-shortcuts.sh'
            text = CONFIG_MENU.read_text(encoding='utf-8')
            stub_block = '''
startup_fast_config_sanitize_menu() { :; }
config_ai_model() { echo "SHORTCUT:MODEL:$*"; }
config_channels_official() { echo "SHORTCUT:CHANNELS:$*"; }
repair_runtime_config_preserve_data() { echo "SHORTCUT:REPAIR:$*"; }
install_pixel_house_stack_menu() { echo "SHORTCUT:PIXEL:$*"; }
manage_engine_menu() { echo "SHORTCUT:ENGINE:$*"; }
install_remote_local_control_menu() { echo "SHORTCUT:REMOTE_LOCAL:$*"; }
'''
            marker = '    # 启动阶段只做本地 JSON 快速修复，避免旧服务器在进入菜单前卡死。'
            text = text.replace(marker, stub_block + '\n' + marker, 1)
            script_copy.write_text(text, encoding='utf-8')
            script_copy.chmod(0o755)

            env = {
                'HOME': str(home),
                'PATH': '/usr/bin:/bin:/usr/sbin:/sbin',
            }

            cases = [
                (['bash', str(script_copy), '--model-only'], 'SHORTCUT:MODEL:'),
                (['bash', str(script_copy), '--official-channels-only'], 'SHORTCUT:CHANNELS:'),
                (['bash', str(script_copy), '--repair-config'], 'SHORTCUT:REPAIR:'),
                (['bash', str(script_copy), '--install-pixel-house'], 'SHORTCUT:PIXEL:'),
                (['bash', str(script_copy), '--engine-menu'], 'SHORTCUT:ENGINE:'),
                (['bash', str(script_copy), '--remote-local-control'], 'SHORTCUT:REMOTE_LOCAL:'),
            ]

            for cmd, expected in cases:
                result = subprocess.run(cmd, cwd=ROOT, text=True, capture_output=True, env=env)
                if result.returncode != 0:
                    raise AssertionError(
                        f"shortcut command failed: {' '.join(cmd)}\nSTDOUT:\n{result.stdout}\nSTDERR:\n{result.stderr}"
                    )
                self.assertIn(expected, result.stdout)


if __name__ == '__main__':
    unittest.main()

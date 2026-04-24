import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CONFIG_MENU = ROOT / 'config-menu.sh'


class ConfigMenuDeepRuntimeTests(unittest.TestCase):
    def test_model_only_shortcut_enters_model_menu_and_executes_a_real_branch(self):
        with tempfile.TemporaryDirectory() as td:
            home = Path(td)
            script_copy = home / 'config-menu-model-smoke.sh'
            text = CONFIG_MENU.read_text(encoding='utf-8')
            stub_block = '''
startup_fast_config_sanitize_menu() { :; }
clear_screen() { :; }
print_header() { :; }
print_divider() { :; }
print_equipment_slots_menu() { :; }
print_menu_item() { :; }
refresh_game_progress_profile_menu() { echo "MODEL:REFRESH"; }
run_official_model_onboard() { echo "MODEL:ONBOARD"; return 0; }
config_minimax() { echo "MODEL:MINIMAX"; }
config_image_provider_viviai() { echo "MODEL:VIVIAI"; }
press_enter() { :; }
log_info() { printf '%s\n' "$*"; }
log_error() { printf '%s\n' "$*"; }
openclaw_skill_fallback_init() { :; }
'''
            # 将 stub 插入到脚本开头，确保在任何函数调用之前定义
            text = stub_block + '\n' + text
            script_copy.write_text(text, encoding='utf-8')
            script_copy.chmod(0o755)

            env = {
                'HOME': str(home),
                'PATH': '/usr/bin:/bin:/usr/sbin:/sbin',
            }
            result = subprocess.run(
                ['bash', str(script_copy), '--model-only'],
                cwd=ROOT,
                text=True,
                capture_output=True,
                input='3\n0\n',
                env=env,
            )
            if result.returncode != 0:
                raise AssertionError(
                    f"model-only deep runtime failed\nSTDOUT:\n{result.stdout}\nSTDERR:\n{result.stderr}"
                )
            self.assertIn('MODEL:MINIMAX', result.stdout)
            self.assertIn('模型配置流程结束。', result.stdout)

    def test_official_channels_shortcut_enters_channel_menu_and_executes_a_real_branch(self):
        with tempfile.TemporaryDirectory() as td:
            home = Path(td)
            script_copy = home / 'config-menu-channels-smoke.sh'
            text = CONFIG_MENU.read_text(encoding='utf-8')
            stub_block = '''
startup_fast_config_sanitize_menu() { :; }
clear_screen() { :; }
print_header() { :; }
print_divider() { :; }
print_menu_item() { :; }
press_enter() { :; }
config_telegram() { echo "CHANNEL:TELEGRAM"; }
config_discord() { echo "CHANNEL:DISCORD"; }
config_whatsapp() { echo "CHANNEL:WHATSAPP"; }
config_slack() { echo "CHANNEL:SLACK"; }
config_feishu() { echo "CHANNEL:FEISHU"; }
config_signal() { echo "CHANNEL:SIGNAL"; }
config_msteams() { echo "CHANNEL:MSTEAMS"; }
config_mattermost() { echo "CHANNEL:MATTERMOST"; }
config_googlechat() { echo "CHANNEL:GOOGLECHAT"; }
config_matrix() { echo "CHANNEL:MATRIX"; }
config_line() { echo "CHANNEL:LINE"; }
config_nextcloud_talk() { echo "CHANNEL:NEXTCLOUD"; }
config_more_official_channels() { echo "CHANNEL:MORE"; }
log_error() { printf '%s\n' "$*"; }
openclaw_skill_fallback_init() { :; }
'''
            # 将 stub 插入到脚本开头，确保在任何函数调用之前定义
            text = stub_block + '\n' + text
            script_copy.write_text(text, encoding='utf-8')
            script_copy.chmod(0o755)

            env = {
                'HOME': str(home),
                'PATH': '/usr/bin:/bin:/usr/sbin:/sbin',
            }
            result = subprocess.run(
                ['bash', str(script_copy), '--official-channels-only'],
                cwd=ROOT,
                text=True,
                capture_output=True,
                input='5\n',
                env=env,
            )
            if result.returncode != 0:
                raise AssertionError(
                    f"official-channels-only deep runtime failed\nSTDOUT:\n{result.stdout}\nSTDERR:\n{result.stderr}"
                )
            self.assertIn('CHANNEL:FEISHU', result.stdout)
            self.assertIn('官方消息渠道配置流程结束。', result.stdout)


if __name__ == '__main__':
    unittest.main()

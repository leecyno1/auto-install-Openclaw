import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CONFIG_MENU = ROOT / 'config-menu.sh'
INSTALL = ROOT / 'install.sh'
COMMON = ROOT / 'scripts' / 'lib' / 'openclaw-common.sh'
SKILLS_LIB = ROOT / 'scripts' / 'lib' / 'skills.sh'
README = ROOT / 'README.md'

MINIMAX_OFFICIAL_SKILLS = [
    'android-native-dev', 'buddy-sings', 'flutter-dev', 'frontend-dev', 'fullstack-dev',
    'gif-sticker-maker', 'ios-application-dev', 'minimax-docx', 'minimax-multimodal-toolkit',
    'minimax-music-gen', 'minimax-music-playlist', 'minimax-pdf', 'minimax-xlsx',
    'pptx-generator', 'react-native-dev', 'shader-dev', 'vision-analysis',
]


def run_common(expr: str) -> str:
    cmd = f"source {COMMON}; {expr}"
    return subprocess.check_output(['bash', '-lc', cmd], text=True, cwd=ROOT).strip()


class ConfigSurfaceTests(unittest.TestCase):
    def test_config_menu_help_is_available_non_interactively(self):
        output = subprocess.check_output(
            ['bash', str(CONFIG_MENU), '--help'],
            text=True,
            cwd=ROOT,
        )
        self.assertIn('OpenClaw 配置菜单', output)
        self.assertIn('--install-pixel-house', output)
        self.assertIn('--engine-menu', output)
        self.assertIn('--model-only', output)
        self.assertIn('--official-channels-only', output)

    def test_config_menu_noninteractive_shortcuts_are_whitelisted_and_routed(self):
        text = CONFIG_MENU.read_text(encoding='utf-8')
        self.assertIn('allow_noninteractive_shortcut_menu()', text)
        self.assertIn(
            '--help|-h|--repair-config|--repair-pairing|--install-pixel-house|--engine-menu|--model-only|--official-channels-only',
            text,
        )
        self.assertIn('--model-only)', text)
        self.assertIn('config_ai_model', text)
        self.assertIn('--official-channels-only)', text)
        self.assertIn('config_channels_official', text)
        self.assertIn('--repair-config)', text)
        self.assertIn('repair_runtime_config_preserve_data', text)
        self.assertIn('--repair-pairing)', text)
        self.assertIn('repair_dashboard_pairing_only_menu', text)
        self.assertIn('--install-pixel-house)', text)
        self.assertIn('install_pixel_house_stack_menu', text)
        self.assertIn('--engine-menu)', text)
        self.assertIn('manage_engine_menu', text)

    def test_readme_uses_lobster_setup_as_primary_entry(self):
        text = README.read_text(encoding='utf-8')
        self.assertIn('lobster-setup config', text)
        self.assertIn('lobster-setup install', text)

    def test_advanced_settings_has_single_advanced_model_and_image_api_entry(self):
        text = CONFIG_MENU.read_text(encoding='utf-8')
        self.assertIn('print_menu_item "11" "高级模型配置（中/高档）"', text)
        self.assertIn('print_menu_item "12" "生图 API 配置（图片生成）"', text)
        self.assertNotIn('print_menu_item "12" "专家模型配置', text)
        self.assertIn('12)\n            config_image_provider_viviai', text)

    def test_legacy_expert_model_menu_is_not_user_facing_or_callable(self):
        text = CONFIG_MENU.read_text(encoding='utf-8')
        self.assertNotIn('configure_expert_model_menu()', text)
        self.assertNotIn('专家模型配置', text)

    def test_minimax_custom_provider_url_is_preserved_raw(self):
        self.assertEqual(
            run_common('openclaw_normalize_minimax_provider_url " https://api.sfkey.cn "'),
            'https://api.sfkey.cn',
        )
        self.assertEqual(
            run_common('openclaw_resolve_minimax_provider_base_url minimax "https://api.sfkey.cn"'),
            'https://api.sfkey.cn',
        )

    def test_minimax_official_defaults_keep_anthropic_path(self):
        self.assertEqual(
            run_common('openclaw_resolve_minimax_provider_base_url minimax ""'),
            'https://api.minimax.io/anthropic',
        )
        self.assertEqual(
            run_common('openclaw_resolve_minimax_provider_base_url minimax-cn ""'),
            'https://api.minimaxi.com/anthropic',
        )

    def test_image_api_url_split_supports_root_and_full_endpoint(self):
        self.assertEqual(
            run_common('openclaw_split_api_url "https://api.viviai.cc" "/v1/chat/completions"'),
            'https://api.viviai.cc|/v1/chat/completions',
        )
        self.assertEqual(
            run_common('openclaw_split_api_url "https://api.viviai.cc/v1/chat/completions" "/v1/chat/completions"'),
            'https://api.viviai.cc|/v1/chat/completions',
        )

    def test_minimax_official_skills_are_local_and_wired_via_shared_skill_catalog(self):
        install_text = INSTALL.read_text(encoding='utf-8')
        menu_text = CONFIG_MENU.read_text(encoding='utf-8')
        skills_lib_text = SKILLS_LIB.read_text(encoding='utf-8')
        for skill in MINIMAX_OFFICIAL_SKILLS:
            self.assertTrue((ROOT / 'skills' / 'default' / skill / 'SKILL.md').is_file(), skill)
            self.assertIn(skill, skills_lib_text)
        self.assertIn('openclaw_skill_fallback_init()', skills_lib_text)
        self.assertIn('openclaw_skill_manifest_list()', skills_lib_text)
        self.assertIn('load_openclaw_skills_lib_install()', install_text)
        self.assertIn('load_openclaw_skills_lib_menu()', menu_text)
        self.assertIn('scripts/lib/skills.sh', install_text)
        self.assertIn('scripts/lib/skills.sh', menu_text)
        self.assertIn('openclaw_skill_fallback_init install', install_text)
        self.assertIn('openclaw_skill_fallback_init menu', menu_text)
        self.assertIn('openclaw_skill_manifest_list minimax_official', install_text)
        self.assertIn('openclaw_skill_manifest_list minimax_official', menu_text)

    def test_super_skill_local_import_entries_do_not_use_author_machine_paths(self):
        text = CONFIG_MENU.read_text(encoding='utf-8')
        self.assertNotIn('/Users/lichengyin/.codex/skills/ai-meeting-notes', text)
        self.assertNotIn('/Users/lichengyin/.codex/skills/tmux', text)
        self.assertIn('install_super_skill_from_local "ai-meeting-notes" "ai-meeting-notes"', text)
        self.assertIn('install_super_skill_from_local "tmux" "tmux"', text)

    def test_super_skill_repo_entries_prefer_local_bundle_before_remote_repo(self):
        text = CONFIG_MENU.read_text(encoding='utf-8')
        self.assertIn('install_super_skill_from_bundle_or_repo()', text)
        self.assertIn('安装 Baoyu 系列技能（本地优先）', text)
        self.assertIn('安装 wechat-skills（本地优先）', text)
        self.assertIn(
            'install_super_skill_from_bundle_or_repo "baoyu-skills" "https://github.com/JimLiu/baoyu-skills.git" "baoyu-skills"',
            text,
        )
        self.assertIn(
            'install_super_skill_from_bundle_or_repo "wechat-skills" "https://github.com/gainubi/wechat-skills.git" "wechat-skills"',
            text,
        )

    def test_official_plugin_install_prefers_local_bundle_and_remote_fallback_is_optional(self):
        text = CONFIG_MENU.read_text(encoding='utf-8')
        self.assertIn('install_official_plugin_local_first()', text)
        self.assertIn('本地包安装插件 -> 启用插件 -> 渠道配置向导', text)
        self.assertIn('插件安装失败（未启用远端兜底时不会从网络下载）', text)
        self.assertIn('OPENCLAW_ALLOW_REMOTE_PLUGIN_FALLBACK=1 openclaw plugins install $FEISHU_PLUGIN_OFFICIAL', text)


if __name__ == '__main__':
    unittest.main()

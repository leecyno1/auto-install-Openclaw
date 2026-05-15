import subprocess
import importlib.util
import unittest
import json
import os
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CONFIG_MENU = ROOT / 'config-menu.sh'
INSTALL = ROOT / 'install.sh'
COMMON = ROOT / 'scripts' / 'lib' / 'openclaw-common.sh'
SKILLS_LIB = ROOT / 'scripts' / 'lib' / 'skills.sh'
README = ROOT / 'README.md'
BACKEND_APP = ROOT / 'subprojects' / 'lobster-sanctum-ui' / 'vendor' / 'star-office-ui' / 'backend' / 'app.py'
BACKEND_DIR = BACKEND_APP.parent
BOUTIQUE_SKILLS = ROOT.parent / 'boutique-openclaw-skills' / 'skills' / 'default'

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
        self.assertIn('大圣之怒配置中心', output)
        self.assertIn('--install-pixel-house', output)
        self.assertIn('--remote-local-control', output)
        self.assertIn('--remote-local-bootstrap', output)
        self.assertIn('--engine-menu', output)
        self.assertIn('--model-only', output)
        self.assertIn('--official-channels-only', output)
        self.assertIn('--repair-minimax', output)

    def test_config_menu_noninteractive_shortcuts_are_whitelisted_and_routed(self):
        text = CONFIG_MENU.read_text(encoding='utf-8')
        self.assertIn('allow_noninteractive_shortcut_menu()', text)
        self.assertIn(
            '--help|-h|--repair-config|--repair-minimax|--install-pixel-house|--remote-local-control|--remote-local-bootstrap|--engine-menu|--model-only|--official-channels-only',
            text,
        )
        self.assertIn('--model-only)', text)
        self.assertIn('config_ai_model', text)
        self.assertIn('--official-channels-only)', text)
        self.assertIn('config_channels_official', text)
        self.assertIn('--repair-config)', text)
        self.assertIn('repair_runtime_config_preserve_data', text)
        self.assertIn('--repair-minimax)', text)
        self.assertIn('repair_minimax_provider_only_menu', text)
        self.assertIn('--remote-local-control)', text)
        self.assertIn('install_remote_local_control_menu', text)
        self.assertIn('--remote-local-bootstrap)', text)
        self.assertIn('bootstrap_remote_local_control_menu', text)

    def test_installer_and_menu_prepare_website_dashboard_integration(self):
        install_text = INSTALL.read_text(encoding='utf-8')
        menu_text = CONFIG_MENU.read_text(encoding='utf-8')
        common_text = COMMON.read_text(encoding='utf-8')

        for text in (install_text, menu_text):
            self.assertIn('OPENCLAW_DASHBOARD_PORT', text)
            self.assertIn('HERMES_DASHBOARD_PORT', text)
            self.assertIn('9119', text)
            self.assertIn('gateway.controlUi.allowedOrigins', text)
            self.assertIn('OPENCLAW_DASHBOARD_ALLOWED_ORIGINS', text)
            self.assertIn('https://monkeykingfury.com', text)
            self.assertIn('gateway.controlUi.allowInsecureAuth', text)
            self.assertIn('gateway.controlUi.dangerouslyDisableDeviceAuth', text)
            self.assertIn('patch_openclaw_dashboard_json', text)

        self.assertIn('ensure_website_dashboard_integration_install', install_text)
        self.assertIn('gateway.controlUi.dangerouslyDisableDeviceAuth" "false"', install_text)
        self.assertIn("control['dangerouslyDisableDeviceAuth'] = False", install_text)
        self.assertIn('gateway.controlUi.dangerouslyDisableDeviceAuth" "false"', menu_text)
        self.assertIn("control['dangerouslyDisableDeviceAuth'] = False", menu_text)
        self.assertIn('ensure_website_dashboard_integration_menu', menu_text)
        self.assertIn('start_hermes_dashboard_install', install_text)
        self.assertIn('start_hermes_dashboard_menu', menu_text)
        self.assertIn('HERMES_DASHBOARD_HOST="127.0.0.1"', install_text)
        self.assertIn('HERMES_DASHBOARD_HOST="127.0.0.1"', menu_text)
        self.assertIn('HERMES_CHAT_PORT_DEFAULT="${HERMES_CHAT_PORT:-8000}"', install_text)
        self.assertIn('HERMES_CHAT_PORT_DEFAULT="${HERMES_CHAT_PORT:-8000}"', menu_text)
        self.assertIn('start_hermes_openai_bridge_install', install_text)
        self.assertIn('start_hermes_openai_bridge_menu', menu_text)
        self.assertIn('openclaw_install_hermes_openai_bridge', text)
        self.assertIn('/v1/chat/completions', text)
        self.assertIn('openclaw_apply_hermes_default_model_from_env', common_text)
        self.assertIn('cleanup_custom_model_provider_env_install', install_text)
        self.assertIn('cleanup_custom_model_provider_env_menu', menu_text)
        self.assertNotIn('--repair-' + 'pairing', text)
        self.assertNotIn('repair_dashboard_' + 'pairing_only_menu', text)
        self.assertIn('--install-pixel-house)', text)
        self.assertIn('install_pixel_house_stack_menu', text)
        self.assertIn('--engine-menu)', text)
        self.assertIn('manage_engine_menu', text)

    def test_readme_uses_openclaw_setup_as_primary_entry(self):
        text = README.read_text(encoding='utf-8')
        self.assertIn('openclaw-setup config', text)
        self.assertIn('openclaw-setup install', text)
        self.assertIn('lobster-setup', text)
        self.assertIn('install-openclaw.sh', text)
        self.assertIn('install-hermes.sh', text)

    def test_provider_menu_is_generic_and_supports_custom_provider(self):
        text = CONFIG_MENU.read_text(encoding='utf-8')
        self.assertIn('官方 Provider 预设配置', text)
        self.assertIn('自定义 Provider 高级配置', text)
        self.assertIn('生图 Provider 配置', text)
        self.assertNotIn('MiniMax 自定义 Provider 地址', text)
        self.assertIn('config_provider_presets_menu()', text)
        self.assertIn('config_custom_provider_menu()', text)
        self.assertIn('save_custom_provider_config()', text)
        self.assertIn('OPENCLAW_CUSTOM_PROVIDER_ID', text)
        self.assertIn('OPENCLAW_ACTIVE_PROVIDER_PRESET', text)

    def test_config_menu_has_runtime_cache_and_runtime_snapshot_resolution(self):
        text = CONFIG_MENU.read_text(encoding='utf-8')
        self.assertIn('CONFIG_MENU_CACHE_FILE=', text)
        self.assertIn('invalidate_runtime_cache_menu()', text)
        self.assertIn('CONFIG_MENU_MODEL_REF_CACHE=', text)
        self.assertIn('RUNTIME_REPO_DIR_MENU="$HOME/.openclaw/runtime/installer-repo"', text)
        self.assertIn('"$RUNTIME_REPO_DIR_MENU/$relative_path"', text)
        self.assertIn('"$RUNTIME_REPO_DIR_MENU/scripts/lobster-world.sh"', text)

    def test_installer_persists_cli_access_and_noninteractive_repair(self):
        text = INSTALL.read_text(encoding='utf-8')
        self.assertIn('persist_cli_command_access_install()', text)
        self.assertIn('persist_openclaw_command_access_install', text)
        self.assertIn('persist_hermes_command_access_install', text)
        self.assertIn('sync_minimax_auth_profile_install', text)
        self.assertIn('auth-profiles.json', text)
        self.assertIn('ln -sf "$command_path" "/usr/local/bin/$command_name"', text)
        self.assertIn("printf 'y\\n\\n' | bash \"$config_menu_path\" --repair-config", text)
        self.assertIn('配置清理失败，继续安装', text)
        self.assertIn('return 0', text)

    def test_install_launchers_prefer_runtime_snapshot_repo(self):
        text = INSTALL.read_text(encoding='utf-8')
        self.assertIn('runtime_repo_snapshot_root_install()', text)
        self.assertIn('sync_runtime_repo_snapshot_install()', text)
        self.assertIn('"$runtime_repo/$relative_path"', text)
        self.assertIn('"$runtime_repo/config-menu.sh"', text)
        self.assertIn('install_script="$runtime_repo/install.sh"', text)
        self.assertIn('sync_runtime_repo_snapshot_install >/dev/null 2>&1 || true', text)

    def test_glm_configuration_supports_custom_base_url(self):
        text = CONFIG_MENU.read_text(encoding='utf-8')
        self.assertIn('ZAI_BASE_URL', text)
        self.assertIn('输入 Base URL', text)

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
        backend_text = BACKEND_APP.read_text(encoding='utf-8')
        web_text = (ROOT / 'subprojects' / 'lobster-sanctum-ui' / 'web' / 'configure.js').read_text(encoding='utf-8')
        self.assertIn('"minimax": str(env_data.get("OPENCLAW_MINIMAX_PROVIDER_URL") or "https://api.minimax.io/anthropic")', backend_text)
        self.assertIn('{ id: "minimax", label: "MiniMax", apiType: "anthropic-messages", baseUrl: "https://api.minimax.io/anthropic"', web_text)

    def test_minimax_bundle_defaults_cover_multimodal_and_latest_music_model(self):
        install_text = INSTALL.read_text(encoding='utf-8')
        menu_text = CONFIG_MENU.read_text(encoding='utf-8')
        self.assertIn('MINIMAX_IMAGE_MODEL_DEFAULT="${MINIMAX_IMAGE_MODEL:-image-01}"', install_text)
        self.assertIn('MINIMAX_MCP_BASE_PATH_DEFAULT="${MINIMAX_MCP_BASE_PATH:-$MINIMAX_MULTIMODAL_OUTPUT_PATH_DEFAULT}"', install_text)
        self.assertIn('MINIMAX_MUSIC_MODEL_DEFAULT="${MINIMAX_MUSIC_MODEL:-music-2.6}"', install_text)
        self.assertIn('upsert_minimax_multimodal_env_defaults_install()', install_text)
        self.assertIn('sync_minimax_image_provider_install()', install_text)
        self.assertIn("delete cfg.models.providers[otherProvider];", install_text)
        self.assertIn('MINIMAX_MUSIC_MODEL_DEFAULT="${MINIMAX_MUSIC_MODEL:-music-2.6}"', menu_text)
        self.assertIn('upsert_minimax_multimodal_env_defaults_menu()', menu_text)
        self.assertIn('sync_minimax_image_provider_menu()', menu_text)
        self.assertIn("delete cfg.models.providers[otherProvider];", menu_text)

    def test_minimax_scripts_read_configured_host_and_output_path(self):
        web_search = (BOUTIQUE_SKILLS / 'minimax-web-search' / 'scripts' / 'web_search.py').read_text(encoding='utf-8')
        vision = (BOUTIQUE_SKILLS / 'minimax-image-understanding' / 'scripts' / 'understand_image.py').read_text(encoding='utf-8')
        self.assertIn("config.get('mcp_base_path')", web_search)
        self.assertIn("config.get('api_host')", web_search)
        self.assertIn("cfg.get('mcp_base_path')", vision)
        self.assertIn("cfg.get('resource_mode')", vision)

    def test_backend_minimax_apply_replaces_stale_provider_entries_instead_of_accumulating(self):
        with tempfile.TemporaryDirectory() as td:
            home = Path(td) / '.openclaw'
            (home / 'profile').mkdir(parents=True)
            (home / 'env').write_text('', encoding='utf-8')
            (home / 'openclaw.json').write_text(json.dumps({
                'models': {'mode': 'merge', 'providers': {
                    'minimax': {'baseUrl': 'https://old.example/anthropic', 'models': [{'id': 'legacy', 'name': 'legacy'}]},
                    'minimax-cn': {'baseUrl': 'https://api.minimaxi.com/anthropic', 'models': [{'id': 'MiniMax-M2.7', 'name': 'MiniMax'}]},
                }},
                'agents': {'defaults': {'models': {
                    'minimax/MiniMax-M2.7': {'alias': 'bad'},
                    'minimax-cn/MiniMax-M2.7-highspeed': {'alias': 'old'},
                }}},
            }, ensure_ascii=False, indent=2), encoding='utf-8')
            sys.path.insert(0, str(BACKEND_DIR))
            os.environ['OPENCLAW_HOME'] = str(home)
            spec = importlib.util.spec_from_file_location('star_office_backend_test', BACKEND_APP)
            backend = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(backend)
            backend._apply_provider_config({
                'preset': 'minimax-cn',
                'providerId': 'minimax-cn',
                'displayName': 'MiniMax',
                'baseUrl': 'https://api.sfkey.cn',
                'model': 'MiniMax-M2.7-highspeed',
                'apiType': 'anthropic-messages',
                'apiKey': 'sk-test',
                'keepExistingKey': True,
            }, {})
            data = json.loads((home / 'openclaw.json').read_text(encoding='utf-8'))
            self.assertEqual(list(data['models']['providers'].keys()), ['minimax-cn'])
            self.assertEqual(list(data['agents']['defaults']['models'].keys()), ['minimax-cn/MiniMax-M2.7-highspeed'])

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
            self.assertTrue((BOUTIQUE_SKILLS / skill / 'SKILL.md').is_file(), skill)
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

    def test_default_skills_sync_uses_boutique_repository(self):
        install_text = INSTALL.read_text(encoding='utf-8')
        menu_text = CONFIG_MENU.read_text(encoding='utf-8')
        module_text = (ROOT / 'scripts' / 'modules' / 'skills.sh').read_text(encoding='utf-8')
        readme_text = README.read_text(encoding='utf-8')

        for text in (install_text, menu_text, module_text):
            self.assertIn('boutique-openclaw-skills', text)
            self.assertIn('OPENCLAW_SKILLS_REPO_URL', text)
            self.assertIn('https://gitee.com/leecyno1/boutique-openclaw-skills.git', text)
            self.assertIn('OPENCLAW_SKILLS_REPO_GITHUB_URL', text)
            self.assertIn('tiers/low.json', text)

        self.assertIn('技能如果需要同步从 boutique 仓库进行同步', readme_text)
        self.assertIn('boutique-openclaw-skills', readme_text)

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

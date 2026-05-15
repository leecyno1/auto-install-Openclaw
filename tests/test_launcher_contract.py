import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BACKUP_MANAGER = ROOT / 'scripts' / 'backup-manager.sh'


class LauncherContractTests(unittest.TestCase):
    def test_install_script_defines_primary_and_compat_launchers(self):
        install_text = (ROOT / 'install.sh').read_text(encoding='utf-8')
        self.assertIn('print_lobster_setup_quick_commands()', install_text)
        self.assertIn('print_post_install_config_hint()', install_text)
        self.assertIn('local launcher="$LOBSTER_BIN_DIR/openclaw-setup"', install_text)
        self.assertIn('local compat_launcher="$LOBSTER_BIN_DIR/lobster-setup"', install_text)
        self.assertIn('print_lobster_setup_help()', install_text)
        self.assertIn('cmd="\\${1:-config}"', install_text)
        self.assertIn('help|-h|--help)', install_text)
        self.assertIn(
            '用法: openclaw-setup {install|config|repair|workbench|status|doctor|engine|migrate|backup|help}',
            install_text,
        )
        self.assertIn('像素小屋补装/修复后会同步接线并启动 13146 健康检查', install_text)
        self.assertNotIn('像素小屋补装/修复后会同步接线 13146 健康检查 与 13147 配额强制', install_text)

    def test_install_script_launcher_routes_key_commands(self):
        install_text = (ROOT / 'install.sh').read_text(encoding='utf-8')
        self.assertIn('bash "\\$config_menu" "\\$@"', install_text)
        self.assertIn('bash "\\$config_menu" --repair-config "\\$@"', install_text)
        self.assertIn('bash "\\$config_menu" --engine-menu "\\$@"', install_text)
        self.assertIn('bash "\\$workbench" "\\${1:-status}"', install_text)
        self.assertIn('bash "\\$HOME/.openclaw/backup-manager.sh" "\\$@"', install_text)
        self.assertIn('exec "$launcher" "\\$@"', install_text)

    def test_install_script_installs_backup_manager_target_used_by_launcher(self):
        install_text = (ROOT / 'install.sh').read_text(encoding='utf-8')
        self.assertIn('install_backup_manager_script()', install_text)
        self.assertIn('scripts/backup-manager.sh', install_text)
        self.assertIn('$CONFIG_DIR/backup-manager.sh', install_text)
        self.assertIn('chmod +x "$CONFIG_DIR/backup-manager.sh"', install_text)
        self.assertIn('install_backup_manager_script', install_text)

    def test_install_script_installs_health_and_quota_helpers_exposed_in_readme(self):
        install_text = (ROOT / 'install.sh').read_text(encoding='utf-8')
        self.assertIn('install_health_server_launcher()', install_text)
        self.assertIn('scripts/health-server.sh', install_text)
        self.assertIn('$CONFIG_DIR/health-server.sh', install_text)
        self.assertIn('install_gateway_quota_enforcer_script()', install_text)
        self.assertIn('scripts/gateway-quota-enforcer.py', install_text)
        self.assertIn('$CONFIG_DIR/scripts/gateway-quota-enforcer.py', install_text)
        self.assertIn('scripts/media_quota.py', install_text)
        self.assertIn('$CONFIG_DIR/scripts/media_quota.py', install_text)
        self.assertIn('mkdir -p "$CONFIG_DIR/scripts"', install_text)
        self.assertIn('install_health_server_launcher', install_text)
        self.assertIn('install_gateway_quota_enforcer_script', install_text)

    def test_install_script_prepares_data_disk_storage_and_traffic_controls(self):
        install_text = (ROOT / 'install.sh').read_text(encoding='utf-8')
        self.assertIn('setup_data_disk_storage_install()', install_text)
        self.assertIn('resolve_openclaw_data_root_install()', install_text)
        self.assertIn('/data/openclaw-storage', install_text)
        self.assertIn('migrate_path_to_symlink_install "$CONFIG_DIR/backups"', install_text)
        self.assertIn('migrate_path_to_symlink_install "$HOME/.openclaw-upgrade-backups"', install_text)
        self.assertIn('migrate_path_to_symlink_install "$HOME/.cache"', install_text)
        self.assertIn('OPENCLAW_DATA_ROOT', install_text)
        self.assertIn('OPENCLAW_TRAFFIC_CONTROL_ENABLED', install_text)
        self.assertIn('OPENCLAW_QUOTA_ENFORCER_MODE', install_text)
        self.assertIn('OPENCLAW_MEDIA_QUOTA_STATE_FILE', install_text)

    def test_install_script_installs_remote_local_control_helper(self):
        install_text = (ROOT / 'install.sh').read_text(encoding='utf-8')
        self.assertIn('install_remote_local_control_helper()', install_text)
        self.assertIn('scripts/remote-local-control.sh', install_text)
        self.assertIn('$CONFIG_DIR/remote-local-control.sh', install_text)
        self.assertIn('chmod +x "$CONFIG_DIR/remote-local-control.sh"', install_text)
        self.assertIn('install_remote_local_control_helper', install_text)

    def test_remote_local_control_helper_is_opt_in_and_uses_safe_reverse_ssh_defaults(self):
        helper = ROOT / 'scripts' / 'remote-local-control.sh'
        text = helper.read_text(encoding='utf-8')
        self.assertIn('install-local', text)
        self.assertIn('install-cloud', text)
        self.assertIn('start-tunnel', text)
        self.assertIn('openclaw-local-command-gate', text)
        self.assertIn('-R 127.0.0.1:${port}:127.0.0.1:${local_port}', text)
        self.assertIn('no-agent-forwarding,no-X11-forwarding,no-pty', text)
        self.assertIn('SSH_ORIGINAL_COMMAND', text)

    def test_remote_local_control_helper_provides_local_bootstrap_and_desktop_whitelist(self):
        helper = ROOT / 'scripts' / 'remote-local-control.sh'
        text = helper.read_text(encoding='utf-8')
        self.assertIn('bootstrap-local', text)
        self.assertIn('desktop-create-folder', text)
        self.assertIn('desktop-write-article', text)
        self.assertIn('safe_leaf_name()', text)
        self.assertIn('base64 --decode', text)
        self.assertIn('command="$gate_path",no-agent-forwarding,no-X11-forwarding,no-pty', text)

    def test_remote_local_control_helper_can_install_persistent_tunnel_service(self):
        helper = ROOT / 'scripts' / 'remote-local-control.sh'
        text = helper.read_text(encoding='utf-8')
        self.assertIn('install-tunnel-service', text)
        self.assertIn('openclaw-local-tunnel', text)
        self.assertIn('LaunchAgents', text)
        self.assertIn('systemd/user', text)
        self.assertIn('start-tunnel --cloud', text)

    def test_remote_local_control_helper_supports_local_configure_pairing_and_cloud_ssh_port(self):
        helper = ROOT / 'scripts' / 'remote-local-control.sh'
        text = helper.read_text(encoding='utf-8')
        self.assertIn('configure-local', text)
        self.assertIn('--pairing-file', text)
        self.assertIn('--cloud-ssh-port', text)
        self.assertIn('OPENCLAW_REMOTE_LOCAL_PAIRING_FILE', text)
        self.assertIn('OPENCLAW_REMOTE_LOCAL_CLOUD_SSH_PORT', text)
        self.assertIn('read_pairing_value()', text)
        self.assertIn('-p "$cloud_ssh_port"', text)

    def test_env_exports_are_shell_quoted_for_values_with_spaces(self):
        install_text = (ROOT / 'install.sh').read_text(encoding='utf-8')
        menu_text = (ROOT / 'config-menu.sh').read_text(encoding='utf-8')
        self.assertIn('quote_env_value_install()', install_text)
        self.assertIn('quoted_value="$(quote_env_value_install "$value")"', install_text)
        self.assertIn('awk -v k="$key" -v v="$quoted_value"', install_text)
        self.assertIn('quote_env_value_menu()', menu_text)
        self.assertIn('quoted_value="$(quote_env_value_menu "$value")"', menu_text)
        self.assertIn('awk -v k="$key" -v v="$quoted_value"', menu_text)

    def test_auto_confirm_preserves_explicit_rule_profile(self):
        install_text = (ROOT / 'install.sh').read_text(encoding='utf-8')
        self.assertIn('if [ -z "${OPENCLAW_RULE_PROFILE:-}" ] && [ -z "${RULE_PROFILE_SELECTED:-}" ]; then', install_text)
        self.assertIn('RULE_PROFILE_SELECTED="low"', install_text)

    def test_minimax_provider_respects_openai_v1_api_type(self):
        install_text = (ROOT / 'install.sh').read_text(encoding='utf-8')
        self.assertIn('local custom_api_type="${5:-}"', install_text)
        self.assertIn("baseUrl.includes('/v1') ? 'openai-completions' : 'anthropic-messages'", install_text)
        self.assertIn('api: apiType', install_text)
        self.assertIn('ensure_minimax_provider_config "$AI_PROVIDER" "$AI_MODEL" "$openclaw_json" "${OPENCLAW_MINIMAX_PROVIDER_URL:-}" "${AI_API_TYPE:-}"', install_text)

    def test_installer_supports_repeatable_extra_models_and_image_capability_chain(self):
        install_text = (ROOT / 'install.sh').read_text(encoding='utf-8')
        common_text = (ROOT / 'scripts' / 'lib' / 'openclaw-common.sh').read_text(encoding='utf-8')
        readme_text = (ROOT / 'README.md').read_text(encoding='utf-8')
        self.assertIn('--extra-model <spec>', install_text)
        self.assertIn('append_extra_model_spec_install "$2"', install_text)
        self.assertIn('OPENCLAW_EXTRA_MODELS', install_text)
        self.assertIn('apply_extra_models_install()', install_text)
        self.assertIn('scripts/lib/model_registry.py', install_text)
        self.assertIn('agent_models_json="$HOME/.openclaw/agents/main/agent/models.json"', install_text)
        self.assertIn('capabilities_json="$HOME/.openclaw/model-capabilities.json"', install_text)
        self.assertIn('OPENCLAW_ROUTER_BACKEND', install_text)
        self.assertIn('OPENCLAW_ROUTER_STRATEGY', install_text)
        self.assertIn('build_model_registry_specs_install()', install_text)
        self.assertIn('OPENCLAW_EXTRA_MODELS', common_text)
        self.assertIn('OPENCLAW_ROUTER_BACKEND', common_text)
        self.assertIn('OPENCLAW_ROUTER_STRATEGY', common_text)
        self.assertIn('image_tool=responses-image-generation', readme_text)
        self.assertIn('gpt-5.5', readme_text)

    def test_install_script_keeps_remote_plugin_fallback_optional(self):
        install_text = (ROOT / 'install.sh').read_text(encoding='utf-8')
        self.assertIn('OPENCLAW_ALLOW_REMOTE_PLUGIN_FALLBACK', install_text)
        self.assertIn('本地包缺失或安装失败时，再按需尝试远端兜底', install_text)
        self.assertIn('if [ "${OPENCLAW_ALLOW_REMOTE_PLUGIN_FALLBACK:-0}" = "1" ] && openclaw_plugins_install_with_retry_install "$spec"; then', install_text)

    def test_install_script_wires_health_helper_into_pixel_house_startup_without_default_quota_proxy(self):
        install_text = (ROOT / 'install.sh').read_text(encoding='utf-8')
        self.assertIn('LOBSTER_HEALTH_SERVICE_NAME="lobster-health.service"', install_text)
        self.assertIn('LOBSTER_QUOTA_SERVICE_NAME="lobster-quota-enforcer.service"', install_text)
        self.assertIn('run_as_root systemctl enable "$LOBSTER_WORLD_SERVICE_NAME" "$LOBSTER_PROJECTION_SERVICE_NAME" "$LOBSTER_BRIDGE_SERVICE_NAME" "$LOBSTER_HEALTH_SERVICE_NAME"', install_text)
        self.assertNotIn('run_as_root systemctl restart "$LOBSTER_QUOTA_SERVICE_NAME"', install_text)
        self.assertNotIn('nohup python3 "$CONFIG_DIR/scripts/gateway-quota-enforcer.py" restart >/tmp/openclaw-quota-enforcer.log 2>&1 &', install_text)
        self.assertIn('run_as_root systemctl restart "$LOBSTER_HEALTH_SERVICE_NAME"', install_text)
        self.assertIn('HEALTH_PORT="13146" "$CONFIG_DIR/health-server.sh" restart', install_text)

    def test_install_script_does_not_write_13147_as_default_public_api(self):
        install_text = (ROOT / 'install.sh').read_text(encoding='utf-8')
        self.assertNotIn('upsert_env_export_install "OPENCLAW_PUBLIC_API_URL" "http://127.0.0.1:13147"', install_text)
        self.assertNotIn('upsert_env_export_install "OPENCLAW_QUOTA_ENFORCER_URL" "http://127.0.0.1:13147"', install_text)

    def test_backup_manager_cron_uses_installed_script_path(self):
        text = BACKUP_MANAGER.read_text(encoding='utf-8')
        self.assertIn('BACKUP_MANAGER_SELF=', text)
        self.assertIn('local cron_cmd="$BACKUP_MANAGER_SELF create --auto >> /tmp/openclaw-backup.log 2>&1"', text)

    def test_backup_manager_does_not_copy_backups_directory_into_itself(self):
        text = BACKUP_MANAGER.read_text(encoding='utf-8')
        self.assertNotIn('cp -r "$CONFIG_DIR"/* "$backup_dir/"', text)
        self.assertIn('find "$CONFIG_DIR" -mindepth 1 -maxdepth 1', text)
        self.assertIn('! -name "$(basename "$BACKUP_BASE")"', text)

    def test_backup_manager_treats_auto_flag_as_timestamped_backup(self):
        text = BACKUP_MANAGER.read_text(encoding='utf-8')
        self.assertIn('if [ "${1:-}" = "--auto" ]; then', text)
        self.assertIn('create_backup ""', text)

    def test_backup_manager_restore_excludes_backup_metadata_files(self):
        text = BACKUP_MANAGER.read_text(encoding='utf-8')
        self.assertNotIn('cp -r "$backup_dir"/* "$CONFIG_DIR/"', text)
        self.assertIn('! -name "backup.json"', text)
        self.assertIn('! -name "env.redacted"', text)
        self.assertIn('! -name "env.original"', text)

    def test_install_script_uses_shared_launcher_and_config_hints(self):
        install_text = (ROOT / 'install.sh').read_text(encoding='utf-8')
        self.assertIn('print_lobster_setup_quick_commands "compact"', install_text)
        self.assertIn('print_lobster_setup_quick_commands "full"', install_text)
        self.assertIn('print_post_install_config_hint "prompt"', install_text)
        self.assertIn('print_post_install_config_hint "auto"', install_text)
        self.assertIn('print_post_install_config_hint "later"', install_text)
        self.assertIn('openclaw-setup config', install_text)
        self.assertIn('openclaw-setup engine', install_text)
        self.assertIn('lobster-setup ...          # 兼容旧命令，等价转发到 openclaw-setup', install_text)
        self.assertIn('像素小屋补装/修复后会自动接线并启动健康检查服务', install_text)


if __name__ == '__main__':
    unittest.main()

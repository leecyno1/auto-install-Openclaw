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

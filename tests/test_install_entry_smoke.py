import os
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
INSTALL = ROOT / 'install.sh'


class InstallEntrySmokeTests(unittest.TestCase):
    def test_install_entry_auto_confirm_all_runs_main_flow_and_installs_core_artifacts(self):
        with tempfile.TemporaryDirectory() as td:
            home = Path(td)
            patched = ROOT / f'.tmp-install-entry-smoke-{os.getpid()}.sh'
            try:
                install_text = INSTALL.read_text(encoding='utf-8')
                prefix = install_text.split("\n# 始终输出收尾提示", 1)[0]
                prelude = r'''
openclaw_skill_fallback_init() { :; }
openclaw_skill_manifest_list() { return 1; }
openclaw_skill_manifest_default_sentinels() { return 1; }
'''
                overrides = r'''
print_banner() { :; }
print_install_plan() { :; }
clean_legacy_config_if_needed() { :; }
detect_os() { :; }
check_root() { :; }
ensure_sudo_privileges() { :; }
install_dependencies() { :; }
install_channel_assets() { :; }
cleanup_stale_plugin_state() { :; }
apply_default_feishu_runtime_flags() { :; }
setup_identity() { :; }
apply_vendor_rule_profile() { :; }
apply_default_security_baseline() { :; }
start_pixel_house_stack_install() { :; }
verify_pixel_house_ready_install() { return 1; }
setup_daemon() { :; }
start_openclaw_service() { :; }
reset_gateway_chat_history_for_fresh_start() { :; }
apply_default_welcome_after_session_reset() { :; }
persist_lobster_engine_state_install() { :; }
run_config_menu() { :; }
run_hermes_status_summary() { :; }
print_exit_hint() { :; }
pixel_house_systemd_available_install() { return 1; }
install_openclaw() {
    mkdir -p "$HOME/.local/bin"
    cat > "$HOME/.local/bin/openclaw" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
  --version) echo "openclaw-smoke-0.0.0" ;;
  doctor) echo "OPENCLAW_DOCTOR" ;;
  gateway)
    case "${2:-}" in
      status) echo "OPENCLAW_GATEWAY_STATUS" ;;
      start|restart|stop|install) exit 0 ;;
    esac
    ;;
  models)
    case "${2:-}" in
      set|status) exit 0 ;;
    esac
    ;;
  config)
    case "${2:-}" in
      get) exit 0 ;;
    esac
    ;;
esac
exit 0
EOF
    chmod +x "$HOME/.local/bin/openclaw"
    export PATH="$HOME/.local/bin:$PATH"
    return 0
}
run_onboard_wizard() { :; }
main "$@"
'''
                patched.write_text(prelude + "\n" + prefix + "\n" + overrides, encoding='utf-8')
                patched.chmod(0o755)

                env = {
                    'HOME': str(home),
                    'PATH': '/usr/bin:/bin:/usr/sbin:/sbin',
                }
                result = subprocess.run(
                    ['bash', str(patched), '--auto-confirm-all', '--engine', 'openclaw'],
                    cwd=ROOT,
                    text=True,
                    capture_output=True,
                    env=env,
                )
                if result.returncode != 0:
                    raise AssertionError(
                        f"install entry smoke failed\nSTDOUT:\n{result.stdout}\nSTDERR:\n{result.stderr}"
                    )

                openclaw_home = home / '.openclaw'
                bin_dir = home / '.local' / 'bin'
                self.assertTrue((openclaw_home / 'backup-manager.sh').is_file())
                self.assertTrue((openclaw_home / 'config-menu.sh').is_file())
                self.assertTrue((openclaw_home / 'lobster-world.sh').is_file())
                self.assertTrue((openclaw_home / 'lobster-projection-api.sh').is_file())
                self.assertTrue((openclaw_home / 'lobster-openclaw-bridge.sh').is_file())
                self.assertTrue((openclaw_home / 'health-server.sh').is_file())
                self.assertTrue((openclaw_home / 'scripts' / 'gateway-quota-enforcer.py').is_file())
                self.assertTrue((openclaw_home / 'scripts' / 'media_quota.py').is_file())
                self.assertTrue((bin_dir / 'openclaw-setup').is_file())
                self.assertTrue((bin_dir / 'lobster-setup').is_file())
                self.assertTrue((bin_dir / 'openclaw').is_file())

                env_file = openclaw_home / 'env'
                self.assertTrue(env_file.is_file())
                env_text = env_file.read_text(encoding='utf-8')
                self.assertIn('export STAR_BACKEND_PORT=19000', env_text)
                self.assertIn('export PROJECTION_API_PORT=19100', env_text)
                self.assertIn('export OPENCLAW_STATUS_URL=http://127.0.0.1:13145/status', env_text)
                self.assertIn('export OPENCLAW_DASHBOARD_PORT=13145', env_text)
                self.assertIn('export HERMES_DASHBOARD_PORT=9119', env_text)
                self.assertIn('export HERMES_CHAT_PORT=8000', env_text)
                self.assertIn('export OPENCLAW_WEBSITE_ALLOWED_ORIGINS=', env_text)
                self.assertIn('export OPENCLAW_DASHBOARD_ALLOWED_ORIGINS=', env_text)
                self.assertIn('export OPENCLAW_DATA_ROOT=', env_text)
                self.assertIn('export OPENCLAW_BACKUP_DIR=', env_text)
                self.assertIn('export OPENCLAW_UPGRADE_BACKUP_DIR=', env_text)
                self.assertIn('export OPENCLAW_CACHE_DIR=', env_text)
                self.assertIn('export OPENCLAW_MEDIA_QUOTA_STATE_FILE=', env_text)
                self.assertIn('export OPENCLAW_TRAFFIC_CONTROL_ENABLED=1', env_text)
                self.assertIn('export OPENCLAW_QUOTA_ENFORCER_MODE=embedded', env_text)
                self.assertIn('export NODE_COMPILE_CACHE=', env_text)
                self.assertIn('/storage/node-compile-cache', env_text)
                self.assertIn('export OPENCLAW_NO_RESPAWN=1', env_text)
                self.assertNotIn('export OPENCLAW_PUBLIC_API_URL=http://127.0.0.1:13147', env_text)
                self.assertNotIn('export OPENCLAW_QUOTA_ENFORCER_URL=http://127.0.0.1:13147', env_text)

                self.assertIn('🦞 Lobster 安装完成！当前引擎: openclaw', result.stdout)
            finally:
                patched.unlink(missing_ok=True)


if __name__ == '__main__':
    unittest.main()

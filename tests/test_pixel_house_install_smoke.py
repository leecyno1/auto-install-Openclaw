import os
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
INSTALL = ROOT / 'install.sh'


class PixelHouseInstallSmokeTests(unittest.TestCase):
    def test_setup_lobster_world_defaults_installs_expected_artifacts_into_temp_home(self):
        with tempfile.TemporaryDirectory() as td:
            home = Path(td)
            partial = ROOT / f'.tmp-install-partial-{os.getpid()}.sh'
            install_text = INSTALL.read_text(encoding='utf-8')
            partial.write_text(install_text.split("\n# 始终输出收尾提示", 1)[0] + "\n", encoding='utf-8')
            try:
                script = f'''
                    set -euo pipefail
                    export HOME="{home}"
                    export OPENCLAW_HOME="{home / '.openclaw'}"
                    export LOBSTER_HOME="{home / '.lobster'}"
                    export HERMES_HOME="{home / '.hermes'}"
                    source "{partial}"
                    CONFIG_DIR="$HOME/.openclaw"
                    LOBSTER_BIN_DIR="$HOME/.local/bin"
                    mkdir -p "$CONFIG_DIR" "$LOBSTER_BIN_DIR"
                    start_pixel_house_stack_install() {{ :; }}
                    verify_pixel_house_ready_install() {{ return 1; }}
                    pixel_house_systemd_available_install() {{ return 1; }}
                    resolve_lobster_world_script_install() {{ echo "$CONFIG_DIR/lobster-world.sh"; }}
                    setup_lobster_world_defaults_install
                '''
                result = subprocess.run(
                    ['env', '-i', 'PATH=/usr/bin:/bin:/usr/sbin:/sbin', 'bash', '-c', script],
                    cwd=ROOT,
                    text=True,
                    capture_output=True,
                )
                if result.returncode != 0:
                    raise AssertionError(
                        f"setup_lobster_world_defaults_install failed\nSTDOUT:\n{result.stdout}\nSTDERR:\n{result.stderr}"
                    )

                openclaw_home = home / '.openclaw'
                env_file = openclaw_home / 'env'
                self.assertTrue((openclaw_home / 'config-menu.sh').is_file())
                self.assertTrue((openclaw_home / 'lobster-world.sh').is_file())
                self.assertTrue((openclaw_home / 'lobster-projection-api.sh').is_file())
                self.assertTrue((openclaw_home / 'lobster-openclaw-bridge.sh').is_file())
                self.assertTrue((openclaw_home / 'health-server.sh').is_file())
                self.assertTrue((openclaw_home / 'scripts' / 'gateway-quota-enforcer.py').is_file())
                self.assertTrue((openclaw_home / 'scripts' / 'media_quota.py').is_file())
                self.assertTrue(env_file.is_file())

                env_text = env_file.read_text(encoding='utf-8')
                self.assertIn('export STAR_BACKEND_PORT=19000', env_text)
                self.assertIn('export PROJECTION_API_PORT=19100', env_text)
                self.assertIn('export OPENCLAW_STATUS_URL=http://127.0.0.1:13145/status', env_text)
                self.assertIn('export PROJECTION_API_INGEST_URL=http://127.0.0.1:19100/runtime/ingest', env_text)

                helper_env = {
                    'HOME': str(home),
                    'PATH': '/usr/bin:/bin:/usr/sbin:/sbin',
                }
                health_status = subprocess.run(
                    ['bash', str(openclaw_home / 'health-server.sh'), 'status'],
                    cwd=ROOT,
                    text=True,
                    capture_output=True,
                    env=helper_env,
                )
                if health_status.returncode != 0:
                    raise AssertionError(
                        f"installed health helper status failed\nSTDOUT:\n{health_status.stdout}\nSTDERR:\n{health_status.stderr}"
                    )
                self.assertIn('健康检查服务', health_status.stdout)

                quota_status = subprocess.run(
                    ['python3', str(openclaw_home / 'scripts' / 'gateway-quota-enforcer.py'), 'status'],
                    cwd=ROOT,
                    text=True,
                    capture_output=True,
                    env=helper_env,
                )
                if quota_status.returncode != 0:
                    raise AssertionError(
                        f"installed quota helper status failed\nSTDOUT:\n{quota_status.stdout}\nSTDERR:\n{quota_status.stderr}"
                    )
                self.assertIn('Quota enforcer', quota_status.stdout)
            finally:
                partial.unlink(missing_ok=True)


if __name__ == '__main__':
    unittest.main()

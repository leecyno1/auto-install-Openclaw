import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
INSTALL = ROOT / "install.sh"
OPENCLAW_INSTALLER = ROOT / "install-openclaw.sh"
HERMES_INSTALLER = ROOT / "install-hermes.sh"


class DualInstallerEntrypointTests(unittest.TestCase):
    def test_wrapper_scripts_print_user_facing_help(self):
        openclaw_help = subprocess.check_output([str(OPENCLAW_INSTALLER), "--help"], text=True, cwd=ROOT)
        hermes_help = subprocess.check_output([str(HERMES_INSTALLER), "--help"], text=True, cwd=ROOT)
        self.assertIn("OpenClaw 独立安装入口", openclaw_help)
        self.assertIn("install-openclaw.sh", openclaw_help)
        self.assertIn("openclaw-setup install openclaw", openclaw_help)
        self.assertIn("Hermes 独立安装入口", hermes_help)
        self.assertIn("install-hermes.sh", hermes_help)
        self.assertIn("openclaw-setup install hermes", hermes_help)

    def test_wrapper_scripts_exist_and_lock_engine_selection(self):
        self.assertTrue(OPENCLAW_INSTALLER.is_file())
        self.assertTrue(HERMES_INSTALLER.is_file())
        openclaw_text = OPENCLAW_INSTALLER.read_text(encoding="utf-8")
        hermes_text = HERMES_INSTALLER.read_text(encoding="utf-8")
        self.assertIn('exec bash "$script_dir/install.sh" --engine openclaw "$@"', openclaw_text)
        self.assertIn('exec bash "$script_dir/install.sh" --engine hermes "$@"', hermes_text)
        self.assertIn('请不要再传 --engine', openclaw_text)
        self.assertIn('请不要再传 --engine', hermes_text)

    def test_lobster_setup_install_subcommands_route_to_install_sh_engine(self):
        with tempfile.TemporaryDirectory() as td:
            home = Path(td)
            bin_dir = home / ".local" / "bin"
            openclaw_home = home / ".openclaw"
            partial = ROOT / f".tmp-install-launcher-subcmd-{Path(td).name}.sh"
            install_text = INSTALL.read_text(encoding="utf-8")
            partial.write_text(install_text.split("\n# 始终输出收尾提示", 1)[0] + "\n", encoding="utf-8")
            try:
                bin_dir.mkdir(parents=True)
                openclaw_home.mkdir(parents=True)
                script = f'''
                    set -euo pipefail
                    export HOME="{home}"
                    export PATH="{bin_dir}:/usr/bin:/bin:/usr/sbin:/sbin"
                    source "{partial}"
                    CONFIG_DIR="$HOME/.openclaw"
                    LOBSTER_BIN_DIR="$HOME/.local/bin"
                    install_lobster_setup_launcher
                '''
                subprocess.run(
                    ['env', '-i', 'PATH=/usr/bin:/bin:/usr/sbin:/sbin', 'bash', '-c', script],
                    cwd=ROOT,
                    text=True,
                    capture_output=True,
                    check=True,
                )
                launcher = bin_dir / "openclaw-setup"
                text = launcher.read_text(encoding="utf-8")
                self.assertIn('bash "$install_script" --engine "$sub" "$@"', text)
                self.assertIn('openclaw-setup install openclaw', text)
                self.assertIn('openclaw-setup install hermes', text)
                self.assertIn('openclaw-setup install both', text)
            finally:
                partial.unlink(missing_ok=True)


if __name__ == "__main__":
    unittest.main()

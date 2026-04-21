import os
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
INSTALL = ROOT / 'install.sh'


class LobsterSetupRuntimeTests(unittest.TestCase):
    def test_lobster_setup_routes_help_workbench_status_doctor_and_menu_commands(self):
        with tempfile.TemporaryDirectory() as td:
            home = Path(td)
            bin_dir = home / '.local' / 'bin'
            openclaw_home = home / '.openclaw'
            config_menu = openclaw_home / 'config-menu.sh'
            workbench = openclaw_home / 'lobster-world.sh'
            partial = ROOT / f'.tmp-install-launcher-partial-{os.getpid()}.sh'
            install_text = INSTALL.read_text(encoding='utf-8')
            partial.write_text(install_text.split("\n# 始终输出收尾提示", 1)[0] + "\n", encoding='utf-8')
            try:
                bin_dir.mkdir(parents=True)
                openclaw_home.mkdir(parents=True)
                config_menu.write_text('#!/usr/bin/env bash\necho "CONFIG:$*"\n', encoding='utf-8')
                config_menu.chmod(0o755)
                workbench.write_text('#!/usr/bin/env bash\necho "WORKBENCH:$*"\n', encoding='utf-8')
                workbench.chmod(0o755)
                (openclaw_home / 'backup-manager.sh').write_text('#!/usr/bin/env bash\necho "BACKUP:$*"\n', encoding='utf-8')
                (openclaw_home / 'backup-manager.sh').chmod(0o755)

                (bin_dir / 'openclaw').write_text(
                    '#!/usr/bin/env bash\n'
                    'if [ "$1" = "gateway" ] && [ "$2" = "status" ]; then echo "OPENCLAW_STATUS"; exit 0; fi\n'
                    'if [ "$1" = "doctor" ]; then echo "OPENCLAW_DOCTOR"; exit 0; fi\n'
                    'exit 0\n',
                    encoding='utf-8',
                )
                (bin_dir / 'openclaw').chmod(0o755)
                (bin_dir / 'hermes').write_text(
                    '#!/usr/bin/env bash\n'
                    'if [ "$1" = "status" ]; then echo "HERMES_STATUS"; exit 0; fi\n'
                    'if [ "$1" = "doctor" ]; then echo "HERMES_DOCTOR"; exit 0; fi\n'
                    'exit 0\n',
                    encoding='utf-8',
                )
                (bin_dir / 'hermes').chmod(0o755)

                script = f'''
                    set -euo pipefail
                    export HOME="{home}"
                    export PATH="{bin_dir}:/usr/bin:/bin:/usr/sbin:/sbin"
                    source "{partial}"
                    CONFIG_DIR="$HOME/.openclaw"
                    LOBSTER_BIN_DIR="$HOME/.local/bin"
                    install_lobster_setup_launcher
                '''
                install_result = subprocess.run(
                    ['env', '-i', 'PATH=/usr/bin:/bin:/usr/sbin:/sbin', 'bash', '-c', script],
                    cwd=ROOT,
                    text=True,
                    capture_output=True,
                )
                if install_result.returncode != 0:
                    raise AssertionError(
                        f"install_lobster_setup_launcher failed\nSTDOUT:\n{install_result.stdout}\nSTDERR:\n{install_result.stderr}"
                    )

                launcher = bin_dir / 'lobster-setup'
                compat_launcher = bin_dir / 'openclaw-setup'
                self.assertTrue(launcher.is_file())
                self.assertTrue(compat_launcher.is_file())

                env = {'HOME': str(home), 'PATH': f'{bin_dir}:/usr/bin:/bin:/usr/sbin:/sbin'}

                help_result = subprocess.run([str(launcher), 'help'], cwd=ROOT, text=True, capture_output=True, env=env)
                self.assertEqual(help_result.returncode, 0, help_result.stderr)
                self.assertIn('用法: lobster-setup', help_result.stdout)
                self.assertIn('13146 健康检查', help_result.stdout)
                self.assertIn('13147 配额强制', help_result.stdout)

                workbench_result = subprocess.run([str(launcher), 'workbench', 'restart'], cwd=ROOT, text=True, capture_output=True, env=env)
                self.assertEqual(workbench_result.returncode, 0, workbench_result.stderr)
                self.assertIn('WORKBENCH:restart', workbench_result.stdout)

                config_result = subprocess.run([str(launcher), 'config', '--model-only'], cwd=ROOT, text=True, capture_output=True, env=env)
                self.assertEqual(config_result.returncode, 0, config_result.stderr)
                self.assertIn('CONFIG:--model-only', config_result.stdout)

                repair_result = subprocess.run([str(launcher), 'repair'], cwd=ROOT, text=True, capture_output=True, env=env)
                self.assertEqual(repair_result.returncode, 0, repair_result.stderr)
                self.assertIn('CONFIG:--repair-config', repair_result.stdout)

                status_result = subprocess.run([str(launcher), 'status'], cwd=ROOT, text=True, capture_output=True, env=env)
                self.assertEqual(status_result.returncode, 0, status_result.stderr)
                self.assertIn('OPENCLAW_STATUS', status_result.stdout)
                self.assertIn('HERMES_STATUS', status_result.stdout)

                doctor_result = subprocess.run([str(launcher), 'doctor'], cwd=ROOT, text=True, capture_output=True, env=env)
                self.assertEqual(doctor_result.returncode, 0, doctor_result.stderr)
                self.assertIn('OPENCLAW_DOCTOR', doctor_result.stdout)
                self.assertIn('HERMES_DOCTOR', doctor_result.stdout)

                engine_result = subprocess.run([str(launcher), 'engine'], cwd=ROOT, text=True, capture_output=True, env=env)
                self.assertEqual(engine_result.returncode, 0, engine_result.stderr)
                self.assertIn('CONFIG:--engine-menu', engine_result.stdout)

                backup_result = subprocess.run([str(launcher), 'backup', 'list'], cwd=ROOT, text=True, capture_output=True, env=env)
                self.assertEqual(backup_result.returncode, 0, backup_result.stderr)
                self.assertIn('BACKUP:list', backup_result.stdout)

                compat_cases = [
                    (['help'], '用法: lobster-setup'),
                    (['config', '--official-channels-only'], 'CONFIG:--official-channels-only'),
                    (['repair'], 'CONFIG:--repair-config'),
                    (['workbench', 'status'], 'WORKBENCH:status'),
                    (['status'], 'OPENCLAW_STATUS'),
                    (['doctor'], 'OPENCLAW_DOCTOR'),
                    (['engine'], 'CONFIG:--engine-menu'),
                    (['backup', 'list'], 'BACKUP:list'),
                ]
                for args, expected in compat_cases:
                    compat_result = subprocess.run([str(compat_launcher), *args], cwd=ROOT, text=True, capture_output=True, env=env)
                    self.assertEqual(compat_result.returncode, 0, compat_result.stderr)
                    self.assertIn(expected, compat_result.stdout)
            finally:
                partial.unlink(missing_ok=True)


if __name__ == '__main__':
    unittest.main()

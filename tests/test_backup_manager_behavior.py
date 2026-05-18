import os
import json
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BACKUP_MANAGER = ROOT / 'scripts' / 'backup-manager.sh'


class BackupManagerBehaviorTests(unittest.TestCase):
    def test_create_auto_backup_uses_timestamp_dir_and_excludes_nested_backups(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            home = Path(tmpdir)
            openclaw_home = home / '.openclaw'
            backups_dir = openclaw_home / 'backups'
            skills_dir = openclaw_home / 'skills'
            docs_dir = openclaw_home / 'docs'

            backups_dir.mkdir(parents=True)
            skills_dir.mkdir(parents=True)
            docs_dir.mkdir(parents=True)

            (openclaw_home / 'env').write_text('TEST_API_KEY=secret\nNORMAL=value\n', encoding='utf-8')
            (skills_dir / 'demo.txt').write_text('skill-demo\n', encoding='utf-8')
            (docs_dir / 'note.md').write_text('hello\n', encoding='utf-8')
            (backups_dir / 'existing-marker.txt').write_text('keep\n', encoding='utf-8')

            env = os.environ.copy()
            env['HOME'] = str(home)

            subprocess.check_call(
                ['bash', str(BACKUP_MANAGER), 'create', '--auto'],
                cwd=ROOT,
                env=env,
            )

            backup_dirs = [p for p in backups_dir.iterdir() if p.is_dir()]
            self.assertEqual(len(backup_dirs), 1)
            created = backup_dirs[0]
            self.assertNotEqual(created.name, '--auto')
            self.assertRegex(created.name, r'^\d{8}_\d{6}$')

            self.assertTrue((created / 'skills' / 'demo.txt').is_file())
            self.assertTrue((created / 'docs' / 'note.md').is_file())
            self.assertTrue((created / 'env.original').is_file())
            self.assertTrue((created / 'env.redacted').is_file())
            self.assertTrue((created / 'backup.json').is_file())
            self.assertFalse((created / 'backups').exists())

            metadata = json.loads((created / 'backup.json').read_text(encoding='utf-8'))
            self.assertEqual(metadata['name'], created.name)
            self.assertIsInstance(metadata['size_bytes'], int)
            self.assertGreater(metadata['size_bytes'], 0)
            self.assertEqual(metadata['files'], 6)

    def test_restore_backup_merges_top_level_directories_without_double_nesting(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            home = Path(tmpdir)
            openclaw_home = home / '.openclaw'
            backups_dir = openclaw_home / 'backups'
            current_skills = openclaw_home / 'skills'
            backup_dir = backups_dir / 'restore_case'

            current_skills.mkdir(parents=True)
            backup_dir.mkdir(parents=True)
            (current_skills / 'old.txt').write_text('old\n', encoding='utf-8')

            (backup_dir / 'skills').mkdir()
            (backup_dir / 'docs').mkdir()
            (backup_dir / 'skills' / 'demo.txt').write_text('restored\n', encoding='utf-8')
            (backup_dir / 'docs' / 'note.md').write_text('note\n', encoding='utf-8')
            (backup_dir / 'backup.json').write_text('{}\n', encoding='utf-8')
            (backup_dir / 'env.redacted').write_text('X=***\n', encoding='utf-8')
            (backup_dir / 'env.original').write_text('X=1\n', encoding='utf-8')

            env = os.environ.copy()
            env['HOME'] = str(home)

            subprocess.run(
                ['bash', str(BACKUP_MANAGER), 'restore', 'restore_case'],
                cwd=ROOT,
                env=env,
                input='y\n',
                text=True,
                check=True,
            )

            self.assertTrue((openclaw_home / 'skills' / 'demo.txt').is_file())
            self.assertTrue((openclaw_home / 'docs' / 'note.md').is_file())
            self.assertFalse((openclaw_home / 'skills' / 'skills').exists())
            self.assertFalse((openclaw_home / 'docs' / 'docs').exists())
            self.assertFalse((openclaw_home / 'backup.json').exists())
            self.assertFalse((openclaw_home / 'env.redacted').exists())
            self.assertFalse((openclaw_home / 'env.original').exists())


if __name__ == '__main__':
    unittest.main()

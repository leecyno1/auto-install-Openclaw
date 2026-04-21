import importlib.util
import tempfile
import unittest
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = ROOT / 'scripts' / 'refresh_default_skills.py'


spec = importlib.util.spec_from_file_location('refresh_default_skills', MODULE_PATH)
assert spec and spec.loader
refresh = importlib.util.module_from_spec(spec)
spec.loader.exec_module(refresh)


class RefreshDefaultSkillsLogicTests(unittest.TestCase):
    def test_parse_cli_json_tolerates_progress_prefix(self):
        payload = refresh.parse_cli_json('- Fetching skill\n{"ok":true,"value":1}\n')
        self.assertEqual(payload, {"ok": True, "value": 1})

    def test_parse_github_hint_supports_tree_subpaths(self):
        self.assertEqual(
            refresh.parse_github_hint('https://github.com/JimLiu/baoyu-skills/tree/main/skills/baoyu-comic'),
            ('https://github.com/JimLiu/baoyu-skills.git', 'main', 'skills/baoyu-comic'),
        )

    def test_find_local_source_supports_system_skill_alias(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            root = tmp_path / 'skills'
            target = root / '.system' / 'openai-docs'
            target.mkdir(parents=True)
            (target / 'SKILL.md').write_text('# docs\n', encoding='utf-8')

            with mock.patch.object(refresh, 'LOCAL_SOURCE_ROOTS', [root]):
                label, source = refresh.find_local_source('openai-docs')

            self.assertEqual(label, refresh.display_path(root))
            self.assertEqual(source, target)

    def test_find_local_source_supports_tdd_alias(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            root = tmp_path / 'skills'
            target = root / 'test-driven-development'
            target.mkdir(parents=True)
            (target / 'SKILL.md').write_text('# tdd\n', encoding='utf-8')

            with mock.patch.object(refresh, 'LOCAL_SOURCE_ROOTS', [root]):
                label, source = refresh.find_local_source('tdd')

            self.assertEqual(label, refresh.display_path(root))
            self.assertEqual(source, target)

    def test_find_local_source_supports_fullstack_dev_alias(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            root = tmp_path / 'skills'
            target = root / 'fullstack-guardian'
            target.mkdir(parents=True)
            (target / 'SKILL.md').write_text('# fullstack\n', encoding='utf-8')

            with mock.patch.object(refresh, 'LOCAL_SOURCE_ROOTS', [root]):
                label, source = refresh.find_local_source('fullstack-dev')

            self.assertEqual(label, refresh.display_path(root))
            self.assertEqual(source, target)

    def test_find_local_source_supports_web_design_alias(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            root = tmp_path / 'skills'
            target = root / 'web-design-guidelines'
            target.mkdir(parents=True)
            (target / 'SKILL.md').write_text('# web\n', encoding='utf-8')

            with mock.patch.object(refresh, 'LOCAL_SOURCE_ROOTS', [root]):
                label, source = refresh.find_local_source('web-design')

            self.assertEqual(label, refresh.display_path(root))
            self.assertEqual(source, target)

    def test_repo_root_readme_can_be_used_for_wrapper_hub_skills(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            repo_dir = tmp_path / 'repo'
            repo_dir.mkdir()
            (repo_dir / 'README.md').write_text('# upstream\n', encoding='utf-8')

            skill_dir = tmp_path / 'marketingskills'
            (skill_dir / 'references').mkdir(parents=True)
            (skill_dir / 'references' / 'upstream-README.md').write_text('# old\n', encoding='utf-8')

            source = refresh.find_wrapper_readme_source(skill_dir, repo_dir)
            self.assertEqual(source, repo_dir / 'README.md')
            self.assertEqual(
                refresh.resolve_sync_target(skill_dir, source),
                skill_dir / 'references' / 'upstream-README.md',
            )

    def test_wrapper_readme_sync_copies_to_references_target(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            repo_dir = tmp_path / 'repo'
            repo_dir.mkdir()
            source = repo_dir / 'README.md'
            source.write_text('# upstream v2\n', encoding='utf-8')

            skill_dir = tmp_path / 'inference-skills'
            target_dir = skill_dir / 'references'
            target_dir.mkdir(parents=True)
            target = target_dir / 'upstream-README.md'
            target.write_text('# upstream v1\n', encoding='utf-8')

            refresh.copy_source(source, skill_dir)
            self.assertEqual(target.read_text(encoding='utf-8'), '# upstream v2\n')

    def test_dead_local_doc_hint_falls_back_to_clawhub_origin(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            skill_dir = tmp_path / 'agent-builder'
            (skill_dir / '.clawhub').mkdir(parents=True)
            (skill_dir / '.clawhub' / 'origin.json').write_text(
                '{"registry":"https://clawhub.ai","slug":"agent-builder"}',
                encoding='utf-8',
            )
            with mock.patch.object(refresh, 'fetch_clawhub_latest', return_value=None):
                label, source_dir, source_kind = refresh.find_source(
                    'agent-builder',
                    skill_dir,
                    agentmail_repo=None,
                    doc_hints={'agent-builder': '~/.codex/skills/agent-builder'},
                    tmp_root=tmp_path,
                    clone_cache={},
                )
            self.assertEqual(label, 'https://clawhub.ai/agent-builder')
            self.assertIsNone(source_dir)
            self.assertEqual(source_kind, 'hint-only')

    def test_dead_local_doc_hint_without_clawhub_stays_as_dead_local_hint(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            skill_dir = tmp_path / 'shell'
            label, source_dir, source_kind = refresh.find_source(
                'shell',
                skill_dir,
                agentmail_repo=None,
                doc_hints={'shell': '~/.codex/skills/shell'},
                tmp_root=tmp_path,
                clone_cache={},
            )
            self.assertEqual(label, '~/.codex/skills/shell')
            self.assertIsNone(source_dir)
            self.assertEqual(source_kind, 'dead-local-hint')

    def test_clawhub_api_payload_is_mapped_to_skill_md_target(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            skill_dir = tmp_path / 'agent-browser'
            skill_dir.mkdir()
            source = tmp_path / 'agent-browser.clawhub.json'
            source.write_text('{"content":"# new skill\\n"}', encoding='utf-8')
            self.assertEqual(
                refresh.resolve_sync_target(skill_dir, source),
                skill_dir / 'SKILL.md',
            )

    def test_clawhub_api_source_writes_skill_md_only(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            skill_dir = tmp_path / 'agent-browser'
            skill_dir.mkdir()
            (skill_dir / 'SKILL.md').write_text('# old skill\n', encoding='utf-8')
            (skill_dir / 'README.md').write_text('keep me\n', encoding='utf-8')

            source = tmp_path / 'agent-browser.clawhub.json'
            source.write_text('{"content":"# new skill\\n"}', encoding='utf-8')

            refresh.copy_source(source, skill_dir)
            self.assertEqual((skill_dir / 'SKILL.md').read_text(encoding='utf-8'), '# new skill\n')
            self.assertEqual((skill_dir / 'README.md').read_text(encoding='utf-8'), 'keep me\n')

    def test_fetch_clawhub_latest_builds_directory_from_cli_inspect(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)

            with mock.patch.object(
                refresh,
                'run_clawhub_inspect_json',
                side_effect=[
                    {
                        'version': {
                            'files': [
                                {'path': 'SKILL.md'},
                                {'path': 'references/commands.md'},
                                {'path': 'scripts/setup.sh'},
                            ]
                        }
                    },
                    {'file': {'content': '# skill\n'}},
                    {'file': {'content': '# commands\n'}},
                    {'file': {'content': '#!/usr/bin/env bash\necho ok\n'}},
                ],
            ):
                source = refresh.fetch_clawhub_latest('openclaw-agent-browser', tmp_path / 'agent-browser.clawhub')

            self.assertEqual(source, tmp_path / 'agent-browser.clawhub')
            self.assertEqual((source / 'SKILL.md').read_text(encoding='utf-8'), '# skill\n')
            self.assertEqual((source / 'references' / 'commands.md').read_text(encoding='utf-8'), '# commands\n')
            self.assertEqual((source / 'scripts' / 'setup.sh').read_text(encoding='utf-8'), '#!/usr/bin/env bash\necho ok\n')

    def test_resolve_hint_source_uses_clawhub_slug_alias(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            skill_dir = tmp_path / 'agent-browser'
            (skill_dir / '.clawhub').mkdir(parents=True)
            (skill_dir / '.clawhub' / 'origin.json').write_text(
                '{"registry":"https://clawhub.ai","slug":"agent-browser"}',
                encoding='utf-8',
            )
            fetched = tmp_path / 'openclaw-agent-browser.clawhub'
            fetched.mkdir()
            (fetched / 'SKILL.md').write_text('# skill\n', encoding='utf-8')

            with mock.patch.object(refresh, 'fetch_clawhub_latest', return_value=fetched) as fetch_mock:
                label, source, kind = refresh.resolve_hint_source(
                    'agent-browser',
                    skill_dir,
                    'https://clawhub.ai/agent-browser',
                    tmp_path,
                    {},
                )

            fetch_mock.assert_called_once()
            self.assertEqual(fetch_mock.call_args[0][0], 'openclaw-agent-browser')
            self.assertEqual(label, 'https://clawhub.ai/agent-browser')
            self.assertEqual(source, fetched)
            self.assertEqual(kind, 'clawhub')

    def test_row_for_missing_clawhub_hint_mentions_cli_resolution(self):
        row = refresh.row_for_missing('agent-browser', 'https://clawhub.ai/agent-browser', 'hint-only')
        self.assertTrue('clawhub CLI' in row['detail'] or '官方 CLI' in row['detail'])

    def test_row_for_missing_repo_maintained_skill_is_classified_clearly(self):
        row = refresh.row_for_missing('dasheng-xuanti', '未找到可用上游源', 'missing')
        self.assertIn('仓库自维护技能', row['detail'])

    def test_row_for_missing_dead_local_hint_is_classified_clearly(self):
        row = refresh.row_for_missing('shell', '~/.codex/skills/shell', 'dead-local-hint')
        self.assertIn('本机 skill 当前不存在', row['detail'])


if __name__ == '__main__':
    unittest.main()

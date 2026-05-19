import json
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SKILLS_DIR = ROOT / 'skills'
SKILLS_LIB = ROOT / 'scripts' / 'lib' / 'skills.sh'
BOUTIQUE_ROOT = ROOT.parent / 'boutique-openclaw-skills'
BOUTIQUE_SKILLS = BOUTIQUE_ROOT / 'skills' / 'default'

REQUIRED_LOW = {
    'agent-browser', 'skill-creator', 'subagent-driven-development',
    'using-superpowers', 'verification-before-completion', 'writing-skills',
    'weather', 'shell', 'data-analyst', 'task', 'todo', 'xlsx', 'docx',
}


def run_bash(expr: str) -> str:
    return subprocess.check_output(['bash', '-lc', expr], text=True, cwd=ROOT).strip()


class SkillsBoutiqueBoundaryTests(unittest.TestCase):
    def test_installer_repo_no_longer_vendors_default_skills(self):
        self.assertTrue((SKILLS_DIR / 'README.md').is_file())
        tracked_payload = [
            path.relative_to(SKILLS_DIR).as_posix()
            for path in SKILLS_DIR.rglob('*')
            if path.is_file() or path.is_symlink()
        ]
        self.assertEqual(tracked_payload, ['README.md'])
        self.assertFalse((ROOT / 'skills' / 'manifest.json').exists())
        self.assertFalse((ROOT / 'skills' / 'default').exists())

    def test_obsolete_local_skill_generators_are_removed(self):
        for relative in (
            'scripts/generate_skills_manifest.py',
            'scripts/generate_skill_guides.py',
            'scripts/generate_skills_triage.py',
            'scripts/refresh_default_skills.py',
            'docs/skills-guides.md',
            'docs/skills-update-report.md',
            'docs/upstream-sources.md',
        ):
            self.assertFalse((ROOT / relative).exists(), relative)

    def test_boutique_tier_files_are_the_skill_source_of_truth(self):
        self.assertTrue(BOUTIQUE_SKILLS.is_dir(), f'missing boutique skills source: {BOUTIQUE_SKILLS}')
        standard_path = BOUTIQUE_ROOT / 'catalog' / 'standard-bundle.json'
        self.assertTrue(standard_path.is_file(), standard_path)
        standard_payload = json.loads(standard_path.read_text(encoding='utf-8'))
        standard_ids = [
            item if isinstance(item, str) else item.get('skill') or item.get('id')
            for item in standard_payload.get('skills', [])
        ]
        standard_ids = [item for item in standard_ids if item]
        self.assertEqual(len(standard_ids), len(set(standard_ids)))
        self.assertIn('skill-creator', standard_ids)
        self.assertIn('verification-before-completion', standard_ids)
        tiers = {}
        for tier in ('low', 'medium', 'high'):
            path = BOUTIQUE_ROOT / 'tiers' / f'{tier}.json'
            self.assertTrue(path.is_file(), path)
            payload = json.loads(path.read_text(encoding='utf-8'))
            ids = [item['id'] for item in payload.get('skills', [])]
            self.assertEqual(len(ids), len(set(ids)), tier)
            tiers[tier] = set(ids)
        self.assertTrue(REQUIRED_LOW <= tiers['low'])
        self.assertTrue(tiers['low'] <= tiers['medium'] <= tiers['high'])

    def test_shell_library_gracefully_falls_back_without_local_manifest(self):
        command = f'source {SKILLS_LIB}; openclaw_skill_manifest_path >/tmp/openclaw-manifest-path.txt 2>/dev/null'
        proc = subprocess.run(['bash', '-lc', command], cwd=ROOT, text=True)
        self.assertNotEqual(proc.returncode, 0)
        fallback = run_bash(f'source {SKILLS_LIB}; openclaw_skill_fallback_init; printf "%s" "$PROFILE_BASIC_SKILLS"')
        self.assertIn('using-superpowers', fallback)
        self.assertIn('weather', fallback)

    def test_installers_resolve_boutique_not_repo_local_skills(self):
        install_text = (ROOT / 'install.sh').read_text(encoding='utf-8')
        menu_text = (ROOT / 'config-menu.sh').read_text(encoding='utf-8')
        module_text = (ROOT / 'scripts' / 'modules' / 'skills.sh').read_text(encoding='utf-8')
        custom_text = (ROOT / 'scripts' / 'lib' / 'openclaw-custom.sh').read_text(encoding='utf-8')
        for text in (install_text, menu_text, module_text, custom_text):
            self.assertIn('boutique-openclaw-skills', text)
            self.assertIn('https://gitee.com/leecyno1/boutique-openclaw-skills.git', text)
            self.assertNotIn('auto-install-openclaw-main/skills/default', text)
        self.assertNotIn('$script_dir/skills/default', install_text)
        self.assertNotIn('$script_dir/skills/default', menu_text)
        self.assertNotIn('$REPO_ROOT/skills/default', module_text)
        self.assertIn('get_boutique_profile_skill_list_install', install_text)
        self.assertIn('get_boutique_profile_skill_list_menu', menu_text)
        self.assertIn('get_boutique_standard_skill_list_install', install_text)
        self.assertIn('get_boutique_standard_skill_list_menu', menu_text)

    def test_installer_defaults_to_standard_skills_not_rule_tiers(self):
        install_text = (ROOT / 'install.sh').read_text(encoding='utf-8')
        menu_text = (ROOT / 'config-menu.sh').read_text(encoding='utf-8')
        setup_text = (ROOT / 'openclaw-setup.sh').read_text(encoding='utf-8')
        self.assertIn('apply_standard_skill_policy || true', install_text)
        self.assertNotIn('apply_profile_skill_policy "$level" || true', install_text)
        self.assertNotIn('apply_profile_skill_policy_menu "$level" 0 || true', menu_text)
        self.assertIn('sync_standard_skills_bundle 0', menu_text)
        self.assertIn('manage_tier_skills', menu_text)
        self.assertIn('action="${1:-standard}"', setup_text)

    def test_release_check_no_longer_requires_local_manifest_generation(self):
        text = (ROOT / 'scripts' / 'release-check.sh').read_text(encoding='utf-8')
        self.assertNotIn('generate_skills_manifest.py', text)
        self.assertIn('./scripts/preflight-check.sh', text)
        self.assertIn('rg -n', text)


if __name__ == '__main__':
    unittest.main()

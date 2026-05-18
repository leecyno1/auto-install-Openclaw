import json
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / 'skills' / 'manifest.json'
SKILLS_LIB = ROOT / 'scripts' / 'lib' / 'skills.sh'
BOUTIQUE_SKILLS = ROOT.parent / 'boutique-openclaw-skills' / 'skills' / 'default'

REQUIRED_DEFAULT = {
    'agentmail', 'agentmail-cli', 'agentmail-mcp', 'agentmail-toolkit',
    'skill-creator', 'github', 'self-improving-agent-cn', 'subagent-driven-development',
    'using-superpowers', 'verification-before-completion', 'writing-skills',
    'skill-security-auditor', 'weather', 'shell', 'data-analyst', 'finance-data',
    'pdf', 'pptx', 'task', 'todo', 'xlsx', 'docx', 'agent-browser', 'media-downloader',
}

MINIMAX_OFFICIAL = {
    'android-native-dev', 'buddy-sings', 'flutter-dev', 'frontend-dev', 'fullstack-dev',
    'gif-sticker-maker', 'ios-application-dev', 'minimax-docx', 'minimax-multimodal-toolkit',
    'minimax-music-gen', 'minimax-music-playlist', 'minimax-pdf', 'minimax-xlsx',
    'pptx-generator', 'react-native-dev', 'shader-dev', 'vision-analysis',
}


def run_skill_lib(expr: str) -> str:
    cmd = f'source {SKILLS_LIB}; {expr}'
    return subprocess.check_output(['bash', '-lc', cmd], text=True, cwd=ROOT).strip()


class SkillsManifestTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data = json.loads(MANIFEST.read_text(encoding='utf-8'))
        cls.skills = {item['id']: item for item in cls.data['skills']}

    def test_manifest_contains_every_local_skill_directory(self):
        self.assertTrue(BOUTIQUE_SKILLS.is_dir(), f'missing boutique skills source: {BOUTIQUE_SKILLS}')
        local = {p.name for p in BOUTIQUE_SKILLS.iterdir() if p.is_dir()}
        missing = sorted(local - set(self.skills))
        self.assertEqual(missing, [])

    def test_required_default_and_minimax_skills_are_classified(self):
        for skill_id in REQUIRED_DEFAULT:
            self.assertIn(skill_id, self.skills)
            self.assertIn('basic', self.skills[skill_id]['tiers'])
        for skill_id in MINIMAX_OFFICIAL:
            self.assertIn(skill_id, self.skills)
            self.assertIn('minimax_official', self.skills[skill_id]['groups'])
            self.assertIn('basic', self.skills[skill_id]['tiers'])

    def test_manifest_descriptions_are_not_placeholder_for_managed_skills(self):
        managed = REQUIRED_DEFAULT | MINIMAX_OFFICIAL | {'ai-image-generation', 'planning-with-files', 'baoyu-skills'}
        bad = []
        for skill_id in managed:
            desc = self.skills[skill_id].get('description', '').strip().lower()
            if not desc or '来自本地技能仓' in desc or desc in {'todo', 'skill'}:
                bad.append(skill_id)
        self.assertEqual(sorted(bad), [])

    def test_shell_library_reads_manifest_bundle_lists(self):
        minimax = set(run_skill_lib('openclaw_skill_manifest_list minimax_official').split())
        basic = set(run_skill_lib('openclaw_skill_manifest_list tier:basic').split())
        extended = set(run_skill_lib('openclaw_skill_manifest_list tier:extended').split())
        super_set = set(run_skill_lib('openclaw_skill_manifest_list tier:super').split())
        sentinels = set(run_skill_lib('openclaw_skill_manifest_default_sentinels').split())
        menu_enhanced = set(run_skill_lib('openclaw_skill_manifest_list menu_enhanced').split())
        baoyu = set(run_skill_lib('openclaw_skill_manifest_list group:baoyu').split())
        self.assertTrue(MINIMAX_OFFICIAL <= minimax)
        self.assertTrue(REQUIRED_DEFAULT <= basic)
        self.assertIn('planning-with-files', extended)
        self.assertIn('baoyu-skills', super_set)
        self.assertTrue({'agentmail', 'ai-image-generation', 'minimax-docx'} <= sentinels)
        self.assertIn('frontend-design', menu_enhanced)
        self.assertIn('stock-analysis', menu_enhanced)
        self.assertIn('baoyu-post-to-wechat', baoyu)

    def test_installer_and_menu_delegate_skill_lists_to_manifest_when_available(self):
        install_text = (ROOT / 'install.sh').read_text(encoding='utf-8')
        menu_text = (ROOT / 'config-menu.sh').read_text(encoding='utf-8')
        for text in (install_text, menu_text):
            self.assertIn('scripts/lib/skills.sh', text)
            self.assertIn('openclaw_skill_fallback_init', text)
            self.assertIn('openclaw_skill_manifest_list minimax_official', text)
            self.assertIn('openclaw_skill_manifest_list tier:basic', text)
            self.assertIn('openclaw_skill_manifest_default_sentinels', text)
        self.assertIn('openclaw_skill_manifest_list menu_enhanced', menu_text)
        self.assertIn('openclaw_skill_manifest_list group:baoyu', menu_text)

    def test_manifest_can_be_regenerated_without_diff(self):
        generator = ROOT / 'scripts' / 'generate_skills_manifest.py'
        self.assertTrue(generator.is_file())
        before = MANIFEST.read_text(encoding='utf-8')
        subprocess.check_call(['python3', str(generator), '--check'], cwd=ROOT)
        after = MANIFEST.read_text(encoding='utf-8')
        self.assertEqual(before, after)

    def test_release_check_script_exists_and_runs_required_checks(self):
        release_check = ROOT / 'scripts' / 'release-check.sh'
        self.assertTrue(release_check.is_file())
        text = release_check.read_text(encoding='utf-8')
        self.assertIn('./scripts/preflight-check.sh', text)
        self.assertIn('rg -n', text)
        self.assertIn('sk-cp-', text)
        self.assertIn("--glob '!tests/**'", text)
        self.assertIn("--glob '!examples/**'", text)
        self.assertIn("--glob '!scripts/release-check.sh'", text)


if __name__ == '__main__':
    unittest.main()

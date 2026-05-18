import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
REGISTRY = ROOT / 'scripts' / 'lib' / 'model_registry.py'


class ModelRegistryTests(unittest.TestCase):
    def run_registry(self, specs, tmpdir):
        openclaw_json = tmpdir / 'openclaw.json'
        agent_models_json = tmpdir / 'models.json'
        capabilities_json = tmpdir / 'model-capabilities.json'
        result = subprocess.run(
            [
                sys.executable,
                str(REGISTRY),
                '--specs',
                '|||'.join(specs),
                '--openclaw-json',
                str(openclaw_json),
                '--agent-models-json',
                str(agent_models_json),
                '--capabilities-json',
                str(capabilities_json),
            ],
            cwd=ROOT,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=True,
        )
        return result.stdout, json.loads(openclaw_json.read_text()), json.loads(capabilities_json.read_text())

    def test_dedupes_active_family_slots_and_archives_replaced_providers(self):
        with tempfile.TemporaryDirectory() as raw_tmp:
            tmpdir = Path(raw_tmp)
            _, openclaw_cfg, capabilities = self.run_registry(
                [
                    'id=minimax-old,provider=minimax,model=MiniMax-M2.5,base_url=https://old.example/v1,api_key=old',
                    'id=minimax-official,provider=minimax,model=MiniMax-M2.7,base_url=https://api.minimaxi.com/v1,api_key=new',
                    'id=deepseek-v4,provider=deepseek,model=DeepSeek-V4,base_url=https://api.deepseek.com/v1,api_key=ds',
                    'id=gpt-5-4,provider=openai,model=gpt-5.4,base_url=https://gateway.example/v1,api_key=gpt',
                    'id=gpt-5-5,provider=openai,model=gpt-5.5,base_url=https://gateway.example/v1,api_key=gpt,image_tool=responses-image-generation,image_model=gpt-image-2',
                ],
                tmpdir,
            )

        providers = openclaw_cfg['models']['providers']
        self.assertIn('minimax-official', providers)
        self.assertNotIn('minimax-old', providers)
        self.assertIn('gpt-5-5', providers)
        self.assertNotIn('gpt-5-4', providers)

        slots = capabilities['registry']['slots']
        self.assertEqual(slots['minimax']['provider'], 'minimax-official')
        self.assertEqual(slots['gpt']['model'], 'gpt-5.5')
        self.assertEqual(capabilities['archivedProviders']['minimax-old']['slot'], 'minimax')
        self.assertEqual(capabilities['archivedProviders']['gpt-5-4']['slot'], 'gpt')

        gpt_capability = capabilities['models']['gpt-5-5/gpt-5.5']['imageGeneration']
        self.assertEqual(gpt_capability['endpoint'], '/v1/responses')
        self.assertEqual(gpt_capability['tool'], 'image_generation')
        self.assertIn('/v1/images/generations', gpt_capability['fallbacks']['unavailable'])
        self.assertEqual(capabilities['router']['backend'], 'embedded')
        self.assertEqual(capabilities['router']['strategy'], 'rules')


if __name__ == '__main__':
    unittest.main()

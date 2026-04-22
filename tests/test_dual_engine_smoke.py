import os
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
COMMON = ROOT / 'scripts' / 'lib' / 'openclaw-common.sh'


class DualEngineSmokeTests(unittest.TestCase):
    def test_install_script_hermes_only_keeps_shared_workbench_but_skips_openclaw_runtime_start(self):
        text = (ROOT / 'install.sh').read_text(encoding='utf-8')
        self.assertIn('setup_lobster_world_defaults_install "shared"', text)
        self.assertIn('Hermes-only 模式：跳过 OpenClaw 渠道、onboard、Gateway 与运行桥接初始化。', text)
        self.assertIn('已安装共享像素小屋框架（Hermes-only 默认不自动启动运行桥接）。', text)

    def test_shared_state_and_hermes_skill_bridge_use_temp_home(self):
        with tempfile.TemporaryDirectory() as td:
            home = Path(td)
            openclaw_home = home / '.openclaw'
            hermes_home = home / '.hermes'
            lobster_home = home / '.lobster'
            skill_dir = openclaw_home / 'skills' / 'agentmail'
            skill_dir.mkdir(parents=True)
            (skill_dir / 'SKILL.md').write_text('# AgentMail\n', encoding='utf-8')
            env_file = openclaw_home / 'env'
            env_file.write_text('\n'.join([
                'export OPENCLAW_PERSONA_ROLE="warrior"',
                'export OPENCLAW_RULE_PROFILE="medium"',
                'export OPENCLAW_WEB_SKILL_PACK="medium"',
                'export OPENCLAW_PROFILE_SKILL_PACK_LABEL="extended"',
                'export OPENCLAW_PROFILE_SKILL_LIST="agentmail shell github"',
                'export OPENCLAW_PROFILE_SKILL_COUNT="3"',
                'export OPENCLAW_RULE_MAX_REQUESTS="300"',
                'export OPENCLAW_RULE_MAX_IMAGE_REQUESTS="20"',
                'export OPENCLAW_RULE_MAX_VIDEO_REQUESTS="1"',
                'export OPENCLAW_MINIMAX_PROVIDER_URL="https://api.sfkey.cn"',
                'export MINIMAX_API_KEY="dummy-minimax-key"',
                'export MINIMAX_API_HOST="https://api.sfkey.cn"',
                'export MINIMAX_MULTIMODAL_OUTPUT_PATH="~/.openclaw/workspace/minimax-output"',
                'export MINIMAX_MCP_BASE_PATH="~/.openclaw/workspace/minimax-output"',
                'export MINIMAX_API_RESOURCE_MODE="local"',
                'export MINIMAX_IMAGE_MODEL="image-01"',
                'export MINIMAX_IMAGE_ENDPOINT="/v1/image_generation"',
                'export MINIMAX_TTS_MODEL="speech-2.8-hd"',
                'export MINIMAX_TTS_ENDPOINT="/v1/t2a_v2"',
                'export MINIMAX_VIDEO_MODEL="MiniMax-Hailuo-2.3"',
                'export MINIMAX_VIDEO_ENDPOINT="/v1/video_generation"',
                'export MINIMAX_VIDEO_QUERY_ENDPOINT="/v1/query/video_generation"',
                'export MINIMAX_FILES_RETRIEVE_ENDPOINT="/v1/files/retrieve"',
                'export MINIMAX_MUSIC_MODEL="music-2.6"',
                'export MINIMAX_MUSIC_ENDPOINT="/v1/music_generation"',
                'export OPENCLAW_IMAGE_API_URL="https://api.viviai.cc/v1/chat/completions"',
                'export OPENCLAW_IMAGE_MODEL="gemini-3.1-flash-image-preview"',
            ]) + '\n', encoding='utf-8')

            script = f'''
                set -euo pipefail
                export HOME="{home}"
                export OPENCLAW_HOME="{openclaw_home}"
                export HERMES_HOME="{hermes_home}"
                export LOBSTER_HOME="{lobster_home}"
                source "{COMMON}"
                openclaw_set_lobster_engine_state openclaw "openclaw,hermes"
                openclaw_sync_dual_engine_state "{env_file}" "{hermes_home}"
            '''
            result = subprocess.run(
                ['env', '-i', 'PATH=/usr/bin:/bin:/usr/sbin:/sbin', 'bash', '-c', script],
                cwd=ROOT,
                text=True,
                capture_output=True,
            )
            if result.returncode != 0:
                raise AssertionError(f"smoke shell failed\nSTDOUT:\n{result.stdout}\nSTDERR:\n{result.stderr}")

            shared_env = lobster_home / 'config' / 'shared.env'
            hermes_env = hermes_home / '.env'
            profile = hermes_home / 'lobster-profile.env'
            runtime = hermes_home / 'lobster-runtime.env'
            link = hermes_home / 'skills' / 'agentmail'
            for path in [shared_env, hermes_env, profile, runtime]:
                self.assertTrue(path.is_file(), path)
            self.assertTrue(link.is_symlink(), link)
            self.assertEqual(os.readlink(link), str(skill_dir))

            self.assertIn('MINIMAX_BASE_URL="https://api.sfkey.cn"', hermes_env.read_text(encoding='utf-8'))
            hermes_text = hermes_env.read_text(encoding='utf-8')
            self.assertIn('MINIMAX_API_HOST="https://api.sfkey.cn"', hermes_text)
            self.assertIn('MINIMAX_IMAGE_MODEL="image-01"', hermes_text)
            self.assertIn('MINIMAX_TTS_MODEL="speech-2.8-hd"', hermes_text)
            self.assertIn('MINIMAX_VIDEO_MODEL="MiniMax-Hailuo-2.3"', hermes_text)
            self.assertIn('MINIMAX_MUSIC_MODEL="music-2.6"', hermes_text)
            self.assertIn('MINIMAX_MCP_BASE_PATH="~/.openclaw/workspace/minimax-output"', hermes_text)
            self.assertIn('LOBSTER_PROFILE_SKILL_COUNT="3"', runtime.read_text(encoding='utf-8'))
            self.assertIn('LOBSTER_PERSONA_ROLE="warrior"', profile.read_text(encoding='utf-8'))
            shared_text = shared_env.read_text(encoding='utf-8')
            self.assertIn('OPENCLAW_MINIMAX_PROVIDER_URL="https://api.sfkey.cn"', shared_text)
            self.assertIn('MINIMAX_MUSIC_MODEL="music-2.6"', shared_text)
            self.assertIn('MINIMAX_IMAGE_ENDPOINT="/v1/image_generation"', shared_text)


if __name__ == '__main__':
    unittest.main()

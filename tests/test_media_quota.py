import json
import os
import tempfile
import time
import unittest
from pathlib import Path
from importlib import util

MODULE_PATH = Path(__file__).resolve().parents[1] / 'scripts' / 'media_quota.py'

spec = util.spec_from_file_location('media_quota', MODULE_PATH)
media_quota = util.module_from_spec(spec) if spec and spec.loader else None
if spec and spec.loader:
    spec.loader.exec_module(media_quota)


class MediaQuotaTests(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.state_path = Path(self.temp_dir.name) / 'quota-state.json'
        self.env = {
            'OPENCLAW_RULE_WINDOW_HOURS': '5',
            'OPENCLAW_RULE_MAX_IMAGE_REQUESTS': '20',
            'OPENCLAW_RULE_MAX_VIDEO_REQUESTS': '1',
            'OPENCLAW_RULE_PROFILE': 'medium',
            'OPENCLAW_MEDIA_QUOTA_STATE_FILE': str(self.state_path),
        }

    def tearDown(self):
        self.temp_dir.cleanup()

    def test_medium_image_quota_blocks_after_limit(self):
        self.assertIsNotNone(media_quota)
        reservation_ids = []
        for _ in range(20):
            result = media_quota.reserve_quota('image', 1, env=self.env, tool='test')
            self.assertTrue(result['ok'])
            reservation_ids.append(result['reservation']['id'])
        blocked = media_quota.reserve_quota('image', 1, env=self.env, tool='test')
        self.assertFalse(blocked['ok'])
        self.assertEqual(blocked['reason'], 'quota_exceeded')
        for reservation_id in reservation_ids:
            media_quota.commit_quota(reservation_id, env=self.env)

    def test_low_profile_rejects_all_image_and_video(self):
        self.assertIsNotNone(media_quota)
        env = dict(self.env)
        env['OPENCLAW_RULE_PROFILE'] = 'low'
        env['OPENCLAW_RULE_MAX_IMAGE_REQUESTS'] = '0'
        env['OPENCLAW_RULE_MAX_VIDEO_REQUESTS'] = '0'
        image = media_quota.reserve_quota('image', 1, env=env, tool='test')
        video = media_quota.reserve_quota('video', 1, env=env, tool='test')
        self.assertFalse(image['ok'])
        self.assertFalse(video['ok'])
        self.assertEqual(image['reason'], 'disabled')
        self.assertEqual(video['reason'], 'disabled')

    def test_release_frees_reserved_capacity(self):
        self.assertIsNotNone(media_quota)
        reservation = media_quota.reserve_quota('video', 1, env=self.env, tool='test')
        self.assertTrue(reservation['ok'])
        reservation_id = reservation['reservation']['id']
        blocked = media_quota.reserve_quota('video', 1, env=self.env, tool='test')
        self.assertFalse(blocked['ok'])
        media_quota.release_quota(reservation_id, env=self.env)
        allowed = media_quota.reserve_quota('video', 1, env=self.env, tool='test')
        self.assertTrue(allowed['ok'])

    def test_committed_entries_expire_outside_window(self):
        self.assertIsNotNone(media_quota)
        now = int(time.time())
        payload = {
            'version': 1,
            'entries': [
                {
                    'id': 'old-image',
                    'category': 'image',
                    'units': 5,
                    'status': 'committed',
                    'reserved_at': now - 7 * 3600,
                    'committed_at': now - 7 * 3600,
                    'expires_at': now - 6 * 3600,
                    'tool': 'test',
                }
            ],
        }
        self.state_path.write_text(json.dumps(payload), encoding='utf-8')
        status = media_quota.get_quota_status(env=self.env)
        self.assertEqual(status['image']['used'], 0)
        self.assertEqual(status['image']['remaining'], 20)

    def test_text_quota_blocks_after_max_requests(self):
        self.assertIsNotNone(media_quota)
        env = dict(self.env)
        env['OPENCLAW_RULE_MAX_REQUESTS'] = '3'
        for _ in range(3):
            reservation = media_quota.reserve_quota('text', 1, env=env, tool='test')
            self.assertTrue(reservation['ok'])
            media_quota.commit_quota(reservation['reservation']['id'], env=env)
        blocked = media_quota.reserve_quota('text', 1, env=env, tool='test')
        self.assertFalse(blocked['ok'])
        self.assertEqual(blocked['reason'], 'quota_exceeded')

    def test_status_includes_family_and_task_breakdown(self):
        self.assertIsNotNone(media_quota)
        reservation = media_quota.reserve_quota(
            'text',
            1,
            env=self.env,
            tool=json.dumps({'path': '/v1/chat/completions', 'modelFamily': 'gpt', 'taskType': 'coding_review'}),
        )
        self.assertTrue(reservation['ok'])
        media_quota.commit_quota(reservation['reservation']['id'], env=self.env)
        status = media_quota.get_quota_status(env=self.env)
        self.assertEqual(status['breakdown']['families']['gpt']['used'], 1)
        self.assertEqual(status['breakdown']['tasks']['coding_review']['used'], 1)

    def test_high_profile_text_quota_is_unlimited(self):
        self.assertIsNotNone(media_quota)
        env = dict(self.env)
        env['OPENCLAW_RULE_PROFILE'] = 'high'
        env['OPENCLAW_RULE_MAX_REQUESTS'] = '0'
        for _ in range(40):
            reservation = media_quota.reserve_quota('text', 1, env=env, tool='test')
            self.assertTrue(reservation['ok'])
            media_quota.commit_quota(reservation['reservation']['id'], env=env)
        status = media_quota.get_quota_status(env=env)
        self.assertTrue(status['text']['enabled'])
        self.assertTrue(status['text']['unlimited'])

    def test_none_profile_is_unlimited_for_all_categories(self):
        self.assertIsNotNone(media_quota)
        env = dict(self.env)
        env['OPENCLAW_RULE_PROFILE'] = 'none'
        env['OPENCLAW_RULE_MAX_REQUESTS'] = '0'
        env['OPENCLAW_RULE_MAX_IMAGE_REQUESTS'] = '0'
        env['OPENCLAW_RULE_MAX_VIDEO_REQUESTS'] = '0'
        for category in ('text', 'image', 'video'):
            for _ in range(3):
                reservation = media_quota.reserve_quota(category, 1, env=env, tool='test')
                self.assertTrue(reservation['ok'], reservation)
                media_quota.commit_quota(reservation['reservation']['id'], env=env)
        status = media_quota.get_quota_status(env=env)
        for category in ('text', 'image', 'video'):
            self.assertTrue(status[category]['enabled'])
            self.assertTrue(status[category]['unlimited'])
            self.assertEqual(status[category]['remaining'], -1)

    def test_high_profile_keeps_image_and_video_caps(self):
        self.assertIsNotNone(media_quota)
        env = dict(self.env)
        env['OPENCLAW_RULE_PROFILE'] = 'high'
        env['OPENCLAW_RULE_MAX_REQUESTS'] = '0'
        env['OPENCLAW_RULE_MAX_IMAGE_REQUESTS'] = '50'
        env['OPENCLAW_RULE_MAX_VIDEO_REQUESTS'] = '2'
        for _ in range(50):
            reservation = media_quota.reserve_quota('image', 1, env=env, tool='test')
            self.assertTrue(reservation['ok'])
            media_quota.commit_quota(reservation['reservation']['id'], env=env)
        blocked_image = media_quota.reserve_quota('image', 1, env=env, tool='test')
        self.assertFalse(blocked_image['ok'])
        self.assertEqual(blocked_image['reason'], 'quota_exceeded')
        for _ in range(2):
            reservation = media_quota.reserve_quota('video', 1, env=env, tool='test')
            self.assertTrue(reservation['ok'])
            media_quota.commit_quota(reservation['reservation']['id'], env=env)
        blocked_video = media_quota.reserve_quota('video', 1, env=env, tool='test')
        self.assertFalse(blocked_video['ok'])
        self.assertEqual(blocked_video['reason'], 'quota_exceeded')


if __name__ == '__main__':
    unittest.main()

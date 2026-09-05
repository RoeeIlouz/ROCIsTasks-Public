import unittest
from unittest.mock import patch, MagicMock
from pathlib import Path
import tempfile
import json

from scripts.marketing_bot.media_manager import MediaManager
from scripts.marketing_bot.threads_client import ThreadsClient
from scripts.marketing_bot.mastodon_client import MastodonClient
from scripts.marketing_bot.bluesky_client import BlueskyClient
from scripts.marketing_bot.devto_client import DevtoClient
from scripts.marketing_bot.hashnode_client import HashnodeClient
from scripts.marketing_bot.state_manager import StateManager
from scripts.marketing_bot.telegram_bot import TelegramBot
from scripts.marketing_bot.analytics import AnalyticsTracker
from scripts.marketing_bot.launch_kit import LaunchKitGenerator
from scripts.marketing_bot.query_tuner import QueryTuner

class TestV3MarketingFeatures(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.state_file = Path(self.temp_dir.name) / "test_state.json"
        self.state_mgr = StateManager(self.state_file)

    def tearDown(self):
        self.temp_dir.cleanup()

    # -------------------------------------------------------------------------
    # 1. MediaManager Tests
    # -------------------------------------------------------------------------
    def test_media_manager_cdn_urls(self):
        mgr = MediaManager()
        banner_url = mgr.get_default_banner_url()
        logo_url = mgr.get_logo_url()

        self.assertIn("raw.githubusercontent.com/RoeeIlouz/ROCIs-Tasks/main", banner_url)
        self.assertIn("feature_graphic.png", banner_url)
        self.assertIn("logo.png", logo_url)

    def test_media_manager_local_resolution(self):
        # Create a mock asset directory structure in temp_dir
        assets_dir = Path(self.temp_dir.name) / "assets" / "images" / "play_store"
        assets_dir.mkdir(parents=True, exist_ok=True)
        sample_img = assets_dir / "screenshot_01.png"
        sample_img.write_bytes(b"\x89PNG\r\n\x1a\nfake_image_bytes")

        mgr = MediaManager(root_dir=Path(self.temp_dir.name))
        res = mgr.get_asset_data("assets/images/play_store/screenshot_01.png")
        self.assertIsNotNone(res)
        data, mime = res
        self.assertEqual(data, b"\x89PNG\r\n\x1a\nfake_image_bytes")
        self.assertEqual(mime, "image/png")

        shots = mgr.list_available_screenshots()
        self.assertEqual(len(shots), 1)

    # -------------------------------------------------------------------------
    # 2. Platform Client Media Attachment Tests
    # -------------------------------------------------------------------------
    @patch("requests.post")
    def test_threads_post_thread_with_image(self, mock_post):
        resp1 = MagicMock()
        resp1.status_code = 200
        resp1.json.return_value = {"id": "cnt_img_123"}

        resp2 = MagicMock()
        resp2.status_code = 200
        resp2.json.return_value = {"id": "post_img_456"}

        mock_post.side_effect = [resp1, resp2]

        client = ThreadsClient(user_id="user_123", access_token="token_abc_12345")
        res = client.post_thread(
            "Check out ROCIs Tasks with widgets!",
            image_url="https://raw.githubusercontent.com/RoeeIlouz/ROCIs-Tasks/main/banner.png"
        )

        self.assertEqual(res, "https://www.threads.net/post/post_img_456")
        create_payload = mock_post.call_args_list[0][1]["data"]
        self.assertEqual(create_payload["media_type"], "IMAGE")
        self.assertEqual(create_payload["image_url"], "https://raw.githubusercontent.com/RoeeIlouz/ROCIs-Tasks/main/banner.png")

    @patch("requests.post")
    def test_mastodon_upload_media_and_post(self, mock_post):
        # Step 1: upload_media
        upload_resp = MagicMock()
        upload_resp.status_code = 200
        upload_resp.json.return_value = {"id": "mastodon_media_789"}

        # Step 2: post_status
        status_resp = MagicMock()
        status_resp.status_code = 200
        status_resp.json.return_value = {"url": "https://mastodon.social/@rocis/999"}

        mock_post.side_effect = [upload_resp, status_resp]

        client = MastodonClient(access_token="valid_mastodon_token_1234")
        media_id = client.upload_media(b"fake_bytes", mime_type="image/png", description="App Feature")
        self.assertEqual(media_id, "mastodon_media_789")

        post_url = client.post_status("Status with media", media_ids=[media_id])
        self.assertEqual(post_url, "https://mastodon.social/@rocis/999")

        call_payload = mock_post.call_args_list[1][1]["json"]
        self.assertEqual(call_payload["media_ids"], ["mastodon_media_789"])

    @patch("requests.post")
    def test_bluesky_upload_blob_and_embed(self, mock_post):
        # 1. Login response
        auth_resp = MagicMock()
        auth_resp.status_code = 200
        auth_resp.json.return_value = {"accessJwt": "jwt_123", "did": "did:plc:test1234"}

        # 2. Blob upload response
        blob_resp = MagicMock()
        blob_resp.status_code = 200
        blob_resp.json.return_value = {
            "blob": {
                "$type": "blob",
                "ref": {"$link": "bafkreitest"},
                "mimeType": "image/png",
                "size": 1024
            }
        }

        # 3. Create record response
        record_resp = MagicMock()
        record_resp.status_code = 200
        record_resp.json.return_value = {"uri": "at://did:plc:test/app.bsky.feed.post/3k12345"}

        mock_post.side_effect = [auth_resp, blob_resp, record_resp]

        client = BlueskyClient(handle="rocisapps.bsky.social", app_password="password123")
        blob = client.upload_blob(b"fake_image_bytes")
        self.assertIsNotNone(blob)

        url = client.post_reply("Post with image", image_blob=blob)
        self.assertIn("rocisapps.bsky.social", url)

        create_call_payload = mock_post.call_args_list[2][1]["json"]["record"]
        self.assertIn("embed", create_call_payload)
        self.assertEqual(create_call_payload["embed"]["$type"], "app.bsky.embed.images")

    @patch("requests.post")
    def test_devto_and_hashnode_cover_image(self, mock_post):
        # Dev.to with main_image
        devto_resp = MagicMock()
        devto_resp.status_code = 200
        devto_resp.json.return_value = {"id": 888, "url": "https://dev.to/rocis/article-888"}
        mock_post.return_value = devto_resp

        devto = DevtoClient(api_key="valid_devto_key_123")
        res_d = devto.publish_article("Title", "Body", main_image="https://cdn.example.com/banner.png")
        self.assertIsNotNone(res_d)
        devto_payload = mock_post.call_args[1]["json"]["article"]
        self.assertEqual(devto_payload["main_image"], "https://cdn.example.com/banner.png")

        # Hashnode with cover_image_url
        hash_resp = MagicMock()
        hash_resp.status_code = 200
        hash_resp.json.return_value = {
            "data": {
                "publishPost": {
                    "post": {"id": "hash_123", "slug": "slug", "url": "https://hashnode.com/post"}
                }
            }
        }
        mock_post.return_value = hash_resp

        hashnode = HashnodeClient(access_token="valid_hash_token_123", publication_id="pub_123")
        res_h = hashnode.publish_article("Title", "Body", cover_image_url="https://cdn.example.com/banner.png")
        self.assertIsNotNone(res_h)
        hash_payload = mock_post.call_args[1]["json"]["variables"]["input"]
        self.assertEqual(hash_payload["coverImageOptions"]["coverImageURL"], "https://cdn.example.com/banner.png")

    # -------------------------------------------------------------------------
    # 3. Analytics Tracker Tests
    # -------------------------------------------------------------------------
    def test_analytics_tracker_collect_and_digest(self):
        mock_bot = MagicMock()
        mock_devto = MagicMock()
        mock_devto.is_configured.return_value = True
        mock_devto.get_analytics.return_value = [
            {
                "id": 1,
                "title": "Flutter Background Isolates",
                "url": "https://dev.to/rocis/isolates",
                "page_views_count": 850,
                "positive_reactions_count": 42,
                "comments_count": 9,
                "published": True
            }
        ]

        mock_hashnode = MagicMock()
        mock_hashnode.is_configured.return_value = True
        mock_hashnode.get_publication_stats.return_value = {
            "title": "ROCIs Engineering",
            "total_views": 320,
            "total_reactions": 15,
            "total_posts": 3
        }

        mock_bsky = MagicMock()
        mock_bsky.is_configured.return_value = True
        mock_bsky.get_profile_stats.return_value = {"followers_count": 120, "posts_count": 35}

        mock_mastodon = MagicMock()
        mock_mastodon.is_configured.return_value = True
        mock_mastodon.get_profile_stats.return_value = {"followers_count": 85, "statuses_count": 28}

        tracker = AnalyticsTracker(
            state_manager=self.state_mgr,
            telegram_bot=mock_bot,
            devto_client=mock_devto,
            hashnode_client=mock_hashnode,
            bluesky_client=mock_bsky,
            mastodon_client=mock_mastodon
        )

        success = tracker.generate_and_send_digest()
        self.assertTrue(success)

        mock_bot.send_message.assert_called_once()
        digest_msg = mock_bot.send_message.call_args[0][0]
        self.assertIn("850", digest_msg)
        self.assertIn("320", digest_msg)
        self.assertIn("Flutter Background Isolates", digest_msg)
        self.assertIn("120 followers", digest_msg)

        # Verify state was saved
        saved_snapshot = self.state_mgr.data.get("analytics_snapshot")
        self.assertIsNotNone(saved_snapshot)
        self.assertEqual(saved_snapshot["devto"]["total_views"], 850)

    # -------------------------------------------------------------------------
    # 4. LaunchKitGenerator Tests
    # -------------------------------------------------------------------------
    def test_launch_kit_generator_fallback(self):
        mock_bot = MagicMock()
        mock_gemini = MagicMock()
        mock_gemini.is_available.return_value = False

        generator = LaunchKitGenerator(
            state_manager=self.state_mgr,
            telegram_bot=mock_bot,
            gemini_engine=mock_gemini
        )

        pkg = generator.generate_launch_package(version="1.1")
        self.assertIn("show_hn", pkg)
        self.assertIn("product_hunt", pkg)
        self.assertIn("ROCIs Tasks v1.1", pkg["show_hn"]["title"])
        self.assertIn("Android home widgets", pkg["product_hunt"]["tagline"])

        success = generator.dispatch_to_telegram(version="1.1")
        self.assertTrue(success)
        mock_bot.send_message.assert_called_once()
        call_text = mock_bot.send_message.call_args[0][0]
        self.assertIn("HACKER NEWS (SHOW HN)", call_text)
        self.assertIn("PRODUCT HUNT", call_text)

    # -------------------------------------------------------------------------
    # 5. QueryTuner Tests
    # -------------------------------------------------------------------------
    def test_query_tuner_caching_and_fallback(self):
        mock_gemini = MagicMock()
        mock_gemini.is_available.return_value = True
        mock_gemini.generate_text.return_value = json.dumps([
            "android home widget calendar",
            "offline tasks app privacy",
            "minimalist todo without cloud"
        ])

        tuner = QueryTuner(state_manager=self.state_mgr, gemini_engine=mock_gemini)

        # First call: should query Gemini and cache
        queries = tuner.get_active_queries()
        self.assertEqual(len(queries), 3)
        self.assertIn("android home widget calendar", queries)
        mock_gemini.generate_text.assert_called_once()

        # Second call: should use cache, zero additional Gemini calls
        mock_gemini.generate_text.reset_mock()
        cached_queries = tuner.get_active_queries()
        self.assertEqual(cached_queries, queries)
        mock_gemini.generate_text.assert_not_called()

if __name__ == "__main__":
    unittest.main()


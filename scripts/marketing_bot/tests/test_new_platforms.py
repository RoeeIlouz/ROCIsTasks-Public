import unittest
from unittest.mock import patch, MagicMock
from pathlib import Path
import tempfile

from scripts.marketing_bot.mastodon_client import MastodonClient
from scripts.marketing_bot.threads_client import ThreadsClient
from scripts.marketing_bot.hashnode_client import HashnodeClient
from scripts.marketing_bot.medium_client import MediumClient
from scripts.marketing_bot.state_manager import StateManager
from scripts.marketing_bot.telegram_bot import TelegramBot
from scripts.marketing_bot.poster import Poster

class TestNewPlatforms(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.state_file = Path(self.temp_dir.name) / "test_state.json"
        self.state_mgr = StateManager(self.state_file)

    def tearDown(self):
        self.temp_dir.cleanup()

    # -------------------------------------------------------------------------
    # 1. Mastodon Tests
    # -------------------------------------------------------------------------
    def test_mastodon_client_configuration(self):
        client_empty = MastodonClient(access_token="")
        self.assertFalse(client_empty.is_configured())
        self.assertIsNone(client_empty.post_status("test"))

        client_configured = MastodonClient(access_token="test_mastodon_token_12345")
        self.assertTrue(client_configured.is_configured())

    @patch("requests.post")
    def test_mastodon_post_status_success(self, mock_post):
        mock_resp = MagicMock()
        mock_resp.status_code = 200
        mock_resp.json.return_value = {"url": "https://mastodon.social/@rocisapps/123456789"}
        mock_post.return_value = mock_resp

        client = MastodonClient(access_token="test_token_12345678")
        url = client.post_status("Building offline Flutter apps with native widgets #buildinpublic")

        self.assertEqual(url, "https://mastodon.social/@rocisapps/123456789")
        mock_post.assert_called_once()
        call_json = mock_post.call_args[1]["json"]
        self.assertIn("Building offline Flutter apps", call_json["status"])
        self.assertEqual(call_json["visibility"], "public")

    # -------------------------------------------------------------------------
    # 2. Meta Threads Tests
    # -------------------------------------------------------------------------
    def test_threads_client_configuration(self):
        client_empty = ThreadsClient(user_id="", access_token="")
        self.assertFalse(client_empty.is_configured())
        self.assertIsNone(client_empty.post_thread("test"))

        client_configured = ThreadsClient(user_id="123456", access_token="threads_token_1234567")
        self.assertTrue(client_configured.is_configured())

    @patch("requests.post")
    def test_threads_post_thread_success(self, mock_post):
        # Mock step 1 (create container) and step 2 (publish)
        resp1 = MagicMock()
        resp1.status_code = 200
        resp1.json.return_value = {"id": "container_999"}

        resp2 = MagicMock()
        resp2.status_code = 200
        resp2.json.return_value = {"id": "post_888"}

        mock_post.side_effect = [resp1, resp2]

        client = ThreadsClient(user_id="123456", access_token="threads_token_1234567")
        url = client.post_thread("Hello Meta Threads from ROCIs Tasks!")

        self.assertEqual(url, "https://www.threads.net/post/post_888")
        self.assertEqual(mock_post.call_count, 2)

    # -------------------------------------------------------------------------
    # 3. Hashnode Tests
    # -------------------------------------------------------------------------
    def test_hashnode_client_configuration(self):
        client_empty = HashnodeClient(access_token="", publication_id="")
        self.assertFalse(client_empty.is_configured())
        self.assertIsNone(client_empty.publish_article("title", "body"))

        # Configured with token only (auto-discovery mode)
        client_token_only = HashnodeClient(access_token="hashnode_token_12345", publication_id="")
        self.assertTrue(client_token_only.is_configured())

        # Configured with both token and publication ID
        client_configured = HashnodeClient(access_token="hashnode_token_12345", publication_id="pub_12345")
        self.assertTrue(client_configured.is_configured())

    @patch("requests.post")
    def test_hashnode_auto_discover_publication_id_success(self, mock_post):
        mock_resp = MagicMock()
        mock_resp.status_code = 200
        mock_resp.json.return_value = {
            "data": {
                "me": {
                    "publications": {
                        "edges": [
                            {
                                "node": {
                                    "id": "auto_discovered_pub_999",
                                    "title": "ROCIs Engineering",
                                    "url": "https://engineering.rocisapps.com"
                                }
                            }
                        ]
                    }
                }
            }
        }
        mock_post.return_value = mock_resp

        client = HashnodeClient(access_token="valid_hashnode_token_123", publication_id=None)
        pub_id = client._get_publication_id()

        self.assertEqual(pub_id, "auto_discovered_pub_999")
        self.assertEqual(client.publication_id, "auto_discovered_pub_999")
        mock_post.assert_called_once()

    @patch("requests.post")
    def test_hashnode_auto_discover_publication_id_failure(self, mock_post):
        mock_resp = MagicMock()
        mock_resp.status_code = 200
        mock_resp.json.return_value = {
            "data": {
                "me": {
                    "publications": {
                        "edges": []
                    }
                }
            }
        }
        mock_post.return_value = mock_resp

        client = HashnodeClient(access_token="valid_hashnode_token_123", publication_id=None)
        pub_id = client._get_publication_id()

        self.assertIsNone(pub_id)

    @patch("requests.post")
    def test_hashnode_publish_article_success(self, mock_post):
        mock_resp = MagicMock()
        mock_resp.status_code = 200
        mock_resp.json.return_value = {
            "data": {
                "publishPost": {
                    "post": {
                        "id": "post_abc",
                        "slug": "flutter-background-isolates",
                        "url": "https://blog.rocisapps.com/flutter-background-isolates"
                    }
                }
            }
        }
        mock_post.return_value = mock_resp

        client = HashnodeClient(access_token="valid_hashnode_token_123", publication_id="pub_123")
        res = client.publish_article(
            title="Flutter Background Isolates",
            body_markdown="Content goes here...",
            canonical_url="https://dev.to/rocisapps/article-123"
        )

        self.assertIsNotNone(res)
        self.assertEqual(res["url"], "https://blog.rocisapps.com/flutter-background-isolates")
        call_json = mock_post.call_args[1]["json"]
        self.assertEqual(call_json["variables"]["input"]["originalArticleURL"], "https://dev.to/rocisapps/article-123")
        self.assertEqual(call_json["variables"]["input"]["publicationId"], "pub_123")

    @patch("requests.post")
    def test_hashnode_publish_article_with_auto_discovery(self, mock_post):
        # First call: _get_publication_id, second call: publishPost mutation
        resp_discover = MagicMock()
        resp_discover.status_code = 200
        resp_discover.json.return_value = {
            "data": {
                "me": {
                    "publications": {
                        "edges": [
                            {
                                "node": {
                                    "id": "discovered_pub_456",
                                    "title": "ROCIs Engineering Blog"
                                }
                            }
                        ]
                    }
                }
            }
        }

        resp_publish = MagicMock()
        resp_publish.status_code = 200
        resp_publish.json.return_value = {
            "data": {
                "publishPost": {
                    "post": {
                        "id": "post_xyz",
                        "slug": "auto-discovered-post",
                        "url": "https://blog.rocisapps.com/auto-discovered-post"
                    }
                }
            }
        }

        mock_post.side_effect = [resp_discover, resp_publish]

        client = HashnodeClient(access_token="valid_hashnode_token_123", publication_id="")
        res = client.publish_article(
            title="Auto Discovery Test",
            body_markdown="Testing auto-discovery in publish_article...",
            canonical_url="https://dev.to/rocisapps/article-456"
        )

        self.assertIsNotNone(res)
        self.assertEqual(res["url"], "https://blog.rocisapps.com/auto-discovered-post")
        self.assertEqual(mock_post.call_count, 2)
        publish_call_json = mock_post.call_args_list[1][1]["json"]
        self.assertEqual(publish_call_json["variables"]["input"]["publicationId"], "discovered_pub_456")

    # -------------------------------------------------------------------------
    # 4. Medium Tests
    # -------------------------------------------------------------------------
    def test_medium_client_configuration(self):
        client_empty = MediumClient(integration_token="")
        self.assertFalse(client_empty.is_configured())
        self.assertIsNone(client_empty.publish_article("title", "body"))

        client_configured = MediumClient(integration_token="medium_token_1234567")
        self.assertTrue(client_configured.is_configured())

    @patch("requests.get")
    @patch("requests.post")
    def test_medium_publish_article_success(self, mock_post, mock_get):
        # Mock /me call
        get_resp = MagicMock()
        get_resp.status_code = 200
        get_resp.json.return_value = {"data": {"id": "medium_user_456"}}
        mock_get.return_value = get_resp

        # Mock /posts call
        post_resp = MagicMock()
        post_resp.status_code = 201
        post_resp.json.return_value = {
            "data": {
                "id": "med_post_789",
                "url": "https://medium.com/@rocisapps/article-789"
            }
        }
        mock_post.return_value = post_resp

        client = MediumClient(integration_token="valid_medium_token_123")
        res = client.publish_article(
            title="Why Your Flutter Widgets Crash",
            body_markdown="Article content here...",
            canonical_url="https://dev.to/rocisapps/article-123"
        )

        self.assertIsNotNone(res)
        self.assertEqual(res["url"], "https://medium.com/@rocisapps/article-789")
        call_json = mock_post.call_args[1]["json"]
        self.assertEqual(call_json["canonicalUrl"], "https://dev.to/rocisapps/article-123")

    # -------------------------------------------------------------------------
    # 5. Poster execute_devlog multi-platform cross-posting
    # -------------------------------------------------------------------------
    def test_poster_execute_devlog_cross_posting_graceful(self):
        bot = TelegramBot(token="", chat_id="")
        poster = Poster(self.state_mgr, bot)

        draft = {
            "id": "devlog_test_cross_platform",
            "milestone_slug": "test_milestone_multi",
            "devto_title": "Offline-First Flutter Architecture",
            "devto_body": "Deep dive into offline caching with Hive and SQLite.",
            "tags": ["flutter", "android"],
            "x_text": "How we built offline caching in Flutter",
            "bsky_text": "Building offline caching with Hive",
            "mastodon_text": "Deep dive into offline caching in Flutter #buildinpublic",
            "threads_text": "How we made our Flutter app 100% offline first"
        }

        # With unconfigured tokens, it should safely skip remote calls and not crash
        res = poster.execute_devlog(draft)
        self.assertTrue(res)

        posted_devlogs = self.state_mgr.data.get("posted_devlogs", {})
        self.assertIn("test_milestone_multi", posted_devlogs)

    def test_poster_execute_devlog_medium_helper_attached(self):
        mock_bot = MagicMock()
        poster = Poster(self.state_mgr, mock_bot)
        poster.devto = MagicMock()
        poster.devto.is_configured.return_value = True
        poster.devto.publish_article.return_value = {
            "id": 123,
            "url": "https://dev.to/rocisapps/offline-flutter-test"
        }

        draft = {
            "id": "devlog_test_medium_helper",
            "milestone_slug": "test_milestone_medium_helper",
            "devto_title": "Offline-First Flutter Architecture",
            "devto_body": "Content",
            "telegram_message_id": 555
        }

        res = poster.execute_devlog(draft)
        self.assertTrue(res)

        mock_bot.edit_message_text.assert_called_once()
        call_args = mock_bot.edit_message_text.call_args
        msg_text = call_args[0][1]
        reply_markup = call_args[1].get("reply_markup")

        self.assertIn("Medium (1-Click Import)", msg_text)
        self.assertIn("https://dev.to/rocisapps/offline-flutter-test", msg_text)
        self.assertIsNotNone(reply_markup)
        buttons = reply_markup.get("inline_keyboard", [])
        button_urls = [btn["url"] for row in buttons for btn in row if "url" in btn]
        self.assertIn("https://medium.com/p/import", button_urls)
        self.assertIn("https://dev.to/rocisapps/offline-flutter-test", button_urls)

if __name__ == "__main__":
    unittest.main()

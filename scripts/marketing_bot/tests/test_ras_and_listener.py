import unittest
from unittest.mock import patch, MagicMock
from pathlib import Path
import tempfile
import json

from scripts.marketing_bot.ras_client import RASClient
from scripts.marketing_bot.telegram_bot import TelegramBot
from scripts.marketing_bot.poster import Poster
from scripts.marketing_bot.state_manager import StateManager
from scripts.marketing_bot.gemini_engine import GeminiEngine
from scripts.marketing_bot.telegram_listener import TelegramListener


class TestRASAndTelegramListener(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.state_file = Path(self.temp_dir.name) / "test_state.json"
        self.state_mgr = StateManager(self.state_file)

    def tearDown(self):
        self.temp_dir.cleanup()

    # -------------------------------------------------------------------------
    # 1. RASClient Tests
    # -------------------------------------------------------------------------
    @patch("requests.get")
    def test_ras_is_online_true(self, mock_get):
        mock_res = MagicMock()
        mock_res.status_code = 200
        mock_get.return_value = mock_res

        client = RASClient("http://localhost:3000")
        self.assertTrue(client.is_online())

    @patch("requests.get")
    def test_ras_is_online_false_on_connection_error(self, mock_get):
        mock_get.side_effect = Exception("Connection refused")

        client = RASClient("http://localhost:3000")
        self.assertFalse(client.is_online())

    @patch("requests.get")
    def test_ras_get_tasks_telemetry(self, mock_get):
        mock_res = MagicMock()
        mock_res.status_code = 200
        mock_res.json.return_value = {
            "success": True,
            "data": {
                "app": {"name": "ROCI's Tasks", "version": "0.2.10", "buildNumber": 88},
                "metrics": {"dau": 1840, "mau": 24900, "dauGrowth": 14.8},
                "stability": {"crashFreeRate": 99.85},
                "googleTasksSync": {"totalSyncs24h": 48200, "averageLatencyMs": 142}
            }
        }
        mock_get.return_value = mock_res

        client = RASClient("http://localhost:3000")
        telemetry = client.get_tasks_telemetry()
        self.assertIsNotNone(telemetry)
        self.assertEqual(telemetry["app"]["version"], "0.2.10")
        self.assertEqual(telemetry["metrics"]["dau"], 1840)

        # Grounded context summary when online
        summary = client.get_grounded_context_summary()
        self.assertIn("ONLINE", summary)
        self.assertIn("1,840 DAU", summary)
        self.assertIn("99.85%", summary)

    @patch("requests.get")
    def test_ras_offline_graceful_fallback(self, mock_get):
        mock_get.side_effect = Exception("Server not running")

        client = RASClient("http://localhost:3000")
        summary = client.get_grounded_context_summary()

        self.assertIn("OFFLINE (Fallback Mode)", summary)
        self.assertIn("ROCIs Tasks", summary)

    @patch("requests.post")
    def test_ras_query_cognition(self, mock_post):
        mock_res = MagicMock()
        mock_res.status_code = 200
        mock_res.text = "data: Live spatial runtime telemetry indicates 120 FPS.\n"
        mock_post.return_value = mock_res

        client = RASClient("http://localhost:3000")
        reply = client.query_ras_cognition("Status check")
        self.assertIsNotNone(reply)
        self.assertIn("120 FPS", reply)

    # -------------------------------------------------------------------------
    # 2. TelegramBot Interactive Card Builders
    # -------------------------------------------------------------------------
    @patch("requests.post")
    def test_send_interactive_draft_card(self, mock_post):
        mock_res = MagicMock()
        mock_res.status_code = 200
        mock_res.json.return_value = {"result": {"message_id": 12345}}
        mock_post.return_value = mock_res

        bot = TelegramBot(token="123456789:ABCDefghIJKLmnoPQRstuvWXyz", chat_id="999888")
        msg_id = bot.send_interactive_draft_card(
            draft_id="od_test123",
            platform="bsky",
            content="Check out the new Android home screen widget!",
            topic="Home screen widgets"
        )
        self.assertEqual(msg_id, 12345)

        # Verify inline keyboard layout
        call_args = mock_post.call_args[1]["json"]
        self.assertIn("reply_markup", call_args)
        buttons = call_args["reply_markup"]["inline_keyboard"]
        self.assertEqual(buttons[0][0]["callback_data"], "approve:od_test123")
        self.assertEqual(buttons[0][1]["callback_data"], "regen:od_test123")
        self.assertEqual(buttons[1][0]["callback_data"], "reject:od_test123")

    @patch("requests.post")
    def test_send_multi_platform_approval_card(self, mock_post):
        mock_res = MagicMock()
        mock_res.status_code = 200
        mock_res.json.return_value = {"result": {"message_id": 54321}}
        mock_post.return_value = mock_res

        bot = TelegramBot(token="123456789:ABCDefghIJKLmnoPQRstuvWXyz", chat_id="999888")
        drafts = {
            "bsky": "Bluesky post content",
            "x": "X tweet content",
            "mastodon": "Mastodon status content"
        }
        msg_id = bot.send_multi_platform_approval_card(
            group_id="grp_999",
            drafts=drafts,
            topic="Multi-platform update"
        )
        self.assertEqual(msg_id, 54321)

        call_args = mock_post.call_args[1]["json"]
        buttons = call_args["reply_markup"]["inline_keyboard"]
        # Top button: Approve all
        self.assertEqual(buttons[0][0]["callback_data"], "approve_all:grp_999")
        # Bottom button: Cancel all
        self.assertEqual(buttons[-1][0]["callback_data"], "reject_all:grp_999")

    # -------------------------------------------------------------------------
    # 3. Poster.publish_single_post Tests
    # -------------------------------------------------------------------------
    def test_publish_single_post_bsky(self):
        bot = TelegramBot(token="fake", chat_id="fake")
        poster = Poster(self.state_mgr, bot)
        poster.bluesky.is_configured = MagicMock(return_value=True)
        poster.bluesky.post_reply = MagicMock(return_value="https://bsky.app/profile/user/post/123")

        res = poster.publish_single_post("bsky", "Hello Bluesky!")
        self.assertTrue(res["success"])
        self.assertEqual(res["url"], "https://bsky.app/profile/user/post/123")

    def test_publish_single_post_x(self):
        bot = TelegramBot(token="fake", chat_id="fake")
        poster = Poster(self.state_mgr, bot)
        poster.x_client.is_configured = MagicMock(return_value=True)
        poster.x_client.can_post = MagicMock(return_value=True)
        poster.x_client.post_tweet = MagicMock(return_value="https://x.com/user/status/456")

        res = poster.publish_single_post("x", "Hello Twitter!")
        self.assertTrue(res["success"])
        self.assertEqual(res["url"], "https://x.com/user/status/456")

    def test_publish_single_post_mastodon(self):
        bot = TelegramBot(token="fake", chat_id="fake")
        poster = Poster(self.state_mgr, bot)
        poster.mastodon.is_configured = MagicMock(return_value=True)
        poster.mastodon.post_status = MagicMock(return_value="https://mastodon.social/@user/789")

        res = poster.publish_single_post("mastodon", "Hello Fediverse!")
        self.assertTrue(res["success"])
        self.assertEqual(res["url"], "https://mastodon.social/@user/789")

    # -------------------------------------------------------------------------
    # 4. TelegramListener Command & Callback Tests
    # -------------------------------------------------------------------------
    def test_listener_command_help(self):
        mock_bot = MagicMock()
        mock_bot.is_configured.return_value = True
        listener = TelegramListener(telegram_bot=mock_bot, state_manager=self.state_mgr)

        listener.handle_command("/help")
        mock_bot.send_message.assert_called_once()
        self.assertIn("/draft", mock_bot.send_message.call_args[0][0])

    def test_listener_command_status(self):
        mock_bot = MagicMock()
        mock_bot.is_configured.return_value = True
        listener = TelegramListener(telegram_bot=mock_bot, state_manager=self.state_mgr)

        listener.handle_command("/status")
        mock_bot.send_message.assert_called_once()
        self.assertIn("System Status & Health", mock_bot.send_message.call_args[0][0])

    def test_listener_command_draft_single(self):
        mock_bot = MagicMock()
        mock_bot.is_configured.return_value = True
        mock_gemini = MagicMock()
        mock_gemini.draft_social_post.return_value = "Drafted Bluesky Post #indiedev"

        listener = TelegramListener(
            telegram_bot=mock_bot,
            state_manager=self.state_mgr,
            gemini=mock_gemini
        )

        listener.handle_command("/draft bsky Widgets update")
        mock_gemini.draft_social_post.assert_called_once()
        mock_bot.send_interactive_draft_card.assert_called_once()

        # Verify stored in pending drafts
        self.assertEqual(len(listener.pending_drafts), 1)
        draft_id = list(listener.pending_drafts.keys())[0]
        self.assertEqual(listener.pending_drafts[draft_id]["platform"], "bsky")

    def test_listener_command_draft_all(self):
        mock_bot = MagicMock()
        mock_bot.is_configured.return_value = True
        mock_gemini = MagicMock()
        mock_gemini.draft_social_post.side_effect = lambda p, topic, ctx: f"Post for {p}"

        listener = TelegramListener(
            telegram_bot=mock_bot,
            state_manager=self.state_mgr,
            gemini=mock_gemini
        )

        listener.handle_command("/draft all Product Hunt launch")
        mock_bot.send_multi_platform_approval_card.assert_called_once()

        # Verify stored in pending groups
        self.assertEqual(len(listener.pending_groups), 1)
        group_id = list(listener.pending_groups.keys())[0]
        self.assertIn("bsky", listener.pending_groups[group_id]["drafts"])
        self.assertIn("x", listener.pending_groups[group_id]["drafts"])

    def test_listener_callback_approve_single(self):
        mock_bot = MagicMock()
        mock_poster = MagicMock()
        mock_poster.publish_single_post.return_value = {"success": True, "url": "https://bsky.app/post/111"}

        listener = TelegramListener(
            telegram_bot=mock_bot,
            poster=mock_poster,
            state_manager=self.state_mgr
        )
        listener.pending_drafts["od_123"] = {
            "id": "od_123",
            "platform": "bsky",
            "topic": "Testing",
            "content": "Awesome post"
        }

        listener.handle_callback("approve:od_123", cb_id="cb_1", msg_id=777)
        mock_poster.publish_single_post.assert_called_once_with(platform="bsky", text="Awesome post")
        mock_bot.edit_message_text.assert_called_once()
        self.assertNotIn("od_123", listener.pending_drafts)

    def test_listener_callback_reject(self):
        mock_bot = MagicMock()
        listener = TelegramListener(telegram_bot=mock_bot, state_manager=self.state_mgr)
        listener.pending_drafts["od_456"] = {
            "id": "od_456",
            "platform": "x",
            "topic": "Canceled topic",
            "content": "Canceled content"
        }

        listener.handle_callback("reject:od_456", cb_id="cb_2", msg_id=888)
        self.assertNotIn("od_456", listener.pending_drafts)
        mock_bot.edit_message_text.assert_called_once()
        self.assertIn("canceled", mock_bot.edit_message_text.call_args[0][1].lower())

    def test_listener_callback_approve_all(self):
        mock_bot = MagicMock()
        mock_poster = MagicMock()
        mock_poster.publish_single_post.side_effect = lambda platform, text: {
            "success": True,
            "url": f"https://{platform}.com/post/999"
        }

        listener = TelegramListener(
            telegram_bot=mock_bot,
            poster=mock_poster,
            state_manager=self.state_mgr
        )
        listener.pending_groups["grp_100"] = {
            "id": "grp_100",
            "topic": "Big Release",
            "drafts": {
                "bsky": "Post Bsky",
                "x": "Post X"
            }
        }

        listener.handle_callback("approve_all:grp_100", cb_id="cb_3", msg_id=999)
        self.assertEqual(mock_poster.publish_single_post.call_count, 2)
        mock_bot.edit_message_text.assert_called_once()
        self.assertNotIn("grp_100", listener.pending_groups)

    @patch("requests.get")
    @patch("requests.post")
    def test_telegram_bot_has_token_and_dynamic_chat_id(self, mock_post, mock_get):
        bot = TelegramBot(token="123456789:ABCDefghIJKLmnoPQRstuvWXyz", chat_id=None)
        self.assertTrue(bot.has_token())
        self.assertFalse(bot.is_configured())  # chat_id is missing

        # get_updates works with token alone
        mock_res = MagicMock()
        mock_res.status_code = 200
        mock_res.json.return_value = {"result": [{"update_id": 1}]}
        mock_get.return_value = mock_res

        updates = bot.get_updates()
        self.assertEqual(len(updates), 1)

        # send_message works when dynamic chat_id is passed
        mock_post_res = MagicMock()
        mock_post_res.status_code = 200
        mock_post_res.json.return_value = {"result": {"message_id": 999}}
        mock_post.return_value = mock_post_res

        msg = bot.send_message("Hello dynamic", chat_id="dynamic_chat_123")
        self.assertIsNotNone(msg)
        payload = mock_post.call_args[1]["json"]
        self.assertEqual(payload["chat_id"], "dynamic_chat_123")

    def test_listener_run_polling_stops_when_no_token(self):
        mock_bot = MagicMock()
        mock_bot.has_token.return_value = False
        listener = TelegramListener(telegram_bot=mock_bot, state_manager=self.state_mgr)

        # run_polling should return immediately and not enter infinite loop
        listener.run_polling()
        self.assertFalse(listener.running)

    def test_listener_routes_dynamic_chat_id(self):
        mock_bot = MagicMock()
        mock_bot.has_token.return_value = True
        listener = TelegramListener(telegram_bot=mock_bot, state_manager=self.state_mgr)

        raw_update = {
            "update_id": 42,
            "message": {
                "message_id": 100,
                "from": {"id": 123456},
                "chat": {"id": 789012},
                "text": "/help"
            }
        }
        listener.process_update(raw_update)
        mock_bot.send_message.assert_called_once()
        self.assertEqual(mock_bot.send_message.call_args[1].get("chat_id"), 789012)


if __name__ == "__main__":
    unittest.main()

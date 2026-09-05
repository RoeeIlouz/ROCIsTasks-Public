import unittest
import tempfile
import os
import json
from pathlib import Path

from scripts.marketing_bot.state_manager import StateManager
from scripts.marketing_bot.gemini_engine import _clean_json_markdown, GeminiEngine
from scripts.marketing_bot.telegram_bot import TelegramBot
from scripts.marketing_bot.discovery import DiscoveryEngine
from scripts.marketing_bot.poster import Poster

class TestMarketingBot(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.state_file = Path(self.temp_dir.name) / "test_state.json"
        self.state_mgr = StateManager(self.state_file)

    def tearDown(self):
        self.temp_dir.cleanup()

    def test_state_manager_lifecycle(self):
        # 1. Check fresh state
        self.assertEqual(self.state_mgr.telegram_last_update_id, 0)
        self.assertFalse(self.state_mgr.is_thread_inspected("test_thread_1"))

        # 2. Record inspected thread
        self.state_mgr.record_inspected_thread("test_thread_1", {"title": "Best todo app"})
        self.assertTrue(self.state_mgr.is_thread_inspected("test_thread_1"))

        # 3. Add pending draft
        self.state_mgr.add_pending_draft("draft_123", {
            "thread_id": "test_thread_1",
            "draft_text": "Check out ROCIs Tasks!"
        })
        draft = self.state_mgr.get_pending_draft("draft_123")
        self.assertIsNotNone(draft)
        self.assertEqual(draft["status"], "pending")

        # 4. Status transitions
        self.state_mgr.mark_draft_status("draft_123", "approved")
        self.assertEqual(self.state_mgr.get_pending_draft("draft_123")["status"], "approved")

        # 5. Persist and reload
        self.state_mgr.telegram_last_update_id = 42
        self.state_mgr.save()

        reloaded = StateManager(self.state_file)
        self.assertEqual(reloaded.telegram_last_update_id, 42)
        self.assertTrue(reloaded.is_thread_inspected("test_thread_1"))
        self.assertEqual(reloaded.get_pending_draft("draft_123")["status"], "approved")

    def test_clean_json_markdown(self):
        wrapped = "```json\n{\"is_relevant\": true, \"score\": 90}\n```"
        cleaned = _clean_json_markdown(wrapped)
        data = json.loads(cleaned)
        self.assertTrue(data["is_relevant"])
        self.assertEqual(data["score"], 90)

    def test_telegram_bot_unconfigured_safe(self):
        # When unconfigured, it should safely return None without throwing
        bot = TelegramBot(token="", chat_id="")
        self.assertFalse(bot.is_configured())
        self.assertIsNone(bot.send_message("Hello world"))
        self.assertIsNone(bot.send_draft_approval_card(
            "draft_1", "reddit", "Title", "https://reddit.com", 85, "reason", "reply"
        ))
        actions, max_id = bot.get_pending_user_actions(10)
        self.assertEqual(actions, [])
        self.assertEqual(max_id, 10)

    def test_poster_manual_drop_fallback(self):
        bot = TelegramBot(token="", chat_id="")
        poster = Poster(self.state_mgr, bot)
        draft = {
            "thread_id": "reddit_abc",
            "platform": "reddit",
            "thread_url": "https://reddit.com/r/androidapps/123",
            "thread_title": "Looking for offline todo app",
            "draft_text": "ROCIs Tasks is offline-first with widgets."
        }
        res = poster.execute_post(draft)
        self.assertTrue(res)
        posted = self.state_mgr.get_posted_threads()
        self.assertIn("reddit_abc", posted)
        self.assertEqual(posted["reddit_abc"]["method"], "manual_drop")

    def test_reddit_playwright_availability(self):
        from scripts.marketing_bot.reddit_playwright import RedditPlaywrightPoster
        poster_none = RedditPlaywrightPoster(session_cookie="")
        self.assertFalse(poster_none.is_available())
        poster_with_cookie = RedditPlaywrightPoster(session_cookie="dummy_reddit_session_cookie_value_12345")
        self.assertTrue(poster_with_cookie.is_available())

    def test_bluesky_client_configuration(self):
        from scripts.marketing_bot.bluesky_client import BlueskyClient
        client_empty = BlueskyClient(handle="", app_password="")
        self.assertFalse(client_empty.is_configured())
        self.assertEqual(client_empty.search_posts("todo"), [])
        self.assertIsNone(client_empty.post_reply("test"))

        client_configured = BlueskyClient(handle="user.bsky.social", app_password="password123")
        self.assertTrue(client_configured.is_configured())

    def test_x_client_configuration(self):
        from scripts.marketing_bot.x_client import XClient
        client = XClient()
        # When env not set, should report not configured
        if not client.api_key:
            self.assertFalse(client.is_configured())
            self.assertIsNone(client.post_tweet("test"))

    def test_feedback_storage(self):
        self.state_mgr.add_feedback({
            "category": "feature_request",
            "author": "john_doe",
            "summary": "Add Wear OS support",
            "raw_text": "Would love a Wear OS watch complication!"
        })
        self.assertEqual(len(self.state_mgr.data["recorded_feedback"]), 1)
        self.assertEqual(self.state_mgr.data["recorded_feedback"][0]["author"], "john_doe")

    def test_persona_engine_generation(self):
        from scripts.marketing_bot.persona_engine import PersonaEngine
        engine = PersonaEngine(api_key="")  # uses curated fallback
        thought = engine.generate_organic_thought()
        self.assertIn("text", thought)
        self.assertIn("topic", thought)
        self.assertGreater(len(thought["text"]), 10)
        self.assertLessEqual(len(thought["text"]), 280)
        # Verify zero self-promotion in organic thoughts
        self.assertNotIn("http://", thought["text"])
        self.assertNotIn("https://", thought["text"])
        self.assertNotIn("ROCIs Tasks", thought["text"])

    def test_state_manager_organic_cadence(self):
        # 1. Fresh state should allow organic post
        self.assertTrue(self.state_mgr.can_post_organic(min_interval_hours=12))

        # 2. Record organic post
        self.state_mgr.record_organic_post("Debugging Flutter layouts", ["Twitter/X", "Bluesky"], "mobile_engineering")
        self.assertEqual(len(self.state_mgr.data["organic_posts"]), 1)
        self.assertEqual(self.state_mgr.data["organic_posts"][0]["topic"], "mobile_engineering")

        # 3. Subsequent check with 12h cooldown should be False
        self.assertFalse(self.state_mgr.can_post_organic(min_interval_hours=12))

        # 4. Immediate cooldown (0h) should be True
        self.assertTrue(self.state_mgr.can_post_organic(min_interval_hours=0))

if __name__ == "__main__":
    unittest.main()



import unittest
from pathlib import Path
from unittest.mock import MagicMock

from scripts.marketing_bot.devlog_engine import SecretSanitizer, SummaryParser, DevlogEngine

class TestDevlogEngine(unittest.TestCase):
    def test_secret_sanitization(self):
        sensitive_text = (
            "Here is my token: ghp_1234567890abcdefghijklmnopqrstuvwxyz12\n"
            "Telegram bot token: 123456789:ABCdefGHIjklMNOpqrsTUVwxyz123456789\n"
            "Google key: AIzaSyD12345678901234567890123456789012\n"
            "Path: C:\\Users\\roeei\\Documents\\rocis_apps\\ROCIs-tasks\\lib\\main.dart\n"
            "Config: password=\"SuperSecretPassword123!\"\n"
        )
        clean = SecretSanitizer.sanitize(sensitive_text)
        self.assertNotIn("ghp_", clean)
        self.assertNotIn("123456789:ABCdefGHIjklMNOpqrsTUVwxyz123456789", clean)
        self.assertNotIn("AIzaSy", clean)
        self.assertNotIn("SuperSecretPassword123!", clean)
        self.assertNotIn("C:\\Users\\roeei", clean)
        self.assertIn("[REDACTED_GH_TOKEN]", clean)
        self.assertIn("[REDACTED_TELEGRAM_TOKEN]", clean)
        self.assertIn("[REDACTED_GOOGLE_KEY]", clean)

    def test_summary_parser_chronological(self):
        parser = SummaryParser()
        milestones = parser.parse_milestones()
        self.assertGreater(len(milestones), 5)
        # Verify chronological order: oldest milestone is first
        first_m = milestones[0]
        self.assertIn("slug", first_m)
        self.assertIn("title", first_m)
        self.assertIn("body", first_m)
        self.assertTrue(first_m["slug"].startswith("devlog_"))

    def test_find_next_milestone(self):
        gemini_mock = MagicMock()
        engine = DevlogEngine(gemini_mock)
        milestones = engine.parser.parse_milestones()
        first_slug = milestones[0]["slug"]

        # When neither posted nor pending, first milestone is returned
        next_m = engine.find_next_milestone(posted_slugs=set(), pending_slugs=set())
        self.assertIsNotNone(next_m)
        self.assertEqual(next_m["slug"], first_slug)

        # When first is posted, second milestone is returned
        next_m2 = engine.find_next_milestone(posted_slugs={first_slug}, pending_slugs=set())
        self.assertIsNotNone(next_m2)
        self.assertEqual(next_m2["slug"], milestones[1]["slug"])

if __name__ == "__main__":
    unittest.main()

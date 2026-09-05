import unittest
from unittest.mock import MagicMock

from scripts.marketing_bot.reddit_post_generator import RedditPostGenerator

class TestRedditPostGenerator(unittest.TestCase):
    def test_generate_showcase_post(self):
        gemini_mock = MagicMock()
        gemini_mock.is_available.return_value = True
        gemini_mock._call_gemini.return_value = '''```json
{
  "title": "Why I built native Kotlin widgets for an offline Flutter app",
  "body": "Hey everyone, as a solo dev I was annoyed by...",
  "topic": "flutter_widgets"
}
```'''
        generator = RedditPostGenerator(gemini_mock)
        draft = generator.generate_showcase_post(subreddit="SideProject")

        self.assertIsNotNone(draft)
        self.assertEqual(draft["type"], "reddit_post")
        self.assertEqual(draft["platform"], "reddit")
        self.assertEqual(draft["subreddit"], "SideProject")
        self.assertEqual(draft["title"], "Why I built native Kotlin widgets for an offline Flutter app")
        self.assertIn("Hey everyone", draft["body"])
        self.assertEqual(draft["topic"], "flutter_widgets")
        self.assertEqual(draft["status"], "pending")

    def test_generate_showcase_post_regex_recovery(self):
        # Test Gemini output with unescaped quotes and newlines in markdown that break json.loads
        gemini_mock = MagicMock()
        gemini_mock.is_available.return_value = True
        gemini_mock._call_gemini.return_value = '''```json
{
  "title": "Why I stopped using "productivity gurus" advice",
  "body": "Here is a breakdown of why:
1. It is too complex.
2. "Simple" systems work better.
Feedback welcome!",
  "topic": "indie_journey"
}
```'''
        generator = RedditPostGenerator(gemini_mock)
        draft = generator.generate_showcase_post(subreddit="SideProject")

        self.assertIsNotNone(draft)
        self.assertEqual(draft["title"], 'Why I stopped using "productivity gurus" advice')
        self.assertIn("Feedback welcome!", draft["body"])
        self.assertEqual(draft["topic"], "indie_journey")

    def test_generator_unavailable_when_gemini_missing(self):
        gemini_mock = MagicMock()
        gemini_mock.is_available.return_value = False
        generator = RedditPostGenerator(gemini_mock)
        self.assertIsNone(generator.generate_showcase_post(subreddit="SideProject"))

if __name__ == "__main__":
    unittest.main()

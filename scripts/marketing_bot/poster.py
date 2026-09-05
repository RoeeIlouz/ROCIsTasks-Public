import logging
from typing import Dict, Any, Optional

from .config import (
    REDDIT_CLIENT_ID,
    REDDIT_CLIENT_SECRET,
    REDDIT_USERNAME,
    REDDIT_PASSWORD,
    REDDIT_USER_AGENT
)
from .state_manager import StateManager
from .telegram_bot import TelegramBot

logger = logging.getLogger(__name__)

class Poster:
    def __init__(self, state_manager: StateManager, telegram_bot: TelegramBot):
        self.state_manager = state_manager
        self.telegram = telegram_bot
        self._reddit = None

    def _get_reddit_client(self):
        if self._reddit is not None:
            return self._reddit

        if all([REDDIT_CLIENT_ID, REDDIT_CLIENT_SECRET, REDDIT_USERNAME, REDDIT_PASSWORD]):
            try:
                import praw
                self._reddit = praw.Reddit(
                    client_id=REDDIT_CLIENT_ID,
                    client_secret=REDDIT_CLIENT_SECRET,
                    username=REDDIT_USERNAME,
                    password=REDDIT_PASSWORD,
                    user_agent=REDDIT_USER_AGENT
                )
                logger.info("Reddit PRAW client initialized.")
            except Exception as e:
                logger.error(f"Failed to initialize PRAW: {e}")
        return self._reddit

    def execute_post(self, draft: Dict[str, Any]) -> bool:
        """
        Executes posting for an approved draft.
        Uses direct API posting if credentials exist; otherwise delivers a 1-tap copy card.
        """
        platform = draft.get("platform")
        thread_id = draft.get("thread_id")
        thread_url = draft.get("thread_url")
        draft_text = draft.get("draft_text")
        thread_title = draft.get("thread_title", "")

        reddit_client = self._get_reddit_client()

        if platform == "reddit" and reddit_client:
            try:
                # Extract clean reddit submission ID (strip 'reddit_')
                sub_id = thread_id.replace("reddit_", "")
                submission = reddit_client.submission(id=sub_id)
                comment = submission.reply(draft_text)
                comment_url = f"https://reddit.com{comment.permalink}"

                self.state_manager.record_posted_thread(thread_id, {
                    "platform": "reddit",
                    "thread_url": thread_url,
                    "post_id": comment.id,
                    "comment_url": comment_url,
                    "posted_text": draft_text,
                    "thread_title": thread_title
                })

                self.telegram.send_message(
                    f"🚀 <b>Successfully Posted to Reddit!</b>\n\n"
                    f"📌 <b>Thread:</b> <a href=\"{comment_url}\">{thread_title}</a>\n"
                    f"<i>Monitoring for incoming comments and feature suggestions...</i>"
                )
                return True
            except Exception as e:
                logger.error(f"Failed to post comment to Reddit: {e}")
                self.telegram.send_message(f"⚠️ Failed to auto-post to Reddit: {e}")

        # Fallback / Direct 1-Tap Manual Drop for platforms without API credentials
        safe_title = thread_title.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
        safe_text = draft_text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")

        card_text = (
            f"📋 <b>1-Click Promotion Drop Ready ({platform.upper()})</b>\n\n"
            f"📌 <b>Thread:</b> <a href=\"{thread_url}\">{safe_title}</a>\n\n"
            f"<i>Tap the block below to copy response directly to your clipboard, then paste into the thread:</i>\n\n"
            f"<code>{safe_text}</code>"
        )
        reply_markup = {
            "inline_keyboard": [
                [{"text": "🌐 Open Thread to Paste", "url": thread_url}]
            ]
        }
        self.telegram.send_message(card_text, reply_markup=reply_markup)

        self.state_manager.record_posted_thread(thread_id, {
            "platform": platform,
            "thread_url": thread_url,
            "posted_text": draft_text,
            "thread_title": thread_title,
            "type": "manual_drop"
        })
        return True


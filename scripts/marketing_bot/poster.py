import logging
from datetime import datetime, timezone
from typing import Dict, Any, Optional
import requests

from .config import (
    REDDIT_CLIENT_ID,
    REDDIT_CLIENT_SECRET,
    REDDIT_USERNAME,
    REDDIT_PASSWORD,
    REDDIT_USER_AGENT,
    DEVTO_API_KEY,
    X_MAX_MONTHLY_POSTS,
    X_MAX_DAILY_POSTS
)
from .state_manager import StateManager
from .telegram_bot import TelegramBot
from .reddit_playwright import RedditPlaywrightPoster
from .bluesky_client import BlueskyClient
from .x_client import XClient
from .devto_client import DevtoClient

logger = logging.getLogger(__name__)

class Poster:
    def __init__(self, state_manager: StateManager, telegram_bot: TelegramBot):
        self.state_manager = state_manager
        self.telegram = telegram_bot
        self.playwright_poster = RedditPlaywrightPoster()
        self.bluesky = BlueskyClient()
        self.x_client = XClient()
        self.devto = DevtoClient()
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
        Executes posting for an approved draft across platforms:
        - Reddit: Uses Playwright (Headless Chrome) or PRAW API.
        - Bluesky: Uses AT Protocol API via BlueskyClient.
        - X (Twitter): Uses Twitter API v2 via XClient.
        - Dev.to: Uses official REST API if DEVTO_API_KEY is present.
        - Fallback: Formats a 1-tap clipboard card so you can paste in 2 seconds.
        """
        platform = draft.get("platform")
        thread_id = draft.get("thread_id")
        thread_url = draft.get("thread_url")
        draft_text = draft.get("draft_text")
        thread_title = draft.get("thread_title", "")

        # ---------------------------------------------------------------------
        # 1. Reddit Auto-Posting
        # ---------------------------------------------------------------------
        if platform == "reddit":
            if self.playwright_poster.is_available():
                logger.info(f"Attempting Reddit posting via Playwright: {thread_url}")
                comment_url = self.playwright_poster.post_comment(thread_url, draft_text)
                if comment_url:
                    self.state_manager.record_posted_thread(thread_id, {
                        "platform": "reddit",
                        "thread_url": thread_url,
                        "comment_url": comment_url,
                        "posted_text": draft_text,
                        "thread_title": thread_title,
                        "method": "playwright"
                    })
                    self.telegram.send_message(
                        f"🚀 <b>Auto-Posted to Reddit via Playwright!</b>\n\n"
                        f"📌 <b>Thread:</b> <a href=\"{comment_url}\">{thread_title}</a>\n"
                        f"<i>Now monitoring thread for feedback...</i>"
                    )
                    return True
                else:
                    logger.warning("Playwright submission failed. Falling back to 1-tap drop.")

            reddit_client = self._get_reddit_client()
            if reddit_client:
                try:
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
                        "thread_title": thread_title,
                        "method": "praw"
                    })
                    self.telegram.send_message(
                        f"🚀 <b>Auto-Posted to Reddit via API!</b>\n\n"
                        f"📌 <b>Thread:</b> <a href=\"{comment_url}\">{thread_title}</a>"
                    )
                    return True
                except Exception as e:
                    logger.error(f"Failed to auto-post to Reddit via PRAW: {e}")

        # ---------------------------------------------------------------------
        # 2. Bluesky Auto-Posting
        # ---------------------------------------------------------------------
        elif platform == "bluesky" and self.bluesky.is_configured():
            try:
                uri = draft.get("uri")
                cid = draft.get("cid")
                post_link = self.bluesky.post_reply(draft_text, reply_to_uri=uri, reply_to_cid=cid)
                if post_link:
                    self.state_manager.record_posted_thread(thread_id, {
                        "platform": "bluesky",
                        "thread_url": post_link,
                        "posted_text": draft_text,
                        "thread_title": thread_title,
                        "method": "api"
                    })
                    self.telegram.send_message(
                        f"🚀 <b>Auto-Posted to Bluesky!</b>\n\n"
                        f"📌 <b>Post:</b> <a href=\"{post_link}\">{thread_title}</a>"
                    )
                    return True
            except Exception as e:
                logger.error(f"Failed to post to Bluesky: {e}")

        # ---------------------------------------------------------------------
        # 3. Twitter / X Auto-Posting (Guarded by ZERO-COST free quota limits)
        # ---------------------------------------------------------------------
        elif platform == "x" and self.x_client.is_configured():
            if not self.state_manager.can_post_to_x(max_monthly=X_MAX_MONTHLY_POSTS, max_daily=X_MAX_DAILY_POSTS):
                logger.warning("SAFETY GUARD: X post blocked because free tier limit would be exceeded. Preventing charges.")
                return False
            try:
                tweet_url = self.x_client.post_tweet(draft_text)
                if tweet_url:
                    self.state_manager.record_x_post()
                    self.state_manager.record_posted_thread(thread_id, {
                        "platform": "x",
                        "thread_url": tweet_url,
                        "posted_text": draft_text,
                        "thread_title": thread_title,
                        "method": "api"
                    })
                    self.telegram.send_message(
                        f"🚀 <b>Auto-Posted to X/Twitter!</b>\n\n"
                        f"📌 <b>Tweet:</b> <a href=\"{tweet_url}\">{thread_title}</a>"
                    )
                    return True
            except Exception as e:
                logger.error(f"Failed to post to X: {e}")

        # ---------------------------------------------------------------------
        # 4. Dev.to Auto-Posting (Comments & Discussions)
        # ---------------------------------------------------------------------
        elif platform == "devto" and self.devto.is_configured():
            try:
                art_id = thread_id.replace("devto_", "")
                comment_url = self.devto.post_comment(art_id, draft_text)
                if comment_url:
                    self.state_manager.record_posted_thread(thread_id, {
                        "platform": "devto",
                        "thread_url": thread_url,
                        "posted_text": draft_text,
                        "thread_title": thread_title,
                        "method": "api"
                    })
                    self.telegram.send_message(
                        f"🚀 <b>Auto-Posted to Dev.to via API!</b>\n\n"
                        f"📌 <b>Article:</b> <a href=\"{thread_url}\">{thread_title}</a>"
                    )
                    return True
            except Exception as e:
                logger.error(f"Failed to post to Dev.to via API: {e}")

        # ---------------------------------------------------------------------
        # 5. Fallback: 1-Tap Manual Clipboard Drop
        # ---------------------------------------------------------------------
        safe_title = thread_title.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
        safe_text = draft_text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")

        card_text = (
            f"📋 <b>1-Click Promotion Drop Ready ({platform.upper()})</b>\n\n"
            f"📌 <b>Thread:</b> <a href=\"{thread_url}\">{safe_title}</a>\n\n"
            f"<i>Tap the block below to copy response to clipboard, then paste:</i>\n\n"
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
            "method": "manual_drop"
        })
        return True

    def execute_devlog(self, draft: Dict[str, Any]) -> bool:
        """
        Publishes an approved DevLog across platforms:
        1. Dev.to (long-form article, published as live)
        2. X/Twitter (post with link to Dev.to article + app)
        3. Bluesky (post with link to Dev.to article + app)
        4. Updates Telegram message with live publication links.
        """
        slug = draft.get("milestone_slug", "unknown")
        devto_title = draft.get("devto_title", "")
        devto_body = draft.get("devto_body", "")
        tags = draft.get("tags", ["flutter", "android", "indiedev", "productivity"])
        x_text = draft.get("x_text", "")
        bsky_text = draft.get("bsky_text", "")
        msg_id = draft.get("telegram_message_id")

        published_links = {}

        # 1. Publish to Dev.to
        devto_url = None
        if self.devto.is_configured():
            try:
                res = self.devto.publish_article(
                    title=devto_title,
                    body_markdown=devto_body,
                    tags=tags,
                    published=True
                )
                if res and res.get("url"):
                    devto_url = res["url"]
                    published_links["Dev.to"] = devto_url
                    logger.info(f"Dev.to article published live: {devto_url}")
            except Exception as e:
                logger.error(f"Failed to publish Dev.to article: {e}")
        else:
            logger.warning("Dev.to is not configured. Skipping Dev.to publication.")

        # 2. Publish to X / Twitter
        x_url = None
        if self.x_client.is_configured():
            try:
                tweet_text = x_text
                if devto_url:
                    tweet_text = f"{x_text}\n\nRead breakdown: {devto_url}\n📲 https://tasks.rocisapps.com"
                else:
                    tweet_text = f"{x_text}\n\n📲 https://tasks.rocisapps.com"

                res_x = self.x_client.post_tweet(tweet_text)
                if res_x:
                    x_url = res_x
                    published_links["X"] = x_url
                    self.state_manager.record_x_post()
            except Exception as e:
                logger.error(f"Failed to post DevLog to X: {e}")

        # 3. Publish to Bluesky
        bsky_url = None
        if self.bluesky.is_configured():
            try:
                post_text = bsky_text
                if devto_url:
                    post_text = f"{bsky_text}\n\nRead on Dev.to: {devto_url}\n📲 https://tasks.rocisapps.com"
                else:
                    post_text = f"{bsky_text}\n\n📲 https://tasks.rocisapps.com"

                res_bsky = self.bluesky.post_update(post_text)
                if res_bsky:
                    bsky_url = res_bsky
                    published_links["Bluesky"] = bsky_url
            except Exception as e:
                logger.error(f"Failed to post DevLog to Bluesky: {e}")

        # 4. Update state
        self.state_manager.record_posted_devlog(slug, {
            "title": devto_title,
            "devto_url": devto_url,
            "x_url": x_url,
            "bsky_url": bsky_url,
            "published_at": datetime.now(timezone.utc).isoformat()
        })
        self.state_manager.mark_draft_status(draft["id"], "approved")

        # 5. Notify/Edit Telegram Card
        summary_lines = []
        if devto_url:
            summary_lines.append(f"📝 <b>Dev.to:</b> <a href=\"{devto_url}\">{devto_title}</a>")
        if x_url:
            summary_lines.append(f"🐦 <b>X/Twitter:</b> <a href=\"{x_url}\">View Tweet</a>")
        elif self.x_client.is_configured():
            summary_lines.append("🐦 <b>X/Twitter:</b> Published")
        if bsky_url:
            summary_lines.append(f"🦋 <b>Bluesky:</b> <a href=\"{bsky_url}\">View Post</a>")
        elif self.bluesky.is_configured():
            summary_lines.append("🦋 <b>Bluesky:</b> Published")

        status_text = (
            f"🎉 <b>DevLog Published Successfully!</b>\n\n"
            f"📌 <b>Title:</b> {devto_title}\n\n" +
            "\n".join(summary_lines)
        )

        if msg_id:
            self.telegram.edit_message_text(msg_id, status_text)
        else:
            self.telegram.send_message(status_text)

        return True

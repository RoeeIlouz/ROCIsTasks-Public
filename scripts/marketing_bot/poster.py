import html
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
from .mastodon_client import MastodonClient
from .threads_client import ThreadsClient
from .hashnode_client import HashnodeClient
from .medium_client import MediumClient
from .media_manager import MediaManager

logger = logging.getLogger(__name__)

class Poster:
    def __init__(self, state_manager: StateManager, telegram_bot: TelegramBot):
        self.state_manager = state_manager
        self.telegram = telegram_bot
        self.playwright_poster = RedditPlaywrightPoster()
        self.bluesky = BlueskyClient()
        self.x_client = XClient()
        self.devto = DevtoClient()
        self.mastodon = MastodonClient()
        self.threads = ThreadsClient()
        self.hashnode = HashnodeClient()
        self.medium = MediumClient()
        self.media_manager = MediaManager()
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
        banner_url = self.media_manager.get_default_banner_url()
        banner_data = self.media_manager.get_default_banner_data()

        # 1. Publish to Dev.to (Primary canonical publication)
        devto_url = None
        if self.devto.is_configured():
            try:
                res = self.devto.publish_article(
                    title=devto_title,
                    body_markdown=devto_body,
                    tags=tags,
                    published=True,
                    main_image=banner_url
                )
                if res and res.get("url"):
                    devto_url = res["url"]
                    published_links["Dev.to"] = devto_url
                    logger.info(f"Dev.to article published live: {devto_url}")
            except Exception as e:
                logger.error(f"Failed to publish Dev.to article: {e}")
        else:
            logger.warning("Dev.to is not configured. Skipping Dev.to publication.")

        # 2. Publish to Hashnode (with canonical URL & cover image)
        hashnode_url = None
        if self.hashnode.is_configured():
            try:
                res_h = self.hashnode.publish_article(
                    title=devto_title,
                    body_markdown=devto_body,
                    tags=tags,
                    canonical_url=devto_url,
                    cover_image_url=banner_url
                )
                if res_h and res_h.get("url"):
                    hashnode_url = res_h["url"]
                    published_links["Hashnode"] = hashnode_url
                    logger.info(f"Hashnode article published: {hashnode_url}")
            except Exception as e:
                logger.error(f"Failed to publish to Hashnode: {e}")

        # 3. Publish to Medium (with canonical URL)
        medium_url = None
        if self.medium.is_configured():
            try:
                res_m = self.medium.publish_article(
                    title=devto_title,
                    body_markdown=devto_body,
                    tags=tags,
                    canonical_url=devto_url
                )
                if res_m and res_m.get("url"):
                    medium_url = res_m["url"]
                    published_links["Medium"] = medium_url
                    logger.info(f"Medium article published: {medium_url}")
            except Exception as e:
                logger.error(f"Failed to publish to Medium: {e}")

        # 4. Publish to X / Twitter
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

        # 5. Publish to Bluesky (with image attachment)
        bsky_url = None
        if self.bluesky.is_configured():
            try:
                link_part = f"\n\nRead on Dev.to: {devto_url}\n📲 https://tasks.rocisapps.com" if devto_url else "\n\n📲 https://tasks.rocisapps.com"
                max_bsky_body = 295 - len(link_part)
                clean_bsky = (bsky_text or "").strip()
                if len(clean_bsky) > max_bsky_body:
                    clean_bsky = clean_bsky[:max_bsky_body - 1].rstrip() + "…"
                post_text = f"{clean_bsky}{link_part}"

                image_blob = None
                if banner_data:
                    image_blob = self.bluesky.upload_blob(banner_data[0], mime_type=banner_data[1])

                res_bsky = self.bluesky.post_reply(post_text, image_blob=image_blob)
                if res_bsky:
                    bsky_url = res_bsky
                    published_links["Bluesky"] = bsky_url
            except Exception as e:
                logger.error(f"Failed to post DevLog to Bluesky: {e}")

        # 6. Publish to Mastodon / Fediverse (with media attachment)
        mastodon_url = None
        if self.mastodon.is_configured():
            try:
                primary_link = devto_url or "https://tasks.rocisapps.com"
                link_footer = f"\n\nRead breakdown: {primary_link}\n📲 https://tasks.rocisapps.com"
                m_text = (draft.get("mastodon_text") or bsky_text or x_text).strip()
                max_m_body = 495 - len(link_footer)
                if len(m_text) > max_m_body:
                    m_text = m_text[:max_m_body - 1].rstrip() + "…"

                media_ids = None
                if banner_data:
                    m_id = self.mastodon.upload_media(
                        banner_data[0],
                        mime_type=banner_data[1],
                        description="ROCIs Tasks Offline App"
                    )
                    if m_id:
                        media_ids = [m_id]

                res_m = self.mastodon.post_status(f"{m_text}{link_footer}", media_ids=media_ids)
                if res_m:
                    mastodon_url = res_m
                    published_links["Mastodon"] = mastodon_url
            except Exception as e:
                logger.error(f"Failed to post DevLog to Mastodon: {e}")

        # 7. Publish to Meta Threads (with image attachment)
        threads_url = None
        if self.threads.is_configured():
            try:
                primary_link = devto_url or "https://tasks.rocisapps.com"
                link_footer = f"\n\nRead breakdown: {primary_link}\n📲 https://tasks.rocisapps.com"
                t_text = (draft.get("threads_text") or bsky_text or x_text).strip()
                max_t_body = 495 - len(link_footer)
                if len(t_text) > max_t_body:
                    t_text = t_text[:max_t_body - 1].rstrip() + "…"
                res_t = self.threads.post_thread(f"{t_text}{link_footer}", image_url=banner_url)
                if res_t:
                    threads_url = res_t
                    published_links["Threads"] = threads_url
            except Exception as e:
                logger.error(f"Failed to post DevLog to Threads: {e}")

        # 8. Update state
        self.state_manager.record_posted_devlog(slug, {
            "title": devto_title,
            "devto_url": devto_url,
            "hashnode_url": hashnode_url,
            "medium_url": medium_url,
            "x_url": x_url,
            "bsky_url": bsky_url,
            "mastodon_url": mastodon_url,
            "threads_url": threads_url,
            "published_at": datetime.now(timezone.utc).isoformat()
        })
        self.state_manager.mark_draft_status(draft["id"], "approved")

        # 9. Notify/Edit Telegram Card
        summary_lines = []
        if devto_url:
            summary_lines.append(f"📝 <b>Dev.to:</b> <a href=\"{devto_url}\">{devto_title}</a>")
        if hashnode_url:
            summary_lines.append(f"📘 <b>Hashnode:</b> <a href=\"{hashnode_url}\">Read Article</a>")
        if medium_url:
            summary_lines.append(f"📰 <b>Medium:</b> <a href=\"{medium_url}\">Read Article</a>")
        if x_url:
            summary_lines.append(f"🐦 <b>X/Twitter:</b> <a href=\"{x_url}\">View Tweet</a>")
        if bsky_url:
            summary_lines.append(f"🦋 <b>Bluesky:</b> <a href=\"{bsky_url}\">View Post</a>")
        if mastodon_url:
            summary_lines.append(f"🐘 <b>Mastodon:</b> <a href=\"{mastodon_url}\">View Post</a>")
        if threads_url:
            summary_lines.append(f"🧵 <b>Threads:</b> <a href=\"{threads_url}\">View Post</a>")

        # Semi-automated Medium 1-Click Import Helper
        inline_keyboard = []
        if not medium_url and (devto_url or hashnode_url):
            import_source = devto_url or hashnode_url
            summary_lines.append(
                f"\n📖 <b>Medium (1-Click Import):</b>\n"
                f"Tap to copy URL: <code>{import_source}</code>\n"
                f"Then paste at <a href=\"https://medium.com/p/import\">medium.com/p/import</a>"
            )
            inline_keyboard.append([{"text": "📖 Import to Medium", "url": "https://medium.com/p/import"}])

        if devto_url:
            inline_keyboard.append([{"text": "📝 View on Dev.to", "url": devto_url}])

        reply_markup = {"inline_keyboard": inline_keyboard} if inline_keyboard else None

        status_text = (
            f"🎉 <b>DevLog Published Successfully!</b>\n\n"
            f"📌 <b>Title:</b> {devto_title}\n\n" +
            "\n".join(summary_lines)
        )

        if msg_id:
            self.telegram.edit_message_text(msg_id, status_text, reply_markup=reply_markup)
        else:
            self.telegram.send_message(status_text, reply_markup=reply_markup)

        return True

    def execute_reddit_post(self, draft: Dict[str, Any]) -> bool:
        """
        Submits an approved top-level Reddit showcase or feedback request.
        """
        draft_id = draft["id"]
        subreddit = draft["subreddit"]
        title = draft["title"]
        body = draft["body"]
        msg_id = draft.get("telegram_message_id")

        post_url = None

        # 1. Try Playwright
        if self.playwright_poster.is_available():
            logger.info(f"Submitting Reddit post to r/{subreddit} via Playwright...")
            post_url = self.playwright_poster.submit_post(subreddit, title, body)

        # 2. Fallback to PRAW API
        if not post_url:
            reddit_client = self._get_reddit_client()
            if reddit_client:
                try:
                    logger.info(f"Submitting Reddit post to r/{subreddit} via PRAW API...")
                    sub = reddit_client.subreddit(subreddit)
                    submission = sub.submit(title=title, selftext=body)
                    post_url = f"https://reddit.com{submission.permalink}"
                except Exception as e:
                    logger.error(f"Failed to submit post to r/{subreddit} via PRAW: {e}")

        # 3. If both automated methods fail or unconfigured, send 1-tap clipboard drop
        if not post_url:
            submit_direct_link = f"https://www.reddit.com/r/{subreddit}/submit"
            safe_title = html.escape(title)
            safe_body = html.escape(body[:3000])
            if len(body) > 3000:
                safe_body += "\n...[truncated for Telegram]"
            drop_card = (
                f"📋 <b>Reddit 1-Tap Submission Ready (r/{subreddit})</b>\n\n"
                f"📌 <b>Title:</b>\n<code>{safe_title}</code>\n\n"
                f"📝 <b>Body:</b>\n<code>{safe_body}</code>\n\n"
                f"👉 <a href=\"{submit_direct_link}\">Open r/{subreddit} Submit Page</a>"
            )
            self.telegram.send_message(drop_card)
            self.state_manager.mark_draft_status(draft_id, "approved")
            return True

        # 4. Success handling
        self.state_manager.record_posted_thread(f"reddit_post_{draft_id}", {
            "platform": "reddit",
            "thread_url": post_url,
            "posted_text": body,
            "thread_title": title,
            "subreddit": subreddit,
            "method": "auto"
        })
        self.state_manager.mark_draft_status(draft_id, "approved")

        status_text = (
            f"🎉 <b>Top-Level Reddit Post Published to r/{subreddit}!</b>\n\n"
            f"📌 <b>Title:</b> <a href=\"{post_url}\">{title}</a>\n"
            f"<i>Now monitoring thread for community comments & feedback...</i>"
        )
        if msg_id:
            self.telegram.edit_message_text(msg_id, status_text)
        else:
            self.telegram.send_message(status_text)

        return True

    def publish_single_post(
        self,
        platform: str,
        text: str,
        title: Optional[str] = None,
        media_url: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Publishes a single post to any supported platform on demand.
        Returns {'success': bool, 'url': Optional[str], 'error': Optional[str]}.
        """
        p = platform.lower().strip()
        banner_data = self.media_manager.get_default_banner_data() if not media_url else None

        try:
            if p in ("bsky", "bluesky"):
                if not self.bluesky.is_configured():
                    return {"success": False, "error": "Bluesky credentials not configured"}
                image_blob = None
                if banner_data:
                    image_blob = self.bluesky.upload_blob(banner_data[0], mime_type=banner_data[1])
                url = self.bluesky.post_reply(text, image_blob=image_blob)
                return {"success": bool(url), "url": url, "error": None if url else "Bluesky post rejected"}

            elif p in ("x", "twitter"):
                if not self.x_client.is_configured():
                    return {"success": False, "error": "X/Twitter credentials not configured"}
                if not self.x_client.can_post():
                    return {"success": False, "error": "X monthly or daily rate limits reached"}
                url = self.x_client.post_tweet(text)
                if url:
                    self.state_manager.record_x_post()
                return {"success": bool(url), "url": url, "error": None if url else "X post failed"}

            elif p in ("mastodon", "fediverse"):
                if not self.mastodon.is_configured():
                    return {"success": False, "error": "Mastodon credentials not configured"}
                media_ids = None
                if banner_data:
                    m_id = self.mastodon.upload_media(banner_data[0], mime_type=banner_data[1], description="ROCIs Tasks")
                    if m_id:
                        media_ids = [m_id]
                url = self.mastodon.post_status(text, media_ids=media_ids)
                return {"success": bool(url), "url": url, "error": None if url else "Mastodon post failed"}

            elif p in ("threads",):
                if not self.threads.is_configured():
                    return {"success": False, "error": "Threads credentials not configured"}
                image_url = media_url or self.media_manager.get_default_banner_url()
                url = self.threads.post_thread(text, image_url=image_url)
                return {"success": bool(url), "url": url, "error": None if url else "Threads post failed"}

            elif p in ("devto", "dev.to"):
                if not self.devto.is_configured():
                    return {"success": False, "error": "Dev.to credentials not configured"}
                res = self.devto.publish_article(
                    title=title or "ROCIs Tasks DevLog",
                    body_markdown=text,
                    published=True
                )
                url = res.get("url") if res else None
                return {"success": bool(url), "url": url, "error": None if url else "Dev.to publish failed"}

            elif p in ("hashnode",):
                if not self.hashnode.is_configured():
                    return {"success": False, "error": "Hashnode credentials not configured"}
                res = self.hashnode.publish_article(
                    title=title or "ROCIs Tasks Update",
                    body_markdown=text
                )
                url = res.get("url") if res else None
                return {"success": bool(url), "url": url, "error": None if url else "Hashnode publish failed"}

            else:
                return {"success": False, "error": f"Unsupported platform: {platform}"}

        except Exception as e:
            logger.error(f"Error publishing to {platform}: {e}")
            return {"success": False, "error": str(e)}



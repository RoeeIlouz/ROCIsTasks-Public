import logging
import time
from typing import Dict, Any, List
import requests

from .config import REDDIT_USER_AGENT
from .state_manager import StateManager
from .gemini_engine import GeminiEngine
from .telegram_bot import TelegramBot

logger = logging.getLogger(__name__)

class FeedbackMonitor:
    def __init__(
        self,
        state_manager: StateManager,
        gemini_engine: GeminiEngine,
        telegram_bot: TelegramBot
    ):
        self.state_manager = state_manager
        self.gemini = gemini_engine
        self.telegram = telegram_bot

    def check_all_posted_threads(self) -> None:
        """
        Scans all previously promoted threads for new incoming replies,
        extracts feature requests and bug reports, and alerts the user on Telegram.
        """
        posted = self.state_manager.get_posted_threads()
        if not posted:
            logger.info("No posted threads to monitor yet.")
            return

        logger.info(f"Monitoring {len(posted)} active threads for comments...")

        for thread_id, info in posted.items():
            platform = info.get("platform")
            try:
                if platform == "reddit":
                    self._check_reddit_thread(thread_id, info)
                elif platform == "hackernews":
                    self._check_hackernews_thread(thread_id, info)
                time.sleep(1.0)  # Rate limiting
            except Exception as e:
                logger.error(f"Error checking thread {thread_id} for feedback: {e}")

    def _check_reddit_thread(self, thread_id: str, info: Dict[str, Any]) -> None:
        sub_id = thread_id.replace("reddit_", "")
        url = f"https://www.reddit.com/comments/{sub_id}.json"
        headers = {"User-Agent": REDDIT_USER_AGENT}

        res = requests.get(url, headers=headers, timeout=10)
        if res.status_code != 200:
            return

        data = res.json()
        if not isinstance(data, list) or len(data) < 2:
            return

        comments_listing = data[1].get("data", {}).get("children", [])
        tracked = set(info.get("tracked_comments", []))
        new_tracked = list(tracked)

        for item in comments_listing:
            cdata = item.get("data", {})
            cid = cdata.get("id")
            author = cdata.get("author", "")
            body = cdata.get("body", "")

            if not cid or cid in tracked or not body:
                continue
            if body in ("[removed]", "[deleted]"):
                continue

            # Process new comment through Gemini
            self._process_comment(
                thread_title=info.get("thread_title", "Reddit Thread"),
                thread_url=info.get("thread_url", f"https://reddit.com/comments/{sub_id}"),
                comment_id=cid,
                author=author,
                comment_body=body
            )
            new_tracked.append(cid)

        info["tracked_comments"] = new_tracked
        info["last_comment_check"] = time.time()

    def _check_hackernews_thread(self, thread_id: str, info: Dict[str, Any]) -> None:
        hn_id = thread_id.replace("hn_", "")
        url = f"https://hn.algolia.com/api/v1/items/{hn_id}"

        res = requests.get(url, timeout=10)
        if res.status_code != 200:
            return

        data = res.json()
        children = data.get("children", [])
        tracked = set(info.get("tracked_comments", []))
        new_tracked = list(tracked)

        for c in children:
            cid = str(c.get("id"))
            author = c.get("author", "anonymous")
            text = c.get("text", "")

            if not cid or cid in tracked or not text:
                continue

            self._process_comment(
                thread_title=info.get("thread_title", "HN Thread"),
                thread_url=info.get("thread_url", f"https://news.ycombinator.com/item?id={hn_id}"),
                comment_id=cid,
                author=author,
                comment_body=text
            )
            new_tracked.append(cid)

        info["tracked_comments"] = new_tracked
        info["last_comment_check"] = time.time()

    def _process_comment(
        self,
        thread_title: str,
        thread_url: str,
        comment_id: str,
        author: str,
        comment_body: str
    ) -> None:
        logger.info(f"Analyzing new comment from @{author} on '{thread_title}'...")

        analysis = self.gemini.classify_comment_and_extract_feedback(
            post_title=thread_title,
            comment_text=comment_body,
            author=author
        )

        if not analysis:
            return

        category = analysis.get("category", "general")
        sentiment = analysis.get("sentiment", "neutral")
        summary = analysis.get("summary", "")
        suggested_reply = analysis.get("suggested_reply")

        # Save to state feedback log
        self.state_manager.add_feedback({
            "comment_id": comment_id,
            "category": category,
            "sentiment": sentiment,
            "author": author,
            "summary": summary,
            "raw_text": comment_body,
            "thread_url": thread_url,
            "suggested_reply": suggested_reply
        })

        # Alert user on Telegram for actionable/noteworthy feedback
        if category in ("feature_request", "bug_report", "praise", "question", "criticism"):
            self.telegram.send_feedback_alert(
                category=category,
                sentiment=sentiment,
                summary=summary,
                author=author,
                post_title=thread_title,
                thread_url=thread_url,
                raw_comment=comment_body,
                suggested_reply=suggested_reply
            )


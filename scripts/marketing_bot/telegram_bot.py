import logging
from typing import Dict, Any, List, Tuple, Optional
import requests

from .config import TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_ID

logger = logging.getLogger(__name__)

class TelegramBot:
    def __init__(self, token: Optional[str] = None, chat_id: Any = "DEFAULT"):
        self.token = token if token is not None else TELEGRAM_BOT_TOKEN
        self.chat_id = TELEGRAM_CHAT_ID if chat_id == "DEFAULT" else chat_id
        self.base_url = f"https://api.telegram.org/bot{self.token}"

    def has_token(self) -> bool:
        return bool(self.token and len(str(self.token).strip()) > 10)

    def is_configured(self) -> bool:
        return bool(self.has_token() and self.chat_id)

    def delete_webhook(self, drop_pending_updates: bool = False) -> bool:
        """Removes any active Telegram webhook so getUpdates polling works properly."""
        if not self.has_token():
            return False
        url = f"{self.base_url}/deleteWebhook"
        try:
            res = requests.post(url, json={"drop_pending_updates": drop_pending_updates}, timeout=10)
            if res.status_code == 200 and res.json().get("ok", False):
                logger.info("Cleared Telegram webhook successfully for polling mode.")
                return True
            return False
        except Exception as e:
            logger.warning(f"Failed to delete Telegram webhook: {e}")
            return False

    def sync_commands(self) -> bool:
        """Registers the bot's slash commands with Telegram so the client UI shows the command menu."""
        if not self.has_token():
            return False
        commands = [
            {"command": "draft", "description": "Draft social post (/draft <platform> <topic>)"},
            {"command": "status", "description": "Check platform APIs & RAS bridge"},
            {"command": "analytics", "description": "Weekly performance & traction digest"},
            {"command": "launchkit", "description": "Generate HN & PH launch maker cards"},
            {"command": "ras", "description": "Query RAS spatial intelligence"},
            {"command": "help", "description": "Show manual and available commands"}
        ]
        url = f"{self.base_url}/setMyCommands"
        try:
            res = requests.post(url, json={"commands": commands}, timeout=10)
            if res.status_code == 200 and res.json().get("ok", False):
                logger.info("Synchronized Telegram bot commands with Telegram servers.")
                return True
            return False
        except Exception as e:
            logger.warning(f"Failed to set Telegram commands: {e}")
            return False

    def send_message(
        self,
        text: str,
        reply_markup: Optional[Dict[str, Any]] = None,
        parse_mode: str = "HTML",
        chat_id: Optional[Any] = None
    ) -> Optional[Dict[str, Any]]:
        target_chat = chat_id or self.chat_id
        if not self.has_token() or not target_chat:
            logger.warning("TelegramBot not configured (token or chat_id missing). Skipping message dispatch.")
            return None

        url = f"{self.base_url}/sendMessage"
        payload = {
            "chat_id": target_chat,
            "text": text,
            "parse_mode": parse_mode,
            "disable_web_page_preview": False
        }
        if reply_markup:
            payload["reply_markup"] = reply_markup

        try:
            res = requests.post(url, json=payload, timeout=20)
            if res.status_code != 200:
                logger.error(f"Telegram API Error ({res.status_code}): {res.text}")
                if "chat not found" in res.text or "blocked by the user" in res.text:
                    logger.error("=" * 60)
                    logger.error("⚠️ CRITICAL TELEGRAM SETUP REQUIREMENT:")
                    logger.error("Telegram bots CANNOT initiate contact with a user.")
                    logger.error("You MUST open Telegram on your phone/desktop, search for your bot,")
                    logger.error("and tap 'START' (or send /start). Once you do this once, the bot")
                    logger.error("will be authorized to send you messages!")
                    logger.error("=" * 60)
            res.raise_for_status()
            return res.json().get("result")
        except Exception as e:
            logger.error(f"Failed to send Telegram message: {e}")
            return None

    def edit_message_text(
        self,
        message_id: int,
        new_text: str,
        reply_markup: Optional[Dict[str, Any]] = None,
        parse_mode: str = "HTML",
        chat_id: Optional[Any] = None
    ) -> bool:
        target_chat = chat_id or self.chat_id
        if not self.has_token() or not target_chat:
            return False

        url = f"{self.base_url}/editMessageText"
        payload = {
            "chat_id": target_chat,
            "message_id": message_id,
            "text": new_text,
            "parse_mode": parse_mode
        }
        if reply_markup is not None:
            payload["reply_markup"] = reply_markup

        try:
            res = requests.post(url, json=payload, timeout=20)
            res.raise_for_status()
            return True
        except Exception as e:
            logger.error(f"Failed to edit Telegram message {message_id}: {e}")
            return False

    def answer_callback_query(self, callback_query_id: Optional[str], text: str) -> None:
        if not self.is_configured() or not callback_query_id:
            return
        url = f"{self.base_url}/answerCallbackQuery"
        try:
            requests.post(url, json={"callback_query_id": callback_query_id, "text": text}, timeout=10)
        except Exception as e:
            logger.error(f"Failed to answer callback query {callback_query_id}: {e}")

    def send_draft_approval_card(
        self,
        draft_id: str,
        platform: str,
        thread_title: str,
        thread_url: str,
        relevance_score: int,
        reasoning: str,
        draft_reply: str
    ) -> Optional[int]:
        """
        Sends an approval card to Telegram with inline buttons:
        [✅ Approve & Post] | [❌ Skip]
        [🌐 View Original Thread]
        """
        # Escape basic HTML
        safe_title = thread_title.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
        safe_reasoning = reasoning.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
        safe_reply = draft_reply.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")

        text = (
            f"🎯 <b>New Promotion Opportunity ({platform.upper()})</b>\n\n"
            f"📌 <b>Thread:</b> <a href=\"{thread_url}\">{safe_title}</a>\n"
            f"📊 <b>Relevance:</b> {relevance_score}/100\n"
            f"💡 <b>Why:</b> {safe_reasoning}\n\n"
            f"📝 <b>Proposed Reply:</b>\n"
            f"<blockquote>{safe_reply}</blockquote>\n\n"
            f"<i>Tap below to approve posting or skip:</i>"
        )

        reply_markup = {
            "inline_keyboard": [
                [
                    {"text": "✅ Approve & Post", "callback_data": f"approve:{draft_id}"},
                    {"text": "❌ Skip", "callback_data": f"reject:{draft_id}"}
                ],
                [
                    {"text": "🌐 Open Thread", "url": thread_url}
                ]
            ]
        }

        msg = self.send_message(text, reply_markup=reply_markup)
        if msg:
            return msg.get("message_id")
        return None

    def send_devlog_approval_card(
        self,
        draft_id: str,
        milestone_title: str,
        milestone_date: str,
        devto_title: str,
        devto_preview: str,
        x_post: str,
        bsky_post: str
    ) -> Optional[int]:
        """
        Sends an approval card for a generated DevLog to Telegram with inline buttons:
        [✅ Approve & Publish DevLog] | [❌ Skip DevLog]
        """
        safe_m_title = milestone_title.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
        safe_d_title = devto_title.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
        safe_preview = devto_preview[:350].replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
        safe_x = x_post.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
        safe_bsky = bsky_post.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")

        text = (
            f"🛠️ <b>New DevLog Ready ({milestone_date})</b>\n\n"
            f"📌 <b>Milestone:</b> {safe_m_title}\n"
            f"📝 <b>Dev.to Article:</b> <i>{safe_d_title}</i>\n"
            f"<blockquote>{safe_preview}...</blockquote>\n\n"
            f"🐦 <b>X/Twitter Preview:</b>\n"
            f"<code>{safe_x}</code>\n\n"
            f"🦋 <b>Bluesky Preview:</b>\n"
            f"<code>{safe_bsky}</code>\n\n"
            f"<i>Tap below to approve publishing across Dev.to, X, and Bluesky:</i>"
        )

        reply_markup = {
            "inline_keyboard": [
                [
                    {"text": "✅ Approve & Publish DevLog", "callback_data": f"approve:{draft_id}"},
                    {"text": "❌ Skip DevLog", "callback_data": f"reject:{draft_id}"}
                ]
            ]
        }

        msg = self.send_message(text, reply_markup=reply_markup)
        if msg:
            return msg.get("message_id")
        return None

    def send_reddit_post_approval_card(
        self,
        draft_id: str,
        subreddit: str,
        title: str,
        body_preview: str,
        topic: str
    ) -> Optional[int]:
        """
        Sends an approval card for an authentic top-level Reddit submission:
        [✅ Approve & Post to r/{sub}] | [❌ Skip]
        """
        safe_title = title.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
        safe_preview = body_preview[:380].replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
        safe_topic = topic.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")

        text = (
            f"🚀 <b>New Reddit Showcase Draft (r/{subreddit})</b>\n\n"
            f"📌 <b>Title:</b> {safe_title}\n"
            f"🏷️ <b>Topic:</b> #{safe_topic}\n\n"
            f"📝 <b>Body Preview:</b>\n"
            f"<blockquote>{safe_preview}...</blockquote>\n\n"
            f"<i>Tap below to approve posting or skip:</i>"
        )

        reply_markup = {
            "inline_keyboard": [
                [
                    {"text": f"✅ Approve & Post to r/{subreddit}", "callback_data": f"approve:{draft_id}"},
                    {"text": "❌ Skip", "callback_data": f"reject:{draft_id}"}
                ]
            ]
        }

        msg = self.send_message(text, reply_markup=reply_markup)
        if msg:
            return msg.get("message_id")
        return None

    def send_feedback_alert(
        self,
        category: str,
        sentiment: str,
        summary: str,
        author: str,
        post_title: str,
        thread_url: str,
        raw_comment: str,
        suggested_reply: Optional[str] = None
    ) -> None:
        """
        Notifies user of community comments, categorized into Feature Requests, Bugs, or Praise.
        """
        icons = {
            "feature_request": "💡 <b>Feature Request</b>",
            "bug_report": "🐛 <b>Bug Report</b>",
            "praise": "⭐ <b>Praise & Compliment</b>",
            "question": "❓ <b>User Question</b>",
            "criticism": "⚠️ <b>Constructive Criticism</b>"
        }
        badge = icons.get(category, f"💬 <b>Feedback ({category})</b>")

        safe_summary = summary.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
        safe_comment = raw_comment.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
        safe_title = post_title.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")

        text = (
            f"{badge} (Sentiment: {sentiment.capitalize()})\n\n"
            f"📌 <b>Thread:</b> <a href=\"{thread_url}\">{safe_title}</a>\n"
            f"👤 <b>Author:</b> @{author}\n\n"
            f"🔍 <b>Summary:</b> {safe_summary}\n\n"
            f"💬 <b>Original Comment:</b>\n"
            f"<blockquote>{safe_comment}</blockquote>"
        )

        if suggested_reply:
            safe_reply = suggested_reply.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
            text += f"\n\n🤖 <b>Suggested Reply:</b>\n<code>{safe_reply}</code>"

        reply_markup = {
            "inline_keyboard": [
                [{"text": "🌐 View on Thread", "url": thread_url}]
            ]
        }
        self.send_message(text, reply_markup=reply_markup)

    def send_interactive_draft_card(
        self,
        draft_id: str,
        platform: str,
        content: str,
        topic: str = "",
        media_url: Optional[str] = None,
        chat_id: Optional[Any] = None
    ) -> Optional[int]:
        """
        Sends an interactive on-demand draft card with Approve, Regenerate, and Cancel buttons.
        """
        safe_content = content.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
        safe_topic = topic.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;") if topic else "General Update"

        icon_map = {
            "bsky": "🦋",
            "bluesky": "🦋",
            "x": "🐦",
            "twitter": "🐦",
            "mastodon": "🐘",
            "threads": "🧵",
            "devto": "📝",
            "hashnode": "📑",
            "reddit": "🚀"
        }
        icon = icon_map.get(platform.lower(), "📢")

        text = (
            f"{icon} <b>On-Demand Draft ({platform.upper()})</b>\n"
            f"📌 <b>Topic:</b> <i>{safe_topic}</i>\n\n"
            f"📝 <b>Proposed Post:</b>\n"
            f"<blockquote>{safe_content}</blockquote>\n\n"
            f"<i>Tap below to approve or regenerate:</i>"
        )

        reply_markup = {
            "inline_keyboard": [
                [
                    {"text": f"✅ Approve & Post ({platform.upper()})", "callback_data": f"approve:{draft_id}"},
                    {"text": "🔄 Regenerate", "callback_data": f"regen:{draft_id}"}
                ],
                [
                    {"text": "❌ Cancel", "callback_data": f"reject:{draft_id}"}
                ]
            ]
        }

        msg = self.send_message(text, reply_markup=reply_markup, chat_id=chat_id)
        if msg:
            return msg.get("message_id")
        return None

    def send_multi_platform_approval_card(
        self,
        group_id: str,
        drafts: Dict[str, str],
        topic: str = "",
        chat_id: Optional[Any] = None
    ) -> Optional[int]:
        """
        Sends a unified multi-platform draft card with both a master 'Approve All' button
        and granular per-platform buttons.
        """
        safe_topic = topic.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;") if topic else "Ecosystem Showcase"
        platforms_str = ", ".join(p.upper() for p in drafts.keys())

        icon_map = {
            "bsky": "🦋",
            "bluesky": "🦋",
            "x": "🐦",
            "twitter": "🐦",
            "mastodon": "🐘",
            "threads": "🧵",
            "devto": "📝",
            "hashnode": "📑"
        }

        body_parts = []
        for p, text in drafts.items():
            icon = icon_map.get(p.lower(), "📢")
            safe_text = text[:280].replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
            if len(text) > 280:
                safe_text += "..."
            body_parts.append(f"{icon} <b>{p.upper()}:</b>\n<blockquote>{safe_text}</blockquote>")

        drafts_preview = "\n\n".join(body_parts)

        text = (
            f"🌐 <b>Multi-Platform Broadcast Draft</b>\n"
            f"📌 <b>Topic:</b> <i>{safe_topic}</i>\n"
            f"🎯 <b>Targets:</b> {platforms_str}\n\n"
            f"{drafts_preview}\n\n"
            f"<i>Choose an action below:</i>"
        )

        # Build inline buttons
        inline_keyboard = [
            [{"text": "🚀 Approve & Post All", "callback_data": f"approve_all:{group_id}"}]
        ]

        # Granular per-platform buttons (paired 2 per row)
        row = []
        for p in drafts.keys():
            icon = icon_map.get(p.lower(), "📢")
            row.append({
                "text": f"{icon} Post {p.upper()}",
                "callback_data": f"approve_single:{group_id}:{p}"
            })
            if len(row) == 2:
                inline_keyboard.append(row)
                row = []
        if row:
            inline_keyboard.append(row)

        inline_keyboard.append([
            {"text": "❌ Cancel All", "callback_data": f"reject_all:{group_id}"}
        ])

        reply_markup = {"inline_keyboard": inline_keyboard}
        msg = self.send_message(text, reply_markup=reply_markup, chat_id=chat_id)
        if msg:
            return msg.get("message_id")
        return None


    def get_pending_user_actions(self, last_update_id: int) -> Tuple[List[Dict[str, Any]], int]:
        """
        Fetches unprocessed Telegram callback query button clicks since last_update_id.
        Returns (list_of_actions, max_update_id_seen).
        """
        if not self.has_token():
            return [], last_update_id

        url = f"{self.base_url}/getUpdates"
        params = {"offset": last_update_id + 1, "timeout": 0}
        actions = []
        max_update_id = last_update_id

        try:
            res = requests.get(url, params=params, timeout=15)
            if res.status_code == 409:
                logger.info("Telegram webhook is active; skipping getUpdates polling.")
                return [], last_update_id
            res.raise_for_status()
            updates = res.json().get("result", [])

            for u in updates:
                up_id = u.get("update_id", 0)
                if up_id > max_update_id:
                    max_update_id = up_id

                callback = u.get("callback_query")
                if callback:
                    cb_id = callback.get("id")
                    data = callback.get("data", "")
                    msg = callback.get("message", {})
                    msg_id = msg.get("message_id")

                    if ":" in data:
                        action, draft_id = data.split(":", 1)
                        actions.append({
                            "action": action,
                            "draft_id": draft_id,
                            "callback_id": cb_id,
                            "message_id": msg_id
                        })
            return actions, max_update_id
        except Exception as e:
            logger.error(f"Failed to fetch Telegram updates: {e}")
            return [], last_update_id

    def get_updates(self, offset: int = 0, timeout: int = 20) -> List[Dict[str, Any]]:
        """
        Fetches raw Telegram updates using long-polling.
        """
        if not self.has_token():
            return []
        url = f"{self.base_url}/getUpdates"
        params = {"offset": offset, "timeout": timeout}
        try:
            res = requests.get(url, params=params, timeout=timeout + 5)
            if res.status_code == 409:
                logger.info("Telegram webhook is active; skipping getUpdates polling.")
                return []
            res.raise_for_status()
            return res.json().get("result", [])
        except Exception as e:
            logger.error(f"Failed to fetch Telegram updates: {e}")
            return []



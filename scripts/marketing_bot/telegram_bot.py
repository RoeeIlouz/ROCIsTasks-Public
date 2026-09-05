import logging
from typing import Dict, Any, List, Tuple, Optional
import requests

from .config import TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_ID

logger = logging.getLogger(__name__)

class TelegramBot:
    def __init__(self, token: Optional[str] = None, chat_id: Optional[str] = None):
        self.token = token or TELEGRAM_BOT_TOKEN
        self.chat_id = chat_id or TELEGRAM_CHAT_ID
        self.base_url = f"https://api.telegram.org/bot{self.token}"

    def is_configured(self) -> bool:
        return bool(self.token and self.chat_id and len(self.token.strip()) > 10)

    def send_message(
        self,
        text: str,
        reply_markup: Optional[Dict[str, Any]] = None,
        parse_mode: str = "HTML"
    ) -> Optional[Dict[str, Any]]:
        if not self.is_configured():
            logger.warning("TelegramBot not configured. Skipping message dispatch.")
            return None

        url = f"{self.base_url}/sendMessage"
        payload = {
            "chat_id": self.chat_id,
            "text": text,
            "parse_mode": parse_mode,
            "disable_web_page_preview": False
        }
        if reply_markup:
            payload["reply_markup"] = reply_markup

        try:
            res = requests.post(url, json=payload, timeout=20)
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
        parse_mode: str = "HTML"
    ) -> bool:
        if not self.is_configured():
            return False

        url = f"{self.base_url}/editMessageText"
        payload = {
            "chat_id": self.chat_id,
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

    def answer_callback_query(self, callback_query_id: str, text: str) -> None:
        if not self.is_configured():
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

    def get_pending_user_actions(self, last_update_id: int) -> Tuple[List[Dict[str, Any]], int]:
        """
        Fetches unprocessed Telegram callback query button clicks since last_update_id.
        Returns (list_of_actions, max_update_id_seen).
        """
        if not self.is_configured():
            return [], last_update_id

        url = f"{self.base_url}/getUpdates"
        params = {"offset": last_update_id + 1, "timeout": 0}
        actions = []
        max_update_id = last_update_id

        try:
            res = requests.get(url, params=params, timeout=15)
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


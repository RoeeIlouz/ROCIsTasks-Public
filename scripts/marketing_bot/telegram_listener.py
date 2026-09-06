import logging
import time
import uuid
from typing import Dict, Any, Optional, List
from datetime import datetime, timezone

try:
    from scripts.marketing_bot.config import (
        TELEGRAM_CHAT_ID,
        TELEGRAM_ALLOWED_USERS,
        DRY_RUN
    )
    from scripts.marketing_bot.telegram_bot import TelegramBot
    from scripts.marketing_bot.poster import Poster
    from scripts.marketing_bot.state_manager import StateManager
    from scripts.marketing_bot.gemini_engine import GeminiEngine
    from scripts.marketing_bot.ras_client import RASClient
    from scripts.marketing_bot.analytics import AnalyticsTracker
    from scripts.marketing_bot.launch_kit import LaunchKitGenerator
except ImportError:
    from config import (
        TELEGRAM_CHAT_ID,
        TELEGRAM_ALLOWED_USERS,
        DRY_RUN
    )
    from telegram_bot import TelegramBot
    from poster import Poster
    from state_manager import StateManager
    from gemini_engine import GeminiEngine
    from ras_client import RASClient
    from analytics import AnalyticsTracker
    from launch_kit import LaunchKitGenerator

logger = logging.getLogger("TelegramListener")


class TelegramListener:
    """
    Interactive background service that polls Telegram updates for on-demand
    drafting commands (/draft), approval button callbacks, and RAS commands.
    """

    def __init__(
        self,
        telegram_bot: Optional[TelegramBot] = None,
        poster: Optional[Poster] = None,
        state_manager: Optional[StateManager] = None,
        gemini: Optional[GeminiEngine] = None,
        ras_client: Optional[RASClient] = None
    ):
        self.state_manager = state_manager or StateManager()
        self.telegram = telegram_bot or TelegramBot()
        self.poster = poster or Poster(self.state_manager, self.telegram)
        self.gemini = gemini or GeminiEngine()
        self.ras = ras_client or RASClient()
        self.analytics = AnalyticsTracker(self.state_manager, self.telegram)
        self.launch_kit = LaunchKitGenerator(self.state_manager, self.telegram)

        self.last_update_id = 0
        self.running = False

        # In-memory storage for pending interactive drafts: {draft_id: draft_dict}
        self.pending_drafts: Dict[str, Dict[str, Any]] = {}
        # In-memory storage for multi-platform groups: {group_id: group_dict}
        self.pending_groups: Dict[str, Dict[str, Any]] = {}

    def is_user_authorized(self, user_id: Any, chat_id: Any) -> bool:
        """Verifies if the message or callback came from an authorized owner."""
        s_user_id = str(user_id)
        s_chat_id = str(chat_id)

        if TELEGRAM_ALLOWED_USERS:
            return s_user_id in TELEGRAM_ALLOWED_USERS or s_chat_id in TELEGRAM_ALLOWED_USERS

        if TELEGRAM_CHAT_ID:
            return s_user_id == str(TELEGRAM_CHAT_ID) or s_chat_id == str(TELEGRAM_CHAT_ID)

        return True

    def process_update(self, update: Dict[str, Any]) -> None:
        """Processes a single raw Telegram update (message or callback_query)."""
        up_id = update.get("update_id", 0)
        if up_id > self.last_update_id:
            self.last_update_id = up_id

        # 1. Handle incoming chat messages
        if "message" in update:
            msg = update["message"]
            from_user = msg.get("from", {})
            user_id = from_user.get("id")
            chat_id = msg.get("chat", {}).get("id")
            text = msg.get("text", "").strip()

            if not text:
                return

            if not self.is_user_authorized(user_id, chat_id):
                logger.warning(f"Unauthorized command attempt from user_id: {user_id}")
                return

            self.handle_command(text, chat_id=chat_id)

        # 2. Handle inline button callback clicks
        elif "callback_query" in update:
            cb = update["callback_query"]
            cb_id = cb.get("id")
            from_user = cb.get("from", {})
            user_id = from_user.get("id")
            msg = cb.get("message", {})
            chat_id = msg.get("chat", {}).get("id")
            msg_id = msg.get("message_id")
            data = cb.get("data", "")

            if not self.is_user_authorized(user_id, chat_id):
                self.telegram.answer_callback_query(cb_id, text="⚠️ Unauthorized")
                return

            self.handle_callback(data, cb_id=cb_id, msg_id=msg_id)

    def handle_command(self, text: str, chat_id: Optional[int] = None) -> None:
        """Routes slash commands like /draft, /status, /analytics, /ras, /help."""
        parts = text.split()
        cmd = parts[0].lower() if parts else ""

        if cmd == "/help" or cmd == "/start":
            self._cmd_help()
        elif cmd == "/status":
            self._cmd_status()
        elif cmd == "/analytics":
            self._cmd_analytics()
        elif cmd == "/launchkit":
            self._cmd_launchkit()
        elif cmd == "/ras":
            query = text[len(cmd):].strip()
            self._cmd_ras(query)
        elif cmd == "/draft":
            args = text[len(cmd):].strip()
            self._cmd_draft(args)
        else:
            if text.startswith("/"):
                self.telegram.send_message(
                    f"❓ Unknown command: <code>{cmd}</code>\n"
                    f"Send /help to see all available drafting and telemetry commands."
                )

    def _cmd_help(self) -> None:
        help_text = (
            "🤖 <b>ROCIs Tasks Marketing & RAS Command Center</b>\n\n"
            "<b>Available Commands:</b>\n"
            "✍️ <code>/draft &lt;platform&gt; &lt;topic&gt;</code> — Draft on-demand post with 1-tap approval\n"
            "   <i>Platforms:</i> <code>bsky</code>, <code>x</code>, <code>mastodon</code>, <code>threads</code>, <code>devto</code>, <code>hashnode</code>, <code>all</code>\n"
            "   <i>Example:</i> <code>/draft bsky Android home widget updates in v0.2.10</code>\n"
            "   <i>Example:</i> <code>/draft all Launching our Product Hunt post today</code>\n\n"
            "🌐 <code>/ras [query]</code> — Telemetry status or ask RAS intelligence\n"
            "📊 <code>/analytics</code> — Weekly cross-platform traction & engagement\n"
            "🚀 <code>/launchkit</code> — Hacker News & Product Hunt maker cards\n"
            "🩺 <code>/status</code> — Check health of social platform APIs & RAS bridge\n"
            "ℹ️ <code>/help</code> — Show this manual"
        )
        self.telegram.send_message(help_text)

    def _cmd_status(self) -> None:
        ras_online = self.ras.is_online()
        ras_status = "🟢 Online (http://localhost:3000)" if ras_online else "🟡 Offline (Fallback Active)"

        bsky_status = "🟢 Configured" if self.poster.bluesky.is_configured() else "🔴 Missing Credentials"
        x_status = "🟢 Configured" if self.poster.x_client.is_configured() else "🔴 Missing Credentials"
        masto_status = "🟢 Configured" if self.poster.mastodon.is_configured() else "🔴 Missing Credentials"
        threads_status = "🟢 Configured" if self.poster.threads.is_configured() else "🔴 Missing Credentials"
        devto_status = "🟢 Configured" if self.poster.devto.is_configured() else "🔴 Missing Credentials"
        hashnode_status = "🟢 Configured" if self.poster.hashnode.is_configured() else "🔴 Missing Credentials"

        text = (
            "🩺 <b>System Status & Health</b>\n\n"
            f"🧠 <b>RAS Bridge:</b> {ras_status}\n"
            f"🦋 <b>Bluesky:</b> {bsky_status}\n"
            f"🐦 <b>X / Twitter:</b> {x_status}\n"
            f"🐘 <b>Mastodon:</b> {masto_status}\n"
            f"🧵 <b>Threads:</b> {threads_status}\n"
            f"📝 <b>Dev.to:</b> {devto_status}\n"
            f"📑 <b>Hashnode:</b> {hashnode_status}\n\n"
            f"<i>Dry Run Mode:</i> {'🟡 ON' if DRY_RUN else '🟢 LIVE'}"
        )
        self.telegram.send_message(text)

    def _cmd_analytics(self) -> None:
        self.telegram.send_message("📊 Generating weekly traction report...")
        self.analytics.generate_and_send_digest()

    def _cmd_launchkit(self) -> None:
        self.telegram.send_message("🚀 Generating Launch Kit cards...")
        self.launch_kit.dispatch_to_telegram()

    def _cmd_ras(self, query: str) -> None:
        if not query:
            # Display telemetry overview
            summary = self.ras.get_grounded_context_summary()
            self.telegram.send_message(f"🧠 <b>RAS Ecosystem Telemetry:</b>\n\n<code>{summary}</code>")
            return

        self.telegram.send_message(f"🧠 Asking RAS: <i>\"{query}\"</i>...")
        answer = self.ras.query_ras_cognition(query)
        if answer:
            self.telegram.send_message(f"🧠 <b>RAS Core:</b>\n\n{answer}")
        else:
            # Fallback to standalone Gemini
            fallback_answer = self.gemini.generate_content(
                f"You are R.A.S, the spatial intelligence of ROCIs Ecosystem. Answer: {query}"
            )
            if fallback_answer:
                self.telegram.send_message(f"🧠 <b>RAS (Standalone Fallback):</b>\n\n{fallback_answer}")
            else:
                self.telegram.send_message("⚠️ Failed to reach RAS Core and standalone Gemini.")

    def _cmd_draft(self, args: str) -> None:
        parts = args.split(maxsplit=1)
        if not parts:
            self.telegram.send_message(
                "✍️ <b>Usage:</b> <code>/draft &lt;platform&gt; &lt;topic&gt;</code>\n"
                "<i>Example:</i> <code>/draft bsky New offline SQLite and Hive speedup</code>\n"
                "<i>Example:</i> <code>/draft all Product Hunt launch is live</code>"
            )
            return

        target_platform = parts[0].lower()
        topic = parts[1] if len(parts) > 1 else "ROCIs Tasks latest update"

        # Ground draft in live RAS telemetry or local fallback
        context_str = self.ras.get_grounded_context_summary()

        if target_platform == "all":
            self._handle_draft_all(topic, context_str)
        else:
            self._handle_draft_single(target_platform, topic, context_str)

    def _handle_draft_single(self, platform: str, topic: str, context_str: str) -> None:
        self.telegram.send_message(f"✍️ Drafting <b>{platform.upper()}</b> post for: <i>\"{topic}\"</i>...")

        draft_content = self.gemini.draft_social_post(platform, topic, context_str)
        if not draft_content:
            self.telegram.send_message(f"⚠️ Failed to generate draft for {platform.upper()}. Please try again.")
            return

        draft_id = f"od_{uuid.uuid4().hex[:8]}"
        self.pending_drafts[draft_id] = {
            "id": draft_id,
            "platform": platform,
            "topic": topic,
            "content": draft_content,
            "context_str": context_str,
            "created_at": datetime.now(timezone.utc).isoformat()
        }

        self.telegram.send_interactive_draft_card(
            draft_id=draft_id,
            platform=platform,
            content=draft_content,
            topic=topic
        )

    def _handle_draft_all(self, topic: str, context_str: str) -> None:
        self.telegram.send_message(f"🌐 Drafting multi-platform broadcast for: <i>\"{topic}\"</i>...")

        target_platforms = ["bsky", "x", "mastodon", "threads"]
        drafts: Dict[str, str] = {}

        for p in target_platforms:
            text = self.gemini.draft_social_post(p, topic, context_str)
            if text:
                drafts[p] = text

        if not drafts:
            self.telegram.send_message("⚠️ Failed to generate drafts across platforms.")
            return

        group_id = f"grp_{uuid.uuid4().hex[:8]}"
        self.pending_groups[group_id] = {
            "id": group_id,
            "topic": topic,
            "drafts": drafts,
            "context_str": context_str,
            "created_at": datetime.now(timezone.utc).isoformat()
        }

        self.telegram.send_multi_platform_approval_card(
            group_id=group_id,
            drafts=drafts,
            topic=topic
        )

    def handle_callback(self, data: str, cb_id: Optional[str] = None, msg_id: Optional[int] = None) -> None:
        """Handles inline keyboard button taps."""
        if ":" not in data:
            self.telegram.answer_callback_query(cb_id, text="⚠️ Invalid action")
            return

        action, payload = data.split(":", 1)

        # 1. Single draft approval: approve:<draft_id>
        if action == "approve":
            draft_id = payload
            draft = self.pending_drafts.get(draft_id)
            if not draft:
                self.telegram.answer_callback_query(cb_id, text="⚠️ Draft expired or not found")
                return

            self.telegram.answer_callback_query(cb_id, text=f"🚀 Publishing to {draft['platform'].upper()}...")
            if DRY_RUN:
                post_url = "https://example.com/dry-run-post"
                res = {"success": True, "url": post_url}
            else:
                res = self.poster.publish_single_post(
                    platform=draft["platform"],
                    text=draft["content"]
                )

            if res.get("success"):
                post_url = res.get("url") or "Published"
                confirm_text = (
                    f"✅ <b>Published to {draft['platform'].upper()}!</b>\n\n"
                    f"📌 <b>Topic:</b> {draft['topic']}\n"
                    f"🔗 <a href=\"{post_url}\">View Live Post</a>\n\n"
                    f"<blockquote>{draft['content']}</blockquote>"
                )
                if msg_id:
                    self.telegram.edit_message_text(msg_id, confirm_text)
                else:
                    self.telegram.send_message(confirm_text)
                self.pending_drafts.pop(draft_id, None)
            else:
                err = res.get("error", "Unknown error")
                self.telegram.send_message(f"❌ Failed to publish to {draft['platform'].upper()}: {err}")

        # 2. Single draft reject: reject:<draft_id>
        elif action == "reject":
            draft_id = payload
            draft = self.pending_drafts.pop(draft_id, None)
            self.telegram.answer_callback_query(cb_id, text="❌ Draft canceled")
            if msg_id:
                platform_name = draft["platform"].upper() if draft else "Draft"
                self.telegram.edit_message_text(msg_id, f"❌ <b>{platform_name} canceled.</b>")

        # 3. Single draft regenerate: regen:<draft_id>
        elif action == "regen":
            draft_id = payload
            draft = self.pending_drafts.get(draft_id)
            if not draft:
                self.telegram.answer_callback_query(cb_id, text="⚠️ Draft not found")
                return

            self.telegram.answer_callback_query(cb_id, text="🔄 Regenerating draft...")
            new_content = self.gemini.draft_social_post(draft["platform"], draft["topic"], draft["context_str"])
            if new_content:
                draft["content"] = new_content
                self.telegram.send_interactive_draft_card(
                    draft_id=draft_id,
                    platform=draft["platform"],
                    content=new_content,
                    topic=draft["topic"]
                )
            else:
                self.telegram.send_message("⚠️ Failed to regenerate draft. Please try again.")

        # 4. Multi-platform master approve: approve_all:<group_id>
        elif action == "approve_all":
            group_id = payload
            group = self.pending_groups.get(group_id)
            if not group:
                self.telegram.answer_callback_query(cb_id, text="⚠️ Broadcast expired or not found")
                return

            self.telegram.answer_callback_query(cb_id, text="🚀 Publishing across all platforms...")
            results = []
            for p, text in group["drafts"].items():
                if DRY_RUN:
                    results.append(f"✅ <b>{p.upper()}:</b> <a href=\"https://example.com/dry-run\">View Post</a> (DRY RUN)")
                else:
                    res = self.poster.publish_single_post(platform=p, text=text)
                    if res.get("success"):
                        url = res.get("url") or "Published"
                        results.append(f"✅ <b>{p.upper()}:</b> <a href=\"{url}\">View Post</a>")
                    else:
                        results.append(f"❌ <b>{p.upper()}:</b> {res.get('error', 'Error')}")

            summary_text = (
                f"🎉 <b>Multi-Platform Broadcast Published!</b>\n\n"
                f"📌 <b>Topic:</b> {group['topic']}\n\n" +
                "\n".join(results)
            )
            if msg_id:
                self.telegram.edit_message_text(msg_id, summary_text)
            else:
                self.telegram.send_message(summary_text)
            self.pending_groups.pop(group_id, None)

        # 5. Multi-platform single approve: approve_single:<group_id>:<platform>
        elif action == "approve_single":
            if ":" not in payload:
                self.telegram.answer_callback_query(cb_id, text="⚠️ Invalid single approval")
                return
            group_id, p = payload.split(":", 1)
            group = self.pending_groups.get(group_id)
            if not group or p not in group["drafts"]:
                self.telegram.answer_callback_query(cb_id, text="⚠️ Draft not found")
                return

            text = group["drafts"][p]
            self.telegram.answer_callback_query(cb_id, text=f"🚀 Publishing to {p.upper()}...")
            if DRY_RUN:
                res = {"success": True, "url": "https://example.com/dry-run"}
            else:
                res = self.poster.publish_single_post(platform=p, text=text)

            if res.get("success"):
                url = res.get("url") or "Published"
                self.telegram.send_message(
                    f"✅ <b>Published to {p.upper()}!</b>\n\n"
                    f"🔗 <a href=\"{url}\">View Post</a>\n\n"
                    f"<blockquote>{text}</blockquote>"
                )
                # Remove posted item from group
                group["drafts"].pop(p, None)
            else:
                self.telegram.send_message(f"❌ Failed to post to {p.upper()}: {res.get('error')}")

        # 6. Multi-platform reject all: reject_all:<group_id>
        elif action == "reject_all":
            group_id = payload
            self.pending_groups.pop(group_id, None)
            self.telegram.answer_callback_query(cb_id, text="❌ Broadcast canceled")
            if msg_id:
                self.telegram.edit_message_text(msg_id, "❌ <b>Multi-platform broadcast canceled.</b>")

    def run_polling(self, interval: float = 2.0) -> None:
        """Continuous long-polling loop."""
        self.running = True
        logger.info("=" * 60)
        logger.info("🚀 Telegram Interactive Listener Active!")
        logger.info(f"Target Chat: {TELEGRAM_CHAT_ID or 'ANY'}")
        logger.info(f"RAS Bridge: {self.ras.base_url} ({'ONLINE' if self.ras.is_online() else 'OFFLINE/FALLBACK'})")
        logger.info("Listening for /draft, /status, /analytics, /ras, /help...")
        logger.info("=" * 60)

        while self.running:
            try:
                updates = self.telegram.get_updates(offset=self.last_update_id + 1, timeout=15)
                for u in updates:
                    self.process_update(u)
            except KeyboardInterrupt:
                logger.info("Stopping Telegram Listener (KeyboardInterrupt)...")
                self.running = False
                break
            except Exception as e:
                logger.error(f"Error in Telegram polling loop: {e}")
                time.sleep(interval)

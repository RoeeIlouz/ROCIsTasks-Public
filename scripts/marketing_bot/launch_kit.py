import json
import logging
from typing import Dict, Any, Optional

from .gemini_engine import GeminiEngine
from .telegram_bot import TelegramBot
from .state_manager import StateManager

logger = logging.getLogger(__name__)

class LaunchKitGenerator:
    """
    Generates high-converting, tailored launch packages for:
    1. Hacker News ("Show HN") adhering strictly to community technical standards.
    2. Product Hunt (Tagline, Pitch, First Maker Comment, Categories).
    Dispatches directly to Telegram with 1-tap copy functionality.
    """
    def __init__(
        self,
        state_manager: StateManager,
        telegram_bot: TelegramBot,
        gemini_engine: Optional[GeminiEngine] = None
    ):
        self.state_manager = state_manager
        self.telegram = telegram_bot
        self.gemini = gemini_engine or GeminiEngine()

    def generate_launch_package(self, version: str = "1.0") -> Dict[str, Any]:
        """Generates launch assets using Gemini or high-quality technical fallbacks."""
        prompt = f"""
        Generate a high-conversion launch kit for ROCIs Tasks (v{version}):
        The app is an offline-first, privacy-focused task manager built with Flutter and native Android widgets.
        Key features:
        - 100% offline (no accounts, no cloud telemetry, zero remote tracking).
        - Home screen widgets with native Kotlin state sync (month calendar, quick task check-off).
        - Smooth glassmorphism UI with category tints.
        - Background isolates for scheduling without UI lag.

        Return ONLY a JSON object with this schema:
        {{
            "show_hn": {{
                "title": "Show HN: ROCIs Tasks – Offline-first task manager in Flutter with native home widgets",
                "body": "Detailed technical post explaining motivation, architecture, hurdles solved with platform channels, and open-source/privacy commitment (300-500 words)."
            }},
            "product_hunt": {{
                "tagline": "Offline-first task manager with Android home widgets (<60 chars)",
                "short_pitch": "Privacy-focused task management without accounts, telemetry, or cloud lag (<250 chars)",
                "maker_comment": "Founder story on why offline-first matters, what tech stack was used, and asking community for feedback.",
                "topics": ["Productivity", "Android", "Open Source", "Flutter"]
            }}
        }}
        """

        data = None
        if self.gemini.is_available():
            try:
                res_text = self.gemini.generate_text(prompt)
                # Extract JSON block
                clean_json = res_text.strip()
                if "```json" in clean_json:
                    clean_json = clean_json.split("```json")[1].split("```")[0].strip()
                elif "```" in clean_json:
                    clean_json = clean_json.split("```")[1].split("```")[0].strip()
                data = json.loads(clean_json)
            except Exception as e:
                logger.error(f"Gemini launch kit generation failed: {e}. Using expert fallback.")

        if not data:
            data = self._get_fallback_launch_kit(version)

        return data

    def _get_fallback_launch_kit(self, version: str) -> Dict[str, Any]:
        """Expert technical fallback adhering to Hacker News and Product Hunt guidelines."""
        return {
            "show_hn": {
                "title": f"Show HN: ROCIs Tasks v{version} – Offline-first task manager in Flutter with native Android widgets",
                "body": (
                    "Hey HN,\n\n"
                    "I built ROCIs Tasks because I was tired of modern task managers that force cloud logins, "
                    "track usage telemetry, and lag when syncing simple home screen widgets. "
                    "I wanted a task manager that works 100% offline, starts instantly, and respects user privacy.\n\n"
                    "Architecture Highlights:\n"
                    "• Offline-First: All tasks and recurrence rules are persisted locally in Hive/SQLite with zero remote dependencies.\n"
                    "• Native Android Widgets: We built native Kotlin home screen widgets that calculate state shifts natively "
                    "before notifying Dart over platform channels. This eliminates double-increment race conditions and startup locks.\n"
                    "• Background Isolates: Silent task scheduling runs in dedicated isolates without loading UI theme or analytics engines.\n"
                    "• Glassmorphism Design: Custom Flutter shaders with tinted blur and category accents running at a locked 60fps.\n\n"
                    "App & Code:\n"
                    "GitHub: https://github.com/RoeeIlouz/ROCIs-Tasks\n"
                    "Web / Play Store: https://tasks.rocisapps.com\n\n"
                    "I'd love feedback on the widget responsiveness and offline architecture!"
                )
            },
            "product_hunt": {
                "tagline": "Offline-first task manager with Android home widgets",
                "short_pitch": "Privacy-focused productivity without cloud accounts, telemetry, or lag. Beautiful glassmorphism UI with interactive Android home screen widgets.",
                "maker_comment": (
                    "Hi Product Hunt! 👋\n\n"
                    "Most task apps today treat user data as an analytics pipeline and require accounts just to check off groceries. "
                    "ROCIs Tasks was created with a single mission: fast, offline-first task management that never sells your data or requires internet.\n\n"
                    "Featuring native Android widgets, glassmorphism UI, and lightning-fast local storage. Would love to hear your thoughts and suggestions!"
                ),
                "topics": ["Productivity", "Android", "Open Source", "Flutter"]
            }
        }

    def dispatch_to_telegram(self, version: str = "1.0", chat_id: Optional[Any] = None) -> bool:
        """Generates launch kit and delivers it to Telegram as interactive drop cards."""
        pkg = self.generate_launch_package(version)
        hn = pkg.get("show_hn", {})
        ph = pkg.get("product_hunt", {})

        hn_title = hn.get("title", "").replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
        hn_body = hn.get("body", "").replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
        ph_tagline = ph.get("tagline", "").replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
        ph_pitch = ph.get("short_pitch", "").replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
        ph_comment = ph.get("maker_comment", "").replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")

        card_text = (
            f"🚀 <b>ROCIs Tasks Launch Kit (v{version}) Ready!</b>\n\n"
            f"━━━━━━━━━━━━━━━━━━━━\n"
            f"🟧 <b>HACKER NEWS (SHOW HN)</b>\n"
            f"<b>Title:</b>\n"
            f"<code>{hn_title}</code>\n\n"
            f"<b>Body (Tap to Copy):</b>\n"
            f"<code>{hn_body}</code>\n\n"
            f"━━━━━━━━━━━━━━━━━━━━\n"
            f"🐱 <b>PRODUCT HUNT</b>\n"
            f"<b>Tagline:</b> <code>{ph_tagline}</code>\n"
            f"<b>Pitch:</b> <code>{ph_pitch}</code>\n\n"
            f"<b>First Maker Comment:</b>\n"
            f"<code>{ph_comment}</code>\n\n"
            f"<i>Tap any code block to copy to clipboard for 1-click submission!</i>"
        )

        reply_markup = {
            "inline_keyboard": [
                [
                    {"text": "🟧 Submit Show HN", "url": "https://news.ycombinator.com/submit"},
                    {"text": "🐱 Product Hunt Post", "url": "https://www.producthunt.com/posts/new"}
                ]
            ]
        }

        sent = self.telegram.send_message(card_text, reply_markup=reply_markup, chat_id=chat_id)
        return bool(sent)


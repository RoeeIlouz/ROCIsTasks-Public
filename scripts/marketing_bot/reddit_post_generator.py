import hashlib
import json
import logging
import re
from datetime import datetime, timezone
from typing import Dict, Any, List, Optional

from .config import APP_INFO, TARGET_SUBREDDITS
from .gemini_engine import GeminiEngine, _clean_json_markdown
from .devlog_engine import SecretSanitizer

logger = logging.getLogger(__name__)

SUBREDDIT_GUIDELINES = {
    "SideProject": {
        "audience": "Fellow indie makers and builders.",
        "angle": "Honest story of why you built ROCIs Tasks, key engineering choices (Flutter, Hive local database, native Kotlin widgets), lessons learned, and inviting feedback.",
        "tone": "Transparent, humble, focused on the indie dev journey."
    },
    "FlutterDev": {
        "audience": "Dart & Flutter mobile engineers.",
        "angle": "Deep technical showcase: Solving platform channels for home screen widgets, isolate architecture, offline caching, and memory optimization.",
        "tone": "In-depth, engineering-focused, architecture tradeoffs."
    },
    "productivity": {
        "audience": "Power users, students, and professionals battling task friction and procrastination.",
        "angle": "Why friction in task managers leads to abandoned systems. How single-line natural language input and glanceable home screen widgets help keep momentum.",
        "tone": "Thoughtful, practical, minimal self-shill."
    },
    "roastmystartup": {
        "audience": "Brutally honest startup founders and critics.",
        "angle": "Presenting ROCIs Tasks as an indie solopreneur utility: Ask them to critique the onboarding flow, value prop, or feature density.",
        "tone": "Thick-skinned, receptive to feedback, direct."
    },
    "androidapps": {
        "audience": "Android enthusiasts and power users who love native features.",
        "angle": "Showcasing Android-native capabilities: True AMOLED pitch-black UI, Material 3/Glassmorphism design, and rich desktop widgets.",
        "tone": "Friendly, feature-oriented, Android pride."
    }
}

class RedditPostGenerator:
    """
    Generates authentic, high-yield top-level Reddit posts tailored to specific subreddits.
    Zero automated piggybacking or spammy hijack attempts.
    """
    def __init__(self, gemini_engine: GeminiEngine):
        self.gemini = gemini_engine

    def generate_showcase_post(
        self,
        subreddit: str,
        topic_focus: Optional[str] = None
    ) -> Optional[Dict[str, Any]]:
        if not self.gemini.is_available():
            logger.warning("Gemini API not available for Reddit post generation.")
            return None

        if subreddit not in SUBREDDIT_GUIDELINES:
            subreddit = "SideProject"

        guide = SUBREDDIT_GUIDELINES[subreddit]
        app_features_str = "\n".join(f"- {f}" for f in APP_INFO["core_features"])

        prompt = f"""You are an authentic indie developer building 'ROCIs Tasks' (an offline-first Android task & calendar app with native Kotlin home screen widgets, built with Flutter).

TARGET SUBREDDIT: r/{subreddit}
TARGET AUDIENCE: {guide['audience']}
SUBREDDIT ANGLE: {guide['angle']}
DESIRED TONE: {guide['tone']}
SPECIFIC TOPIC: {topic_focus or 'Building an offline-first Android productivity tool without subscription fatigue'}

APP CONTEXT:
Tagline: {APP_INFO['tagline']}
Google Play: {APP_INFO['play_store_url']}
Web Version: {APP_INFO['web_url']}
Core Features:
{app_features_str}

TASK:
Write an authentic, highly engaging top-level post for r/{subreddit}.

CRITICAL COMMUNITY RULES:
1. RESPECT THE SUBREDDIT CULTURE: Absolutely NO corporate buzzwords, fake hype, or pushy sales copy.
2. VALUE FIRST: Tell a real story, explain technical challenges overcome, or present thoughtful design decisions.
3. CONVERSATION STARTER: End with an open question asking the community for constructive feedback, their own setup, or thoughts.
4. LINKS: Mention Google Play ({APP_INFO['play_store_url']}) and Web ({APP_INFO['web_url']}) naturally at the bottom as optional references.

OUTPUT FORMAT:
Return ONLY valid JSON matching this exact structure:
{{
  "title": "<Catchy, authentic Reddit submission title under 120 chars>",
  "body": "<Full Markdown formatted Reddit self-text post>",
  "topic": "<1-2 word topic tag, e.g. flutter_architecture, indie_journey, widget_sync>"
}}
"""
        raw_response = self.gemini._call_gemini(prompt, temperature=0.7, max_tokens=2500)
        if not raw_response:
            return None

        cleaned = _clean_json_markdown(raw_response)
        try:
            parsed = json.loads(cleaned)
        except Exception as e:
            logger.error(f"Failed to parse Reddit post JSON: {e}")
            return None

        raw_title = SecretSanitizer.sanitize(parsed.get("title", f"Building ROCIs Tasks for r/{subreddit}"))
        raw_body = SecretSanitizer.sanitize(parsed.get("body", ""))
        topic = parsed.get("topic", "showcase")

        # Generate unique draft ID
        h = hashlib.sha256(f"{subreddit}:{raw_title}".encode()).hexdigest()[:8]
        draft_id = f"reddit_post_{subreddit.lower()}_{h}"

        return {
            "id": draft_id,
            "type": "reddit_post",
            "platform": "reddit",
            "subreddit": subreddit,
            "title": raw_title,
            "body": raw_body,
            "topic": topic,
            "created_at": datetime.now(timezone.utc).isoformat(),
            "status": "pending"
        }

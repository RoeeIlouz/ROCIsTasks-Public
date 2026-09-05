import json
import logging
import random
import re
from typing import Dict, Any, Optional, List
import requests

from .config import GEMINI_API_KEY

logger = logging.getLogger(__name__)

GEMINI_API_URL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent"

# Curated authentic fallback thoughts for when Gemini is offline or rate-limited
CURATED_FALLBACK_THOUGHTS = [
    "Nothing humbles you as a mobile developer quite like spending 2 hours debugging a layout glitch only to realize a nested Column had unbounded height.",
    "The best productivity tool is often the one with the least friction. The moment an app requires 5 clicks just to log a single task, people go back to pen and paper.",
    "Local-first architecture isn't just about offline support. It's about that instant, zero-latency feedback that makes an app feel alive.",
    "Unpopular opinion: 90% of apps would look and feel 10x better if they just embraced a true AMOLED pitch-black mode instead of washed-out dark gray.",
    "One of the hardest parts of being a solo indie maker isn't writing code—it's fighting the urge to add 10 new features before polishing the core one.",
    "Native home screen widgets are such an underrated surface. Quick glance, zero sync delay, instant action. Wish more mobile apps invested real love into them.",
    "Building in public reminder: Done is better than perfect. Your users care way more about whether it solves their friction today than about your clean architecture diagrams.",
    "What's your most controversial hot take about mobile apps in 2026? Mine: not every single utility tool needs an AI chat wrapper.",
    "That feeling when you optimize your local database queries and watch your frame render time drop from 16ms to 4ms. Pure developer dopamine.",
    "A simple test for any task or notes app: if you can't capture a fleeting thought within 3 seconds of unlocking your phone, the workflow has failed.",
    "Solo dev reality: 10% coding, 20% fixing obscure Gradle/Kotlin configuration errors, 70% staring at UI spacing wondering if 8px or 12px padding feels right.",
    "Question for the mobile & indie dev crowd: what's one feature in your daily tools that you wish was 100% private and offline-first?"
]

TOPICS = [
    "mobile_engineering",
    "indie_maker_life",
    "productivity_philosophy",
    "developer_question"
]

class PersonaEngine:
    def __init__(self, api_key: Optional[str] = None):
        self.api_key = api_key or GEMINI_API_KEY

    def is_available(self) -> bool:
        return bool(self.api_key and len(self.api_key.strip()) > 5)

    def generate_organic_thought(self, previous_posts: Optional[List[str]] = None) -> Dict[str, str]:
        """
        Generates an authentic, non-promotional indie developer thought or engaging question
        specifically crafted for Twitter/X and Bluesky.
        Returns a dict with 'text' and 'topic'.
        """
        chosen_topic = random.choice(TOPICS)
        avoid_context = ""
        if previous_posts:
            recent_snippets = [p[:60] for p in previous_posts[-5:]]
            avoid_context = f"\nAvoid repeating similar ideas to these recent posts:\n" + "\n".join(f"- {s}" for s in recent_snippets)

        if not self.is_available():
            logger.info("Gemini API not available. Selecting from curated organic developer pool.")
            return {
                "text": random.choice(CURATED_FALLBACK_THOUGHTS),
                "topic": chosen_topic
            }

        prompt = f"""You are a solo software engineer and indie maker sharing casual, authentic reflections on Twitter/X and Bluesky.

TOPIC FOR THIS POST: {chosen_topic}
{avoid_context}

STRICT ANTI-BOT RULES:
1. ABSOLUTELY ZERO SELF-PROMOTION. Do NOT mention your app name, do NOT include links, do NOT say "check out my project".
2. TONE: Human, thoughtful, unpretentious, relatable indie hacker voice.
3. FORMAT:
   - Length: Strictly under 250 characters (fits comfortably in a single tweet).
   - Style: Natural sentence case or casual developer phrasing.
   - Hashtags: Maximum 0 to 1 natural tag (e.g. #buildinpublic or none at all). NO hashtag spamming.
   - NO corporate clichés ("excited to announce", "game changer", "revolutionary").

TOPIC INSPIRATION:
- If mobile_engineering: Flutter quirks, Android widgets in Kotlin, SQLite/Hive speed, true AMOLED dark mode, 60fps UI smoothness, Gradle build quirks.
- If indie_maker_life: Solo founder mindset, fighting scope creep, shipping vs perfectionism, celebrating micro-milestones.
- If productivity_philosophy: Frictionless capturing, digital minimalism, why complex tools fail, focus habits.
- If developer_question: A casual question asking fellow devs about their stack, daily habits, or favorite design patterns.

OUTPUT FORMAT:
Return ONLY the raw tweet text. Do not wrap in quotes or markdown. Just the exact text to post."""

        headers = {"Content-Type": "application/json"}
        payload = {
            "contents": [
                {"parts": [{"text": prompt}]}
            ],
            "generationConfig": {
                "temperature": 0.85,
                "maxOutputTokens": 200
            }
        }

        from .gemini_engine import GEMINI_MODELS
        for model_name in GEMINI_MODELS:
            url = f"https://generativelanguage.googleapis.com/v1beta/models/{model_name}:generateContent?key={self.api_key}"
            try:
                res = requests.post(url, headers=headers, json=payload, timeout=25)
                if res.status_code == 404:
                    continue
                res.raise_for_status()
                data = res.json()
                candidates = data.get("candidates", [])
                if candidates:
                    raw_text = candidates[0].get("content", {}).get("parts", [{}])[0].get("text", "").strip()
                    clean_text = raw_text.strip('"\n\r ')
                    if clean_text and len(clean_text) <= 280:
                        logger.info(f"Generated organic developer thought ({len(clean_text)} chars) via {model_name}: {clean_text}")
                        return {
                            "text": clean_text,
                            "topic": chosen_topic
                        }
            except Exception as e:
                logger.warning(f"Error generating thought with {model_name}: {e}")

        # Fallback if Gemini fails or exceeds character limit
        fallback = random.choice(CURATED_FALLBACK_THOUGHTS)
        return {
            "text": fallback,
            "topic": chosen_topic
        }


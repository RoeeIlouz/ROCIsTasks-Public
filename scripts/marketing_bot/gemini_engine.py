import json
import logging
import re
from typing import Dict, Any, Optional
import requests

from .config import GEMINI_API_KEY, APP_INFO

logger = logging.getLogger(__name__)

# Candidate models to try in priority order (including future 3.x, 2.5, 2.0, 1.5)
GEMINI_MODELS = [
    "gemini-3.0-flash",
    "gemini-3-flash",
    "gemini-2.5-flash",
    "gemini-2.0-flash",
    "gemini-2.0-flash-exp",
    "gemini-1.5-flash-latest",
    "gemini-1.5-flash",
    "gemini-pro"
]

def _clean_json_markdown(text: str) -> str:
    """Removes ```json ... ``` markdown wrappers if present and extracts the outermost JSON object."""
    text = text.strip()
    # If the response starts with ```json or ```, strip that outer fence
    if text.startswith("```"):
        first_newline = text.find("\n")
        if first_newline != -1:
            text = text[first_newline + 1:]
        if text.endswith("```"):
            text = text[:-3]
        text = text.strip()

    # Find the first '{' and the last '}'
    start_idx = text.find("{")
    end_idx = text.rfind("}")
    if start_idx != -1 and end_idx != -1 and end_idx > start_idx:
        return text[start_idx:end_idx + 1]

    return text

class GeminiEngine:
    def __init__(self, api_key: Optional[str] = None):
        self.api_key = api_key or GEMINI_API_KEY
        self.working_model: Optional[str] = None
        self._discovered_models: Optional[list] = None

    def is_available(self) -> bool:
        return bool(self.api_key and len(self.api_key.strip()) > 5)

    def _discover_available_models(self) -> list:
        """Dynamically queries the Gemini API to find which models are actually available for this key."""
        if self._discovered_models is not None:
            return self._discovered_models

        try:
            url = f"https://generativelanguage.googleapis.com/v1beta/models?key={self.api_key}"
            resp = requests.get(url, timeout=10)
            if resp.status_code == 200:
                data = resp.json()
                raw_models = [
                    m.get("name", "").replace("models/", "")
                    for m in data.get("models", [])
                    if "generateContent" in m.get("supportedGenerationMethods", [])
                ]
                # Filter models: exclude TTS/audio-only preview models
                text_models = [m for m in raw_models if "tts" not in m and "audio" not in m]
                flash_models = [m for m in text_models if "flash" in m]
                other_models = [m for m in text_models if "flash" not in m]
                self._discovered_models = flash_models + other_models
                logger.info(f"Discovered {len(self._discovered_models)} Gemini models via API. Top models: {self._discovered_models[:5]}")
                return self._discovered_models
        except Exception as e:
            logger.warning(f"Could not dynamically query models endpoint: {e}")

        self._discovered_models = list(GEMINI_MODELS)
        return self._discovered_models

    def _call_gemini(self, prompt: str, temperature: float = 0.7, max_tokens: int = 1000) -> Optional[str]:
        if not self.is_available():
            logger.warning("GEMINI_API_KEY not configured. Skipping LLM call.")
            return None

        headers = {"Content-Type": "application/json"}
        payload = {
            "contents": [
                {
                    "parts": [
                        {"text": prompt}
                    ]
                }
            ],
            "generationConfig": {
                "temperature": temperature,
                "maxOutputTokens": max_tokens
            }
        }

        # Build candidate list: working_model first, then discovered from API, then fallback list
        models_to_try = []
        if self.working_model:
            models_to_try.append(self.working_model)

        # Discover dynamic models from Google
        api_models = self._discover_available_models()
        for m in api_models:
            if m not in models_to_try:
                models_to_try.append(m)

        for m in GEMINI_MODELS:
            if m not in models_to_try:
                models_to_try.append(m)

        for model_name in models_to_try:
            url = f"https://generativelanguage.googleapis.com/v1beta/models/{model_name}:generateContent?key={self.api_key}"
            try:
                response = requests.post(url, headers=headers, json=payload, timeout=45)
                if response.status_code == 404:
                    logger.warning(f"Model '{model_name}' returned 404. Trying next model...")
                    continue
                response.raise_for_status()
                data = response.json()
                candidates = data.get("candidates", [])
                if candidates:
                    parts = candidates[0].get("content", {}).get("parts", [])
                    if parts:
                        self.working_model = model_name
                        return parts[0].get("text", "")
            except requests.exceptions.HTTPError as e:
                logger.error(f"Gemini API error with model '{model_name}' ({response.status_code}): {response.text[:200]}")
            except Exception as e:
                logger.error(f"Gemini connection error with model '{model_name}': {e}")

        logger.error("All candidate Gemini models failed.")
        return None

    def evaluate_and_draft_response(self, thread_title: str, thread_body: str, platform: str) -> Optional[Dict[str, Any]]:
        """
        Evaluates thread relevance for ROCIs Tasks and drafts a natural, non-spammy response.
        """
        app_features_str = "\n".join(f"- {f}" for f in APP_INFO["core_features"])

        prompt = f"""You are a helpful growth engineer and developer behind the Android app "{APP_INFO['name']}".

APP CONTEXT:
Tagline: {APP_INFO['tagline']}
Philosophy: {APP_INFO['philosophy']}
Google Play: {APP_INFO['play_store_url']}
Web Version: {APP_INFO['web_url']}

CORE FEATURES:
{app_features_str}

TASK:
Analyze the following public thread from platform: {platform}
Thread Title: {thread_title}
Thread Content:
{thread_body[:1500]}

OBJECTIVES:
1. STRICT ANTI-PIGGYBACKING CHECK:
   - If the author is showcasing or promoting THEIR OWN app, game, or tool, DO NOT self-promote ROCIs Tasks! In this case, mark relevance_score < 70 or only write a genuine, supportive 1-2 sentence compliment/peer feedback without mentioning or linking ROCIs Tasks.
   - ONLY award a high relevance score (90+) if the user is EXPLICITLY asking the community: "What task/calendar app do you recommend?", "How do I fix procrastination?", or asking technical questions about Flutter/widgets/local-first data.
2. If relevance >= 90: Draft a LIGHT, CONCISE, NON-REPETITIVE comment:
   - Maximum 2 to 4 sentences total.
   - NO heavy marketing copy, NO long lists of bullet points, NO repetitive templates.
   - Speak casually as a solo developer who solved that exact problem.
   - Include a natural mention or link only if truly helpful to their explicit question.

OUTPUT FORMAT:
Return ONLY valid JSON matching this exact structure:
{{
  "is_relevant": true/false,
  "relevance_score": <number 0-100>,
  "reasoning": "<brief explanation why it is or is not relevant>",
  "matched_features": ["<feature 1>", "<feature 2>"],
  "draft_reply": "<drafted reply text, or empty if not relevant>"
}}
"""
        raw_text = self._call_gemini(prompt, temperature=0.6)
        if not raw_text:
            return None

        cleaned = _clean_json_markdown(raw_text)
        try:
            parsed = json.loads(cleaned)
            return parsed
        except Exception as e:
            logger.error(f"Failed to parse Gemini response as JSON: {e}. Raw text:\n{raw_text}")
            return None

    def classify_comment_and_extract_feedback(
        self,
        post_title: str,
        comment_text: str,
        author: str
    ) -> Optional[Dict[str, Any]]:
        """
        Classifies user replies to our posts, extracts actionable feature requests or bug reports,
        and drafts a courteous reply.
        """
        prompt = f"""You are reviewing community feedback on our Android app "{APP_INFO['name']}".

Original Post Context: {post_title}
Comment by @{author}:
"{comment_text}"

Analyze this comment and return ONLY valid JSON with this structure:
{{
  "category": "feature_request" | "bug_report" | "praise" | "question" | "criticism" | "unrelated",
  "sentiment": "positive" | "neutral" | "negative",
  "actionable": true/false,
  "summary": "<1-2 sentence concise summary of the suggestion or issue>",
  "suggested_reply": "<courteous, friendly reply acknowledging their feedback or answering their question>"
}}
"""
        raw_text = self._call_gemini(prompt, temperature=0.5)
        if not raw_text:
            return None

        cleaned = _clean_json_markdown(raw_text)
        try:
            return json.loads(cleaned)
        except Exception as e:
            logger.error(f"Failed to parse feedback classification JSON: {e}")
            return None

    def generate_devto_article(self, topic: Optional[str] = None) -> Optional[Dict[str, Any]]:
        """
        Generates an authentic, in-depth technical article or devlog for Dev.to
        sharing architecture insights, lessons learned building ROCIs Tasks with Flutter & Kotlin,
        or solving offline-first synchronization challenges.
        """
        prompt = f"""You are a passionate indie mobile developer writing a high-quality technical article on Dev.to.
Context: You built an offline-first Android task & calendar app called "{APP_INFO['name']}" using Flutter, Kotlin home widgets, and Hive/Firestore.

Topic Focus: {topic or "Architecture & Lessons from building an offline-first mobile app with Flutter & Kotlin"}

REQUIREMENTS:
1. VALUE-FIRST: Provide real technical value (code concepts, architecture patterns, tradeoffs between local Hive storage vs remote Firestore sync, battery life with home widgets).
2. TONE: Honest, humble developer journey (what went wrong, how you solved it, clean code principles). Not a sales pitch.
3. FORMAT:
   - Catchy, authentic developer title (e.g. "How I Built Real-Time Offline-First Sync in Flutter Without State Headaches")
   - Markdown formatted article with headings, code snippets, and key takeaways.
   - 4 relevant tags (e.g. ["flutter", "android", "architecture", "showdev"]).
4. OUTPUT FORMAT:
   Return ONLY valid JSON matching this exact structure:
   {{
     "title": "<article title>",
     "tags": ["flutter", "android", "productivity", "showdev"],
     "body_markdown": "<full markdown body of the article>",
     "summary": "<1-2 sentence summary for Telegram notification>"
   }}
"""
        raw_text = self._call_gemini(prompt, temperature=0.7)
        if not raw_text:
            return None

        cleaned = _clean_json_markdown(raw_text)
        try:
            return json.loads(cleaned)
        except Exception as e:
            logger.error(f"Failed to parse Dev.to article JSON: {e}")
            return None



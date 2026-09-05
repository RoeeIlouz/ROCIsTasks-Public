import json
import logging
import re
from typing import Dict, Any, Optional
import requests

from .config import GEMINI_API_KEY, APP_INFO

logger = logging.getLogger(__name__)

GEMINI_MODELS = [
    "gemini-2.0-flash",
    "gemini-2.5-flash",
    "gemini-1.5-flash-latest",
    "gemini-1.5-flash",
    "gemini-pro"
]

def _clean_json_markdown(text: str) -> str:
    """Removes ```json ... ``` markdown wrappers if present."""
    text = text.strip()
    match = re.search(r"```(?:json)?\s*([\s\S]*?)\s*```", text)
    if match:
        return match.group(1).strip()
    return text

class GeminiEngine:
    def __init__(self, api_key: Optional[str] = None):
        self.api_key = api_key or GEMINI_API_KEY
        self.working_model: Optional[str] = None

    def is_available(self) -> bool:
        return bool(self.api_key and len(self.api_key.strip()) > 5)

    def _call_gemini(self, prompt: str, temperature: float = 0.7) -> Optional[str]:
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
                "maxOutputTokens": 1000
            }
        }

        # If we already found a working model, try that first
        models_to_try = [self.working_model] if self.working_model else list(GEMINI_MODELS)
        for m in GEMINI_MODELS:
            if m not in models_to_try:
                models_to_try.append(m)

        for model_name in models_to_try:
            url = f"https://generativelanguage.googleapis.com/v1beta/models/{model_name}:generateContent?key={self.api_key}"
            try:
                response = requests.post(url, headers=headers, json=payload, timeout=25)
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
1. Determine if this user is genuinely seeking recommendations, solutions, or discussions related to to-do apps, task managers, Android widgets, offline organization, or calendar apps.
2. Score relevance from 0 to 100.
3. If relevance >= 70, draft an authentic, empathetic, human-sounding reply.
   - Tone: Humble indie developer sharing what they built, or a fellow power user offering a genuine recommendation.
   - STRICT BAN: NO corporate buzzwords, NO fake hyperbole ("the absolute revolutionary app"), NO generic bot replies.
   - Directly answer their exact questions or frustrations first.
   - Mention ROCIs Tasks naturally as a relevant option, highlighting the exact feature that addresses their pain point (e.g. true offline sync, natural language typing, or Android home screen widgets).
   - Provide the Google Play link: {APP_INFO['play_store_url']} and web link {APP_INFO['web_url']}.

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


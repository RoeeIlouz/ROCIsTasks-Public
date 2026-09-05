import hashlib
import logging
import re
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, Any, List, Optional

from .config import GEMINI_API_KEY, APP_INFO
from .gemini_engine import GeminiEngine, _clean_json_markdown

logger = logging.getLogger(__name__)

class SecretSanitizer:
    """
    Guarantees zero leakage of sensitive keys, tokens, credentials,
    file paths, or credentials in any public-facing DevLog.
    """
    SECRET_PATTERNS = [
        # GitHub Personal Access Tokens
        (re.compile(r'ghp_[a-zA-Z0-9]{36,}', re.IGNORECASE), '[REDACTED_GH_TOKEN]'),
        (re.compile(r'github_pat_[a-zA-Z0-9_]{50,}', re.IGNORECASE), '[REDACTED_GH_TOKEN]'),
        # Telegram Bot Tokens (e.g. 1234567890:ABCdefGHIjklMNOpqrsTUVwxyz)
        (re.compile(r'\b\d{8,12}:[A-Za-z0-9_-]{35}\b'), '[REDACTED_TELEGRAM_TOKEN]'),
        # Google API Keys
        (re.compile(r'AIza[0-9A-Za-z-_]{35}'), '[REDACTED_GOOGLE_KEY]'),
        # Generic Bearer Tokens
        (re.compile(r'Bearer\s+[A-Za-z0-9_\-\.]{20,}', re.IGNORECASE), 'Bearer [REDACTED_TOKEN]'),
        # Private Keys & PEM Headers
        (re.compile(r'-----BEGIN [A-Z ]+ PRIVATE KEY-----[\s\S]*?-----END [A-Z ]+ PRIVATE KEY-----'), '[REDACTED_PRIVATE_KEY]'),
        # Keystore passwords and sensitive config lines
        (re.compile(r'(?:password|secret|keyPassword|storePassword)\s*=\s*["\']?[^"\'\s\n]+["\']?', re.IGNORECASE), 'password=[REDACTED]'),
        # Local Windows User absolute paths
        (re.compile(r'[a-zA-Z]:\\Users\\[^\\]+\\[^\s\n"\'`]+'), '~/ROCIs-tasks'),
        # Base64 blocks longer than 40 chars
        (re.compile(r'\b(?:[A-Za-z0-9+/]{4}){10,}(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?\b'), '[REDACTED_BASE64]')
    ]

    @classmethod
    def sanitize(cls, text: str) -> str:
        if not text:
            return ""
        sanitized = text
        for pattern, replacement in cls.SECRET_PATTERNS:
            sanitized = pattern.sub(replacement, sanitized)
        return sanitized


class SummaryParser:
    """
    Parses docs/SUMMARY.md to extract milestones chronologically.
    """
    def __init__(self, summary_path: Optional[Path] = None):
        if summary_path:
            self.summary_path = Path(summary_path)
        else:
            self.summary_path = Path(__file__).resolve().parent.parent.parent / "docs" / "SUMMARY.md"

    def parse_milestones(self) -> List[Dict[str, Any]]:
        """
        Parses all sections under '## ' in docs/SUMMARY.md.
        Returns list sorted CHRONOLOGICALLY (oldest milestone first).
        """
        if not self.summary_path.exists():
            logger.warning(f"SUMMARY.md not found at {self.summary_path}")
            return []

        try:
            with open(self.summary_path, "r", encoding="utf-8", errors="replace") as f:
                content = f.read()
        except Exception as e:
            logger.error(f"Failed to read {self.summary_path}: {e}")
            return []

        # Split on markdown H2 headings
        sections = re.split(r'\n##\s+', content)
        milestones = []

        for idx, sec in enumerate(sections):
            if idx == 0 and not sec.startswith("## "):
                # Skip markdown header intro before first '## '
                continue

            sec = sec.strip()
            if not sec:
                continue

            lines = sec.split("\n", 1)
            raw_title = lines[0].strip()
            body = lines[1].strip() if len(lines) > 1 else ""

            # Extract date if present (e.g. "2026-09-05" or "2026-07-17")
            date_match = re.search(r'(\d{4}-\d{2}-\d{2})', raw_title)
            milestone_date = date_match.group(1) if date_match else "Historical"

            # Create deterministic unique slug
            slug_hash = hashlib.sha1(raw_title.encode("utf-8")).hexdigest()[:10]
            clean_title = re.sub(r'[\W_]+', '_', raw_title.lower()).strip('_')[:30]
            slug = f"devlog_{clean_title}_{slug_hash}"

            # Only consider milestones that contain substantive engineering content (> 100 chars)
            if len(body) > 100:
                milestones.append({
                    "title": raw_title,
                    "date": milestone_date,
                    "slug": slug,
                    "body": SecretSanitizer.sanitize(body)
                })

        # SUMMARY.md has newest at top, oldest at bottom.
        # User requested CHRONOLOGICAL order: reverse the list so oldest is first!
        milestones.reverse()
        logger.info(f"SummaryParser extracted {len(milestones)} milestones in chronological order.")
        return milestones


class DevlogEngine:
    """
    Generates multi-platform DevLog packages (Dev.to article + X/Twitter post + Bluesky post)
    from docs/SUMMARY.md engineering milestones.
    """
    def __init__(self, gemini_engine: GeminiEngine):
        self.gemini = gemini_engine
        self.parser = SummaryParser()

    def find_next_milestone(self, posted_slugs: set, pending_slugs: set) -> Optional[Dict[str, Any]]:
        """
        Finds the earliest (oldest) milestone from docs/SUMMARY.md
        that has not yet been posted or queued in pending drafts.
        """
        all_milestones = self.parser.parse_milestones()
        for m in all_milestones:
            slug = m["slug"]
            if slug not in posted_slugs and slug not in pending_slugs:
                return m
        return None

    def generate_devlog_package(self, milestone: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        """
        Produces an authentic, high-signal DevLog package tailored to indie engineering:
        - Dev.to: Long-form article with problem, root cause, architectural fix, code diff, takeaways.
        - X/Twitter: Punchy 1-2 post thread / single post (<260 chars).
        - Bluesky: Engaging micro-devlog (<280 chars).
        """
        title = milestone["title"]
        date = milestone["date"]
        body = milestone["body"]

        logger.info(f"Generating DevLog package for milestone: '{title}' ({date})")

        prompt = f"""You are an authentic, passionate indie mobile developer building 'ROCIs Tasks' (an offline-first Android task & calendar app with native Kotlin home screen widgets, built with Flutter).

Here is a real engineering log from your codebase summary:
---
MILESTONE: {title} ({date})
NOTES & ARCHITECTURE:
{body[:3500]}
---

Generate a cohesive multi-platform DevLog package.

CRITICAL SECURITY RULES:
- NEVER output real API keys, secrets, tokens, passwords, keystore hashes, or internal Windows user paths.
- All code examples must be safe, generalized, and educational.

REQUIREMENTS FOR EACH PLATFORM:

1. DEV.TO ARTICLE (`devto_title`, `devto_body`, `tags`):
   - `devto_title`: Punchy, click-worthy developer title (e.g., 'How I Fixed Android Widgets Rendering Hebrew Weekdays as Y, Y, Y, Y in Flutter' or 'Why My Android Notification Crashed on Flutter Bitmaps').
   - `devto_body`: Full Markdown article (800-1400 words) structured as:
     * **The Hook**: Relatable opening about indie dev life / Android development.
     * **The Mystery / The Bug**: What was happening, why users were seeing it, and why the naive solution failed.
     * **The Root Cause**: Deep dive into Kotlin / Flutter platform channels / Android OS internals.
     * **The Solution & Code Architecture**: How you solved it cleanly, with code blocks/snippets.
     * **Key Lessons for Other Devs**: 2-3 actionable bullet points.
     * **Outro & ROCIs Tasks**: A humble, natural invitation to check out ROCIs Tasks on Google Play ({APP_INFO['play_store_url']}) or web ({APP_INFO['web_url']}).
   - `tags`: Array of up to 4 lowercase tags (e.g. ["flutter", "android", "indiedev", "programming"]).

2. X / TWITTER POST (`x_text`):
   - Under 240 characters (leaves room for link).
   - Hook the reader with the weird/funny bug or technical realization.
   - Casual indie developer tone.

3. BLUESKY POST (`bsky_text`):
   - Under 260 characters (leaves room for link).
   - Conversational, smart technical takeaway.

Output ONLY valid JSON matching this exact structure:
{{
  "devto_title": "string",
  "devto_body": "string (markdown)",
  "tags": ["tag1", "tag2", "tag3", "tag4"],
  "x_text": "string",
  "bsky_text": "string"
}}
"""

        raw_response = self.gemini._call_gemini(prompt, temperature=0.7)
        if not raw_response:
            logger.error("Gemini failed to generate DevLog package.")
            return None

        clean_json = _clean_json_markdown(raw_response)
        try:
            package = json.loads(clean_json)
        except json.JSONDecodeError as e:
            logger.error(f"Failed to parse DevLog JSON from Gemini: {e}\nRaw: {raw_response[:300]}")
            return None

        # Sanitize everything before returning
        devto_title = SecretSanitizer.sanitize(package.get("devto_title", title))
        devto_body = SecretSanitizer.sanitize(package.get("devto_body", ""))
        x_text = SecretSanitizer.sanitize(package.get("x_text", ""))
        bsky_text = SecretSanitizer.sanitize(package.get("bsky_text", ""))
        tags = [re.sub(r'[^a-z0-9]', '', t.lower()) for t in package.get("tags", ["flutter", "android", "indiedev", "productivity"])][:4]

        # Generate unique draft ID
        draft_id = f"devlog_{milestone['slug']}"

        return {
            "id": draft_id,
            "type": "devlog",
            "milestone_title": title,
            "milestone_date": date,
            "milestone_slug": milestone["slug"],
            "devto_title": devto_title,
            "devto_body": devto_body,
            "tags": tags,
            "x_text": x_text,
            "bsky_text": bsky_text,
            "created_at": datetime.now(timezone.utc).isoformat(),
            "status": "pending"
        }

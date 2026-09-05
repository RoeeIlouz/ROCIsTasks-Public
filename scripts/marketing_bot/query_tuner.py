import time
import json
import logging
from typing import List, Optional
from pathlib import Path

from .gemini_engine import GeminiEngine
from .state_manager import StateManager
from .config import DISCOVERY_SEARCH_QUERIES

logger = logging.getLogger(__name__)

CACHE_TTL_SECONDS = 7 * 24 * 3600  # 7 days

class QueryTuner:
    """
    Intelligently generates and rotates community discovery search queries
    based on the latest shipped features, using Gemini with a 7-day TTL cache.
    """
    def __init__(
        self,
        state_manager: StateManager,
        gemini_engine: Optional[GeminiEngine] = None,
        changelog_path: Optional[Path] = None
    ):
        self.state_manager = state_manager
        self.gemini = gemini_engine or GeminiEngine()
        self.changelog_path = changelog_path or (Path(__file__).resolve().parent.parent.parent / "docs" / "CHANGELOG.md")

    def _read_recent_changelog_snippet(self) -> str:
        """Extracts the first 500 characters of the latest release notes."""
        if self.changelog_path and self.changelog_path.is_file():
            try:
                with open(self.changelog_path, "r", encoding="utf-8") as f:
                    content = f.read(1500)
                return content
            except Exception as e:
                logger.warning(f"Failed to read changelog: {e}")
        return "Offline-first task management, Android home screen calendar widgets, glassmorphism UI, local Hive storage."

    def get_active_queries(self, force_refresh: bool = False) -> List[str]:
        """
        Returns the active search queries. Uses cache if valid,
        or triggers Gemini query generation.
        """
        now = time.time()
        cached = self.state_manager.data.get("tuned_queries_cache")

        if not force_refresh and cached:
            cached_ts = cached.get("timestamp", 0)
            cached_queries = cached.get("queries", [])
            if (now - cached_ts) < CACHE_TTL_SECONDS and len(cached_queries) >= 3:
                return cached_queries

        # Generate fresh queries
        queries = self._generate_queries()

        # Cache in state manager
        self.state_manager.data["tuned_queries_cache"] = {
            "timestamp": now,
            "queries": queries
        }
        self.state_manager.save()

        return queries

    def _generate_queries(self) -> List[str]:
        """Asks Gemini to create 5 high-intent community search queries."""
        snippet = self._read_recent_changelog_snippet()

        prompt = f"""
        You are a growth marketing specialist for 'ROCIs Tasks', an offline-first Flutter task manager.
        Recent app highlights:
        {snippet}

        Generate 5 high-intent, 2-to-4 word search queries that users type when seeking solutions ROCIs Tasks provides.
        Examples:
        - "offline todo app android"
        - "task manager with home widget"
        - "todo list without account"
        - "local first task manager"

        Return ONLY a JSON list of 5 string queries, like:
        ["query 1", "query 2", "query 3", "query 4", "query 5"]
        """

        if self.gemini.is_available():
            try:
                res = self.gemini.generate_text(prompt)
                clean_json = res.strip()
                if "```json" in clean_json:
                    clean_json = clean_json.split("```json")[1].split("```")[0].strip()
                elif "```" in clean_json:
                    clean_json = clean_json.split("```")[1].split("```")[0].strip()
                parsed = json.loads(clean_json)
                if isinstance(parsed, list) and len(parsed) >= 3:
                    logger.info(f"Dynamically generated fresh search queries: {parsed}")
                    return [str(q).strip() for q in parsed[:6]]
            except Exception as e:
                logger.error(f"Error generating dynamic search queries with Gemini: {e}")

        # Fallback to configured default discovery queries
        return list(DISCOVERY_SEARCH_QUERIES)


import json
import logging
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, Any, Optional

logger = logging.getLogger(__name__)

DEFAULT_STATE = {
    "version": 1,
    "last_run_timestamp": None,
    "last_organic_post_timestamp": None,
    "telegram_last_update_id": 0,
    "inspected_threads": {},
    "pending_drafts": {},
    "posted_threads": {},
    "recorded_feedback": [],
    "organic_posts": [],
    "x_posts_timestamps": []
}

class StateManager:
    def __init__(self, state_file_path: Path):
        self.state_file_path = Path(state_file_path)
        self.data: Dict[str, Any] = self._load()

    def _load(self) -> Dict[str, Any]:
        if self.state_file_path.exists():
            try:
                with open(self.state_file_path, "r", encoding="utf-8") as f:
                    state = json.load(f)
                    # Backfill any missing top-level keys
                    for key, val in DEFAULT_STATE.items():
                        if key not in state:
                            state[key] = val
                    return state
            except Exception as e:
                logger.error(f"Failed to read state file {self.state_file_path}: {e}. Initializing fresh state.")
        return json.loads(json.dumps(DEFAULT_STATE))

    def save(self) -> None:
        try:
            self.data["last_run_timestamp"] = datetime.now(timezone.utc).isoformat()
            self.state_file_path.parent.mkdir(parents=True, exist_ok=True)
            with open(self.state_file_path, "w", encoding="utf-8") as f:
                json.dump(self.data, f, indent=2, ensure_ascii=False)
            logger.info("State successfully persisted.")
        except Exception as e:
            logger.error(f"Failed to save state to {self.state_file_path}: {e}")

    @property
    def telegram_last_update_id(self) -> int:
        return self.data.get("telegram_last_update_id", 0)

    @telegram_last_update_id.setter
    def telegram_last_update_id(self, val: int) -> None:
        self.data["telegram_last_update_id"] = val

    def is_thread_inspected(self, thread_id: str) -> bool:
        return thread_id in self.data["inspected_threads"]

    def record_inspected_thread(self, thread_id: str, info: Dict[str, Any]) -> None:
        info["inspected_at"] = datetime.now(timezone.utc).isoformat()
        self.data["inspected_threads"][thread_id] = info

    def add_pending_draft(self, draft_id: str, draft_info: Dict[str, Any]) -> None:
        draft_info["created_at"] = datetime.now(timezone.utc).isoformat()
        draft_info["status"] = "pending"
        self.data["pending_drafts"][draft_id] = draft_info

    def get_pending_draft(self, draft_id: str) -> Optional[Dict[str, Any]]:
        return self.data["pending_drafts"].get(draft_id)

    def mark_draft_status(self, draft_id: str, status: str) -> Optional[Dict[str, Any]]:
        draft = self.data["pending_drafts"].get(draft_id)
        if draft:
            draft["status"] = status
            draft["updated_at"] = datetime.now(timezone.utc).isoformat()
        return draft

    def record_posted_thread(self, thread_id: str, post_info: Dict[str, Any]) -> None:
        post_info["posted_at"] = datetime.now(timezone.utc).isoformat()
        if "tracked_comments" not in post_info:
            post_info["tracked_comments"] = []
        self.data["posted_threads"][thread_id] = post_info

    def get_posted_threads(self) -> Dict[str, Dict[str, Any]]:
        return self.data.get("posted_threads", {})

    def add_feedback(self, feedback_item: Dict[str, Any]) -> None:
        feedback_item["recorded_at"] = datetime.now(timezone.utc).isoformat()
        self.data["recorded_feedback"].append(feedback_item)

    def can_post_organic(self, min_interval_hours: int = 12) -> bool:
        """
        Determines if enough time has passed to publish a fresh organic persona post.
        """
        last_ts_str = self.data.get("last_organic_post_timestamp")
        if not last_ts_str:
            return True

        try:
            last_dt = datetime.fromisoformat(last_ts_str)
            now_dt = datetime.now(timezone.utc)
            elapsed_hours = (now_dt - last_dt).total_seconds() / 3600.0
            return elapsed_hours >= min_interval_hours
        except Exception as e:
            logger.warning(f"Error parsing last_organic_post_timestamp: {e}")
            return True

    def record_organic_post(self, text: str, platforms: list, topic: str = "general") -> None:
        """
        Records an executed organic post to maintain history and pace.
        """
        now_iso = datetime.now(timezone.utc).isoformat()
        self.data["last_organic_post_timestamp"] = now_iso
        if "organic_posts" not in self.data:
            self.data["organic_posts"] = []

        self.data["organic_posts"].append({
            "text": text,
            "topic": topic,
            "platforms": platforms,
            "posted_at": now_iso
        })
        # Keep recent 30 posts to avoid unbound growth
        self.data["organic_posts"] = self.data["organic_posts"][-30:]

    def can_post_to_x(self, max_monthly: int = 100, max_daily: int = 5) -> bool:
        """
        Guarantees that X posting NEVER exceeds the free tier quota.
        Counts tweets within the last 30 days and last 24 hours.
        """
        now = datetime.now(timezone.utc)
        timestamps = self.data.get("x_posts_timestamps", [])

        # Filter valid timestamps within 30 days
        valid_30d = []
        count_24h = 0
        for ts_str in timestamps:
            try:
                dt = datetime.fromisoformat(ts_str)
                age_hours = (now - dt).total_seconds() / 3600.0
                if age_hours <= 24 * 30:
                    valid_30d.append(ts_str)
                if age_hours <= 24:
                    count_24h += 1
            except Exception:
                continue

        # Keep state clean
        self.data["x_posts_timestamps"] = valid_30d

        if len(valid_30d) >= max_monthly:
            logger.warning(f"SAFETY GUARD: X monthly free limit reached ({len(valid_30d)}/{max_monthly} in 30d). Blocking post to prevent charges.")
            return False

        if count_24h >= max_daily:
            logger.warning(f"SAFETY GUARD: X daily limit reached ({count_24h}/{max_daily} in 24h). Blocking post to prevent charges.")
            return False

        return True

    def record_x_post(self) -> None:
        """Records a successful post to X to decrement available free quota."""
        now_iso = datetime.now(timezone.utc).isoformat()
        if "x_posts_timestamps" not in self.data:
            self.data["x_posts_timestamps"] = []
        self.data["x_posts_timestamps"].append(now_iso)

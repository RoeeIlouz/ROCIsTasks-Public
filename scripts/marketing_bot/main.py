import argparse
import logging
import sys
import uuid
from typing import Dict, Any

from .config import (
    STATE_FILE_PATH,
    MAX_DISCOVERIES_PER_RUN,
    MIN_RELEVANCE_SCORE,
    DRY_RUN
)
from .state_manager import StateManager
from .gemini_engine import GeminiEngine
from .telegram_bot import TelegramBot
from .discovery import DiscoveryEngine
from .poster import Poster
from .feedback_monitor import FeedbackMonitor

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)]
)
logger = logging.getLogger("MarketingBot")

def run_pipeline(dry_run: bool = False):
    logger.info("Starting ROCIs Tasks Marketing & Feedback Pipeline...")

    state_mgr = StateManager(STATE_FILE_PATH)
    gemini = GeminiEngine()
    telegram = TelegramBot()
    discovery = DiscoveryEngine(state_mgr)
    poster = Poster(state_mgr, telegram)
    monitor = FeedbackMonitor(state_mgr, gemini, telegram)

    # =========================================================================
    # Step 1: Process User Approvals / Rejections from Telegram
    # =========================================================================
    logger.info("Checking Telegram for pending approvals/rejections...")
    actions, max_update_id = telegram.get_pending_user_actions(state_mgr.telegram_last_update_id)
    if actions:
        logger.info(f"Found {len(actions)} user actions from Telegram.")
        for act in actions:
            action = act["action"]
            draft_id = act["draft_id"]
            callback_id = act["callback_id"]
            msg_id = act.get("message_id")

            draft = state_mgr.get_pending_draft(draft_id)
            if not draft:
                telegram.answer_callback_query(callback_id, "Draft not found.")
                continue

            if draft.get("status") != "pending":
                telegram.answer_callback_query(callback_id, f"Already {draft.get('status')}.")
                continue

            if action == "approve":
                logger.info(f"Draft {draft_id} APPROVED by user.")
                state_mgr.mark_draft_status(draft_id, "approved")
                telegram.answer_callback_query(callback_id, "Approved! Processing...")
                if msg_id:
                    telegram.edit_message_text(
                        msg_id,
                        f"✅ <b>Approved & Executed!</b>\n📌 <a href=\"{draft['thread_url']}\">{draft['thread_title']}</a>"
                    )
                if not dry_run:
                    poster.execute_post(draft)
                else:
                    logger.info(f"[DRY RUN] Would execute post for {draft_id}")

            elif action == "reject":
                logger.info(f"Draft {draft_id} REJECTED by user.")
                state_mgr.mark_draft_status(draft_id, "rejected")
                telegram.answer_callback_query(callback_id, "Skipped.")
                if msg_id:
                    telegram.edit_message_text(
                        msg_id,
                        f"❌ <b>Skipped</b>\n📌 <a href=\"{draft['thread_url']}\">{draft['thread_title']}</a>"
                    )

        state_mgr.telegram_last_update_id = max_update_id
        state_mgr.save()
    else:
        logger.info("No pending Telegram user actions.")

    # =========================================================================
    # Step 2: Discover Fresh Promotion Opportunities & Draft Copy
    # =========================================================================
    logger.info("Scanning communities for fresh promotion opportunities...")
    candidates = discovery.discover_opportunities(max_results=MAX_DISCOVERIES_PER_RUN)

    for thread in candidates:
        thread_id = thread["id"]
        platform = thread["platform"]
        title = thread["title"]
        body = thread["body"]
        url = thread["url"]

        # Record thread as inspected so we don't repeat analysis
        state_mgr.record_inspected_thread(thread_id, {
            "platform": platform,
            "title": title,
            "url": url
        })

        if not gemini.is_available():
            logger.warning("Gemini API key is not configured. Skipping copywriting.")
            continue

        logger.info(f"Evaluating relevance for thread: '{title}' ({url})")
        eval_result = gemini.evaluate_and_draft_response(
            thread_title=title,
            thread_body=body,
            platform=platform
        )

        if not eval_result:
            continue

        is_relevant = eval_result.get("is_relevant", False)
        score = eval_result.get("relevance_score", 0)
        reasoning = eval_result.get("reasoning", "")
        draft_reply = eval_result.get("draft_reply", "").strip()

        logger.info(f"Result: Relevant={is_relevant}, Score={score}/100. Reasoning: {reasoning}")

        if is_relevant and score >= MIN_RELEVANCE_SCORE and draft_reply:
            draft_id = f"draft_{uuid.uuid4().hex[:8]}"
            logger.info(f"Creating draft card {draft_id} for Telegram dispatch...")

            if not dry_run and telegram.is_configured():
                msg_id = telegram.send_draft_approval_card(
                    draft_id=draft_id,
                    platform=platform,
                    thread_title=title,
                    thread_url=url,
                    relevance_score=score,
                    reasoning=reasoning,
                    draft_reply=draft_reply
                )
            else:
                logger.info(f"[DRY RUN / NO TELEGRAM] Draft preview for {draft_id}:\n{draft_reply}")
                msg_id = None

            state_mgr.add_pending_draft(draft_id, {
                "thread_id": thread_id,
                "platform": platform,
                "thread_title": title,
                "thread_url": url,
                "relevance_score": score,
                "reasoning": reasoning,
                "draft_text": draft_reply,
                "telegram_message_id": msg_id
            })

    state_mgr.save()

    # =========================================================================
    # Step 3: Monitor Posted Threads for Replies & Feedback
    # =========================================================================
    logger.info("Scanning previously promoted threads for community replies...")
    if not dry_run and gemini.is_available():
        monitor.check_all_posted_threads()
    else:
        logger.info("Skipping comment monitoring in dry-run mode or when Gemini unavailable.")

    # =========================================================================
    # Step 4: Final State Persistence
    # =========================================================================
    state_mgr.save()
    logger.info("Pipeline run completed successfully.")

def main():
    parser = argparse.ArgumentParser(description="ROCIs Tasks Marketing & Feedback Bot")
    parser.add_argument("--dry-run", action="store_true", help="Run without sending real messages or posting.")
    args = parser.parse_args()

    is_dry = args.dry_run or DRY_RUN
    run_pipeline(dry_run=is_dry)

if __name__ == "__main__":
    main()


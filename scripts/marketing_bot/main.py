import argparse
import logging
import os
import sys
import uuid
from typing import Dict, Any

from .config import (
    STATE_FILE_PATH,
    MAX_DISCOVERIES_PER_RUN,
    MIN_RELEVANCE_SCORE,
    DRY_RUN,
    DEVTO_API_KEY,
    AUTO_POST_ORGANIC,
    ORGANIC_POST_MIN_INTERVAL_HOURS,
    X_MAX_MONTHLY_POSTS,
    X_MAX_DAILY_POSTS,
    GEMINI_MAX_CALLS_PER_RUN,
    TARGET_SUBREDDITS
)
from .state_manager import StateManager
from .gemini_engine import GeminiEngine
from .persona_engine import PersonaEngine
from .telegram_bot import TelegramBot
from .discovery import DiscoveryEngine
from .poster import Poster
from .feedback_monitor import FeedbackMonitor
from .devlog_engine import DevlogEngine
from .reddit_post_generator import RedditPostGenerator
from .analytics import AnalyticsTracker
from .launch_kit import LaunchKitGenerator
from .query_tuner import QueryTuner

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)]
)
logger = logging.getLogger("MarketingBot")

def run_pipeline(dry_run: bool = False):
    logger.info("=" * 60)
    logger.info("Starting ROCIs Tasks Marketing & Feedback Pipeline...")
    logger.info("=" * 60)

    state_mgr = StateManager(STATE_FILE_PATH)
    gemini = GeminiEngine()
    persona = PersonaEngine()
    telegram = TelegramBot()
    discovery = DiscoveryEngine(state_mgr)
    poster = Poster(state_mgr, telegram)
    monitor = FeedbackMonitor(state_mgr, gemini, telegram)

    # Diagnostic visibility
    logger.info("Environment Diagnostics:")
    logger.info(f"  • Gemini API: {'AVAILABLE' if gemini.is_available() else 'NOT CONFIGURED'}")
    logger.info(f"  • Telegram Bot: {'CONFIGURED' if telegram.is_configured() else 'NOT CONFIGURED'}")
    logger.info(f"  • Reddit Cookie Poster: {'AVAILABLE' if poster.playwright_poster.is_available() else 'NOT CONFIGURED'}")
    logger.info(f"  • Bluesky API: {'AVAILABLE' if poster.bluesky.is_configured() else 'NOT CONFIGURED'}")
    logger.info(f"  • Dev.to API: {'AVAILABLE' if DEVTO_API_KEY else 'NOT CONFIGURED'}")
    logger.info(f"  • Hashnode API: {'AVAILABLE' if poster.hashnode.is_configured() else 'NOT CONFIGURED'}")
    logger.info(f"  • Medium API: {'AVAILABLE' if poster.medium.is_configured() else 'NOT CONFIGURED'}")
    logger.info(f"  • Mastodon API: {'AVAILABLE' if poster.mastodon.is_configured() else 'NOT CONFIGURED'}")
    logger.info(f"  • Meta Threads API: {'AVAILABLE' if poster.threads.is_configured() else 'NOT CONFIGURED'}")
    logger.info(f"  • X/Twitter API: {'AVAILABLE' if poster.x_client.is_configured() else 'NOT CONFIGURED'}")
    logger.info(f"  • Auto-Post Organic Persona: {'ENABLED' if AUTO_POST_ORGANIC else 'DISABLED'} (Cooldown: {ORGANIC_POST_MIN_INTERVAL_HOURS}h)")
    logger.info(f"  • Dry-Run Mode: {dry_run}")
    logger.info("=" * 60)

    # =========================================================================
    # Step 1: Process User Approvals / Rejections
    # =========================================================================
    actions = []

    # 1a. Check for direct dispatch action from Cloudflare Worker / GitHub Actions payload
    dispatch_action = os.getenv("DISPATCH_ACTION")
    dispatch_draft_id = os.getenv("DISPATCH_DRAFT_ID")
    dispatch_msg_id = os.getenv("DISPATCH_MESSAGE_ID")
    if dispatch_action and dispatch_draft_id:
        logger.info(f"Received webhook dispatch: action='{dispatch_action}', draft_id='{dispatch_draft_id}'")
        actions.append({
            "action": dispatch_action,
            "draft_id": dispatch_draft_id,
            "callback_id": None,
            "message_id": int(dispatch_msg_id) if (dispatch_msg_id and dispatch_msg_id.isdigit()) else None
        })

    # 1b. Check Telegram updates (for polling fallback)
    logger.info("Checking Telegram for pending approvals/rejections...")
    polled_actions, max_update_id = telegram.get_pending_user_actions(state_mgr.telegram_last_update_id)
    actions.extend(polled_actions)
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

            if not msg_id:
                msg_id = draft.get("telegram_message_id")

            if draft.get("status") != "pending":
                telegram.answer_callback_query(callback_id, f"Already {draft.get('status')}.")
                continue

            draft_type = draft.get("type")
            is_devlog = draft_type == "devlog"
            is_reddit_post = draft_type == "reddit_post"

            if action == "approve":
                logger.info(f"Draft {draft_id} (type={draft_type}) APPROVED by user.")
                state_mgr.mark_draft_status(draft_id, "approved")
                telegram.answer_callback_query(callback_id, "Approved! Processing...")
                if is_devlog:
                    if msg_id:
                        telegram.edit_message_text(
                            msg_id,
                            f"⏳ <b>Publishing DevLog across Dev.to, X, and Bluesky...</b>\n📌 <i>{draft.get('devto_title')}</i>"
                        )
                    if not dry_run:
                        poster.execute_devlog(draft)
                    else:
                        logger.info(f"[DRY RUN] Would execute devlog publish for {draft_id}")
                elif is_reddit_post:
                    if msg_id:
                        telegram.edit_message_text(
                            msg_id,
                            f"⏳ <b>Submitting post to r/{draft.get('subreddit')}...</b>\n📌 <i>{draft.get('title')}</i>"
                        )
                    if not dry_run:
                        poster.execute_reddit_post(draft)
                    else:
                        logger.info(f"[DRY RUN] Would submit Reddit post for {draft_id}")
                else:
                    if msg_id:
                        telegram.edit_message_text(
                            msg_id,
                            f"✅ <b>Approved & Executed!</b>\n📌 <a href=\"{draft.get('thread_url', '')}\">{draft.get('thread_title', '')}</a>"
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
                    if is_devlog:
                        skip_title = draft.get('devto_title', '')
                    elif is_reddit_post:
                        skip_title = f"r/{draft.get('subreddit')}: {draft.get('title', '')}"
                    else:
                        skip_title = draft.get('thread_title', '')
                    telegram.edit_message_text(
                        msg_id,
                        f"❌ <b>Skipped</b>\n📌 <i>{skip_title}</i>"
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
    total_candidates = len(candidates)
    dispatched_count = 0

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
                if msg_id:
                    dispatched_count += 1
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
    # Step 3: Check and Queue Next DevLog from SUMMARY.md (Chronological Backlog)
    # =========================================================================
    logger.info("Checking backlog for candidate DevLogs from SUMMARY.md...")
    devlog_engine = DevlogEngine(gemini)
    has_pending_devlog = any(
        d.get("type") == "devlog" and d.get("status") == "pending"
        for d in state_mgr.data.get("pending_drafts", {}).values()
    )

    if has_pending_devlog:
        logger.info("A DevLog draft is already pending user approval. Skipping generation.")
    elif not gemini.is_available():
        logger.info("Gemini API not configured. Cannot generate DevLog.")
    else:
        posted_slugs = set(state_mgr.data.get("posted_devlogs", {}).keys())
        pending_slugs = {
            d.get("milestone_slug")
            for d in state_mgr.data.get("pending_drafts", {}).values()
            if d.get("milestone_slug")
        }
        milestone = devlog_engine.find_next_milestone(posted_slugs, pending_slugs)
        if milestone:
            logger.info(f"Selected milestone for DevLog: '{milestone['title']}' ({milestone['date']})")
            pkg = devlog_engine.generate_devlog_package(milestone)
            if pkg:
                if not dry_run and telegram.is_configured():
                    msg_id = telegram.send_devlog_approval_card(
                        draft_id=pkg["id"],
                        milestone_title=pkg["milestone_title"],
                        milestone_date=pkg["milestone_date"],
                        devto_title=pkg["devto_title"],
                        devto_preview=pkg["devto_body"],
                        x_post=pkg["x_text"],
                        bsky_post=pkg["bsky_text"]
                    )
                    pkg["telegram_message_id"] = msg_id
                    state_mgr.add_pending_draft(pkg["id"], pkg)
                    state_mgr.save()
                    dispatched_count += 1
                    logger.info(f"DevLog approval card sent to Telegram (msg_id={msg_id})")
                else:
                    logger.info(f"[DRY RUN / NO TELEGRAM] Generated DevLog package: {pkg['devto_title']}")
                    if dry_run:
                        state_mgr.add_pending_draft(pkg["id"], pkg)
        else:
            logger.info("All SUMMARY.md milestones have already been published or queued.")

    # =========================================================================
    # Step 3b: Check and Queue Reddit Showcase Draft (r/SideProject, r/FlutterDev, etc.)
    # =========================================================================
    logger.info("Checking backlog for candidate Reddit showcase posts...")
    has_pending_reddit_post = any(
        d.get("type") == "reddit_post" and d.get("status") == "pending"
        for d in state_mgr.data.get("pending_drafts", {}).values()
    )

    if has_pending_reddit_post:
        logger.info("A Reddit post draft is already pending user approval. Skipping generation.")
    elif gemini.is_available():
        reddit_gen = RedditPostGenerator(gemini)
        # Select target subreddit with least recent activity
        target_sub = TARGET_SUBREDDITS[0]  # Defaults to SideProject
        logger.info(f"Generating authentic Reddit showcase draft for r/{target_sub}...")
        r_draft = reddit_gen.generate_showcase_post(subreddit=target_sub)
        if r_draft:
            if not dry_run and telegram.is_configured():
                msg_id = telegram.send_reddit_post_approval_card(
                    draft_id=r_draft["id"],
                    subreddit=r_draft["subreddit"],
                    title=r_draft["title"],
                    body_preview=r_draft["body"],
                    topic=r_draft["topic"]
                )
                r_draft["telegram_message_id"] = msg_id
                state_mgr.add_pending_draft(r_draft["id"], r_draft)
                state_mgr.save()
                dispatched_count += 1
                logger.info(f"Reddit showcase approval card sent to Telegram (msg_id={msg_id})")
            else:
                logger.info(f"[DRY RUN / NO TELEGRAM] Generated Reddit showcase: {r_draft['title']}")
                if dry_run:
                    state_mgr.add_pending_draft(r_draft["id"], r_draft)

    # =========================================================================
    # Step 4: Monitor Posted Threads for Replies & Feedback
    # =========================================================================
    logger.info("Scanning previously promoted threads for community replies...")
    if not dry_run and gemini.is_available():
        monitor.check_all_posted_threads()
    else:
        logger.info("Skipping comment monitoring in dry-run mode or when Gemini unavailable.")

    # =========================================================================
    # Step 4: Autonomous Organic Persona Posting (Anti-Bot Account Warming)
    # =========================================================================
    organic_summary = None
    if AUTO_POST_ORGANIC:
        logger.info("Evaluating eligibility for organic persona post...")
        if state_mgr.can_post_organic(min_interval_hours=ORGANIC_POST_MIN_INTERVAL_HOURS):
            logger.info("Cooldown elapsed. Generating authentic developer thought...")
            recent_texts = [p.get("text", "") for p in state_mgr.data.get("organic_posts", [])]
            thought = persona.generate_organic_thought(previous_posts=recent_texts)
            thought_text = thought["text"]
            thought_topic = thought["topic"]

            published_platforms = []
            if not dry_run:
                # 1. Post to Twitter/X (Guarded by ZERO-COST free quota limits)
                if poster.x_client.is_configured():
                    if state_mgr.can_post_to_x(max_monthly=X_MAX_MONTHLY_POSTS, max_daily=X_MAX_DAILY_POSTS):
                        tweet_url = poster.x_client.post_tweet(thought_text)
                        if tweet_url:
                            state_mgr.record_x_post()
                            published_platforms.append("Twitter/X")
                    else:
                        logger.info("Skipping X post: free tier quota ceiling reached (protecting against charges).")

                # 2. Post to Bluesky
                if poster.bluesky.is_configured():
                    bsky_url = poster.bluesky.post_reply(thought_text)
                    if bsky_url:
                        published_platforms.append("Bluesky")

                if published_platforms:
                    state_mgr.record_organic_post(
                        text=thought_text,
                        platforms=published_platforms,
                        topic=thought_topic
                    )
                    organic_summary = f"🌱 Organic post published to {', '.join(published_platforms)}"
                    logger.info(f"Published organic thought to: {', '.join(published_platforms)}")

                    if telegram.is_configured():
                        telegram.send_message(
                            f"🌱 <b>Autonomous Organic Persona Post</b>\n\n"
                            f"<blockquote>{thought_text}</blockquote>\n\n"
                            f"📌 <b>Platforms:</b> {', '.join(published_platforms)}\n"
                            f"🏷️ <b>Topic:</b> #{thought_topic} <i>(Account warming / zero promo)</i>"
                        )
                else:
                    logger.info("Organic thought generated, but social platforms not connected or post failed.")
            else:
                logger.info(f"[DRY RUN] Would publish organic thought to X & Bluesky:\n{thought_text}")
                organic_summary = f"[DRY RUN] Organic thought generated: \"{thought_text[:60]}...\""
        else:
            logger.info(f"Organic posting cooldown active (minimum {ORGANIC_POST_MIN_INTERVAL_HOURS}h between posts).")

    # =========================================================================
    # Step 5: Final State Persistence & Notification Summary
    # =========================================================================
    state_mgr.save()

    if telegram.is_configured() and not dry_run:
        org_extra = f"\n• {organic_summary}" if organic_summary else ""
        if dispatched_count > 0:
            telegram.send_message(
                f"🎯 <b>ROCIs Marketing Engine Run Finished</b>\n\n"
                f"• Scanned candidate discussions across Reddit, Bluesky, Dev.to & HN.\n"
                f"• Sent <b>{dispatched_count}</b> new high-relevance draft cards above for your approval!\n"
                f"• Tap <b>[Approve & Post]</b> or <b>[Skip]</b> to process them.{org_extra}"
            )
        else:
            telegram.send_message(
                f"🤖 <b>ROCIs Marketing Engine Scan Report</b>\n\n"
                f"• Scanned <b>{total_candidates}</b> active candidate discussions.\n"
                f"• 0 discussions met the <b>>={MIN_RELEVANCE_SCORE}%</b> relevance threshold for an authentic indie plug this run.{org_extra}\n"
                f"• Next automated scan will run in 6 hours (or upon manual trigger)."
            )

    logger.info("Pipeline run completed successfully.")

def main():
    parser = argparse.ArgumentParser(description="ROCIs Tasks Marketing & Feedback Bot")
    parser.add_argument("--dry-run", action="store_true", help="Run without sending real messages or posting.")
    parser.add_argument("--analytics", action="store_true", help="Generate and send weekly analytics traction digest to Telegram.")
    parser.add_argument("--launch-kit", action="store_true", help="Generate Show HN and Product Hunt launch packages to Telegram.")
    parser.add_argument("--version-tag", type=str, default="1.0", help="Version string for launch kit (default: 1.0).")
    parser.add_argument("--refresh-queries", action="store_true", help="Force regenerate dynamic community search queries via Gemini.")
    args = parser.parse_args()

    state_mgr = StateManager(STATE_FILE_PATH)
    telegram = TelegramBot()

    if args.analytics:
        logger.info("Executing Weekly Analytics Digest...")
        tracker = AnalyticsTracker(state_mgr, telegram)
        success = tracker.generate_and_send_digest()
        logger.info(f"Analytics digest dispatch result: {success}")
        return

    if args.launch_kit:
        logger.info(f"Generating Launch Kit for v{args.version_tag}...")
        generator = LaunchKitGenerator(state_mgr, telegram)
        success = generator.dispatch_to_telegram(version=args.version_tag)
        logger.info(f"Launch kit dispatch result: {success}")
        return

    if args.refresh_queries:
        logger.info("Force refreshing dynamic discovery queries...")
        tuner = QueryTuner(state_mgr)
        queries = tuner.get_active_queries(force_refresh=True)
        logger.info(f"Active search queries: {queries}")
        return

    is_dry = args.dry_run or DRY_RUN
    run_pipeline(dry_run=is_dry)

if __name__ == "__main__":
    main()


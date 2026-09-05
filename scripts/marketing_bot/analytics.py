import logging
from datetime import datetime, timezone
from typing import Dict, Any, Optional, List

from .state_manager import StateManager
from .telegram_bot import TelegramBot
from .devto_client import DevtoClient
from .hashnode_client import HashnodeClient
from .bluesky_client import BlueskyClient
from .mastodon_client import MastodonClient

logger = logging.getLogger(__name__)

class AnalyticsTracker:
    """
    Collects cross-platform engagement metrics (Dev.to, Hashnode, Bluesky, Mastodon)
    and delivers a consolidated Traction Digest to Telegram.
    """
    def __init__(
        self,
        state_manager: StateManager,
        telegram_bot: TelegramBot,
        devto_client: Optional[DevtoClient] = None,
        hashnode_client: Optional[HashnodeClient] = None,
        bluesky_client: Optional[BlueskyClient] = None,
        mastodon_client: Optional[MastodonClient] = None
    ):
        self.state_manager = state_manager
        self.telegram = telegram_bot
        self.devto = devto_client or DevtoClient()
        self.hashnode = hashnode_client or HashnodeClient()
        self.bluesky = bluesky_client or BlueskyClient()
        self.mastodon = mastodon_client or MastodonClient()

    def collect_metrics(self) -> Dict[str, Any]:
        """Queries platform APIs and local state to gather current performance metrics."""
        metrics: Dict[str, Any] = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "devto": {"total_views": 0, "total_reactions": 0, "total_comments": 0, "top_article": None},
            "hashnode": {"total_views": 0, "total_reactions": 0, "total_posts": 0},
            "bluesky": {"followers": 0, "posts": 0},
            "mastodon": {"followers": 0, "statuses": 0},
            "app_stats": {
                "total_devlogs_published": len(self.state_manager.data.get("posted_devlogs", {})),
                "total_community_replies": len(self.state_manager.data.get("posted_threads", {}))
            }
        }

        # 1. Dev.to Stats
        if self.devto.is_configured():
            devto_arts = self.devto.get_analytics()
            if devto_arts:
                total_views = sum(a.get("page_views_count", 0) for a in devto_arts)
                total_reactions = sum(a.get("positive_reactions_count", 0) for a in devto_arts)
                total_comments = sum(a.get("comments_count", 0) for a in devto_arts)
                top_art = max(devto_arts, key=lambda x: x.get("page_views_count", 0), default=None)
                metrics["devto"] = {
                    "total_views": total_views,
                    "total_reactions": total_reactions,
                    "total_comments": total_comments,
                    "top_article": top_art
                }

        # 2. Hashnode Stats
        if self.hashnode.is_configured():
            hashnode_data = self.hashnode.get_publication_stats()
            if hashnode_data:
                metrics["hashnode"] = {
                    "total_views": hashnode_data.get("total_views", 0),
                    "total_reactions": hashnode_data.get("total_reactions", 0),
                    "total_posts": hashnode_data.get("total_posts", 0)
                }

        # 3. Bluesky Stats
        if self.bluesky.is_configured():
            bsky_data = self.bluesky.get_profile_stats()
            if bsky_data:
                metrics["bluesky"] = {
                    "followers": bsky_data.get("followers_count", 0),
                    "posts": bsky_data.get("posts_count", 0)
                }

        # 4. Mastodon Stats
        if self.mastodon.is_configured():
            m_data = self.mastodon.get_profile_stats()
            if m_data:
                metrics["mastodon"] = {
                    "followers": m_data.get("followers_count", 0),
                    "statuses": m_data.get("statuses_count", 0)
                }

        return metrics

    def generate_and_send_digest(self) -> bool:
        """
        Compiles metrics, computes growth deltas from previous snapshot,
        records new snapshot, and dispatches Telegram traction card.
        """
        metrics = self.collect_metrics()
        prev_snapshot = self.state_manager.data.get("analytics_snapshot", {})

        prev_views = prev_snapshot.get("devto", {}).get("total_views", 0)
        curr_views = metrics["devto"]["total_views"]
        delta_views = curr_views - prev_views
        delta_str = f" (+{delta_views})" if delta_views > 0 else ""

        top_art = metrics["devto"].get("top_article")
        top_art_line = ""
        if top_art and top_art.get("url"):
            top_art_line = f"• 🏆 <b>Top Post:</b> <a href=\"{top_art['url']}\">{top_art['title'][:40]}</a> ({top_art['page_views_count']} reads)\n"

        digest_text = (
            f"📈 <b>ROCIs Tasks Weekly Traction Digest</b>\n\n"
            f"📝 <b>Technical Articles & DevLogs:</b>\n"
            f"• <b>Dev.to Total Reads:</b> {curr_views:,}{delta_str}\n"
            f"• <b>Dev.to Reactions:</b> {metrics['devto']['total_reactions']}\n"
            f"• <b>Dev.to Comments:</b> {metrics['devto']['total_comments']}\n"
            f"{top_art_line}"
            f"• <b>Hashnode Reads:</b> {metrics['hashnode']['total_views']:,}\n\n"
            f"🌐 <b>Social Channels:</b>\n"
            f"• <b>Bluesky:</b> {metrics['bluesky']['followers']} followers | {metrics['bluesky']['posts']} posts\n"
            f"• <b>Mastodon:</b> {metrics['mastodon']['followers']} followers | {metrics['mastodon']['statuses']} posts\n\n"
            f"🚀 <b>App Distribution Engine:</b>\n"
            f"• <b>Total Milestones Shipped:</b> {metrics['app_stats']['total_devlogs_published']}\n"
            f"• <b>Community Threads Engaged:</b> {metrics['app_stats']['total_community_replies']}\n\n"
            f"<i>Powered by ROCIs Tasks Marketing Engine</i>"
        )

        # Update snapshot in state manager
        self.state_manager.data["analytics_snapshot"] = metrics
        self.state_manager.save()

        sent = self.telegram.send_message(digest_text)
        return bool(sent)


import logging
import time
from typing import List, Dict, Any
import requests

from .config import (
    REDDIT_SUBREDDITS,
    DISCOVERY_SEARCH_QUERIES,
    MAX_POST_AGE_HOURS,
    REDDIT_CLIENT_ID,
    REDDIT_CLIENT_SECRET,
    REDDIT_USER_AGENT
)
from .state_manager import StateManager

logger = logging.getLogger(__name__)

class DiscoveryEngine:
    def __init__(self, state_manager: StateManager):
        self.state_manager = state_manager
        self.now_ts = time.time()
        self.min_created_ts = self.now_ts - (MAX_POST_AGE_HOURS * 3600)
        self._praw_reddit = None

    def _get_praw_reddit(self):
        if self._praw_reddit is not None:
            return self._praw_reddit
        if REDDIT_CLIENT_ID and REDDIT_CLIENT_SECRET:
            try:
                import praw
                self._praw_reddit = praw.Reddit(
                    client_id=REDDIT_CLIENT_ID,
                    client_secret=REDDIT_CLIENT_SECRET,
                    user_agent=REDDIT_USER_AGENT
                )
                logger.info("Initialized PRAW Reddit search client with OAuth.")
            except Exception as e:
                logger.warning(f"Could not initialize PRAW: {e}")
        return self._praw_reddit

    def discover_opportunities(self, max_results: int = 5) -> List[Dict[str, Any]]:
        """
        Discovers active, fresh, and relevant threads across Reddit, Hacker News, and developer communities.
        """
        candidates: List[Dict[str, Any]] = []

        # 1. Search Reddit (via PRAW if credentials configured)
        praw_reddit = self._get_praw_reddit()
        if praw_reddit:
            for sub_name in REDDIT_SUBREDDITS[:4]:
                for query in DISCOVERY_SEARCH_QUERIES[:2]:
                    if len(candidates) >= max_results * 2:
                        break
                    try:
                        sub = praw_reddit.subreddit(sub_name)
                        for post in sub.search(query, sort="new", time_filter="week", limit=5):
                            post_id = f"reddit_{post.id}"
                            if post.created_utc >= self.min_created_ts:
                                candidates.append({
                                    "id": post_id,
                                    "platform": "reddit",
                                    "subreddit": sub_name,
                                    "title": post.title,
                                    "body": post.selftext or "",
                                    "author": str(post.author),
                                    "url": f"https://reddit.com{post.permalink}",
                                    "created_utc": post.created_utc
                                })
                        time.sleep(0.5)
                    except Exception as e:
                        logger.error(f"Error searching Reddit r/{sub_name} for '{query}': {e}")
        else:
            logger.info("Reddit API credentials not set. Reddit search will activate once REDDIT_CLIENT_ID is configured.")

        # 2. Search Hacker News (Open Algolia API)
        for query in DISCOVERY_SEARCH_QUERIES[:3]:
            if len(candidates) >= max_results * 3:
                break
            try:
                hn_threads = self._search_hackernews(query)
                candidates.extend(hn_threads)
                time.sleep(0.5)
            except Exception as e:
                logger.error(f"Error searching Hacker News for '{query}': {e}")

        # 3. Search Dev.to Articles & Discussions (Open Public API)
        try:
            devto_threads = self._search_devto()
            candidates.extend(devto_threads)
        except Exception as e:
            logger.error(f"Error searching Dev.to: {e}")

        # Filter out already inspected or too old
        fresh_unseen = []
        for item in candidates:
            item_id = item["id"]
            if self.state_manager.is_thread_inspected(item_id):
                continue
            if item.get("created_utc", 0) < self.min_created_ts:
                continue
            fresh_unseen.append(item)
            if len(fresh_unseen) >= max_results:
                break

        logger.info(f"Discovered {len(fresh_unseen)} fresh unseen candidate threads.")
        return fresh_unseen

    def _search_hackernews(self, query: str) -> List[Dict[str, Any]]:
        url = "https://hn.algolia.com/api/v1/search_by_date"
        params = {
            "query": query,
            "tags": "story",
            "numericFilters": f"created_at_i>{int(self.min_created_ts)}",
            "hitsPerPage": 10
        }
        results = []
        res = requests.get(url, params=params, timeout=10)
        res.raise_for_status()

        hits = res.json().get("hits", [])
        for hit in hits:
            hn_id = hit.get("objectID")
            post_id = f"hn_{hn_id}"
            title = hit.get("title", "")
            story_text = hit.get("story_text") or ""
            author = hit.get("author", "")
            created_utc = hit.get("created_at_i", 0)

            results.append({
                "id": post_id,
                "platform": "hackernews",
                "title": title,
                "body": story_text,
                "author": author,
                "url": f"https://news.ycombinator.com/item?id={hn_id}",
                "created_utc": created_utc
            })
        return results

    def _search_devto(self) -> List[Dict[str, Any]]:
        """Queries Dev.to for productivity and Android discussions."""
        url = "https://dev.to/api/articles"
        params = {"tag": "productivity", "per_page": 10}
        results = []
        res = requests.get(url, params=params, headers={"User-Agent": "ROCIsTasksMarketing/1.0"}, timeout=10)
        if res.status_code != 200:
            return []

        articles = res.json()
        for art in articles:
            art_id = f"devto_{art.get('id')}"
            title = art.get("title", "")
            desc = art.get("description", "")
            url = art.get("url", "")
            user = art.get("user", {}).get("username", "")

            results.append({
                "id": art_id,
                "platform": "devto",
                "title": title,
                "body": desc,
                "author": user,
                "url": url,
                "created_utc": self.now_ts
            })
        return results


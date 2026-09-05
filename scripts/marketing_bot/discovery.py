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
    REDDIT_USER_AGENT,
    REDDIT_SESSION_COOKIE,
    REDDIT_USERNAME,
    BSKY_HANDLE
)
from .state_manager import StateManager
from .bluesky_client import BlueskyClient
from .query_tuner import QueryTuner

logger = logging.getLogger(__name__)

class DiscoveryEngine:
    def __init__(self, state_manager: StateManager):
        self.state_manager = state_manager
        self.query_tuner = QueryTuner(state_manager)
        self.now_ts = time.time()
        self.min_created_ts = self.now_ts - (MAX_POST_AGE_HOURS * 3600)
        self.bsky = BlueskyClient()
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

    def discover_opportunities(self, max_results: int = 6) -> List[Dict[str, Any]]:
        """
        Discovers active, fresh, and relevant threads across Reddit, Bluesky, Hacker News, and Dev.to.
        """
        candidates: List[Dict[str, Any]] = []
        active_queries = self.query_tuner.get_active_queries()

        # 1. Search Reddit (via PRAW if configured, otherwise headless Playwright)
        praw_reddit = self._get_praw_reddit()
        if praw_reddit:
            for sub_name in REDDIT_SUBREDDITS[:4]:
                for query in active_queries[:3]:
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
            logger.info("PRAW OAuth not configured. Discovering Reddit threads via Playwright browser...")
            reddit_posts = self._discover_reddit_playwright(REDDIT_SUBREDDITS[:4], max_per_sub=4)
            candidates.extend(reddit_posts)

        # 2. Search Bluesky (if configured)
        if self.bsky.is_configured():
            for query in active_queries[:3]:
                try:
                    bsky_posts = self.bsky.search_posts(query, limit=5)
                    candidates.extend(bsky_posts)
                except Exception as e:
                    logger.error(f"Error searching Bluesky: {e}")

        # 3. Search Hacker News (Open Algolia API)
        for query in ["Show HN todo", "Ask HN todo app", "indie app"]:
            if len(candidates) >= max_results * 3:
                break
            try:
                hn_threads = self._search_hackernews(query)
                candidates.extend(hn_threads)
                time.sleep(0.5)
            except Exception as e:
                logger.error(f"Error searching Hacker News for '{query}': {e}")

        # Note: Dev.to is exclusively for publishing our own long-form DevLogs.
        # We do NOT search Dev.to for commenting opportunities to prevent piggybacking loops.

        # Deduplicate and filter out inspected, stale, or self-authored items
        fresh_unseen = []
        for item in candidates:
            item_id = item["id"]
            if self._is_own_content(item):
                logger.info(f"Skipping own content: {item.get('title', item_id)} ({item.get('url')})")
                continue
            if self.state_manager.is_thread_inspected(item_id):
                continue
            if item.get("created_utc", 0) < self.min_created_ts:
                continue
            fresh_unseen.append(item)
            if len(fresh_unseen) >= max_results:
                break

        logger.info(f"Discovered {len(fresh_unseen)} fresh unseen candidate threads.")
        return fresh_unseen

    def _is_own_content(self, item: Dict[str, Any]) -> bool:
        """Checks if a candidate post is authored by ourselves to prevent self-promotional feedback loops."""
        author = (item.get("author") or "").lower().strip()
        url = (item.get("url") or "").lower().strip()
        title = (item.get("title") or "").lower().strip()

        own_handles = {
            "rocisapps", "rocis_apps", "roeeilouz", "roee_ilouz",
            (BSKY_HANDLE or "").lower().strip(),
            (REDDIT_USERNAME or "").lower().strip()
        }
        own_handles.discard("")

        if author in own_handles:
            return True
        if any(h in url for h in ["rocisapps", "roeeilouz", "rocis_apps"]):
            return True
        if "rocis tasks" in title or "rocis_tasks" in title:
            return True
        return False

    def _search_hackernews(self, query: str) -> List[Dict[str, Any]]:
        url = "https://hn.algolia.com/api/v1/search_by_date"
        params = {
            "query": query,
            "tags": "story",
            "numericFilters": f"created_at_i>{int(self.min_created_ts)}",
            "hitsPerPage": 8
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

    def _search_devto(self, tag: str) -> List[Dict[str, Any]]:
        url = "https://dev.to/api/articles"
        params = {"tag": tag, "per_page": 6}
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

    def _discover_reddit_playwright(self, subreddits: List[str], max_per_sub: int = 4) -> List[Dict[str, Any]]:
        """
        Discovers recent posts from target subreddits using headless Playwright.
        Bypasses Reddit API restrictions without requiring OAuth application credentials.
        """
        results: List[Dict[str, Any]] = []
        try:
            from playwright.sync_api import sync_playwright
            with sync_playwright() as p:
                browser = p.chromium.launch(
                    headless=True,
                    args=[
                        "--no-sandbox",
                        "--disable-setuid-sandbox",
                        "--disable-dev-shm-usage",
                        "--disable-blink-features=AutomationControlled"
                    ]
                )
                context = browser.new_context(
                    user_agent=(
                        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                        "AppleWebKit/537.36 (KHTML, like Gecko) "
                        "Chrome/124.0.0.0 Safari/537.36"
                    ),
                    viewport={"width": 1280, "height": 800}
                )

                if REDDIT_SESSION_COOKIE and len(REDDIT_SESSION_COOKIE.strip()) > 10:
                    clean_cookie = REDDIT_SESSION_COOKIE.strip()
                    if clean_cookie.startswith("reddit_session="):
                        clean_cookie = clean_cookie.replace("reddit_session=", "", 1).strip()
                    if ";" in clean_cookie:
                        clean_cookie = clean_cookie.split(";", 1)[0].strip()
                    context.add_cookies([{
                        "name": "reddit_session",
                        "value": clean_cookie,
                        "domain": ".reddit.com",
                        "path": "/",
                        "httpOnly": True,
                        "secure": True
                    }])

                page = context.new_page()
                for sub in subreddits:
                    try:
                        url = f"https://www.reddit.com/r/{sub}/new/"
                        page.goto(url, timeout=25000, wait_until="domcontentloaded")
                        time.sleep(2.5)
                        posts = page.query_selector_all("shreddit-post")
                        for post in posts[:max_per_sub]:
                            post_id = post.get_attribute("id") or ""
                            title = post.get_attribute("post-title") or ""
                            permalink = post.get_attribute("permalink") or ""
                            author = post.get_attribute("author") or ""
                            clean_id = post_id.replace("t3_", "")

                            if clean_id and title and permalink:
                                full_url = f"https://reddit.com{permalink}" if not permalink.startswith("http") else permalink
                                results.append({
                                    "id": f"reddit_{clean_id}",
                                    "platform": "reddit",
                                    "subreddit": sub,
                                    "title": title,
                                    "body": "",
                                    "author": author,
                                    "url": full_url,
                                    "created_utc": self.now_ts
                                })
                    except Exception as sub_err:
                        logger.warning(f"Playwright error scanning r/{sub}: {sub_err}")
                browser.close()
        except Exception as e:
            logger.error(f"Playwright Reddit discovery failed: {e}")

        logger.info(f"Playwright Reddit discovery found {len(results)} posts.")
        return results


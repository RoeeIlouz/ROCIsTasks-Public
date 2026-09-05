import logging
from typing import Optional, Dict, Any, List
import requests

from .config import DEVTO_API_KEY, APP_INFO

logger = logging.getLogger(__name__)

class DevtoClient:
    """
    Handles Dev.to community interactions:
    - Publishing long-form dev log articles (tutorials, architecture deep-dives, indie updates).
    - Posting thoughtful comments to relevant articles.
    """
    def __init__(self, api_key: Optional[str] = None):
        self.api_key = api_key or DEVTO_API_KEY
        self.base_url = "https://dev.to/api"

    def is_configured(self) -> bool:
        return bool(self.api_key and len(self.api_key.strip()) > 5)

    def _headers(self) -> Dict[str, str]:
        return {
            "api-key": self.api_key,
            "Content-Type": "application/json",
            "User-Agent": "ROCIsTasksMarketingBot/1.0"
        }

    def post_comment(self, article_id: str, body_markdown: str) -> Optional[str]:
        """Posts a comment to an existing Dev.to article."""
        if not self.is_configured():
            logger.info("DEVTO_API_KEY not configured. Skipping Dev.to comment.")
            return None

        clean_id = str(article_id).replace("devto_", "")
        url = f"{self.base_url}/comments"
        try:
            res = requests.post(
                url,
                headers=self._headers(),
                json={
                    "comment_id": None,
                    "commentable_id": clean_id,
                    "commentable_type": "Article",
                    "body_markdown": body_markdown
                },
                timeout=15
            )
            if res.status_code in (200, 201):
                logger.info(f"Successfully posted comment on Dev.to article {clean_id}")
                return f"https://dev.to/comments/{clean_id}"
            else:
                logger.error(f"Dev.to comment error ({res.status_code}): {res.text[:200]}")
                return None
        except Exception as e:
            logger.error(f"Network error posting Dev.to comment: {e}")
            return None

    def publish_article(
        self,
        title: str,
        body_markdown: str,
        tags: Optional[List[str]] = None,
        published: bool = True,
        series: Optional[str] = None,
        main_image: Optional[str] = None
    ) -> Optional[Dict[str, Any]]:
        """
        Publishes a new article or devlog on Dev.to.
        If published=False, it creates a draft on your dashboard.
        """
        if not self.is_configured():
            logger.warning("DEVTO_API_KEY not configured. Cannot publish Dev.to article.")
            return None

        url = f"{self.base_url}/articles"
        cleaned_tags = [t.lower().replace("#", "").strip() for t in (tags or ["flutter", "android", "productivity", "showdev"])][:4]

        payload = {
            "article": {
                "title": title,
                "body_markdown": body_markdown,
                "published": published,
                "tags": cleaned_tags
            }
        }
        if series:
            payload["article"]["series"] = series
        if main_image:
            payload["article"]["main_image"] = main_image

        try:
            res = requests.post(url, headers=self._headers(), json=payload, timeout=20)
            if res.status_code in (200, 201):
                data = res.json()
                article_url = data.get("url")
                article_id = data.get("id")
                logger.info(f"Successfully created Dev.to article #{article_id}: {article_url}")
                return {
                    "id": article_id,
                    "url": article_url,
                    "title": title,
                    "published": published
                }
            else:
                logger.error(f"Dev.to article creation error ({res.status_code}): {res.text[:250]}")
                return None
        except Exception as e:
            logger.error(f"Network error publishing Dev.to article: {e}")
            return None

    def get_analytics(self) -> Optional[List[Dict[str, Any]]]:
        """Fetches all published and draft articles with view and reaction stats."""
        if not self.is_configured():
            return None

        url = f"{self.base_url}/articles/me/all"
        try:
            res = requests.get(url, headers=self._headers(), timeout=20)
            res.raise_for_status()
            articles = res.json()
            results = []
            for art in articles:
                results.append({
                    "id": art.get("id"),
                    "title": art.get("title"),
                    "url": art.get("url"),
                    "page_views_count": art.get("page_views_count", 0),
                    "positive_reactions_count": art.get("positive_reactions_count", 0),
                    "comments_count": art.get("comments_count", 0),
                    "published": art.get("published", False)
                })
            return results
        except Exception as e:
            logger.error(f"Failed to fetch Dev.to analytics: {e}")
            return None

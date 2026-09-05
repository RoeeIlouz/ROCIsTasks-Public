import logging
from typing import Optional, Dict, Any, List
import requests

from .config import MEDIUM_INTEGRATION_TOKEN

logger = logging.getLogger(__name__)

MEDIUM_API_BASE = "https://api.medium.com/v1"

class MediumClient:
    """
    Medium REST API Client.
    Publishes long-form engineering articles with canonical SEO links to Medium.
    """
    def __init__(self, integration_token: Optional[str] = None):
        self.token = integration_token or MEDIUM_INTEGRATION_TOKEN
        self._user_id: Optional[str] = None

    def is_configured(self) -> bool:
        return bool(self.token and len(self.token.strip()) > 10)

    def _get_user_id(self) -> Optional[str]:
        if self._user_id:
            return self._user_id
        if not self.is_configured():
            return None

        url = f"{MEDIUM_API_BASE}/me"
        headers = {
            "Authorization": f"Bearer {self.token.strip()}",
            "Accept": "application/json"
        }
        try:
            res = requests.get(url, headers=headers, timeout=15)
            res.raise_for_status()
            data = res.json().get("data", {})
            self._user_id = data.get("id")
            return self._user_id
        except Exception as e:
            logger.error(f"Failed to fetch Medium user profile: {e}")
            return None

    def publish_article(
        self,
        title: str,
        body_markdown: str,
        tags: Optional[List[str]] = None,
        canonical_url: Optional[str] = None,
        publish_status: str = "public"
    ) -> Optional[Dict[str, Any]]:
        """
        Publishes a markdown article to Medium.
        Injects canonicalUrl to ensure SEO authority remains with the original article.
        """
        if not self.is_configured():
            logger.warning("MediumClient not configured. Skipping publication.")
            return None

        user_id = self._get_user_id()
        if not user_id:
            logger.error("Could not determine Medium user ID. Skipping publication.")
            return None

        clean_tags = tags or ["flutter", "android", "indiedev", "programming"]
        url = f"{MEDIUM_API_BASE}/users/{user_id}/posts"
        headers = {
            "Authorization": f"Bearer {self.token.strip()}",
            "Content-Type": "application/json",
            "Accept": "application/json"
        }
        payload: Dict[str, Any] = {
            "title": title,
            "contentFormat": "markdown",
            "content": f"# {title}\n\n{body_markdown}",
            "tags": [t.replace("-", " ") for t in clean_tags[:5]],
            "publishStatus": publish_status
        }
        if canonical_url:
            payload["canonicalUrl"] = canonical_url

        try:
            res = requests.post(url, headers=headers, json=payload, timeout=25)
            if res.status_code not in (200, 201):
                logger.error(f"Medium API error ({res.status_code}): {res.text}")
            res.raise_for_status()
            post_data = res.json().get("data", {})
            post_url = post_data.get("url")
            logger.info(f"Successfully published to Medium: {post_url}")
            return {
                "id": post_data.get("id"),
                "url": post_url
            }
        except Exception as e:
            logger.error(f"Failed to publish to Medium: {e}")
            return None

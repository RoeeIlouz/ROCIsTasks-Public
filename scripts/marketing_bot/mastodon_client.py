import logging
from typing import Optional, Dict, Any
import requests

from .config import MASTODON_INSTANCE, MASTODON_ACCESS_TOKEN

logger = logging.getLogger(__name__)

class MastodonClient:
    """
    Mastodon / Fediverse API Client.
    Supports publishing public updates up to 500 characters.
    """
    def __init__(self, instance_url: Optional[str] = None, access_token: Optional[str] = None):
        self.instance_url = (instance_url or MASTODON_INSTANCE or "https://mastodon.social").rstrip("/")
        self.access_token = access_token or MASTODON_ACCESS_TOKEN

    def is_configured(self) -> bool:
        return bool(self.access_token and len(self.access_token.strip()) > 10)

    def upload_media(
        self,
        image_bytes: bytes,
        mime_type: str = "image/png",
        description: Optional[str] = None
    ) -> Optional[str]:
        """
        Uploads an image to Mastodon via /api/v2/media.
        Returns the media_id if successful, or None on failure.
        """
        if not self.is_configured():
            return None

        url = f"{self.instance_url}/api/v2/media"
        headers = {
            "Authorization": f"Bearer {self.access_token}",
            "User-Agent": "ROCIsTasksMarketing/1.0"
        }
        files = {
            "file": ("image.png", image_bytes, mime_type)
        }
        data = {}
        if description:
            data["description"] = description[:420]

        try:
            res = requests.post(url, headers=headers, files=files, data=data, timeout=30)
            res.raise_for_status()
            media_id = res.json().get("id")
            logger.info(f"Uploaded media to Mastodon successfully: ID={media_id}")
            return media_id
        except Exception as e:
            logger.error(f"Failed to upload media to Mastodon: {e}")
            return None

    def post_status(
        self,
        text: str,
        visibility: str = "public",
        media_ids: Optional[list] = None
    ) -> Optional[str]:
        """
        Publishes a status update to the configured Mastodon instance.
        Optionally attaches uploaded media_ids.
        Returns the web URL of the status if successful, or None on failure.
        """
        if not self.is_configured():
            logger.warning("MastodonClient not configured. Skipping post.")
            return None

        clean_text = text.strip()
        if len(clean_text) > 500:
            logger.warning(f"Mastodon status exceeds 500 chars ({len(clean_text)}). Truncating...")
            clean_text = clean_text[:497] + "..."

        url = f"{self.instance_url}/api/v1/statuses"
        headers = {
            "Authorization": f"Bearer {self.access_token}",
            "User-Agent": "ROCIsTasksMarketing/1.0"
        }
        payload = {
            "status": clean_text,
            "visibility": visibility
        }
        if media_ids:
            payload["media_ids"] = media_ids

        try:
            res = requests.post(url, headers=headers, json=payload, timeout=15)
            if res.status_code not in (200, 201):
                logger.error(f"Mastodon API error ({res.status_code}): {res.text}")
            res.raise_for_status()
            data = res.json()
            status_url = data.get("url")
            logger.info(f"Successfully posted to Mastodon: {status_url}")
            return status_url
        except Exception as e:
            logger.error(f"Failed to post to Mastodon: {e}")
            return None

    def get_profile_stats(self) -> Optional[Dict[str, Any]]:
        """Fetches account follower and status counts."""
        if not self.is_configured():
            return None

        url = f"{self.instance_url}/api/v1/accounts/verify_credentials"
        headers = {
            "Authorization": f"Bearer {self.access_token}",
            "User-Agent": "ROCIsTasksMarketing/1.0"
        }
        try:
            res = requests.get(url, headers=headers, timeout=15)
            res.raise_for_status()
            data = res.json()
            return {
                "followers_count": data.get("followers_count", 0),
                "following_count": data.get("following_count", 0),
                "statuses_count": data.get("statuses_count", 0)
            }
        except Exception as e:
            logger.error(f"Failed to fetch Mastodon profile stats: {e}")
            return None

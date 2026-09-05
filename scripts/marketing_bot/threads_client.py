import logging
import time
from typing import Optional
import requests

from .config import THREADS_USER_ID, THREADS_ACCESS_TOKEN

logger = logging.getLogger(__name__)

THREADS_API_BASE = "https://graph.threads.net/v1.0"

class ThreadsClient:
    """
    Meta Threads API Client.
    Publishes text threads (up to 500 characters) via the official Meta Threads Graph API.
    """
    def __init__(self, user_id: Optional[str] = None, access_token: Optional[str] = None):
        self.user_id = user_id or THREADS_USER_ID
        self.access_token = access_token or THREADS_ACCESS_TOKEN

    def is_configured(self) -> bool:
        return bool(
            self.user_id and len(self.user_id.strip()) > 2 and
            self.access_token and len(self.access_token.strip()) > 10
        )

    def post_thread(self, text: str, image_url: Optional[str] = None) -> Optional[str]:
        """
        Publishes a post on Meta Threads using the 2-step container creation & publishing workflow.
        Supports both text posts and image attachments via public image URLs.
        Returns the thread URL or ID if successful, or None on failure.
        """
        if not self.is_configured():
            logger.warning("ThreadsClient not configured. Skipping post.")
            return None

        clean_text = text.strip()
        if len(clean_text) > 500:
            logger.warning(f"Threads post exceeds 500 chars ({len(clean_text)}). Truncating to 497...")
            clean_text = clean_text[:497] + "..."

        try:
            # Step 1: Create the media container
            create_url = f"{THREADS_API_BASE}/{self.user_id}/threads"
            payload = {
                "access_token": self.access_token,
                "text": clean_text
            }
            if image_url:
                payload["media_type"] = "IMAGE"
                payload["image_url"] = image_url
            else:
                payload["media_type"] = "TEXT"

            res = requests.post(create_url, data=payload, timeout=20)
            if res.status_code not in (200, 201):
                logger.error(f"Threads container creation failed ({res.status_code}): {res.text}")
            res.raise_for_status()
            creation_id = res.json().get("id")
            if not creation_id:
                logger.error("No creation_id returned from Threads API.")
                return None

            # Short wait for container processing
            time.sleep(1.5)

            # Step 2: Publish the media container
            publish_url = f"{THREADS_API_BASE}/{self.user_id}/threads_publish"
            publish_payload = {
                "creation_id": creation_id,
                "access_token": self.access_token
            }
            pub_res = requests.post(publish_url, data=publish_payload, timeout=20)
            if pub_res.status_code not in (200, 201):
                logger.error(f"Threads publishing failed ({pub_res.status_code}): {pub_res.text}")
            pub_res.raise_for_status()

            post_id = pub_res.json().get("id")
            thread_url = f"https://www.threads.net/post/{post_id}" if post_id else None
            logger.info(f"Successfully published to Meta Threads: {thread_url or post_id}")
            return thread_url or str(post_id)

        except Exception as e:
            logger.error(f"Failed to publish to Meta Threads: {e}")
            return None

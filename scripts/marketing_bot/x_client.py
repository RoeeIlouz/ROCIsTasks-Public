import logging
from typing import Optional, Dict, Any
import requests

from .config import (
    X_API_KEY,
    X_API_SECRET,
    X_ACCESS_TOKEN,
    X_ACCESS_SECRET
)

logger = logging.getLogger(__name__)

class XClient:
    def __init__(self):
        self.api_key = X_API_KEY
        self.api_secret = X_API_SECRET
        self.access_token = X_ACCESS_TOKEN
        self.access_secret = X_ACCESS_SECRET

    def is_configured(self) -> bool:
        return bool(self.api_key and self.api_secret and self.access_token and self.access_secret)

    def post_tweet(self, text: str, in_reply_to_tweet_id: Optional[str] = None) -> Optional[str]:
        """Publishes a tweet or reply using Twitter API v2."""
        if not self.is_configured():
            logger.info("X/Twitter API credentials not set. Skipping X posting.")
            return None

        try:
            from requests_oauthlib import OAuth1
            auth = OAuth1(self.api_key, self.api_secret, self.access_token, self.access_secret)
        except ImportError:
            logger.warning("requests_oauthlib not installed for X API. Install via pip install requests-oauthlib.")
            return None

        url = "https://api.twitter.com/2/tweets"
        payload: Dict[str, Any] = {"text": text}
        if in_reply_to_tweet_id:
            payload["reply"] = {"in_reply_to_tweet_id": in_reply_to_tweet_id}

        try:
            res = requests.post(url, auth=auth, json=payload, timeout=15)
            res.raise_for_status()
            data = res.json().get("data", {})
            tweet_id = data.get("id")
            tweet_url = f"https://x.com/i/status/{tweet_id}"
            logger.info(f"Successfully posted to X: {tweet_url}")
            return tweet_url
        except Exception as e:
            logger.error(f"Failed to post to X: {e}")
            return None

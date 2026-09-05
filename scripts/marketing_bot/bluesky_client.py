import logging
import re
from datetime import datetime, timezone
from typing import Optional, Dict, Any, List
import requests

from .config import BSKY_HANDLE, BSKY_APP_PASSWORD

logger = logging.getLogger(__name__)

BSKY_AUTH_URL = "https://bsky.social/xrpc/com.atproto.server.createSession"
BSKY_SEARCH_URL = "https://bsky.social/xrpc/app.bsky.feed.searchPosts"
BSKY_CREATE_RECORD_URL = "https://bsky.social/xrpc/com.atproto.repo.createRecord"

class BlueskyClient:
    def __init__(self, handle: Optional[str] = None, app_password: Optional[str] = None):
        self.handle = handle or BSKY_HANDLE
        self.app_password = app_password or BSKY_APP_PASSWORD
        self.access_jwt: Optional[str] = None
        self.did: Optional[str] = None

    def is_configured(self) -> bool:
        return bool(self.handle and self.app_password and len(self.app_password.strip()) > 5)

    def _login(self) -> bool:
        if not self.is_configured():
            return False
        if self.access_jwt:
            return True

        try:
            payload = {
                "identifier": self.handle,
                "password": self.app_password
            }
            res = requests.post(BSKY_AUTH_URL, json=payload, timeout=15)
            res.raise_for_status()
            data = res.json()
            self.access_jwt = data.get("accessJwt")
            self.did = data.get("did")
            logger.info(f"Authenticated to Bluesky as @{self.handle} ({self.did})")
            return True
        except Exception as e:
            logger.error(f"Bluesky authentication failed: {e}")
            return False

    def search_posts(self, query: str, limit: int = 10) -> List[Dict[str, Any]]:
        """Searches Bluesky for active posts discussing indie apps, task managers, or widgets."""
        if not self._login():
            return []

        headers = {
            "Authorization": f"Bearer {self.access_jwt}",
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
        }
        params = {"q": query, "limit": limit}

        try:
            res = requests.get(BSKY_SEARCH_URL, headers=headers, params=params, timeout=15)
            if res.status_code != 200:
                logger.warning(f"Bluesky search returned status {res.status_code}: {res.text[:150]}")
                return []
            data = res.json()
            posts = data.get("posts", [])
            results = []

            for p in posts:
                uri = p.get("uri", "")
                cid = p.get("cid", "")
                author_handle = p.get("author", {}).get("handle", "")
                record = p.get("record", {})
                text = record.get("text", "")
                created_at = record.get("createdAt", "")

                # Bluesky web permalink format
                # at://did:plc:xyz/app.bsky.feed.post/123 -> https://bsky.app/profile/<handle>/post/<id>
                post_id = uri.split("/")[-1] if "/" in uri else cid
                web_url = f"https://bsky.app/profile/{author_handle}/post/{post_id}"

                results.append({
                    "id": f"bsky_{cid[:12]}",
                    "platform": "bluesky",
                    "title": text[:80] + ("..." if len(text) > 80 else ""),
                    "body": text,
                    "author": author_handle,
                    "url": web_url,
                    "uri": uri,
                    "cid": cid,
                    "created_utc": datetime.now(timezone.utc).timestamp()
                })
            return results
        except Exception as e:
            logger.error(f"Bluesky search error for query '{query}': {e}")
            return []

    @staticmethod
    def _extract_facets(text: str) -> List[Dict[str, Any]]:
        """Extracts ATProto link facets with UTF-8 byte offsets for clickable links."""
        facets = []
        for m in re.finditer(r'https?://[^\s()]+', text):
            raw_url = m.group(0)
            # Strip trailing punctuation that belongs to surrounding prose
            trailing = re.search(r'[.,!?:;\'"]+$', raw_url)
            trim_len = len(trailing.group(0)) if trailing else 0
            url = raw_url[:-trim_len] if trim_len > 0 else raw_url

            start_char = m.start()
            end_char = m.end() - trim_len

            byte_start = len(text[:start_char].encode("utf-8"))
            byte_end = len(text[:end_char].encode("utf-8"))
            facets.append({
                "index": {"byteStart": byte_start, "byteEnd": byte_end},
                "features": [{
                    "$type": "app.bsky.feed.post#link",
                    "uri": url
                }]
            })
        return facets

    def post_reply(self, text: str, reply_to_uri: Optional[str] = None, reply_to_cid: Optional[str] = None) -> Optional[str]:
        """Publishes a post or reply on Bluesky with strict length safety and link facets."""
        if not self._login():
            return None

        # Bluesky hard limit is 300 characters
        clean_text = text.strip()
        if len(clean_text) > 300:
            logger.warning(f"Bluesky post text exceeds 300 chars ({len(clean_text)}). Truncating to 297...")
            clean_text = clean_text[:297] + "..."

        headers = {
            "Authorization": f"Bearer {self.access_jwt}",
            "Content-Type": "application/json"
        }

        # Format ISO-8601 with trailing Z for strict ATProto schema compliance
        created_at_iso = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%f")[:-3] + "Z"

        record: Dict[str, Any] = {
            "$type": "app.bsky.feed.post",
            "text": clean_text,
            "createdAt": created_at_iso
        }

        facets = self._extract_facets(clean_text)
        if facets:
            record["facets"] = facets

        if reply_to_uri and reply_to_cid:
            record["reply"] = {
                "root": {"uri": reply_to_uri, "cid": reply_to_cid},
                "parent": {"uri": reply_to_uri, "cid": reply_to_cid}
            }

        payload = {
            "repo": self.did,
            "collection": "app.bsky.feed.post",
            "record": record
        }

        try:
            res = requests.post(BSKY_CREATE_RECORD_URL, headers=headers, json=payload, timeout=15)
            if res.status_code not in (200, 201):
                logger.error(f"Bluesky createRecord HTTP {res.status_code}: {res.text}")
            res.raise_for_status()
            data = res.json()
            post_uri = data.get("uri", "")
            post_id = post_uri.split("/")[-1] if "/" in post_uri else ""
            web_link = f"https://bsky.app/profile/{self.handle}/post/{post_id}"
            logger.info(f"Successfully posted to Bluesky: {web_link}")
            return web_link
        except Exception as e:
            logger.error(f"Failed to post record to Bluesky: {e}")
            return None

import logging
from typing import Optional, Dict, Any, List
import requests

from .config import HASHNODE_ACCESS_TOKEN, HASHNODE_PUBLICATION_ID

logger = logging.getLogger(__name__)

HASHNODE_GQL_URL = "https://gql.hashnode.com"

class HashnodeClient:
    """
    Hashnode API Client using the modern Hashnode GraphQL API.
    Publishes long-form engineering articles with canonical SEO links.
    """
    def __init__(
        self,
        access_token: Optional[str] = None,
        publication_id: Optional[str] = None
    ):
        self.access_token = access_token or HASHNODE_ACCESS_TOKEN
        self.publication_id = publication_id or HASHNODE_PUBLICATION_ID

    def is_configured(self) -> bool:
        return bool(self.access_token and len(self.access_token.strip()) > 10)

    def _get_publication_id(self) -> Optional[str]:
        """
        Auto-discovers the user's primary Hashnode publication ID via GraphQL
        if HASHNODE_PUBLICATION_ID was not explicitly provided.
        """
        if self.publication_id and len(self.publication_id.strip()) > 5:
            return self.publication_id.strip()

        if not self.access_token:
            return None

        query = """
        query {
          me {
            publications(first: 1) {
              edges {
                node {
                  id
                  title
                  url
                }
              }
            }
          }
        }
        """
        headers = {
            "Authorization": self.access_token.strip(),
            "Content-Type": "application/json",
            "User-Agent": "ROCIsTasksMarketing/1.0"
        }

        try:
            res = requests.post(HASHNODE_GQL_URL, headers=headers, json={"query": query}, timeout=15)
            res.raise_for_status()
            data = res.json()
            edges = data.get("data", {}).get("me", {}).get("publications", {}).get("edges", [])
            if edges:
                node = edges[0].get("node", {})
                pub_id = node.get("id")
                pub_title = node.get("title", "")
                if pub_id:
                    logger.info(f"Auto-discovered Hashnode publication ID: {pub_id} ('{pub_title}')")
                    self.publication_id = pub_id
                    return pub_id
            logger.warning("No Hashnode publications found for this access token.")
            return None
        except Exception as e:
            logger.error(f"Failed to auto-discover Hashnode publication ID: {e}")
            return None

    def publish_article(
        self,
        title: str,
        body_markdown: str,
        tags: Optional[List[str]] = None,
        canonical_url: Optional[str] = None,
        subtitle: Optional[str] = None
    ) -> Optional[Dict[str, Any]]:
        """
        Publishes an engineering article to Hashnode.
        Injects originalArticleURL for SEO canonicalization.
        """
        if not self.is_configured():
            logger.warning("HashnodeClient not configured. Skipping publication.")
            return None

        pub_id = self._get_publication_id()
        if not pub_id:
            logger.error("Could not determine Hashnode publication ID. Skipping publication.")
            return None

        clean_tags = tags or ["flutter", "android", "indiedev", "productivity"]
        tag_inputs = [{"slug": t.lower().replace(" ", "-"), "name": t} for t in clean_tags[:5]]

        mutation = """
        mutation PublishPost($input: PublishPostInput!) {
          publishPost(input: $input) {
            post {
              id
              title
              slug
              url
            }
          }
        }
        """

        post_input: Dict[str, Any] = {
            "title": title,
            "contentMarkdown": body_markdown,
            "publicationId": pub_id,
            "tags": tag_inputs
        }

        if canonical_url:
            post_input["originalArticleURL"] = canonical_url

        if subtitle:
            post_input["subtitle"] = subtitle

        headers = {
            "Authorization": self.access_token.strip(),
            "Content-Type": "application/json",
            "User-Agent": "ROCIsTasksMarketing/1.0"
        }

        try:
            res = requests.post(
                HASHNODE_GQL_URL,
                headers=headers,
                json={"query": mutation, "variables": {"input": post_input}},
                timeout=25
            )
            res.raise_for_status()
            data = res.json()

            if "errors" in data and data["errors"]:
                logger.error(f"Hashnode GraphQL error: {data['errors']}")
                return None

            post_data = data.get("data", {}).get("publishPost", {}).get("post", {})
            post_url = post_data.get("url")
            logger.info(f"Successfully published to Hashnode: {post_url}")
            return {
                "id": post_data.get("id"),
                "url": post_url,
                "slug": post_data.get("slug")
            }

        except Exception as e:
            logger.error(f"Failed to publish to Hashnode: {e}")
            return None

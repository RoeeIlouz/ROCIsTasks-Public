import logging
import time
from typing import Optional

from .config import REDDIT_SESSION_COOKIE

logger = logging.getLogger(__name__)

class RedditPlaywrightPoster:
    def __init__(self, session_cookie: Optional[str] = None):
        self.session_cookie = session_cookie or REDDIT_SESSION_COOKIE

    def is_available(self) -> bool:
        return bool(self.session_cookie and len(self.session_cookie.strip()) > 10)

    def post_comment(self, thread_url: str, comment_text: str) -> Optional[str]:
        """
        Submits a comment to a Reddit thread using headless Playwright with session cookies.
        Returns the comment URL if successful, or None if it fails.
        """
        if not self.is_available():
            logger.warning("REDDIT_SESSION_COOKIE not configured. Skipping Playwright submission.")
            return None

        try:
            from playwright.sync_api import sync_playwright
        except ImportError:
            logger.error("Playwright package is not installed. Install via pip install playwright.")
            return None

        logger.info(f"Launching Playwright to post on Reddit: {thread_url}")

        clean_cookie = self.session_cookie.strip()
        if clean_cookie.startswith("reddit_session="):
            clean_cookie = clean_cookie.replace("reddit_session=", "", 1).strip()
        if ";" in clean_cookie:
            clean_cookie = clean_cookie.split(";", 1)[0].strip()

        try:
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

                # Inject Reddit authentication cookie
                context.add_cookies([
                    {
                        "name": "reddit_session",
                        "value": clean_cookie,
                        "domain": ".reddit.com",
                        "path": "/",
                        "httpOnly": True,
                        "secure": True
                    }
                ])

                page = context.new_page()
                page.goto(thread_url, timeout=30000, wait_until="domcontentloaded")
                time.sleep(3.0)

                # Check if logged in or redirected to login
                if "login" in page.url:
                    logger.error("Reddit session cookie appears invalid or expired (redirected to login).")
                    browser.close()
                    return None

                # Locate the comment box (supports Modern Reddit & Shreddit)
                box_selectors = [
                    "shreddit-composer div[contenteditable='true']",
                    "div[data-testid='comment-creation-box'] div[contenteditable='true']",
                    "div[contenteditable='true'][role='textbox']",
                    "faceplate-form textarea",
                    "textarea[name='text']",
                    "div.public-DraftEditor-content"
                ]

                composer = None
                for sel in box_selectors:
                    elem = page.query_selector(sel)
                    if elem and elem.is_visible():
                        composer = elem
                        break

                if not composer:
                    # Try clicking "Add a comment" placeholder if collapsed
                    placeholder = page.query_selector("button:has-text('Add a comment'), shreddit-composer-button, div[data-testid='trigger-button']")
                    if placeholder and placeholder.is_visible():
                        placeholder.click()
                        time.sleep(1.5)
                        for sel in box_selectors:
                            elem = page.query_selector(sel)
                            if elem and elem.is_visible():
                                composer = elem
                                break

                if not composer:
                    logger.error("Could not locate Reddit comment composer on page.")
                    browser.close()
                    return None

                # Focus and type comment with natural typing simulation
                composer.click()
                time.sleep(0.5)
                composer.fill(comment_text)
                time.sleep(1.0)

                # Find and click Submit / Comment button
                submit_selectors = [
                    "button[slot='submit-button']",
                    "button:has-text('Comment')",
                    "button:has-text('Reply')",
                    "button[type='submit']"
                ]

                submitted = False
                for s_sel in submit_selectors:
                    btn = page.query_selector(s_sel)
                    if btn and btn.is_visible() and btn.is_enabled():
                        btn.click()
                        submitted = True
                        break

                if not submitted:
                    logger.error("Could not find enabled submit button on Reddit composer.")
                    browser.close()
                    return None

                time.sleep(4.0)
                logger.info("Comment submitted successfully via Playwright!")
                browser.close()
                return thread_url

        except Exception as e:
            logger.error(f"Playwright Reddit execution error: {e}")
            return None

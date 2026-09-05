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

    def submit_post(self, subreddit: str, title: str, body: str) -> Optional[str]:
        """
        Submits a top-level text post to a subreddit using headless Playwright with session cookies.
        Includes automatic flair selection, rich-text input event dispatch, and old.reddit.com fallback.
        Returns the submission URL if successful, or None if it fails.
        """
        if not self.is_available():
            logger.warning("REDDIT_SESSION_COOKIE not configured. Skipping Playwright submission.")
            return None

        try:
            from playwright.sync_api import sync_playwright
        except ImportError:
            logger.error("Playwright package is not installed.")
            return None

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

                # -------------------------------------------------------------
                # Attempt 1: Modern Reddit (shreddit)
                # -------------------------------------------------------------
                submit_url = f"https://www.reddit.com/r/{subreddit}/submit"
                logger.info(f"Launching Playwright to submit post to r/{subreddit}: {submit_url}")

                page.goto(submit_url, timeout=35000, wait_until="domcontentloaded")
                time.sleep(3.0)

                if "login" in page.url:
                    logger.error("Reddit session cookie expired (redirected to login).")
                    browser.close()
                    return None

                # Locate Title input
                title_input = page.query_selector(
                    "textarea[placeholder*='Title'], input[placeholder*='Title'], "
                    "shreddit-composer [name='title'], textarea[name='title']"
                )
                if title_input:
                    title_input.click()
                    title_input.fill("")
                    page.keyboard.insert_text(title)
                    page.evaluate(
                        "(el) => { el.dispatchEvent(new Event('input', {bubbles: true})); "
                        "el.dispatchEvent(new Event('change', {bubbles: true})); }",
                        title_input
                    )
                    time.sleep(0.5)
                else:
                    logger.warning("Could not find title input on modern Reddit submit page.")

                # Try switching to Markdown mode if available
                markdown_toggle = page.query_selector(
                    "button:has-text('Markdown'), button:has-text('Switch to markdown'), [aria-label*='Markdown' i]"
                )
                if markdown_toggle and markdown_toggle.is_visible():
                    try:
                        markdown_toggle.click()
                        time.sleep(0.5)
                    except Exception:
                        pass

                # Locate Body input
                body_selectors = [
                    "textarea[name='text']",
                    "shreddit-composer textarea",
                    "div[contenteditable='true'][role='textbox']",
                    "shreddit-composer div[contenteditable='true']",
                    "faceplate-form textarea",
                    "div[role='textbox']"
                ]
                body_input = None
                for sel in body_selectors:
                    elem = page.query_selector(sel)
                    if elem and elem.is_visible():
                        body_input = elem
                        break

                if body_input:
                    body_input.click()
                    page.keyboard.insert_text(body)
                    page.evaluate(
                        "(el) => { el.dispatchEvent(new Event('input', {bubbles: true})); "
                        "el.dispatchEvent(new Event('change', {bubbles: true})); }",
                        body_input
                    )
                    time.sleep(1.0)
                else:
                    logger.warning("Could not find body input on modern Reddit submit page.")

                # Handle Flair selection (required by r/SideProject and many subreddits)
                flair_btn = page.query_selector(
                    "button:has-text('Add flair'), button:has-text('Select flair'), "
                    "button:has-text('Flair'), [aria-label*='flair' i], button[slot*='flair'], "
                    "faceplate-tracker[noun='flair_button'] button"
                )
                if flair_btn and flair_btn.is_visible():
                    try:
                        logger.info("Found flair button; opening flair modal...")
                        flair_btn.click()
                        time.sleep(1.2)
                        flair_options = page.query_selector_all(
                            "li[role='menuitem'], button[role='radio'], input[type='radio'], "
                            "faceplate-menu li, div[role='dialog'] button, r-flair-select li"
                        )
                        for opt in flair_options:
                            opt_text = (opt.inner_text() or "").strip()
                            if opt_text and not any(skip in opt_text.lower() for skip in ["cancel", "close", "back", "clear"]):
                                logger.info(f"Selecting flair option: '{opt_text}'")
                                opt.click()
                                time.sleep(0.5)
                                break
                        apply_btn = page.query_selector(
                            "button:has-text('Apply'), button:has-text('Save'), button:has-text('Done')"
                        )
                        if apply_btn and apply_btn.is_visible():
                            apply_btn.click()
                            time.sleep(0.5)
                    except Exception as flair_err:
                        logger.warning(f"Error handling post flair: {flair_err}")

                # Poll for enabled Post button
                post_btn = None
                for _ in range(8):
                    candidates = page.query_selector_all(
                        "button:has-text('Post'), button[type='submit'], shreddit-composer button"
                    )
                    for btn in candidates:
                        text = (btn.inner_text() or "").strip().lower()
                        if "post" in text and "crosspost" not in text:
                            is_disabled = (
                                btn.get_attribute("disabled") is not None or
                                btn.get_attribute("aria-disabled") == "true"
                            )
                            if not is_disabled and btn.is_visible():
                                post_btn = btn
                                break
                    if post_btn:
                        break
                    time.sleep(0.5)

                if post_btn:
                    logger.info("Clicking enabled Post button on modern Reddit...")
                    post_btn.click()
                    time.sleep(5.0)
                    if "/comments/" in page.url or page.url != submit_url:
                        final_url = page.url
                        logger.info(f"Reddit top-level post submitted successfully! URL: {final_url}")
                        browser.close()
                        return final_url

                # -------------------------------------------------------------
                # Attempt 2: Fallback to old.reddit.com
                # -------------------------------------------------------------
                old_submit_url = f"https://old.reddit.com/r/{subreddit}/submit?selftext=true"
                logger.info(f"Attempting fallback submission via old.reddit.com: {old_submit_url}")
                try:
                    page.goto(old_submit_url, timeout=25000, wait_until="domcontentloaded")
                    time.sleep(2.0)

                    old_title = page.query_selector("textarea[name='title']")
                    old_text = page.query_selector("textarea[name='text']")
                    old_submit = page.query_selector("button[name='submit'], input[type='submit'][name='submit']")

                    if old_title and old_text and old_submit:
                        old_title.fill(title)
                        old_text.fill(body)
                        time.sleep(0.5)
                        old_submit.click()
                        time.sleep(5.0)
                        if "/comments/" in page.url or "submit" not in page.url:
                            final_url = page.url
                            logger.info(f"Reddit post submitted successfully via old.reddit.com! URL: {final_url}")
                            browser.close()
                            return final_url
                except Exception as old_err:
                    logger.warning(f"old.reddit.com fallback attempt failed: {old_err}")

                logger.error("Could not find enabled Post button on Reddit submit page.")
                browser.close()
                return None

        except Exception as e:
            logger.error(f"Playwright Reddit post submission error: {e}")
            return None

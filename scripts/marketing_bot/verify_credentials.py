import os
import sys
import requests
from pathlib import Path
from dotenv import load_dotenv

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

base_dir = Path(__file__).resolve().parent
load_dotenv(base_dir / ".env")
load_dotenv(base_dir.parent.parent / ".env")

from .config import (
    GEMINI_API_KEY,
    TELEGRAM_BOT_TOKEN,
    TELEGRAM_CHAT_ID,
    X_API_KEY,
    X_API_SECRET,
    X_ACCESS_TOKEN,
    X_ACCESS_SECRET,
    BSKY_HANDLE,
    BSKY_APP_PASSWORD,
    DEVTO_API_KEY,
    HASHNODE_ACCESS_TOKEN,
    MASTODON_ACCESS_TOKEN
)

def check_telegram():
    print("\n--- 1. Testing Telegram ---")
    if not TELEGRAM_BOT_TOKEN:
        print("[ERROR] TELEGRAM_BOT_TOKEN is missing.")
        return False

    url = f"https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/getMe"
    try:
        r = requests.get(url, timeout=10)
        data = r.json()
        if data.get("ok"):
            bot_name = data["result"].get("username")
            print(f"[OK] Telegram Token Valid! Bot: @{bot_name}")
        else:
            print(f"[ERROR] Telegram Token Invalid: {data}")
            return False
    except Exception as e:
        print(f"[ERROR] Error reaching Telegram: {e}")
        return False

    if not TELEGRAM_CHAT_ID:
        print("[ERROR] TELEGRAM_CHAT_ID is missing.")
        return False

    url_chat = f"https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/getChat?chat_id={TELEGRAM_CHAT_ID}"
    try:
        r = requests.get(url_chat, timeout=10)
        data = r.json()
        if data.get("ok"):
            chat_title = data["result"].get("first_name", "") or data["result"].get("title", "")
            print(f"[OK] Telegram Chat ID Valid! Chat with: {chat_title}")
            return True
        else:
            print(f"[WARN] Telegram Chat ID Error: {data.get('description')}")
            print("👉 REMINDER: You MUST open Telegram, find your bot, and tap 'START' so the bot can reach you.")
            return False
    except Exception as e:
        print(f"[ERROR] Error checking Telegram chat: {e}")
        return False

def check_gemini():
    print("\n--- 2. Testing Google Gemini ---")
    if not GEMINI_API_KEY:
        print("[ERROR] GEMINI_API_KEY is missing.")
        return False

    url = f"https://generativelanguage.googleapis.com/v1beta/models?key={GEMINI_API_KEY}"
    try:
        r = requests.get(url, timeout=10)
        if r.status_code == 200:
            models_data = r.json().get("models", [])
            flash_models = [m.get("name", "").replace("models/", "") for m in models_data if "flash" in m.get("name", "")]
            print(f"[OK] Gemini API Key is Valid! Found {len(models_data)} models.")
            if flash_models:
                print(f"   Available Flash models: {', '.join(flash_models[:4])}")
            return True
        else:
            print(f"[ERROR] Gemini API Key Error ({r.status_code}): {r.text[:200]}")
            return False
    except Exception as e:
        print(f"[ERROR] Error checking Gemini: {e}")
        return False

def check_twitter():
    print("\n--- 3. Testing X / Twitter (OAuth 1.0a) ---")
    if not all([X_API_KEY, X_API_SECRET, X_ACCESS_TOKEN, X_ACCESS_SECRET]):
        missing = []
        if not X_API_KEY: missing.append("X_API_KEY")
        if not X_API_SECRET: missing.append("X_API_SECRET")
        if not X_ACCESS_TOKEN: missing.append("X_ACCESS_TOKEN")
        if not X_ACCESS_SECRET: missing.append("X_ACCESS_SECRET")
        print(f"❌ Missing X credentials: {', '.join(missing)}")
        return False

    try:
        from requests_oauthlib import OAuth1
    except ImportError:
        print("❌ 'requests-oauthlib' is not installed. Install via: pip install requests-oauthlib")
        return False

    auth = OAuth1(X_API_KEY, X_API_SECRET, X_ACCESS_TOKEN, X_ACCESS_SECRET)
    url = "https://api.twitter.com/2/users/me"

    try:
        r = requests.get(url, auth=auth, timeout=15)
        if r.status_code == 200:
            user_data = r.json().get("data", {})
            name = user_data.get("name")
            handle = user_data.get("username")
            user_id = user_data.get("id")
            print(f"✅ X / Twitter Credentials are VALID and working!")
            print(f"   Authenticated Account: @{handle} ({name}) [ID: {user_id}]")
            return True
        else:
            print(f"❌ X API Error ({r.status_code}): {r.text}")
            if r.status_code == 401:
                print("👉 Hint: Check that API Key, API Secret, Access Token, and Access Token Secret are exact.")
            elif r.status_code == 403:
                print("👉 Hint: Check that User Authentication Settings permissions are set to 'Read and write'.")
            return False
    except Exception as e:
        print(f"❌ Network error contacting Twitter API: {e}")
        return False

def check_bluesky():
    if not (BSKY_HANDLE and BSKY_APP_PASSWORD):
        return None
    print("\n--- 4. Testing Bluesky ---")
    try:
        from .bluesky_client import BlueskyClient
        client = BlueskyClient()
        if client.create_session():
            print(f"✅ Bluesky session authenticated for @{BSKY_HANDLE}!")
            return True
        else:
            print(f"❌ Failed to authenticate Bluesky for @{BSKY_HANDLE}.")
            return False
    except Exception as e:
        print(f"❌ Bluesky error: {e}")
        return False

def check_devto():
    if not DEVTO_API_KEY:
        return None
    print("\n--- 5. Testing Dev.to ---")
    url = "https://dev.to/api/users/me"
    try:
        r = requests.get(url, headers={"api-key": DEVTO_API_KEY}, timeout=10)
        if r.status_code == 200:
            username = r.json().get("username")
            print(f"✅ Dev.to API Key Valid! User: @{username}")
            return True
        else:
            print(f"❌ Dev.to API Error ({r.status_code}): {r.text}")
            return False
    except Exception as e:
        print(f"❌ Error checking Dev.to: {e}")
        return False

def check_hashnode():
    if not HASHNODE_ACCESS_TOKEN:
        return None
    print("\n--- 6. Testing Hashnode ---")
    try:
        from .hashnode_client import HashnodeClient
        client = HashnodeClient()
        pub_id = client._get_publication_id()
        if pub_id:
            print(f"✅ Hashnode Token Valid! Resolved Publication ID: {pub_id}")
            return True
        else:
            print("❌ Could not resolve Hashnode publication ID with the provided token.")
            return False
    except Exception as e:
        print(f"❌ Error checking Hashnode: {e}")
        return False

def check_mastodon():
    if not MASTODON_ACCESS_TOKEN:
        return None
    print("\n--- 7. Testing Mastodon ---")
    try:
        from .mastodon_client import MastodonClient
        client = MastodonClient()
        stats = client.get_profile_stats()
        if stats is not None:
            print(f"✅ Mastodon Token Valid! Followers: {stats.get('followers_count', 0)}, Statuses: {stats.get('statuses_count', 0)}")
            return True
        else:
            print("❌ Failed to verify Mastodon credentials.")
            return False
    except Exception as e:
        print(f"❌ Error checking Mastodon: {e}")
        return False

def main():
    print("=" * 60)
    print("ROCIs Tasks Marketing Engine - Credential Verification")
    print("=" * 60)

    results = {
        "Telegram": check_telegram(),
        "Gemini": check_gemini(),
        "Twitter/X": check_twitter(),
        "Bluesky": check_bluesky(),
        "Dev.to": check_devto(),
        "Hashnode": check_hashnode(),
        "Mastodon": check_mastodon()
    }

    print("\n" + "=" * 60)
    print("Verification Summary:")
    has_failure = False
    for platform, status in results.items():
        if status is True:
            tag = "✅ PASSED"
        elif status is False:
            tag = "❌ FAILED"
            has_failure = True
        else:
            tag = "⚪ SKIPPED (Not Configured)"
        print(f"  • {platform.ljust(12)}: {tag}")
    print("=" * 60)

    if has_failure:
        print("\n⚠️ One or more configured credentials failed verification.")
        sys.exit(1)
    else:
        print("\n🎉 All configured services verified successfully!")
        sys.exit(0)

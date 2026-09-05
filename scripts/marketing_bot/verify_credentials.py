import os
import sys
import requests
from pathlib import Path
from dotenv import load_dotenv

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
    DEVTO_API_KEY
)

def check_telegram():
    print("\n--- 1. Testing Telegram ---")
    if not TELEGRAM_BOT_TOKEN:
        print("❌ TELEGRAM_BOT_TOKEN is missing.")
        return False

    url = f"https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/getMe"
    try:
        r = requests.get(url, timeout=10)
        data = r.json()
        if data.get("ok"):
            bot_name = data["result"].get("username")
            print(f"✅ Telegram Token Valid! Bot: @{bot_name}")
        else:
            print(f"❌ Telegram Token Invalid: {data}")
            return False
    except Exception as e:
        print(f"❌ Error reaching Telegram: {e}")
        return False

    if not TELEGRAM_CHAT_ID:
        print("❌ TELEGRAM_CHAT_ID is missing.")
        return False

    url_chat = f"https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/getChat?chat_id={TELEGRAM_CHAT_ID}"
    try:
        r = requests.get(url_chat, timeout=10)
        data = r.json()
        if data.get("ok"):
            chat_title = data["result"].get("first_name", "") or data["result"].get("title", "")
            print(f"✅ Telegram Chat ID Valid! Chat with: {chat_title}")
            return True
        else:
            print(f"⚠️ Telegram Chat ID Error: {data.get('description')}")
            print("👉 REMINDER: You MUST open Telegram, find your bot, and tap 'START' so the bot can reach you.")
            return False
    except Exception as e:
        print(f"❌ Error checking Telegram chat: {e}")
        return False

def check_gemini():
    print("\n--- 2. Testing Google Gemini ---")
    if not GEMINI_API_KEY:
        print("❌ GEMINI_API_KEY is missing.")
        return False

    url = f"https://generativelanguage.googleapis.com/v1beta/models?key={GEMINI_API_KEY}"
    try:
        r = requests.get(url, timeout=10)
        if r.status_code == 200:
            print("✅ Gemini API Key is Valid!")
            return True
        else:
            print(f"❌ Gemini API Key Error ({r.status_code}): {r.text[:200]}")
            return False
    except Exception as e:
        print(f"❌ Error checking Gemini: {e}")
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
        return True
    print("\n--- 4. Testing Bluesky ---")
    from .bluesky_client import BlueskyClient
    client = BlueskyClient()
    if client.create_session():
        print(f"✅ Bluesky session authenticated for @{BSKY_HANDLE}!")
        return True
    else:
        print(f"❌ Failed to authenticate Bluesky for @{BSKY_HANDLE}.")
        return False

def check_devto():
    if not DEVTO_API_KEY:
        return True
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

def main():
    print("=" * 60)
    print("ROCIs Tasks Marketing Engine - Credential Verification")
    print("=" * 60)

    t_ok = check_telegram()
    g_ok = check_gemini()
    x_ok = check_twitter()
    b_ok = check_bluesky()
    d_ok = check_devto()

    print("\n" + "=" * 60)
    print("Verification Summary:")
    print(f"  • Telegram:   {'✅ PASSED' if t_ok else '❌ FAILED'}")
    print(f"  • Gemini:     {'✅ PASSED' if g_ok else '❌ FAILED'}")
    print(f"  • Twitter/X:  {'✅ PASSED' if x_ok else '❌ FAILED'}")
    print("=" * 60)

if __name__ == "__main__":
    main()

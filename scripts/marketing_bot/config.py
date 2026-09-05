import os
from pathlib import Path
from dotenv import load_dotenv

# Search for .env in current directory or project root
base_dir = Path(__file__).resolve().parent
load_dotenv(base_dir / ".env")
load_dotenv(base_dir.parent.parent / ".env")

# API Keys & Credentials
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "")
TELEGRAM_BOT_TOKEN = os.getenv("TELEGRAM_BOT_TOKEN", "")
TELEGRAM_CHAT_ID = os.getenv("TELEGRAM_CHAT_ID", "")

# Reddit Configuration
REDDIT_SESSION_COOKIE = os.getenv("REDDIT_SESSION_COOKIE", "")
REDDIT_CLIENT_ID = os.getenv("REDDIT_CLIENT_ID", "")
REDDIT_CLIENT_SECRET = os.getenv("REDDIT_CLIENT_SECRET", "")
REDDIT_USERNAME = os.getenv("REDDIT_USERNAME", "")
REDDIT_PASSWORD = os.getenv("REDDIT_PASSWORD", "")
REDDIT_USER_AGENT = os.getenv("REDDIT_USER_AGENT", "python:com.rocisapps.tasks.marketing:v1.0 (by /u/rocis_apps)")

# Bluesky (AT Protocol) Configuration
BSKY_HANDLE = os.getenv("BSKY_HANDLE", "")
BSKY_APP_PASSWORD = os.getenv("BSKY_APP_PASSWORD", "")

# Additional Platform API Keys
DEVTO_API_KEY = os.getenv("DEVTO_API_KEY", "")
X_API_KEY = os.getenv("X_API_KEY", "")
X_API_SECRET = os.getenv("X_API_SECRET", "")
X_ACCESS_TOKEN = os.getenv("X_ACCESS_TOKEN", "")
X_ACCESS_SECRET = os.getenv("X_ACCESS_SECRET", "")

# Operational Settings
DRY_RUN = os.getenv("DRY_RUN", "false").lower() in ("true", "1", "yes")
MAX_DISCOVERIES_PER_RUN = int(os.getenv("MAX_DISCOVERIES_PER_RUN", "6"))
MIN_RELEVANCE_SCORE = int(os.getenv("MIN_RELEVANCE_SCORE", "70"))
MAX_POST_AGE_HOURS = int(os.getenv("MAX_POST_AGE_HOURS", "72"))

# Organic Anti-Bot Persona Settings
AUTO_POST_ORGANIC = os.getenv("AUTO_POST_ORGANIC", "true").lower() in ("true", "1", "yes")
ORGANIC_POST_MIN_INTERVAL_HOURS = int(os.getenv("ORGANIC_POST_MIN_INTERVAL_HOURS", "12"))


# State Storage Path
STATE_FILE_PATH = base_dir / "marketing_state.json"

# App Knowledge Base for Gemini Copywriting (Indie Developer Tone)
APP_INFO = {
    "name": "ROCIs Tasks",
    "play_store_url": "https://play.google.com/store/apps/details?id=com.rocisapps.tasks",
    "web_url": "https://tasks.rocisapps.com",
    "tagline": "The Next-Generation Task & Calendar Workspace for Android",
    "core_features": [
        "Natural Language Task Parser: Type 'Submit report tomorrow at 5pm #urgent @work' to automatically extract dates, times, priorities, and categories without manual dropdowns.",
        "Interactive Android Home Screen Widgets: Native Kotlin-optimized widgets including Daily Focus Agenda, Monthly Calendar, Kanban columns, and Quick Actions with zero sync lag.",
        "Unified Calendar Sync: View Google Calendar, local device calendars, and to-do tasks side-by-side in one cohesive agenda view.",
        "True AMOLED Pitch-Black Mode & Glassmorphism: Battery-saving deep black background (#000000) with frosted glass cards (10-18% tint borders) and smooth micro-haptics.",
        "Offline-First & Fast: Zero waiting, instant offline read/write with Hive, syncing seamlessly with Firebase Firestore whenever online.",
        "Nested Subtasks, Checklists & Attachments: Multi-level subtasks, visual streaks, and progress velocity tracking.",
    ],
    "philosophy": (
        "ROCIs Tasks was crafted by an independent solo developer frustrated with bloated corporate apps "
        "and predatory monthly subscriptions. Built using Flutter, Hive, and native Kotlin widgets with a strong "
        "focus on craftsmanship, speed, and local data ownership."
    )
}

# Target Discovery Queries & Channels: Prioritizing Indie Dev, Build In Public & Mobile Dev Communities
REDDIT_SUBREDDITS = [
    "SideProject",
    "IndieHackers",
    "roastmystartup",
    "FlutterDev",
    "androiddev",
    "SaaS",
    "startups",
    "ADHD_Programmers",
    "selfhosted",
    "androidapps"
]

DISCOVERY_SEARCH_QUERIES = [
    "indie app showcase",
    "built a todo app",
    "offline first task app",
    "flutter task app",
    "android home widget app",
    "what todo app do you use",
    "todo app recommendation indie",
    "simple task manager with calendar sync",
    "offline to-do app without subscription"
]

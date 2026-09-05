# 🤖 ROCIs Tasks Autonomous Marketing & Community Intelligence Bot

An autonomous marketing, promotion, and user feedback engine for **ROCIs Tasks**.

The bot runs on **GitHub Actions** (scheduled every 6 hours + manual trigger), searches public communities (Reddit, Hacker News, Dev.to) for high-intent users looking for Android task/calendar apps, drafts human, authentic recommendations using **Google Gemini**, delivers **1-click approval cards to your Telegram Bot**, monitors replies to our posts, and organizes user feature requests and bug reports into categorized Telegram alerts.

---

## 🔑 Configuration & Secrets

Configure the following secrets in your private GitHub repository:
👉 **Repository Settings** ➔ **Secrets and variables** ➔ **Actions** ➔ **New repository secret**

### 1. Core Engine (Required)
| Secret Name | Description & How to Obtain |
|---|---|
| `GEMINI_API_KEY` | **Google Gemini API Key**<br>Get it free in 10 seconds from [Google AI Studio](https://aistudio.google.com/app/apikey). |
| `TELEGRAM_BOT_TOKEN` | **Telegram Bot Token**<br>Open Telegram, message [@BotFather](https://t.me/BotFather), send `/newbot`, follow prompts, and copy the token. |
| `TELEGRAM_CHAT_ID` | **Your Personal Telegram Chat ID**<br>1. Press "Start" in your new bot chat.<br>2. Message [@userinfobot](https://t.me/userinfobot) or [@myidbot](https://t.me/myidbot) on Telegram to get your numeric ID. |

### 2. Multi-Platform 100% Autonomous Posting (Optional)
| Secret Name | Platform | Description & How to Obtain |
|---|---|---|
| `REDDIT_SESSION_COOKIE` | **Reddit (Playwright)** | **100% Autonomous Reddit Posting without API Approvals**<br>1. Log into Reddit in Chrome/Edge.<br>2. Press `F12` ➔ **Application** tab ➔ **Cookies** ➔ `https://www.reddit.com`.<br>3. Copy the value of cookie `reddit_session`.<br>4. Paste as `REDDIT_SESSION_COOKIE` in GitHub Secrets. |
| `DEVTO_API_KEY` | **Dev.to (API)** | **100% Autonomous Dev.to Posting**<br>Get your API key at [dev.to/settings/extensions](https://dev.to/settings/extensions) under "DEV Community API Keys". |
| `REDDIT_CLIENT_ID` / `_SECRET` | **Reddit (PRAW)** | Legacy Reddit Script App credentials from [reddit.com/prefs/apps](https://www.reddit.com/prefs/apps). |

*(Note: If no auto-posting credentials are set for a platform, the bot automatically falls back to sending a 1-tap clipboard drop card to Telegram with direct permalinks, so you never miss an opportunity!)*

---

## 📱 How It Works

### 1. Opportunity Discovery & Gemini Drafting
* Every 6 hours, GitHub Actions launches the bot.
* The bot queries community search feeds for users asking for offline todo apps, Android home widgets, natural language parsing, and calendar integrations.
* Gemini scores each thread (0-100) and drafts an authentic, empathetic recommendation.

### 2. One-Click Approval & Execution
You receive an interactive Telegram card:
```text
🎯 New Promotion Opportunity (REDDIT)

📌 Thread: What is the best offline to-do app with good Android widgets?
📊 Relevance: 94/100
💡 Why: OP specifically wants an offline Android task app with home widgets.

📝 Proposed Reply:
Hey! I built ROCIs Tasks for this exact problem...

[✅ Approve & Post]   [❌ Skip]
[🌐 Open Thread]
```
* **Tap `[✅ Approve & Post]`**:
  * If `REDDIT_SESSION_COOKIE` is set: Headless **Playwright (Chromium)** launches, logs in via your session cookie, types the comment, and posts automatically!
  * If Dev.to: Posts comment via Dev.to REST API.
  * If no credentials: Delivers a 1-tap pre-copied snippet so you can paste in 2 seconds.
* **Tap `[❌ Skip]`**: Dismisses the opportunity and updates state.

### 3. Community Feedback & Feature Request Digest
* On every run, the bot re-checks our active posts for new comments.
* Gemini parses incoming comments and categorizes them:
  * 💡 **Feature Request** (e.g., *"Can you add repeating subtasks?"*)
  * 🐛 **Bug Report** (e.g., *"Widget crashes on 120Hz display"*)
  * ⭐ **Praise** (e.g., *"Love the AMOLED black mode!"*)
* An alert is instantly dispatched to your Telegram chat with the extracted summary and a suggested reply.

---

## 💻 Local Testing

```bash
# 1. Install dependencies
pip install -r scripts/marketing_bot/requirements.txt
python -m playwright install --with-deps chromium

# 2. Run unit tests
python -m unittest scripts/marketing_bot/tests/test_bot.py

# 3. Dry-run pipeline (no real messages sent)
python -m scripts.marketing_bot.main --dry-run
```

# 🤖 ROCIs Tasks Autonomous Marketing & Community Intelligence Bot

An autonomous marketing, promotion, and user feedback engine for **ROCIs Tasks**.

The bot runs on **GitHub Actions** (scheduled every 6 hours + manual trigger), searches public communities (Reddit, Hacker News, Dev.to) for high-intent users looking for Android task/calendar apps, drafts human, authentic recommendations using **Google Gemini**, delivers **1-click approval cards to your Telegram Bot**, monitors replies to our posts, and organizes user feature requests and bug reports into categorized Telegram alerts.

---

## 🔑 Required API Keys & Setup (One-Time)

To enable the bot, configure the following secrets in your GitHub repository:
👉 **Repository Settings** ➔ **Secrets and variables** ➔ **Actions** ➔ **New repository secret**

| Secret Name | Required? | Description & How to Obtain |
|---|---|---|
| `GEMINI_API_KEY` | **Yes** | **Google Gemini API Key**<br>Get it free in 10 seconds from [Google AI Studio](https://aistudio.google.com/app/apikey). |
| `TELEGRAM_BOT_TOKEN` | **Yes** | **Telegram Bot Token**<br>Open Telegram, message [@BotFather](https://t.me/BotFather), send `/newbot`, follow prompts, and copy the HTTP API token. |
| `TELEGRAM_CHAT_ID` | **Yes** | **Your Personal Telegram Chat ID**<br>1. Press "Start" in your newly created bot chat.<br>2. Message [@userinfobot](https://t.me/userinfobot) or [@myidbot](https://t.me/myidbot) on Telegram to view your numeric ID (e.g., `123456789`). |
| `REDDIT_CLIENT_ID` | *Optional* | Reddit script app ID (from [reddit.com/prefs/apps](https://www.reddit.com/prefs/apps)). If omitted, Reddit opportunities deliver a 1-tap clipboard drop card to Telegram instead. |
| `REDDIT_CLIENT_SECRET` | *Optional* | Reddit script app secret key. |
| `REDDIT_USERNAME` | *Optional* | Your Reddit account username. |
| `REDDIT_PASSWORD` | *Optional* | Your Reddit account password. |

---

## 📱 How It Works

### 1. Opportunity Discovery & Gemini Drafting
* Every 6 hours, GitHub Actions launches the bot.
* The bot queries community search feeds for users asking for offline todo apps, Android home widgets, natural language parsing, and calendar integrations.
* Gemini scores each thread (0-100) and drafts an authentic, empathetic recommendation.

### 2. One-Click Approval in Telegram
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
* **Tap `[✅ Approve & Post]`**: If Reddit API keys are set, it posts automatically. Otherwise, it sends you a pre-formatted snippet that copies to your clipboard with a single tap.
* **Tap `[❌ Skip]`**: Dismisses the opportunity and updates state.

### 3. Community Feedback & Feature Request Digest
* On every run, the bot re-checks our active posts for new comments.
* Gemini parses incoming comments and categorizes them:
  * 💡 **Feature Request** (e.g., *"Can you add repeating subtasks?"*)
  * 🐛 **Bug Report** (e.g., *"Widget crashes on 120Hz display"*)
  * ⭐ **Praise** (e.g., *"Love the AMOLED black mode!"*)
* An alert is instantly dispatched to your Telegram chat with the extracted summary and a suggested reply.

---

## 💻 Local Development & Testing

1. Create your local `.env` file:
```bash
cp scripts/marketing_bot/.env.example scripts/marketing_bot/.env
```
2. Install dependencies:
```bash
pip install -r scripts/marketing_bot/requirements.txt
```
3. Run in dry-run mode (tests discovery without sending real messages):
```bash
python -m scripts.marketing_bot.main --dry-run
```
4. Run unit tests:
```bash
python -m unittest scripts/marketing_bot/tests/test_bot.py
```


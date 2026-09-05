import json
import logging
import random
import re
from typing import Dict, Any, Optional, List
import requests

from .config import GEMINI_API_KEY

logger = logging.getLogger(__name__)

GEMINI_API_URL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent"

# Rich everyday topics reflecting a full, authentic human life
TOPICS = [
    "ee_engineering_struggles",    # electrical engineering labs, oscilloscopes, signal noise, op-amps, breadboards vs code
    "scuba_diving_and_ocean",      # scuba diving serenity, breathing underwater, dive computers, gear checks, ocean quiet
    "student_and_study_grind",     # late night library, 50+ browser tabs, energy drinks, exams vs side projects
    "homelab_and_tinkering",       # self-hosting, raspberry pi/old laptops, docker containers, breaking linux at 1 am
    "gaming_and_steam_deck",       # indie games (Balatro, Hades, Stardew, Hollow Knight), cozy gaming on the couch
    "coffee_and_sleep_delusions",  # aspiring 7 AM morning person failing, caffeine dependency, espresso rituals
    "focus_and_music_loops",       # listening to the same synthwave/lofi track for 4 hours straight, doomscrolling vs flow
    "mobile_and_code_quirks",      # casual flutter/android/kotlin thoughts, UI pixel alignment obsession, gradle pain
    "everyday_observations"        # witty, relatable thoughts on modern life, notifications, desk setups
]

# Curated authentic fallback thoughts tailored to this exact persona
CURATED_FALLBACK_THOUGHTS = [
    "set an alarm for 7:00 am to 'start fresh and have a peaceful morning' and currently sitting here at 1:47 am reading documentation on docker compose.",
    "i have 64 browser tabs open and 43 of them are stackoverflow answers for a bug i fixed three days ago. i cannot close them because what if.",
    "buying an old used thinkpad to turn into a home server is basically the developer equivalent of adopting a stray cat.",
    "the urge to play just one quick run of balatro on the steam deck before bed turning into a 3 hour strategic masterclass.",
    "my daily diet consists of 80% iced coffee, 15% sheer willpower, and 5% synthwave playing on repeat for four hours straight.",
    "nobody talks about the emotional transition between 'today i will study for my exam' and 'today i will rewrite my entire dotfiles configuration from scratch'.",
    "the biggest lie i tell myself is 'i don't need to write this down, i'll remember it tomorrow morning'.",
    "spent 45 minutes cable-managing behind my desk only for it to look like an abstract art installation of black velcro and sorrow.",
    "there is no feeling quite like watching your local test build pass on the first try and immediately getting suspicious of what went wrong.",
    "casual reminder that listening to the exact same 3-minute song on loop for an entire afternoon is completely normal human behavior.",
    "humbling experience: trying to explain to normal people why having a local offline backup of your life matters when 'the cloud exists'.",
    "you either die a young enthusiastic builder or live long enough to realize that 90% of tech problems are solved by restarting the router.",
    "my home server has an uptime of 114 days and at this point i'm terrified to vacuum anywhere near the power strip.",
    "thinking about that one bug you couldn't solve while making your morning espresso hits different.",
    "spending 4 hours debugging an electrical engineering circuit lab only to discover a faulty breadboard jumper wire is peak character building.",
    "there is no silence on earth quite like being 20 meters underwater on a scuba dive. zero notifications, zero slack pings, just fish minding their business.",
    "software bugs make you question your sanity. electrical engineering lab bugs make you question physics itself.",
    "the transition from staring at an oscilloscope for 3 hours to sitting at 20 meters watching sea turtles drift by is the ultimate brain reboot."
]

class PersonaEngine:
    def __init__(self, api_key: Optional[str] = None):
        self.api_key = api_key or GEMINI_API_KEY

    def is_available(self) -> bool:
        return bool(self.api_key and len(self.api_key.strip()) > 5)

    def generate_organic_thought(self, previous_posts: Optional[List[str]] = None) -> Dict[str, str]:
        """
        Generates an authentic, non-promotional human reflection or punchy observation
        specifically crafted for Twitter/X and Bluesky.
        Returns a dict with 'text' and 'topic'.
        """
        chosen_topic = random.choice(TOPICS)
        avoid_context = ""
        if previous_posts:
            recent_snippets = [p[:60] for p in previous_posts[-5:]]
            avoid_context = f"\nAvoid repeating similar themes or phrasing to these recent posts:\n" + "\n".join(f"- {s}" for s in recent_snippets)

        if not self.is_available():
            logger.info("Gemini API not available. Selecting from curated organic persona pool.")
            return {
                "text": random.choice(CURATED_FALLBACK_THOUGHTS),
                "topic": chosen_topic
            }

        prompt = f"""You are posting a short, casual thought on your personal Twitter/X or Bluesky feed.

YOUR CHARACTER & LIFE PROFILE:
- Who you are: An Electrical Engineering (EE) college student and curious indie builder who balances hardware labs, software coding, homelabbing, and scuba diving.
- Daily life & schedule: An aspiring morning person who sets alarms for 7:00 AM with the best intentions, but constantly gets derailed late at night by hyperfocus, tinkering with home servers, or indie games.
- Hobbies & quirks:
  * Electrical Engineering (EE): Staring at oscilloscopes, signal noise, debugging breadboards with loose wires, circuit lab reports, feeling like hardware bugs defy physics.
  * Scuba Diving: Pure underwater tranquility, dive computers, zero pings/notifications at 20 meters, watching sea life, the ultimate brain reset after tech overload.
  * Homelabbing: Running Docker containers, Raspberry Pis, old laptops turned servers, self-hosting stuff.
  * Gaming: Steam Deck on the couch, indie roguelikes/gems (Balatro, Hades, Stardew Valley, Hollow Knight).
  * Music & focus: Listening to the exact same song/synthwave track on a 4-hour loop to get into flow state.
  * Caffeine: Fueling daily life on espresso / iced coffee and laughing at your own sleep deprivation.
  * Student life: Balancing exam/study grind in the library with 50+ open browser tabs against the urge to build side projects.
- Tone & Voice:
  * Dry humor, self-deprecating, witty, low-stress, relatable.
  * Casual, mostly lowercase, punchy one-liners or 2-sentence mini thoughts.
  * Zero cringe, zero corporate buzzwords, NO fake motivational guru vibes.

TOPIC FOR THIS POST: {chosen_topic}
{avoid_context}

STRICT ANTI-BOT RULES:
1. ABSOLUTELY ZERO SELF-PROMOTION. Do NOT mention any app name, do NOT include links, do NOT pitch or advertise anything.
2. Under 220 characters (fits effortlessly in a single tweet).
3. Do NOT use cheesy hashtags (0 hashtags preferred, max 1 if totally natural).
4. No quotation marks around the post. Just the raw text.

OUTPUT FORMAT:
Return ONLY the raw post text ready to send."""

        headers = {"Content-Type": "application/json"}
        payload = {
            "contents": [
                {"parts": [{"text": prompt}]}
            ],
            "generationConfig": {
                "temperature": 0.9,
                "maxOutputTokens": 200
            }
        }

        from .gemini_engine import GEMINI_MODELS
        for model_name in GEMINI_MODELS:
            url = f"https://generativelanguage.googleapis.com/v1beta/models/{model_name}:generateContent?key={self.api_key}"
            try:
                res = requests.post(url, headers=headers, json=payload, timeout=25)
                if res.status_code == 404:
                    continue
                res.raise_for_status()
                data = res.json()
                candidates = data.get("candidates", [])
                if candidates:
                    raw_text = candidates[0].get("content", {}).get("parts", [{}])[0].get("text", "").strip()
                    clean_text = raw_text.strip('"\n\r ')
                    if clean_text and len(clean_text) <= 280:
                        logger.info(f"Generated organic persona thought ({len(clean_text)} chars) via {model_name}: {clean_text}")
                        return {
                            "text": clean_text,
                            "topic": chosen_topic
                        }
            except Exception as e:
                logger.warning(f"Error generating thought with {model_name}: {e}")

        # Fallback to curated pool if LLM is unavailable
        fallback = random.choice(CURATED_FALLBACK_THOUGHTS)
        return {
            "text": fallback,
            "topic": chosen_topic
        }


---
type: doc
status: active
tags: [promo-video, marketing, rocis-tasks, rocis-schedule, ffmpeg, playwright]
relatedTo: [tools/store-screenshots/scripts/README.md]
---

# Promo videos

`promo.html` is a timeline (intro, one scene per feature, outro) that `render.py` seeks frame by frame in
Chromium and pipes into ffmpeg, so the output is identical on every run.

```
python render.py tasks 16x9 out/rocis-tasks-16x9.mp4      # 1920x1080, Play promo / YouTube
python render.py schedule 9x16 out/rocis-schedule-9x16.mp4 # 1080x1920, Shorts / Reels / Reddit
python render.py tasks 9x16 still.png --still 11           # one frame, for review
```

Needs Playwright + Chromium and ffmpeg on PATH. Scene text and timing live in `SCENES` in `promo.html`.

## Screens (`assets/<app>/`, not tracked)

- `icon.png`: `assets/brand/png/<app>-icon-1024.png`.
- Tasks `01`-`11`: the English store captures in `tools/store-screenshots/public/screenshots/android/phone/en/`.
- Tasks `home`, `dial`, `k00`-`k20`, `k99`, `added`: the quick-add flow on a `SCREENSHOT_SEED` web build,
  captured with `capture_web.py` (skip onboarding `c:345,16`, cookies "Essential Only" `c:94,766`,
  FAB `c:309,685`, New Task `c:309,625`, then `t:` two characters and `s:` a frame, then Enter).
- Schedule `01`-`07`: `tools/store-screenshots/public/screenshots/schedule/phone/en/`.
- Schedule `home`, `tue`, `import`, `imported`, `courses`: the Schedule web build with `SCREENSHOT_SEED`
  (day strip Tue `c:141,178`, then `g:#/share?d=<course payload>` and Import `c:195,757`).

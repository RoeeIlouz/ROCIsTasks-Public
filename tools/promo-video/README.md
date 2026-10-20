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

## Feature shorts (`shorts.html`)

Three 9:16 Shorts/Reels for ROCIs Tasks over real emulator footage: 1 quick add, 2 widget check-off,
3 counter-notification ring. Timeline, captions, camera keyframes and tap ripples live in `SHORTS` in
`shorts.html`.

```
python cut_shorts.py <raw_dir>   # takes -> assets/shorts/<n>/NNNN.jpg, sped-up segments per CUTS
python sfx.py                    # assets/shorts/sfx<n>.wav: key clicks, taps, chimes, whooshes (no music)
python render_shorts.py 1 ../../docs/marketing/videos/rocis_tasks_short1_quickadd_9x16.mp4
python render_shorts.py 3 still.png --still 5.5
```

Takes come from `adb shell screenrecord` on the `rocis_shots` emulator (`-gpu swiftshader_indirect`) running a
`flutter build apk --profile --dart-define=SCREENSHOT_SEED=true` build, with the system in dark mode
(`cmd uimode night yes`), a charcoal wallpaper, home-screen suggestions off, `show_touches` on and the
SystemUI demo-mode status bar. screenrecord writes variable frame rate, so convert each take with
`ffmpeg -vf fps=30` to `d<n>_cfr.mp4` before `cut_shorts.py` cuts it by frame number. Music is left out on
purpose: add a track in the YouTube/Instagram editor when posting.
`assets/shorts/icon.png` is `assets/brand/png/tasks-icon-1024.png`. `plate1`-`plate3.jpg` (behind each hook) and
`outro.jpg` (behind the end card) are Higgsfield `z_image` b-roll stills (9:16, 0.15 credits each), cropped to
1080x1920. They never show app UI; every screen in the shorts is real footage.

## Screens (`assets/<app>/`, not tracked)

- `icon.png`: `assets/brand/png/<app>-icon-1024.png`.
- Tasks `01`-`11`: the English store captures in `tools/store-screenshots/public/screenshots/android/phone/en/`.
- Tasks `home`, `dial`, `k00`-`k20`, `k99`, `added`: the quick-add flow on a `SCREENSHOT_SEED` web build,
  captured with `capture_web.py` (skip onboarding `c:345,16`, cookies "Essential Only" `c:94,766`,
  FAB `c:309,685`, New Task `c:309,625`, then `t:` two characters and `s:` a frame, then Enter).
- Schedule `01`-`07`: `tools/store-screenshots/public/screenshots/schedule/phone/en/`.
- Schedule `home`, `tue`, `import`, `imported`, `courses`: the Schedule web build with `SCREENSHOT_SEED`
  (day strip Tue `c:141,178`, then `g:#/share?d=<course payload>` and Import `c:195,757`).

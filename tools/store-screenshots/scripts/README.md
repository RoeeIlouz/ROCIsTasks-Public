# Store asset scripts

Regenerate the Play Store screenshots and listing (see `docs/architecture/adr-006-store-asset-pipeline.md`).

1. Build a capture APK (never publish it):
   `flutter build apk --profile --dart-define=SCREENSHOT_PREMIUM=true --dart-define=SCREENSHOT_SEED=true`
   and install it on an emulator (Pixel 8, API 35) that has the widgets pinned on home pages
   1 (Up Next + Month & Agenda), 2 (Full Calendar) and 3 (Day Agenda).
2. Capture each language: `python capture_locale.py <lang> <ltr|rtl of the current app language>`
   (writes `emu/loc/<lang>/`). Uses `emu.py` (adb helper).
3. `python build_locales.py` copies captures into `public/screenshots/android/phone/<lang>/`
   and fills captions from `../copy.json`.
4. Run the editor (`npm run dev -- -p 3100`), then export with
   `python shoot_editor.py export "Android Phone"` (needs Playwright + Chromium).
5. Copy exports to `../exports/play/<lang>/phone/*.png` + `feature.png`, then
   `python play_listing.py store ../exports/play` (dry run) and add `--commit` to publish
   listing text (`../listings.json`) and images through the Play Developer API.

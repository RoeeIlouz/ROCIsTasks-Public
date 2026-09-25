---
ontology: true
type: decision
domain: marketing
summary: Store screenshots come from real emulator captures with compile-time demo flags, framed in tools/store-screenshots and uploaded via the Play API
status: active
tags: [aso, screenshots, play-console, localization]
related: [adr-004-widget-design-system]
discovered: 2026-09-25
verified: true
---

# ADR-006: Reproducible, localized store asset pipeline

## Status
Accepted (2026-09-25)

## Context
The listing had old English-only screenshots. The main selling point (native widgets) can
only be captured from Android. Screenshots need premium features, clean demo data and
translated content, for 8 app languages, without touching real user data.

## Decision
- Two compile-time flags, off in release builds (`bool.fromEnvironment`):
  `SCREENSHOT_PREMIUM` (Pro on) and `SCREENSHOT_SEED` (replace local data with translated
  demo tasks from `lib/core/dev/screenshot_seed.dart`).
- A local emulator (Pixel 8, API 35) is driven by adb scripts: pin widgets with the app's
  "Add to home screen", switch language, capture light/dark widget pages and app screens.
- `tools/store-screenshots` (Next.js editor, ROCIs Onyx theme) frames them with per-language
  captions (`copy.json`) into 8 slides + feature graphic per language.
- `listings.json` holds Play listing text; assets and text are uploaded in one validated
  Play Developer API edit. `exports/` is regenerated, not tracked.

## Trade-offs
- Profile builds with flags are for capture only and must never be published.
- Emulator scripts depend on launcher layout (pages, coordinates).

## Consequences
- **Positive**: Real, localized, on-brand assets that can be regenerated after any UI change.
- **Negative**: Capture scripts depend on the emulator home-page layout.
- **Mitigation**: Scripts and steps are in `tools/store-screenshots/scripts` (README).

## Revisit trigger
Major UI redesign, new languages, or tablet/feature listings.

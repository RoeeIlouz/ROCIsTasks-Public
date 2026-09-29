---
ontology: true
type: doc
domain: rocis-brand
status: active
summary: ROCIs brand kit (Unbounded Bold R): app icons, studio icon, wordmark, source SVGs and exported PNGs
tags: [brand, logo, app-icon, adaptive-icon, wordmark, unbounded]
relatedTo: [rocis-tasks, rocis-schedule, rocisapps-website]
---

# ROCIs brand kit

Decided 2026-09-29. Every mark is built on the **Unbounded Bold "R"**, converted to outlines, so nothing here needs the font installed.

## Marks

| File | Use |
|---|---|
| `svg/studio-icon.svg` | ROCIs Apps studio icon (dark "Status R": charcoal tile, white R, red status square) |
| `svg/lockup-rocis-apps-{light,dark}.svg` | Icon + "ROCIs Apps" wordmark, for website headers and store pages |
| `svg/wordmark-rocis-apps-{light,dark}.svg`, `svg/wordmark-rocis-{light,dark}.svg` | Wordmark alone |
| `svg/tasks-icon.svg`, `svg/schedule-icon.svg` | App icons (rounded tile) |
| `svg/*-icon-square.svg` | Full-bleed versions for Google Play and maskable web icons (the platform applies the rounding) |
| `svg/*-adaptive-{background,foreground,monochrome}.svg` | Android adaptive icon layers on the 108dp grid; monochrome is the Android 13+ themed icon |
| `svg/rocis-r.svg` | The bare R, `currentColor` |

`png/` holds the exports (launcher 1024, Play Store 512, web 512/192/maskable, apple-touch 180, favicons 32/16, lockups).

## Colors

| Token | Hex |
|---|---|
| Tasks tile / studio tile | `#2D2F33` |
| Tasks accent, status square | `#E5323F` |
| Schedule tile | `#0E6FA8` |
| Schedule "today" | `#3CC44A` |
| Header band | tile color × 0.78 |

These are the same seeds the apps' themes are generated from (`AppTheme.brandScheme` in both apps).

## Rebuilding

`tools/brand/` regenerates everything:

1. `extract_glyphs.py` (only if the letters change): needs `Unbounded-VF.ttf` from google/fonts and `fonttools`; writes `unbounded_glyphs.json`.
2. `generate_brand.py`: writes `svg/`.
3. `render_brand.py export sheet`: writes `png/` and a contact sheet (needs Playwright).

Unbounded is licensed under the SIL Open Font License 1.1 (`Unbounded-OFL.txt`).

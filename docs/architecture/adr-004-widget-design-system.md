---
ontology: true
type: decision
domain: widgets
summary: All home widgets stay native RemoteViews and share WidgetStyle (app palette, tinted assets, system fonts, localized overlay)
status: active
tags: [widgets, remoteviews, design-system, i18n, rtl]
related: [adr-003-widget-actions-in-running-app]
discovered: 2026-09-24
verified: true
---

# ADR-004: Native RemoteViews widgets with a shared WidgetStyle

## Status
Accepted (2026-09-24, refined 2026-09-25)

## Context
Eight widgets had diverging hardcoded colors, glyph buttons and English-only strings; none
matched the app. Constraints: Flutter cannot render widgets; widget previews are drawn from
XML without running code; launchers ignore custom `@font` resources in widgets.

## Options considered
| Option | Pros | Cons |
|---|---|---|
| Jetpack Glance rewrite | Compose-style code, day/night built in | Rewrite of 8 widgets, Compose deps, new risk |
| **RemoteViews + shared style** | Incremental, matches rebuilt FullCalendar, no new deps | Verbose, colors applied imperatively |

## Decision
- Keep RemoteViews. `WidgetStyle.kt` provides the palette (app `primary`/`surfaceContainerLow`/
  `onSurface` synced by `MyApp._syncWidgetTheme`), card/tile tinting of white drawables,
  RTL, priority colors/labels, `formatTime` (app 12h/24h setting) and the shared localized
  free-tier overlay (`widget_pro_overlay.xml`).
- Layout XML carries light-theme default tints and text colors so picker previews render.
- System font families (`sans-serif`, `-medium`, bold) instead of bundled fonts.
- Widgets are redrawn when app colors change and on platform brightness changes.

## Trade-offs
- If the system switches light/dark while the app is not running, widgets update on their
  next refresh (RemoteViews colors are fixed at draw time).
- Brand font (Outfit) is not used in widgets.

## Consequences
- **Positive**: One look across 8 widgets, localized and RTL-correct, previews that sell.
- **Negative**: Imperative color calls in every provider.
- **Mitigation**: Android 12+ `RemoteViews.setColorInt(id, method, day, night)` for true
  day/night — the next step if theme lag is reported.

## Revisit trigger
Adopting Glance, or minSdk ≥ 31 (day/night color pairs everywhere).

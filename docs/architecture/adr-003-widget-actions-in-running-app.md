---
ontology: true
type: decision
domain: widgets
summary: Widget checkbox completion runs in the app's main engine (TaskProvider), not a background Dart isolate
status: active
tags: [widgets, hive, isolates, home_widget]
related: [adr-004-widget-design-system]
discovered: 2026-09-25
verified: true
---

# ADR-003: Widget task completion runs in the running app

## Status
Accepted (2026-09-25). Supersedes the "background isolate completes tasks" design in
ARCHITECTURE.md.

## Context
List widgets can only fire an activity PendingIntent per row (fill-in intents), so tapping a
checkbox launches `MainActivity`. It then forwarded `rocistasks://complete` to a
`HomeWidgetBackgroundIntent`, which starts a second, background Flutter engine. Both engines
opened the same Hive box in one process; the background write was lost or overwritten, and
tapping a checkbox never completed the task (confirmed on a device and an emulator).
Hive does not support concurrent access from two isolates.

## Decision
- `MainActivity` forwards `complete` links to the main engine like other widget links and
  remembers to return home.
- `HomeScreen._completeFromWidget` waits for tasks to load, completes the task through
  `TaskProvider` (same path as the UI: recurrence, notifications, sync, widget refresh), then
  calls `finishWidgetAction`; `MainActivity` then calls `moveTaskToBack(true)`.
- Up Next uses the same path. Background isolates stay for read-only widget syncs
  (navigation, filters).

## Rationale
1. One writer per Hive box: the app that owns the data.
2. Reuses the tested completion logic instead of a parallel implementation.
3. Returning home after completion keeps the "tick from the home screen" feel.

## Trade-offs
- The app briefly starts (cold start shows the splash for a moment) before returning home.

## Consequences
- **Positive**: Completion works and is consistent with the in-app behavior.
- **Negative**: Slower than a true background action on a cold start.
- **Mitigation**: Revisit with Android 12+ `RemoteResponse`/checkbox RemoteViews or a
  single-isolate data service if the flash is reported.

## Revisit trigger
Moving storage off Hive, or adopting Glance/RemoteViews checkbox responses.

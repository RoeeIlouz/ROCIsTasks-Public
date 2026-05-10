# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.1+8] - 2026-04-30

### Fixed

- **Authentication**: Resolved issue where users were forced to re-sign in on every app launch by improving initialization stability.
- **Data Persistence**: Fixed a critical bug where local tasks were accidentally cleared during app startup before authentication state was fully determined.
- **FullCalendar Widget**: Improved task visibility in the widget by preventing accidental data wipes during startup.
- **FullCalendar Widget**: Resolved text clipping issues in daily cells by optimizing padding and layout density.
- **FullCalendar Widget**: Implemented per-calendar colors for Google Calendar events.
- **Search**: Integrated real-time task search into the home screen AppBar.
- **UX**: Added haptic feedback for task interactions and visual highlighting for overdue tasks.
- **Trash**: Added "Empty Trash" functionality for bulk permanent deletion.
- **Localization**: Added full support for Search and Trash features in Hebrew and Spanish.

## [1.0.1+6] - 2026-04-29

### Fixed

- **FullCalendar Widget**: Fixed a critical bug in Hive box initialization that caused tasks to sometimes disappear in the background.
- **FullCalendar Widget**: Fixed text "spilling" out of day borders by optimizing line height and limiting summaries to one line.
- **Widget Sync**: Resolved filter synchronization issues where widget toggles were not consistently reflected in the data.

### Changed

- **Widget UI**: Prioritized event/task details by moving titles to the beginning of the display string.
- **Data Architecture**: Improved consistency by using a shared data source instance across the application isolates.

## [1.0.1+5] - 2026-04-29

### Fixed

- **FullCalendar Widget**: Fixed issue where the current date was not being tracked correctly (dynamic calculation added).
- **FullCalendar Widget**: Fixed task visibility issue by prioritizing local tasks in the summary list.
- **FullCalendar Widget**: Fixed Google Calendar event duration display and multi-day event support.
- **Background Sync**: Resolved Hive box name mismatch (`tasks` vs `tasksBox`) in background handlers.

### Added

- **Localization**: Added full support for Spanish (ES).
- **Premium**: Integrated RevenueCat for subscription management.

### Changed

- Incremented version to 1.0.1+5 for production deployment.

## [1.0.0+4] - 2026-04-28

### Added

- Initial production-ready release with Core features.
- Google Sign-In integration.
- Hive & Firestore synchronization.
- Android Home Screen Widgets.

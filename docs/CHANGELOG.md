# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.1+13] - 2026-05-21

### Fixed
- **Subscription Reliability**: Fixed a UI bug in the Paywall where "Purchases Restored" was shown even if no active subscription was found; now explicitly verifies entitlement status.
- **Localization**: Added missing translations for subscription-related messages in English, Hebrew, and Spanish.

### Changed
- **Configuration**: Centralized RevenueCat entitlement ID in `AppConfig` for easier maintenance and consistent usage across the app.
- **Diagnostics**: Enhanced subscription status logging for better troubleshooting of entitlement issues.

## [1.0.1+12] - 2026-05-21

### Added
- **Authentication Expansion**: Introduced Email & Password authentication alongside Google Sign-In, including dedicated Login and Registration screens with full form validation and password reset functionality.
- **Unified Theme Management**: Added support for explicit Theme selection (System Default, Light Mode, and Dark Mode) while preserving Material You dynamic color support across all modes.
- **Enhanced Security**: Integrated encryption key synchronization for email-based accounts to ensure data privacy and consistency across devices.

### Fixed
- **Background Robustness**: Improved background service stability for locale-aware system notifications and data synchronization.
- **Localization**: Expanded English, Hebrew, and Spanish support for all new authentication workflows and theme configuration settings.

## [1.0.1+11] - 2026-05-16

### Added
- **Productivity Analytics**: Introduced a new Insights dashboard featuring completion trends (line charts) and category distribution (pie charts) to help users visualize their performance.
- **Smart Add (NLP)**: Implemented natural language processing for intelligent task creation, automatically detecting dates and times from task titles.
- **Quick Actions**: Added home screen shortcuts for rapid task creation, trash management, and manual synchronization on Android and iOS.
- **Task Enhancements**: Added support for pinning tasks to the top of the list and refined bulk actions.
- **Web Presence**: Enhanced SEO and social sharing with Open Graph and Twitter metadata for the web platform.

### Fixed
- **UI/UX Stability**: Improved loading states with localized taglines and refined Material You dynamic color implementation.
- **Performance**: Optimized Firestore synchronization and background data handling for better responsiveness.
- **Localization**: Full translation support for analytics, NLP settings, and quick actions in English, Hebrew, and Spanish.
- **Security**: Hardened application URLs to HTTPS and improved data privacy in analytics events.

## [1.0.1+9] - 2026-05-14

### Added
- **Onboarding UX**: Added a "Skip" button to the onboarding flow for a smoother user experience.
- **Localization**: Added full localization support for notification actions and persistent system notifications in English, Hebrew, and Spanish.
- **Subscription Management**: Integrated the RevenueCat Customer Center for professional subscription management with native platform fallbacks.

### Fixed
- **Production Stability**: Resolved a critical "non-constant IconData" error that prevented the App Bundle from being built for production (fixed tree-shaking issue).
- **Security**: Upgraded all internal application URLs (Privacy, Terms, Website) to secure HTTPS.
- **Privacy**: Removed raw task identifiers from Firebase Analytics event logs to improve user privacy.
- **Navigation**: Switched onboarding completion to use `GoRouter` for cleaner stack management and to prevent accidental "back" navigation into onboarding.
- **Configuration**: Synchronized `appVersion` across all configuration files and removed deprecated/misleading session timeout constants.
- **Localization Generator**: Fixed metadata issues in Hebrew and Spanish ARB files that were causing intermittent generation errors.

### Changed
- **Router Diagnostics**: Disabled verbose navigation logging in production builds to optimize performance.
- **Background Handler**: Improved background isolate robustness by correctly resolving device locale for system notifications.

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

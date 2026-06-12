# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.6+30] - 2026-06-12

### Changed

- **Upgraded Firebase to 6.x**: Migrated `firebase_core` to 4.x, `cloud_firestore` to 6.x, `firebase_auth` to 6.x, `firebase_crashlytics` to 5.x, `firebase_analytics` to 12.x, `firebase_performance` to 0.11.x, `firebase_remote_config` to 6.x.
- **Upgraded device_info_plus** to 12.x.
- **Upgraded RevenueCat to 10.x**: Migrated `purchases_flutter` and `purchases_ui_flutter` from 9.x to 10.x.
- **Upgraded remaining packages**: `flutter_timezone` to 5.x, `connectivity_plus` to 7.x, `local_auth` to 3.x, `google_sign_in` to 7.x, `fl_chart` to 1.x, `flutter_dotenv` to 6.x, `flutter_local_notifications` to 22.x, `flutter_launcher_icons` to 0.14.x.
- **Upgraded timezone** to 0.11.x (required by flutter_local_notifications 22.x).
- **Enabled Built-in Kotlin**: Removed explicit `kotlin-android` plugin and `kotlinOptions` from `android/app/build.gradle`. Enabled `android.builtInKotlin=true` in `gradle.properties`.
- **Bumped minSdk** from 21 to 23 for Android Billing Library 8.3.0 compatibility.
- **Removed stale dependency overrides**: Removed `sqflite` overrides from `pubspec.yaml`.
- **Updated CI**: Flutter version updated to 3.44.2 in GitHub Actions.

### Fixed

- Adapted `google_sign_in` calls to v7.x singleton API (`initialize()`, `attemptLightweightAuthentication()`, `authorizationClient`).
- Adapted `flutter_local_notifications` calls to v20.x named-parameter API (`initialize(settings:)`, `zonedSchedule(id:, ...)`, `show(id:, ...)`, `cancel(id:)`).
- Adapted `local_auth` calls to v3.x API (replaced `AuthenticationOptions` with `persistAcrossBackgrounding` and `biometricOnly` parameters).
- Adapted `flutter_timezone` calls to v5.x API (`TimezoneInfo.identifier` instead of `String`).
- Adapted `flutter_dotenv` calls to v6.x API (`loadFromString(envString:)` instead of `testLoad(fileInput:)`, `clean()` for test setup).

## [1.1.4+28] - 2026-06-12

### Fixed

- **Security — Encryption Re-enabled**: Restored AES encryption in `EncryptionService.encrypt()` which previously returned plaintext. The method now performs proper AES encryption with a random IV and outputs `base64(iv):base64(ciphertext)`. Existing unencrypted data continues to work via the backwards-compatible `decrypt()` path.
- **Security — SSL Certificate Pinning**: `SecurityService.getHardenedHttpClient()` now validates peer certificates against configured fingerprints instead of silently allowing all connections. When no fingerprints are configured, a warning is logged. When fingerprints are set, non-matching certificates are rejected with a critical security alert.
- **Security — Environment Detection**: `SecurityService.isEnvironmentSecure()` now returns `kReleaseMode` instead of a hardcoded `true`. Debug and profile builds are flagged with log warnings.
- **Google Calendar Badge**: Replaced the hand-drawn `_GoogleGPainter` custom painter with the official Google "G" SVG icon (`assets/icons/google-icon.svg`) via `flutter_svg`. Badge size increased from 18px to 20px for better visibility.
- **Task Completion Toggle**: Fixed a race condition where toggling a task as complete would immediately revert. The Firestore stream listener was firing a `removed` event (task drops out of the `isCompleted == false` query) and overwriting the local state with stale cloud data before the Firestore write propagated. Added a `_pendingLocalWrites` guard that tracks recently toggled tasks and skips stale stream events.
- **FullCalendar Widget — Update Reliability**: Added a 100ms delay after saving widget data via `HomeWidget.saveWidgetData` and before calling `HomeWidget.updateWidget`, ensuring SharedPreferences are flushed to disk before the native widget reads them. On the Kotlin side, delayed `notifyAppWidgetViewDataChanged` by 300ms so the RemoteViewsFactory reads fresh data. Reduced widget update debounce from 1000ms to 200ms for snappier updates.
- **FullCalendar Widget — Month Switching Performance**: Pre-indexed calendar events and tasks by date into `Map<String, List>` for O(1) day lookups instead of scanning all events for each of the 42 days (was O(42×n)). Pre-loaded categories once instead of per-day. Batched all `HomeWidget.saveWidgetData` calls with `Future.wait` for parallel I/O.

## [1.1.3+27] - 2026-06-11

### Added

- **New Languages**: Added Swedish (`sv`), German (`de`), and French (`fr`) as fully supported app languages — all screens, settings, notifications, and system messages are translated.
- **Smart Language Defaulting**: On first launch, the app now auto-selects the language that matches the device locale if it is in the supported list (`ar`, `de`, `en`, `es`, `fr`, `he`, `sv`); otherwise defaults to English.

### Fixed

- **Localization Crashes**: Replaced direct `AppLocalizations.of(context)!` calls with a crash-proof safe lookup helper (`getSafeAppLocalizations`) that falls back to English when a locale is unavailable, preventing `Null check operator used on a null value` errors reported by users.
- **Background Isolate Locale**: Background task handlers and notification services now correctly retrieve the user's selected language from `SharedPreferences` instead of always using the system locale.
- **Localization in Task Provider**: Task-related UI strings generated outside a widget tree (e.g., in providers) now use the safe helper to prevent null-locale crashes.

## [1.0.3+24] - 2026-06-03

### Added

- **Premium - Biometric Unlock**: Added Fingerprint/FaceID authentication with a clean fallback to the existing PIN unlock flow.
- **Google Calendar Link Badge**: Tasks linked to Google Calendar now display a small Google icon indicator in the task row UI.
- **Premium - Upstream Google Calendar Hook**: Incoming Google Calendar events tagged with `(ROCIsTasks)` or `(RT)` are intercepted, deleted upstream, and recreated as local tasks with matching time boundaries.
- **Premium - Task Attachments**: Added base support for attaching documents/media to tasks via a file picker, with secure premium gating.

### Changed

- **Premium - Locked Task Privacy**: Locked/private tasks now appear in the list with title-only masking until biometric/PIN authorization succeeds.

### Deprecated

- **Task Recurrence**: Recurrence UI and scheduling logic are deprecated; legacy stored values remain safely nullable for backwards compatibility.

### Removed

- **Insights Tab**: Removed the Insights/Analytics tab and associated feature module from the app navigation.

## [1.0.2+22] - 2026-05-30

### Added

- **Completed Tasks Prefetch**: When "Show Completed Tasks" is enabled, the app now proactively fetches the latest completed tasks from Firestore in the background, so the list is populated immediately without requiring a manual sync.
- **Unit Tests**: Added unit tests for `TaskProvider` covering core task management logic.

### Changed

- **CI/CD**: Added Gradle caching to CI builds for significantly faster Android build times. Injected iOS RevenueCat API key into CI environment. Fixed long-running build keep-alive mechanism to prevent CI timeouts.

## [1.0.2+21] - 2026-05-24

### Fixed

- **Build**: Minor `pubspec.yaml` correction to resolve a build pipeline issue.

## [1.0.2+20] - 2026-05-24

### Added

- **Localization**: Full Arabic (`ar`) translation coverage — all app strings, settings, authentication flows, subscription messages, and premium features are now available in Arabic.
- **Secure Account Deletion**: Email/password users are now prompted to re-enter their password before deleting their account, preventing accidental or unauthorized data removal.
- **Re-authentication Support**: Added re-authentication flows for both Google Sign-In and Email/Password providers to protect destructive account actions.

### Fixed

- **Subscription Reliability**: RevenueCat API keys can now be injected via `--dart-define` at build time, making CI/CD pipelines more robust without relying solely on `.env` files.
- **Web Platform Crashes**: Subscription operations (restore, paywall, purchase, manage) are now safely guarded on the web platform to prevent unsupported API calls.
- **Subscription Configuration Errors**: Missing or invalid RevenueCat API keys now surface a clear `configurationError` message instead of silently failing; critical in production builds.

### Changed

- **Paywall UI**: Simplified the paywall screen to use RevenueCat's native paywall UI directly, removing the custom benefits header section for a cleaner, more maintainable flow.
- **Account Deletion UX**: Delete account flow now validates `context.mounted` correctly before showing dialogs, preventing widget state errors in async flows.

## [1.0.1+19] - 2026-05-24

### Added

- **Localization**: Added Arabic (`ar`) to the in-app language selector.
- **Paywall Clarity**: Added a short "What you get with Pro" benefits section to the paywall and premium screens (highlights the main Pro features).

### Fixed

- **Pro Entitlements Isolation**: RevenueCat subscription state is now synced to the currently signed-in account to prevent Pro status from carrying over between different app accounts on the same device.
- **Restore Purchases**: Restore attempts that fail due to a receipt already being owned by another account no longer crash the flow and will keep the user non-premium.

### Changed

- **Subscription Identity**: Added automatic RevenueCat `logIn`/`logOut` handling on authentication state changes for consistent entitlement checks.

## [1.0.1+17] - 2026-05-23

### Added

- **Premium - Private Categories**: Categories can be marked as Private and hidden from widgets and previews while Private Mode is locked.
- **Premium - Private Mode (PIN)**: Added Private Mode with PIN lock/unlock to hide private content.
- **Premium - Advanced Reminders**: Added extra snooze actions for task reminders.
- **Premium - Nag Reminders**: Added repeating reminders after a task is due, with configurable interval and count.
- **Premium - Quiet Hours**: Added quiet hours to delay reminders during a user-defined time window.
- **Premium - Accent Color**: Added a Pro-only accent color picker to customize app theme colors.
- **Premium - Widget Upgrades**: Added Pro-only widget filters (Overdue, Pinned) for the Tasks home screen widget.
- **Premium - Sub-task Dependencies**: Added an option to suppress task reminders until all sub-tasks are completed.

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

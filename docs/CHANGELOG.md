# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.10+91] - 2026-08-29

### Added

- Smart syntax NLP parsing for priorities (`!high`), categories (`#tag`), and relative dates.
- Desktop Web power-user keyboard shortcuts (`Ctrl+N`, `/`, `1-5`, `Esc`).
- Granular category filtering for Android home screen widgets.
- Periodic non-blocking Hive database storage compaction.

### Fixed

- Eliminated startup Credential Manager popups on mobile launches.
- Aligned OAuth scopes with Google Cloud Console.

## [0.2.10+90] - 2026-08-28

### Added

- In-cell event pills with colored category borders and subtle tint backdrops on FullCalendar widget.
- Circular glass navigation controls and brand Crimson Red styling for home screen widgets.
- Local Outfit font bundling for 100% offline instant typography.

### Performance

- Non-blocking startup lifecycle and background RemoteConfig/subscription sync.
- Optimized Android R8 ProGuard keep rules for reduced app binary size.

### Fixed

- Resolved Android RemoteViews XML inflation error on home screen widgets.
- Fixed startup timezone GMT parsing and dotenv initialization guards.

## [0.2.10+89] - 2026-08-27

### Added

- Interactive Kanban Board view across Mobile & Web with drag-and-drop workflow grouping.
- Android Home Screen Kanban Board Widget with native column navigation and quick actions.
- Redesigned FullCalendar Home Screen Widget to match in-app calendar aesthetics.

## [0.2.10+88] - 2026-08-27

### Fixed

- Fixed repeated Google Sign-In authorization prompts on mobile startup and sync.
- Fixed Android 3-button navigation bar overlapping the bottom navigation bar.

## [0.2.10+83] - 2026-08-22

### Fixed

- Resolved offline Crashlytics mapping file upload failure on Android release builds.
- Streamlined CI/CD pipeline with APK artifact delivery and configuration fallback.

## [0.2.10+81] - 2026-08-21

### Added

- Quick 1-tap date chips (Today, Tomorrow, Weekend, Next Week) in task creation & edit.
- Multi-color category dots & badge clusters on calendar view.
- Starter task templates and collapsible completed tasks section in task list.
- Modern segmented pill controls and 1-tap "Reset All" action in Sort & Filter.
- Inline 1-tap reschedule menu on task due date chips.

## [0.2.9+79] - 2026-08-20

### Added

- Complete Android Home Screen Widgets suite: Day Agenda, Samsung-style Month & Agenda, Google-style Schedule Timeline, Quick Actions, and Up Next Pill.
- Direct one-tap task completion from all home widgets.
- Freemium widget limits: 1 active widget on Free tier, unlimited widgets on Pro.

## [0.2.8+78] - 2026-08-20

### Added

- Lifetime Pro plan tier on Web paywall ($49.99 one-time purchase).
- Revamped Onboarding showcasing Google Tasks/Calendar sync and glassmorphism.
- Guest Mode & Delayed Authentication: explore the full app without sign-in friction.
- Custom action lines on tasks (contacts, locations, web links).

## [0.2.7+77] - 2026-08-18

### Added

- Guest Mode: use the full app completely offline on-device without signing in.
- Cloud Backup on Sign-In: automatically upload and back up local tasks and categories upon logging in or registering.
- Continue as guest option on login and account management updates in Settings.

## [0.2.6+76] - 2026-08-15

### Added

- Pro Recurring Tasks: schedule daily, weekday, weekly, monthly, yearly, or custom repeat rules with automatic next-task creation on completion.
- Timezone selector in Settings with search and automatic device timezone detection.

### Fixed

- Fixed Google Calendar event display and permissions on Web.
- Resolved web startup errors caused by browser ad-blockers.
- Updated web app domain configuration to tasks.rocisapps.com.

## [0.2.6+74] - 2026-08-13

### Fixed

- Improved Google reconnect reliability on Web by forcing OAuth consent when re-linking/signing in.
- Treated HTTP 403 responses from Google Calendar/Tasks APIs as reconnect-required token/scope rejection, improving disconnection detection and recovery.

## [0.2.5+73] - 2026-08-05

### Fixed

- Fixed Google sign-in persistence so users no longer get prompted to re-authenticate when reopening the app.
- Improved background token refresh and calendar sync reliability across Web and Android.

## [0.2.5+72] - 2026-08-01

### Added

- Interactive priority selector grid with haptic feedback on the Add Task screen.
- Glowing gradient priority pills on task cards for quick visual urgency recognition.
- Interactive full-screen image lightbox previews and uppercase file type badges on attachments.
- Enlarged 48dp touch targets on pin and removal controls.

## [0.2.5+71] - 2026-08-01

### Added

- Interactive task attachment previews (tap to view full-screen images or open documents).
- Visual file type badges on attachments for quick file identification.

### Improved

- Ergonomic 48dp touch targets on attachment controls for easier tapping.
- Visual theme polish and dynamic glassmorphism performance.

## [0.2.4+70] - 2026-08-01

### Improved

- Upgraded offline storage engine for faster task loading and enhanced stability.
- Optimized background notification scheduling and Google account sync performance.

## [0.2.4+69] - 2026-08-01

### Changed

- Maintenance update and version sync.

## [0.2.4+68] - 2026-07-30

### Fixed

- Seamless background Google account re-authentication without popups.
- Resolved an issue where task lists could occasionally freeze after checking off items.

## [0.2.4+67] - 2026-07-24

### Added

- Interactive Task List mode with item checklists, auto-completion, progress tracking, and one-tap reset.
- Full Hindi (🇮🇳 हिंदी) language localization.
- Full-screen pinch-to-zoom image viewer for task attachments.

### Fixed

- Eliminated redundant Google Sign-In prompts on startup.
- Preserved task due time (hours/minutes) during Google Tasks synchronization.

## [0.2.3+65] - 2026-07-18

### Added

- Lemon Squeezy web checkout overlay modal for seamless web subscriptions.
- Cross-platform subscription sync between Web and Mobile apps.

### Improved

- Touch target hit area expanded to 48dp on task tiles.
- Wallpaper-aware dynamic color blending on glass containers.
- Faster list transition animations.

## [0.2.2+64] - 2026-07-18

### Fixed

- Web paywall stability and billing checkout sync.
- Pulsing loading skeletons to eliminate screen flickering.

### Added

- Background Google Tasks synchronization.

## [0.2.2+63] - 2026-07-17

### Added

- Two-way Google Tasks sync: completions and deletions propagate automatically.
- Reconnect notification banners when Google access token expires.

## [0.2.2+60] - 2026-07-16

### Fixed

- Resolved redundant Google Sign-In prompts on mobile by securely caching access tokens.

## [0.2.2+58] - 2026-07-16

### Added

- Google Calendar integration support for Web authentication and linking flows.

### Fixed

- Google Tasks scope permissions during mobile sign-in.

## [0.2.1+54] - 2026-07-04

### Added

- Full web version release.
- Custom theme, week number, and weekend options for the calendar widget.

### Changed

- Replaced widget selected day border with a bold brand-colored text style to avoid solid color block rendering bugs.
- Retained today's soft 10% opacity tint highlight.

## [0.1.20+49] - 2026-07-02

### Added

- Dynamic customization options for the full calendar widget (Themes, Week Numbers, Weekend Highlights) and a live mock preview.

### Changed

- Migrated task synchronization from Google Calendar to Google Tasks under a custom "ROCIs Tasks" list.
- Cleaned up static analysis warnings and resolved calendar import compilation errors.

## [0.1.19+48] - 2026-06-27

### Added

- Paywall protection and PRO locks for the Glassmorphism visual theme.
- Settings screen lock icon indicators for premium theme options.

### Changed

- Standardized the FAB design across Home and Categories screens (with solid primary coloring fallback for free users).

## [0.1.18+47] - 2026-06-26

### Fixed

- Positioned date numbers above events/tasks in calendar screen and Android home widget.
- Brought event indicators/titles closer to the date headers.
- Centered the "No events for this day" empty state in the calendar screen to fix vertical stretching.

## [0.1.17+46] - 2026-06-26

### Added

- Widget selection menu preview layout for the full calendar widget.
- Bouncy Easter Egg spin animations on double-tap/long-press on FABs and settings logo.
- Soft elevation shadows for cards, FABs, and navbar when glassmorphism is disabled.

### Fixed

- Widget single event/task title display, layout alignment, and color rendering.
- Better calendar screen selection readability using border outlines.

## [0.1.16+45] - 2026-06-26

### Added

- Symmetrical, custom-built bottom navigation bar vertical spacing.
- Dynamic FAB styling (glassy translucent/solid primary based on glassmorphism toggle).
- 10-18% color tinting in glass containers & borders.
- Show single task/event title directly on calendar screen cell.

### Fixed

- Android widget month & today buttons navigation offset updates natively (avoids freeze).
- Timeout for timezone queries in background isolates.

## [0.1.15+44] - 2026-06-25

### Added

- **Task completion haptic feedback:** Ticking a task off now triggers a satisfying medium haptic impact. Un-completing a task triggers a lighter haptic so the two actions feel distinct.
- **Settings toggle for completion feedback:** A new "Task Completion Feedback" toggle in the Productivity section of Settings lets users enable or disable the haptic pulse at any time. The preference is persisted across sessions.

## [0.1.14+43] - 2026-06-25

### Changed

- Completed the glassmorphism visual redesign across the remaining screens and sheets:
  - Upgraded the category screen list items and the category sheet to use the unified premium `GlassContainer`.
  - Converted the date/time picker button inside the new task screen to `GlassContainer` styling.
  - Redesigned the app guide sections to group items within premium glassy containers separated by thin dividers.
  - Restructured the task details view into structured glassy cards for properties, description, subtasks checklist, and attachments.
  - Redesigned the sorting and filtering sheets (Task Filters, Calendar Filters, Calendar Colors) to use high-opacity glass containers with custom rounded corners.
  - Re-styled trash screen items into glassy list elements.
  - Grouped premium feature showcase list items on the ROCIs Tasks Pro screen into a single glassy container card with separators.

## [0.1.13+42] - 2026-06-25

### Added

- Added a floating glassy bottom navigation bar with content extending underneath.
- Redesigned the "New Task" Floating Action Button to match the glassy visual style.
- Added custom glassy empty states for the Task List and Calendar Event List.
- Upgraded Google Calendar Event Tiles to use the unified premium GlassContainer style.

### Fixed

- Resolved all active static analysis warnings: replaced deprecated `withOpacity` with `withValues`, added missing curly braces in control structures, and replaced production `print` statements with `debugPrint`.

## [0.1.11+39] - 2026-06-25

### Changed

- UI Redesign: Implemented Glassmorphism style across the app.
- Added `GlassContainer` widget for frosted glass effect.
- Redesigned `TaskTile` to use `GlassContainer` and circular checkboxes.
- Redesigned `CalendarScreen` (Samsung Calendar style) to display events as horizontal bars inside day cells with custom styling for weekends and the current day.
- Added a subtle gradient background to the main `Scaffold` body to enhance the glassmorphism blur effect.

## [1.1.10+34] - 2026-06-13

### Added

- **Birthday Promo**: Free Pro access for all users from June 16 to July 16, 2026. After the promo ends, users who didn't pay return to the basic version. Premium screen shows "Birthday Promo - Free until July 16" during the promo period.

### Fixed

- **Widget Preview Layout**: Added `android:previewLayout` to Overdue Tasks, Quick Add, and Mini Calendar widget info XMLs to fix "couldn't add widget" error on some launchers.
- **Mini Calendar Widget**: Removed invalid `findViewById` call from `MiniCalendarWidgetProvider.kt` that caused build failures.

## [1.1.8+32] - 2026-06-13

### Added

- **Overdue Tasks Widget**: New Android home screen widget showing overdue incomplete tasks with priority colors, severity indicators, category badges, and due time labels. Includes add task button and empty state.
- **Quick Add Widget**: New minimal Android home screen widget with a + button for rapid task creation without opening the app. Tapping anywhere opens the add task screen.
- **Mini Calendar Widget**: New compact single-month calendar grid variant showing day numbers with event/task indicator dots and month navigation (prev/next/today). Simpler and smaller than the FullCalendar widget.
- **Localization regenerated** from ARB files with all new strings.

## [1.1.7+31] - 2026-06-13

### Added

- **Search Symbols**: Added @ for category, # for title, ! for priority, % for due date, & for subtask, \* for status, and ? for today filtering in search. Symbols are combinable (e.g. `@work !high`). Updated search hint text in all 7 locales.
- **Do Not Remind Option**: Added `skipReminders` field to Task model. Tasks with this option enabled will not schedule any notifications. Available to all users.
- **Private Task Security Prompt**: When creating a private task or category without security enabled, a dismissible dialog prompts the user to set up PIN/biometrics.
- **Attachments in Task Details**: Task detail screen now shows attached files with file-type icons and open functionality via `url_launcher`.
- **Search Symbols in App Guide**: Added a "Search Symbols" section to the app guide documenting all 7 search symbols.
- **New Widget Suggestions**: Documented Quick Add, Overdue Tasks, Weekly Summary, and Habit Tracker widget ideas.

### Fixed

- **Due Date Rescheduling**: Fixed `updateTask()` treating `dueDate: null` as "don't change" instead of "clear the date". Added `clearDueDate` parameter. Removed unconditional `recurrenceRule = null` wipe.
- **Task Counter Notification**: Added immediate task counter notification on task creation, bypassing the widget update debounce.

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

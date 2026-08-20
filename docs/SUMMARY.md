# Project Errors & Changes Summary

This file summarizes errors encountered and changes made to the codebase, ensuring new sessions can quickly align on the project's state.

## Guest Mode, Lifetime Paywall Plan & Onboarding Revamp - 2026-08-20

#### Goals / Requirements
* Eliminate signup friction with **Guest Mode / Delayed Authentication** (try all features immediately).
* Add a **Lifetime Pro Plan** on the Web Paywall to maximize conversion from users resisting subscriptions.
* Revamp **Onboarding Screen** to emphasize Google Tasks & Calendar 2-Way Sync, Glassmorphism UI, and Widgets.
* Maintain 100% localization (8 languages), unit tests, and version synchronization.

#### Changes/Fixes
1. **Guest Mode Core & Routing (`auth_service.dart`, `router.dart`)**:
   - Added `isGuestMode`, `continueAsGuest()`, and `exitGuestMode()` in `AuthService` with persistent `SharedPreferences` flag `is_guest_mode`.
   - Updated `AppRouter` redirect logic to grant immediate app access to guests (`hasAccess = isLoggedIn || isGuestMode`).
   - Automatically cleans up guest mode upon Google/Email authentication or explicit sign-out.
2. **Guest Mode UI & Banners (`login_screen.dart`, `settings_screen.dart`, `task_list_screen.dart`)**:
   - Added *"Continue as Guest"* action with person icon on `LoginScreen`.
   - Added guest status card in `SettingsScreen` with direct *"Sign In"* CTA and omitted unnecessary sign-out actions for guests.
   - Added a dismissible/non-intrusive `GlassContainer` guest banner on `TaskListView` encouraging users to sign in to sync with Google Tasks and secure cloud backups.
3. **Lifetime Pro Web Paywall (`app_config.dart`, `paywall_screen.dart`)**:
   - Configured `AppConfig.lemonSqueezyLifetimeUrl` checkout link.
   - Replaced 2-card web paywall layout with a 3-tier responsive selector (Monthly, Yearly with savings badge, Lifetime with Best Value badge).
4. **Onboarding Screen Revamp (`onboarding_screen.dart`)**:
   - Updated onboarding slides and iconography to showcase Google Tasks 2-way sync (`Icons.sync_alt_rounded`), Glassmorphic design (`Icons.auto_awesome_rounded`), and interactive widgets/habits (`Icons.widgets_rounded`).
5. **Localization & Testing**:
   - Added all new strings across 8 languages (`en`, `he`, `es`, `fr`, `de`, `ar`, `sv`, `hi`) and ran `flutter gen-l10n`.
   - Added unit test in `login_screen_test.dart` for guest mode flow.
   - Verified `flutter analyze` (0 issues) and `flutter test` (222/222 passing).
   - Bumped version to `0.2.7+75` in `pubspec.yaml`, `app_config.dart`, and `docs/CHANGELOG.md`.

## Timezone Selection & Calendar Synchronization - 2026-08-15

#### Goals / Requirements
* Add user option in Settings to change the app timezone (Automatic vs manual IANA selection).
* Ensure calendar events and timestamps sync accurately to the user-selected timezone.
* Provide full internationalization (8 languages) and unit test coverage.

#### Changes/Fixes
1. **Timezone Management Service (`timezone_service.dart`)**:
   - Created `TimezoneService` providing automatic (device) vs custom IANA timezone selection, offset formatting (`UTC+03:00`), and `SharedPreferences` persistence (`app_selected_timezone`).
   - Integrated into `AppInitializer._initTimezone` and `main.dart` `MultiProvider`.
2. **Calendar Sync UTC Mapping (`calendar_service.dart`)**:
   - Updated `_toTZDateTime` to convert parsed UTC DateTime objects into `tz.local` (`tz.TZDateTime.from(dt.toUtc(), tz.local)`).
3. **Settings UI Integration (`settings_screen.dart`)**:
   - Added Timezone `ListTile` showing current timezone and UTC offset.
   - Added searchable bottom sheet picker (`_TimezonePickerSheet`) with instant filter and Automatic mode toggle.
   - Triggered `calendarProvider.loadEvents()` on timezone change to instantly refresh calendar views.
4. **Localization (i18n)**:
   - Added `timezone`, `selectTimezone`, `automaticTimezone`, and `searchTimezone` to all 8 `.arb` files (`en`, `he`, `es`, `fr`, `de`, `ar`, `sv`, `hi`).
5. **Testing & Deployment**:
   - Added `test/core/services/timezone_service_test.dart` with 5 unit tests covering default state, sorting, explicit timezone setting, auto restore, and offset calculation.
   - Verified with `flutter analyze` (0 issues) and `flutter test` (221/221 tests passing).
   - Compiled web release bundle and deployed to Firebase Hosting.

## Google Calendar API 403 (Forbidden) Root Cause & Scope Expansion - 2026-08-15

#### Goals / Requirements
* Investigate Google Calendar API 403 (Forbidden) on Web (`/users/me/calendarList` and `/calendars/primary/events`).
* Add full calendar scope (`https://www.googleapis.com/auth/calendar`) to OAuth manager.
* Add detailed API error response logging and explain Google Cloud Console API enablement steps.

#### Changes/Fixes
1. **Google Calendar Scope Addition (`google_oauth_manager.dart`)**:
   - Added `https://www.googleapis.com/auth/calendar` to `googleTasksScopes` alongside `calendar.readonly` and `calendar.events`.
2. **Enhanced Calendar Error Logging (`calendar_service.dart`)**:
   - Logged HTTP response body on 401/403 status codes.
3. **Google Cloud Console API Enablement Guidance**:
   - Documented the requirement to enable the **Google Calendar API** in Google Cloud Console project `rocis-todo` (`867477199658`).
4. **Verification & Deployment**:
   - `flutter analyze`: 0 issues found.
   - `flutter test`: 216/216 unit and widget tests passed.
   - `flutter build web --release`: Compiled successfully.
   - `firebase deploy --only hosting`: Deployed live to Firebase Hosting.

## Web OAuth Reconnect & 403 Handling Fix - 2026-08-13

#### Goals / Requirements
* Restore reliable Google Tasks and Google Calendar reconnect behavior on Web.
* Ensure insufficient-scope/API-forbidden responses trigger proper reconnect state.

#### Changes/Fixes
1. **Web OAuth Consent Recovery (`auth_service.dart`)**:
   - Updated Web popup OAuth parameters from `prompt: select_account` to `prompt: consent` in both `signInWithGoogle()` fallback and `linkGoogleTasks()`.
   - This forces Google to re-issue access with the currently requested scopes instead of silently reusing a stale scope-deficient grant.
2. **Google Calendar 403 Handling (`calendar_service.dart`)**:
   - Updated Web read flows (`calendarList` and calendar `events` fetch) to treat HTTP `403` the same as `401` and surface `GoogleTokenExpiredException(..., true)`.
3. **Google Tasks 403 Handling (`google_tasks_service.dart`)**:
   - Updated list/create/update/delete/read calls to treat HTTP `403` as server token/scope rejection, aligning reconnect UX behavior with `401`.

## Web Google Calendar Reauth Access Token Fix & Android Startup Prompt Elimination - 2026-08-08

#### Goals / Requirements
* Fix Web issue where Google Calendar remained empty even after re-authenticating.
* Fix Android issue where app reprompted the user to sign in with Google on startup or authorization.
* Verify end-to-end web calendar operation and pass full automated test suite.

#### Changes/Fixes
1. **Platform-Aware Google OAuth Scopes (`google_oauth_manager.dart`)**:
   - Scope request updated so Mobile (Android/iOS) only requests `email` and `https://www.googleapis.com/auth/tasks`, removing sensitive Web REST API scopes (`calendar.readonly`, `calendar.events`) that triggered unwanted consent screens and blocked silent background authentication on Android.
   - Web retains full REST API scopes (`email`, `tasks`, `calendar.readonly`, `calendar.events`).
2. **Web & Mobile Silent OAuth Token Renewal (`google_oauth_manager.dart` & `auth_service.dart`)**:
   - Initialized `GoogleSignIn.instance` on Web with explicit `webClientId` (`867477199658-df3ptf7v5fi66ijc5jeunfmrpf5eghou.apps.googleusercontent.com`), allowing GIS SDK to authenticate and issue access tokens cleanly on Web targets.
   - Added an `authorizeScopes(googleTasksScopes)` fallback to `_performSilentTokenRefresh()` when `authorizationForScopes` returns null. On both Mobile and Web, when the 60-minute OAuth access token expires, the app now silently renews the token in the background without prompting the user to sign in again.
   - Cached all newly acquired access tokens in `SharedPreferences` (`google_access_token` and `google_access_token_expires_at`), eliminating startup reprompts on mobile devices.
3. **Android Startup Reprompt Elimination (`auth_service.dart`)**:
   - Updated `_restoreGoogleUser()` to check `providerData` and cached tokens before calling `attemptLightweightAuthentication()`. Email/Password users without linked Google Tasks now skip lightweight authentication on startup, eliminating native Credential Manager bottom sheet popups.
4. **Verification & Audit**:
   - `flutter analyze`: 0 issues found.
   - `flutter test`: 216/216 unit and integration tests passed.
   - `flutter build web --release`: Web compilation succeeded (110.5s).
   - Local web server verification: Static release assets load properly with HTTP 200 OK.

## Git Push Large Build Artifacts Cleanup - 2026-08-07

#### Goals / Requirements
* Resolve `git push` failure (`pre-receive hook declined: File ... is larger than GitHub's limit of 100.00 MB`).

#### Changes/Fixes
1. **Updated `.gitignore`**:
   - Expanded ignore rules to include `build/`, `**/build/`, `android/app/build/`, `android/build/`, and `repomix-output.xml`.
2. **Purged Build Artifacts from Commit History**:
   - Used `git filter-branch` across unpushed local commits to remove tracked build files (`android/app/build/` and `repomix-output.xml`).
3. **Pushed Cleaned Branch**:
   - Successfully executed `git push AG Public`.

## Web Google Calendar & Tasks Scope Consent & Reconnect Sync Fix - 2026-08-07

#### Goals / Requirements
* Fix issue on Web where clicking "Reconnect" repeatedly prompted the user to sign in and left the calendar completely blank.

#### Changes/Fixes
1. **Google OAuth Scope Consent Enforcement (`auth_service.dart`)**:
   - Added `googleProvider.setCustomParameters({'prompt': 'consent'})` on Web for both `signInWithGoogle()` and `linkGoogleTasks()`. This forces Google OAuth popup to prompt for updated/missing scopes (specifically `calendar.readonly` and `calendar.events`) rather than silently returning a cached, scope-deficient token.
2. **Expired Token Safeguard (`google_oauth_manager.dart`)**:
   - Updated `getGoogleAccessToken()` so that if an access token is expired and silent refresh returns `null` (on Web), it returns `null` instead of returning the stale expired token.
3. **CalendarProvider Token Reset (`calendar_provider.dart`)**:
   - Added `resetTokenExpiredState()` to clear `_isGoogleCalendarTokenExpired` state when re-authenticated.
4. **UI Reconnect Synchronization (`web_home_screen.dart` & `task_list_screen.dart`)**:
   - Updated Reconnect button handlers to reset token state and reload both `calendarProvider.loadEvents()` and `taskProvider.syncGoogleTasksToLocal()` post-reconnect.

## Security Hardening - 2026-08-06

### GitHub Actions Commit SHA Pinning (`flutter-ci.yml`)

#### Goals / Requirements
* Remediate supply-chain security findings caused by mutable tag references in `.github/workflows/flutter-ci.yml`.

#### Changes/Fixes
1. **Immutable Commit SHA Pinning**:
   - Pinned `actions/checkout` to `11bd71901bbe5b1630ceea73d27597364c9af683` (`# v4.2.2`).
   - Pinned `actions/setup-java` to `c5195efecf7bdfc987ee8bae7a71cb8b11521c00` (`# v4.7.1`).
   - Pinned `subosito/flutter-action` to `f2c4f6686ca8e8d6e6d0f28410eeef506ed66aff` (`# v2.18.0`).
   - Pinned `actions/cache` to `0c45773b623bea8c8e75f6c82b208c3cf94ea4f9` (`# v4.0.2`).
   - Pinned `actions/upload-artifact` to `ea165f8d65b6e75b540449e92b4886f43607fa02` (`# v4.6.2`).

## [0.2.5+73] - 2026-08-05

### Silent Google OAuth Token Refresh & Re-Sign-In Fix

#### Goals / Requirements
* Eliminate recurring Google Tasks / Calendar "Re-connect" re-sign-in prompts on Web and Android versions.

#### Changes/Fixes
1. **Web Google Calendar Scopes Fix (`auth_service.dart`)**:
   - Updated `signInWithGoogle()` on Web to request ALL scopes in `GoogleOAuthManager.googleTasksScopes` (including `https://www.googleapis.com/auth/calendar.readonly` and `https://www.googleapis.com/auth/calendar.events`).
   - Previously Web Google Sign-In only requested `tasks` scope, which caused Google Calendar API to return HTTP 403/401, resulting in empty web calendar lists and recurring re-authentication banners.
2. **Cached Token Fallback & Retry (`google_oauth_manager.dart`)**:
   - Added `return freshToken ?? token;` fallback in `getGoogleAccessToken()` so cached tokens are used as a fallback if silent background refresh returns `null` (e.g. startup race/network lag).
   - Added `isServerRejection` flag to `GoogleTokenExpiredException` to distinguish genuine HTTP 401/403 server rejections from transient token unavailability.
3. **CalendarService Web API Scope & Token Pipeline (`calendar_service.dart`)**:
   - Handled both HTTP 401 Unauthorized and HTTP 403 Forbidden status codes from Google Calendar API.
   - Routed Web calendar requests through `AuthService`'s managed token pipeline via `_getWebAccessToken()`.
   - Wired `_calendarService.setAuthService(_authService)` in `main.dart`.
4. **GoogleTasksService Token Retry (`google_tasks_service.dart`)**:
   - Added token retrieval retry in `_getAccessToken()` before throwing.
   - Marked HTTP 401/403 status code throws as `isServerRejection: true`.
5. **Expiration Flagging Scoped to Server Rejections (`task_sync_manager.dart`, `calendar_provider.dart`)**:
   - Updated catch blocks to set `isGoogleTasksTokenExpired` / `isGoogleCalendarTokenExpired` to `true` strictly when `e.isServerRejection` is true.

## [0.2.5+72] - 2026-08-01

### Full UI/UX Visual Redesign & App Version Bump to 0.2.5+72

#### Goals / Requirements
* Execute comprehensive UI/UX visual redesign across Task Cards (`TaskTile`), Add Task Screen (`AddTaskScreen`), attachments, and theme guidelines in alignment with `ui-ux-pro-max` design system rules.
* Synchronize version bump across `pubspec.yaml`, `app_config.dart`, `CHANGELOG.md`, and `SUMMARY.md`.

#### Changes/Fixes
1. **Task Card Redesign (`task_tile.dart`)**:
   - Replaced static priority dots with glowing, rounded priority pill badges (`HIGH`, `MED`, `LOW`) styled in priority tint colors (`#FF5252`, `#FFAB40`, `#69F0AE`).
   - Enlarged pin action icon touch target constraints to `44x44 dp`.
2. **Add / Edit Task Screen Redesign (`add_task_screen.dart`)**:
   - Upgraded dropdown priority selector to an interactive 3-card priority grid selector (`High`, `Medium`, `Low`) with active glow borders and haptic feedback (`HapticFeedback.lightImpact()`).
3. **Version Synchronization**:
   - Bumped `pubspec.yaml` version to `0.2.5+72`.
   - Synchronized `app_config.dart` (`appVersion = '0.2.5'`).
   - Added user-facing release notes under 500 characters to `docs/CHANGELOG.md`.
4. **Verification**: `flutter analyze` — 0 issues; `flutter test` — 216/216 tests passed.

## [0.2.5+71] - 2026-08-01

### UI/UX Design System Guidelines & Task Attachment Component Enhancements

#### Goals / Requirements
* Perform comprehensive UI/UX Pro Max analysis and update `THEME_STYLE_GUIDE.md` with modern micro-interaction, haptic, 48dp touch target, and pre-delivery checklist guidelines.
* Implement UI/UX recommendations in `TaskAttachmentsSection` (`lib/features/tasks/presentation/widgets/task_attachments_section.dart`), including interactive tap-to-preview attachment handlers, enlarged 48dp removal touch targets, and non-image extension badges.
* Add unit test coverage for `TaskAttachmentsSection`.

#### Changes/Fixes
1. **Design System Documentation (`THEME_STYLE_GUIDE.md`)**:
   - Added `TaskAttachmentsSection` chip styling, file badge, and thumbnail specifications.
   - Added Touch Target Ergonomics section enforcing minimum 48×48 dp interactive hit target accessibility standards.
   - Added Skeleton & Contextual Empty State rules (shimmer skeletons over full-screen block spinners, vector empty states, no raw emojis as UI icons).
   - Added Pre-Delivery UI/UX Quality Checklist.
2. **Component UI/UX Implementation (`task_attachments_section.dart`)**:
   - Integrated `AttachmentUtils.openAttachment(context, path)` on attachment chip tap (opening pinch-to-zoom modal for images or native external handler for documents).
   - Expanded remove button (`Icons.close`) touch area to 48×48 dp with `InkWell` padding.
   - Added uppercase file extension badges (e.g. `PDF`, `DOCX`, `TXT`) for non-image attachments.
   - Added tooltip accessibility to `IconButton`.
3. **Widget Unit Testing (`task_attachments_section_test.dart`)**:
   - Created unit tests verifying empty state rendering, file extension badges, filename truncation, tap callbacks, and removal interactions under `MultiProvider`.
4. **Verification**: `flutter analyze` — 0 issues; `flutter test` — All tests passed.

## [0.2.4+70] - 2026-08-01

### Architectural Refactoring, Modularization & Hive CE Migration

#### Goals / Requirements
* Modularize `TaskProvider` (2,058 lines) into dedicated domain helpers while preserving 100% public API compatibility.
* Migrate local persistence from abandoned `hive: ^2.2.3` / `hive_flutter: ^1.1.0` to community-maintained `hive_ce`.
* Expand test coverage with dedicated unit tests for filtering, notification scheduling, and OAuth management.
* Extract `GoogleOAuthManager` from `AuthService` and reusable section widgets from `add_task_screen.dart`.

#### Changes/Fixes
1. **TaskProvider Modularization**: Split into `TaskFilterService`, `TaskNotificationManager`, and `TaskSyncManager` under `lib/features/tasks/presentation/providers/helpers/`.
2. **Hive CE Migration**: Swapped `hive` / `hive_flutter` for `hive_ce: ^2.7.0`, `hive_ce_flutter: ^2.3.0`, and `hive_ce_generator: ^1.4.0`. Updated imports across 9 core files.
3. **AuthService Refactor**: Extracted `GoogleOAuthManager` (`lib/core/services/auth/google_oauth_manager.dart`).
4. **Widget Extraction**: Created `TaskAttachmentsSection` widget in `lib/features/tasks/presentation/widgets/`.
5. **Unit Tests**: Added `task_filter_service_test.dart`, `task_notification_manager_test.dart`, and `google_oauth_manager_test.dart`.
6. **Verification**: `flutter analyze` — 0 issues; `flutter test` — 214/214 tests passed.

## [0.2.4+69] - 2026-08-01

### Version Bump to 0.2.4+69

#### Goals / Requirements
* Increase app build version by one to 0.2.4+69.

#### Changes/Fixes
1. Updated `pubspec.yaml` to `0.2.4+69`.
2. Synchronized `lib/core/config/app_config.dart` (`0.2.4`).
3. Updated release notes in `docs/CHANGELOG.md` and `docs/SUMMARY.md`.

## [0.2.4+68] - 2026-07-30

### Silent Background Google Token Renewal & Task List Stream Sync Fix

#### Goals / Requirements
* Keep Google Tasks & Calendar integration connected perpetually in background without popups or manual re-authentication button presses.
* Fix `_pendingLocalWrites` memory leak in `updateTask()` and `toggleSubTask()` that caused Task List items to become permanently locked out of Firestore stream updates after auto-completion.

#### Changes/Fixes
1. **Silent Background Google Token Renewal (`auth_service.dart`)**:
   - Added single-flight concurrency lock (`_tokenRefreshCompleter`) to prevent concurrent task/calendar sync calls from launching duplicate refresh operations.
   - When cached token is valid (within 55 min), returns cached token immediately (0 popups, 0 network calls).
   - When cached token expires, `_performSilentTokenRefresh()` restores `_googleUser` handle in memory via `attemptLightweightAuthentication()` and uses `authorizationForScopes()` to retrieve fresh 1-hour OAuth access tokens silently in the background.
2. **Pending Write Cleanup (`task_provider.dart`)**:
   - Added `.whenComplete()` with 15-second delayed `_pendingLocalWrites.remove(taskId)` to `updateTask()` and `toggleSubTask()` Firestore calls.

#### Verification
- `flutter analyze`: 0 issues.
- `flutter test`: 201/201 tests passed.

## [0.2.4+67] - 2026-07-24

### Google Auth Silent Refresh, Google Tasks Due Time Sync, Grocery List Feature & Attachment Viewer Fix

#### Goals / Requirements
* Resolve recurring Google sign-in prompts for authenticated users when access token expires.
* Synchronize task due time (hours and minutes) to and from Google Tasks API.
* Implement a dedicated Grocery / Shopping Cart list mode for tasks.
* Fix task attachment viewing failure across platforms.

#### Changes/Fixes
1. **Attachment Viewer Utility (`attachment_utils.dart`)**:
   - Created robust `AttachmentUtils` class for image and file attachments.
   - Built interactive full-screen preview dialog with pinch-to-zoom (`InteractiveViewer`) for images (`.png`, `.jpg`, `.jpeg`, `.webp`, `.gif`, `.bmp`).
   - Implemented cross-platform path parsing (handling Windows `\` vs Unix `/` separators) and dual launcher fallback (`LaunchMode.externalApplication` -> `LaunchMode.platformDefault`).
   - Wired attachment tap handlers in both `TaskDetailScreen` and `AddTaskScreen`.
2. **Elimination of Google Sign-In Startup Popups (`auth_service.dart`)**:
   - Removed automatic `attemptLightweightAuthentication()` calls on cold start from `_initAuth()`, `ensureSecondaryAuth()`, and `getGoogleAccessToken()`.
   - Google access tokens cached in `SharedPreferences` are read directly without triggering native Credential Manager UI sheets on startup.
3. **Task Completion Stream Reversion Fix & Notification Counter (`task_provider.dart`)**:
   - Fixed race condition where active tasks stream `SyncEventType.removed` events triggered `fetchTaskById` network calls that returned stale snapshots (`isCompleted: false`) and reverted completed tasks locally. Now, local completion state in Hive is preserved immediately during pending writes.
   - Extended `_pendingLocalWrites` timeout from 3s to 15s to cover slow mobile network latencies.
   - Added immediate `_updateTaskCounterNotification()` calls inside `toggleTaskCompletion`, `deleteTask`, and `restoreTask` so notification counter badges update instantly when a task is checked off as done.
3. **Google Tasks Due Time Sync (`google_tasks_service.dart` & `task_provider.dart`)**: Preserved exact due hours/minutes in Google Tasks API payloads using ISO 8601 UTC timestamps, and reconciled due time when syncing back to local database.
4. **Interactive Task List Mode (`task.dart`, `sub_task.dart`, `task_detail_screen.dart`, `add_task_screen.dart`, `task_tile.dart`)**:
   - Renamed Grocery/Shopping List mode to **Task List** across all UI screens and localized ARB files.
   - Removed the title check option on `TaskTile` and `TaskDetailScreen` for task lists so main list completion is governed solely by list items.
   - Implemented auto-completion logic in `TaskProvider`: when all subtasks in a Task List are checked off, the main task list automatically marks as completed; checking off a new subtask or un-checking any item automatically resets the main task list to active.
   - Added checklist badges (`Icons.checklist_rounded`) on `TaskTile` and `AddTaskScreen` switch options.
5. **i18n Localization**: Added 9 new localized strings across all 8 supported languages (`app_en.arb`, `app_ar.arb`, `app_de.arb`, `app_es.arb`, `app_fr.arb`, `app_he.arb`, `app_sv.arb`, `app_hi.arb`).
6. **Zero Lint Compliance**: Resolved all IDE static analyzer warnings across `add_task_screen.dart`, `task_detail_screen.dart`, and `attachment_utils.dart` (`flutter analyze` returned 0 issues).

## [0.2.3+65] - 2026-07-23

### AGP 9 Migration Audit & Compatibility Findings

#### Goals / Requirements
* Attempt manual migration to Android Gradle Plugin (AGP) version `9.0.0` and Gradle `9.1.0` per `/agp-9-upgrade` skill instructions.
* Create full backup records of configuration files prior to edits to enable instant restoration.

#### Findings & Outcome
1. **Full Backup Preservation**: Saved original configuration copies in `android/agp9_backup/` (`gradle-wrapper.properties`, `settings.gradle.kts`, `app_build.gradle.kts`, `root_build.gradle.kts`, `gradle.properties`).
2. **Flutter Plugin Legacy API Requirement**: Running AGP 9 with built-in Kotlin resulted in `java.lang.NullPointerException` inside `FlutterPluginUtils.kt` (from Flutter SDK `flutter_tools/gradle`). Flutter's Gradle plugin and several installed Flutter plugins (`device_calendar`, `dynamic_color`, `firebase_analytics`, `home_widget`, etc.) rely on legacy AGP 8 interfaces (`BaseExtension`, `ApkVariant`, `BaseVariantOutput`) that are completely removed/hidden in AGP 9.
3. **Restoration & Verification**: Successfully restored all configuration files from `android/agp9_backup/`. Verified `./gradlew.bat help` completes with **BUILD SUCCESSFUL** under AGP `8.12.3` and Gradle `8.14`.

## [0.2.3+65] - 2026-07-23

### Hindi Localization & NotebookLM Knowledge Grounding Documentation

#### Goals / Requirements
* Add full Hindi (`hi`) language localization to the app.
* Generate a complete set of source documents for NotebookLM upload (`docs/notebooklm/`) to enable AI feature planning discussions.

#### Changes/Fixes
1. **Hindi ARB Translation (`app_hi.arb`)**: Added `lib/l10n/app_hi.arb` containing complete Hindi translations for all 388+ localized strings.
2. **Global Language Name Registration**: Added `"hindi"` key across all ARB files (`app_en.arb`, `app_ar.arb`, `app_de.arb`, `app_es.arb`, `app_fr.arb`, `app_he.arb`, `app_sv.arb`).
3. **Locale Helper & Settings Modal**: Updated `l10n_helper.dart` `supportedLanguageCodes` to include `'hi'` and added Hindi option (`🇮🇳 हिंदी`) in `SettingsScreen`.
4. **NotebookLM Documentation Package**: Created `docs/notebooklm/` containing four structured markdown guides:
   - `01_PROJECT_OVERVIEW.md`: Technical stack, value prop, directory layout.
   - `02_ARCHITECTURE_AND_FEATURES.md`: TaskProvider, search symbols, theme engine, biometrics, billing.
   - `03_DEVELOPER_GUIDE_FOR_ADDITIONS.md`: Guidelines for adding screens, i18n keys, versioning.
   - `04_FULL_CODEBASE_SUMMARY.md`: Consolidated models (`Task`, `Category`) and core service APIs.

## [0.2.3+65] - 2026-07-18

### Web Checkout Overlay, Cross-Platform Billing, and UI Optimizations

#### Goals / Requirements
* Enable the Lemon Squeezy JS checkout overlay modal inside the web app for a native checkout feel.
* Create a secure and free webhook listener without upgrading Firebase to the paid Blaze plan.
* Implement a robust, two-way cross-platform premium sync between Web (Lemon Squeezy) and Mobile (RevenueCat).
* Expand the checkbox touch hit target in task tiles to meet touch standard guidelines (48dp) without altering original visual alignment.
* Integrate GlassContainer backgrounds dynamically with wallpaper-derived Material You colors.
* Increase responsiveness of list load transitions.

#### Changes/Fixes
1. **Lemon Squeezy Overlay Modal**: Added the official Javascript CDN loader and conditional platform-safe JS interop handlers (`web_helper_web.dart`, `web_helper_stub.dart`) to trigger modal checkouts without compile errors on mobile targets.
2. **Pipedream Webhook Integration**: Set up Pipedream webhook signature verification and Firestore admin updates to stay on the free Firebase Spark plan.
3. **Two-Way Cross-Platform Sync**: Updated `SubscriptionService` to track premium status from both Firestore and RevenueCat. Mobile apps now back-sync RevenueCat entitlements to Firestore, and listen to Firestore to unlock Web purchases on mobile.
4. **Ergonomic Checkbox Target**: Wrapped the task tile checkbox gesture detector in padding to expand the interactive zone to 48dp x 48dp, and adjusted tile margins to preserve pixel-perfect visual alignment.
5. **Wallpaper-Aware Glassmorphism**: Updated GlassContainer to blend background highlights dynamically with `theme.colorScheme.surface` instead of static Navy/White values when Material Theme is active.
6. **Snappy Staggered Lists**: Reduced task list animation offsets to `30.0` and durations to `250ms` for faster page loads.
7. **Mock Stub Restoration**: Added `useMaterialTheme` stub inside `task_tile_test.dart` to prevent mock crashes during widget verification.

## [0.2.2+64] - 2026-07-18

### Web Paywall Fix, Gradle & Build Optimization, and Live Lemon Squeezy Integration

#### Goals / Requirements
* Address Web paywall crashes due to unsupported RevenueCat/purchases_ui_flutter widgets.
* Fix Gradle build, R8 shrinking, and subproject namespace compiler failures.
* Minimize empty state flickering during calendar and task load.
* Optimize app startup memory by deferring non-default localization loading.
* Replace simulated web premium state with an operational Lemon Squeezy billing flow and Firestore sync.

#### Changes/Fixes
1. **Live Web Billing Redirect**: Configured custom pricing card selections in `WebPaywallView` to redirect users directly to Lemon Squeezy subscription checkouts, passing the user's Firebase UID.
2. **Real-time Entitlement Synchronization**: Added a Firestore stream listener in `SubscriptionService` on Web to synchronize `is_premium` changes directly from the database and cache them locally in `SharedPreferences`.
3. **Secure Webhook Cloud Function**: Created a JavaScript Firebase Cloud Function (`functions/index.js`) to verify HMAC signatures of incoming Lemon Squeezy payment webhooks and update user documents.
4. **Release Build & R8 Stabilization**: Suppressed Play Core package warnings and standardized layout variables to fix AAB bundle generation.
5. **Gradle & Dependency Alignments**: Coalesced subproject blocks, standardizing on AGP `8.12.1` and Kotlin `2.1.10` with `compileSdk 36` to fix compiler crashes.
6. **Pulsing Loaders**: Expanded `TaskListSkeleton` and `TaskTileSkeleton` across Calendar and Task Dashboard lists to prevent flashing.
7. **Background Sync**: Synced background task notifications back to Google Tasks and corrected construction arguments.
8. **Cold Start & Lazy Load**: Enabled deferred l10n library loading and delayed `CalendarScreen` building until active navigation.

## [0.2.2+63] - 2026-07-17

### Decoupled UI Bindings from Background Isolate & Test Suite Restoration

#### Error/Issue

* Accessing `WidgetsBinding.instance` in the background isolate is unstable and throws runtime errors on some platforms.
* The test suite had two failing tests due to version format validation and an unstubbed Mocktail method for `getGoogleAccessToken()`.

#### Changes/Fixes

1. **Background Isolate Stabilization**: Replaced `WidgetsBinding.instance.platformDispatcher` with `PlatformDispatcher.instance` in `BackgroundHandler._completeTaskInBackground` to avoid accessing uninitialized bindings in background threads.
2. **Version Regex Fix**: Updated the validation regex in `app_config_test.dart` to match version strings with build numbers (e.g., `0.2.2+63`).
3. **Mocking Fix**: Added a default stub for `getGoogleAccessToken()` in `task_provider_test.dart` to prevent Mocktail type casting errors during startup synchronization.

### Google Tasks Back-Sync (Completions, Uncompletions, and Deletions)

#### Feature Request

Synchronize task status updates made directly inside Google Tasks (completions, uncompletions, and deletions) back to ROCIs Tasks.

#### Changes/Fixes

1. **GoogleTasksService Endpoint Expansion**: Added a paginated `getTasks()` method to retrieve all tasks from the synced task list, requesting completed and hidden items.
2. **Reconciliation Logic**: Implemented `syncGoogleTasksToLocal()` in `TaskProvider` to check local tasks status against the returned Google Tasks list:
   * Mark as completed locally if completed on Google Tasks.
   * Mark as uncompleted/active locally if unchecked on Google Tasks.
   * Mark as deleted/trash locally if missing (deleted) from Google Tasks.
3. **Execution Triggers**:
   * Asynchronously on startup / initialization (`syncWithCloud`).
   * Awaited on manual sync via Settings screen ("Sync Now").
   * Triggers on page/tab change when selecting or swiping to the Tasks view on Mobile (`home_screen.dart`) and Web (`web_home_screen.dart`).
4. **Version Sync**: Synchronized app version to `0.2.2+63` in `app_config.dart`.

## [0.2.2+62] - 2026-07-17

### Google Tasks Sync Failures & Disconnection Handling

#### Error/Issue

Even after caching fixes, Google Tasks sync still failed on both platforms because:

* **Root Cause 1**: Google Tasks API was not enabled on the Google Cloud Console for the project.
* **Root Cause 2**: Access tokens expire after 60 minutes. When silent token refresh failed or was bypassed on Web, the API threw `GoogleTokenExpiredException` which was silently ignored by the `TaskProvider`, causing sync to fail indefinitely without user feedback.
* **Root Cause 3**: There was no silent token refresh logic implemented for Web, meaning Web users had to manually sign in again after 1 hour.

#### Changes/Fixes

1. **API Enablement**: Enabled Google Tasks API in the Google Cloud Console.
2. **Platform-Agnostic Silent Refresh**: Added silent scope authorization client requests in `getGoogleAccessToken()` for both Web and Mobile.
3. **Reactive Token Expiration State**: Exposed a `isGoogleTasksTokenExpired` boolean flag in `AuthService` (ChangeNotifier).
4. **Reconnection UI banners**: Added warning banners at the top of the Tasks tab (Mobile) and sidebar (Web) using beautiful Glassmorphism design system rules. Tap-to-reconnect allows seamless user self-healing.
5. **Localization**: Registered localized strings for warning texts across all supported language ARB files and regenerated classes.

## [0.2.2+60] - 2026-07-17

### Google Tasks Sync Multiple Prompts Regression

#### Error/Issue

On mobile (Android/iOS), users were being prompted multiple times to sign in with Google (specifically when tapping the Google Tasks sync toggle and again after pressing the "Create Task" button).

* **Root Cause 1**: Google Sign-In v7 is decoupled: Authentication (ID token) and Authorization (Access token/scopes) are separate steps. `attemptLightweightAuthentication()` is not always silent on Android (it can trigger a Credential Manager overlay chooser). Calling it repeatedly inside `getGoogleAccessToken()` whenever the cache was missing/expired caused back-to-back native prompts.
* **Root Cause 2**: The authenticated `GoogleSignInAccount` object was never saved in memory. Each call to get the access token had to start from scratch.
* **Root Cause 3**: The app requested the Google Calendar scope (`https://www.googleapis.com/auth/calendar`) on mobile. This was redundant because mobile uses `device_calendar` (native OS calendar integration) rather than calling the Google Calendar REST API directly. This triggered extra, scary permission consent prompts.

#### Changes/Fixes

1. **In-Memory Caching**: Added `_googleUser` field in `AuthService` to keep the active `GoogleSignInAccount` session in memory.
2. **Stream Synchronization**: Listened to `_googleSignIn.authenticationEvents` stream on startup to automatically synchronize the active session and silently refresh/cache the token.
3. **Smart Startup Restoration**: Implemented `_restoreGoogleSignInSession()` on startup. It silently restores the session via `attemptLightweightAuthentication()` **only** if the user previously logged in via Google or has linked Google Tasks (preventing generic Email/Password users from ever getting a prompt).
4. **Scope Separation**: Split the requested Google scopes by platform:
   * **Web**: `email`, `profile`, `auth/tasks`, `auth/calendar`
   * **Mobile**: `email`, `profile`, `auth/tasks` (removed calendar scope)
5. **Unified Token Caching**: Enabled SharedPreferences access token caching on Mobile (previously only on Web), ensuring the token survives app restarts.
6. **Sign-out Cleanup**: Updated `signOut()` to clean up the cached Google access token from SharedPreferences on all platforms.

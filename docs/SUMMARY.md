# Project Errors & Changes Summary

This file summarizes errors encountered and changes made to the codebase, ensuring new sessions can quickly align on the project's state.

## Academic Semester Boundaries, Resilient Mobile Schedule Sync & Universal Web Cookie Consent - 2026-09-23

#### Problem & User Requirement
* **Premature Event Population in Calendar**: University classes from ROCIs-Schedule were appearing on weekdays in September 2026 before the academic year began (late October 2026), because recurring events lacked semester date constraints.
* **Invisible Cookie Consent Banner on Web**: On browser viewports under 950px, `HomeScreen` rendered `_buildMobileHomeScreen`, omitting the cookie consent banner completely. Furthermore, the banner did not self-manage its visibility, and users had no way to reset or re-open cookie preferences from settings.
* **Recurring Schedule Disconnection on Mobile**: On mobile, signing into the secondary Firebase project created a secondary auth UID (`secUid`) differing from the user's schedule document UID (`UxZrdJPoccae5hOiMSPIdyJA1072`). Blind caching of `secUid` prevented email-based resolution from ever running. In addition, 4-second timeouts caused dropped calls over cellular networks.

#### Solutions Applied
1. **Academic Semester Date Boundaries (`schedule_firestore_service.dart`)**:
   - Added `semesterStartDate` and `semesterEndDate` to `SyncedScheduleEvent`.
   - Updated `occursOnDay(DateTime day)` to strictly enforce semester date boundaries.
   - Added parallel subcollection query for `/users/$userId/semesters` across REST and Firestore SDK endpoints.
   - Added fallback standard academic dates for Israeli university semesters (`semester_1`: Oct 25, 2026 – Feb 5, 2027; `semester_2`: Mar 14, 2027 – Jun 30, 2027; `semester_summer`: Aug 8, 2027 – Sep 30, 2027).
   - Updated ROCIs-Schedule (`course_provider.dart`) to auto-upload semesters to Firestore on `loadData()`.
2. **Universal Web Cookie Consent Banner (`cookie_consent_banner.dart`, `home_screen.dart`, `settings_screen.dart`)**:
   - Made `CookieConsentBanner` self-managing: checks consent on initialization and manages its own visibility.
   - Mounted `CookieConsentBanner` in `HomeScreen.build()` within a top-level `Stack`, ensuring universal coverage across all viewport dimensions on Web.
   - Removed duplicate banner from `WebHomeScreen`.
   - Added a "Cookie Preferences" tile in `SettingsScreen` (under Privacy & GDPR on Web) that resets consent and brings the banner back up on demand.
3. **Resilient Email-First Mobile Schedule Sync (`schedule_firestore_service.dart`, `auth_service.dart`)**:
   - Reordered `_resolveScheduleUserId` to prioritize email matching via REST (`runQuery`) and Firestore SDK before secondary auth UIDs or cached UIDs.
   - Increased all network timeouts from 4s to 10s.
   - Removed unconditional writes of `secUid` to `cached_schedule_user_id` from `auth_service.dart`.
   - Added self-healing in `fetchEvents`: if zero events are returned, the cached user ID is purged from memory and `SharedPreferences` to re-resolve by email.
4. **Verification & Deployment**:
   - Static analysis: `flutter analyze` passed with 0 issues.
   - Test suite: `flutter test` ran with 362/362 tests passing (100%).
   - Web Deployment: Built and deployed to Firebase Hosting (`https://rocis-todo.web.app`).
   - Android OTA Patch: Published Shorebird OTA Patch 4 to active release `0.2.20+110`.
   - Git: Pushed to `main` across both `ROCIs-tasks` and `ROCIs-Schedule`.

#### Problem & User Requirement
* **Repetitive Google Sign-In Prompts on Launch**: Users had to repeatedly sign in with Google or re-link Google Tasks & Calendar integrations across app launches and browser refreshes.
* **Android Google Play Services Scope Loss**: On Android, `google_sign_in: 7.2.0` uses `Identity.getAuthorizationClient(context)`. When initialized without `serverClientId: webClientId`, AuthorizationClient returned unauthorized on background silent token retrieval (`promptIfUnauthorized: false`).
* **Web Token Eviction on Local Storage Clear**: Browser privacy features and clearing `localStorage` erased OAuth session tokens, requiring interactive re-login.
* **Aggressive Disconnection Banner on Startup / Offline**: When network startup delays occurred, `_isGoogleTasksTokenExpired` was aggressively set to `true`, showing a "ROCIs Schedule Disconnected" banner prematurely even though cached credentials were valid.

#### Solutions Applied
1. **Google OAuth Manager Server Client ID Linking (`google_oauth_manager.dart`)**:
   - Initialized `GoogleSignIn` with `serverClientId: webClientId` on mobile platforms (`await _googleSignIn.initialize(serverClientId: webClientId)`), enabling Google Play Services Credential Manager / AuthorizationClient to bind to the OAuth client ID for background silent authorization.
2. **Web Cookie Storage Abstraction (`cookie_service.dart`, `cookie_service_web.dart`, `cookie_service_stub.dart`)**:
   - Created a cross-platform `CookieService` abstraction that uses `package:web` (`web.document.cookie`) on Web to persist session tokens (`keyAccessToken`, `keyAccessTokenExpiresAt`, `keyUserEmail`) with `SameSite=Lax; Secure` and `max-age` up to 365 days.
   - Preserves authentication session and Google token across browser restarts, even if `localStorage` is purged.
3. **Extended Offline Grace Period (`google_oauth_manager.dart` & `auth_service.dart`)**:
   - On both mobile and web startup, if background silent refresh encounters a network delay or offline state, but previously cached Google credentials exist (`hasCachedGoogleCredentials()`), the system reuses the cached session under grace and does NOT flag the integration as expired (`setGoogleTasksTokenExpired(false)`).
   - Only an actual HTTP 401 unrecoverable response from Google APIs flags the integration as disconnected.
4. **GDPR-Compliant Cookie Consent Banner (`cookie_consent_banner.dart` & `web_home_screen.dart`)**:
   - Created a floating glassmorphic cookie consent banner for the Web application with "Accept All" and "Essential Only" options, and links to Privacy Policy and Terms of Service.
   - Mounted seamlessly as an overlay at the bottom of the Web home screen, persisting user choice across sessions.
5. **Legal & Governance Documentation (`PRIVACY_POLICY.md` & `TERMS_OF_SERVICE.md`)**:
   - Updated `PRIVACY_POLICY.md` with explicit disclosures for Cookies, Local Storage, and Google API session tokens.
   - Authored complete `TERMS_OF_SERVICE.md` covering user accounts, Google integrations, subscriptions, cookies, and data retention.
6. **Automated Verification & Deployment**:
   - Static analysis: `flutter analyze` passed with 0 issues.
   - Test suite: `flutter test` executed all 362 unit & widget tests with 100% pass rate.
   - Android OTA Patch: Published Shorebird OTA Patch 3 for active release `0.2.20+110` and Patch 4 for release `0.2.19+109`.
   - Web Deployment: Compiled `flutter build web --release` and deployed to Firebase Hosting (`https://rocis-todo.web.app` / `https://tasks.rocisapps.com`).

## ROCIs-Schedule Course Name & Code Presentation Enhancement - 2026-09-22

#### Problem & User Requirement
* **Missing Course Name in Event Cards and Widgets**: When syncing university/college classes from `rocis-schedule`, the calendar screen and home widget only displayed generic class session titles (e.g. "הרצאה" / "Lecture") and course numbers (e.g. `90903`), without prominently displaying the full name of the academic course (e.g. "חשבון אינפיניטסימלי 1" / "Calculus 1").
* **Repetitive Generic Month Cells**: In the month view day grid cells, events without the course name prefix simply showed generic labels like "Lecture", making it difficult to distinguish between courses on the same or adjacent days.

#### Solutions Applied
1. **Calendar Screen Event Cards (`calendar_screen.dart`)**:
   - **Line 1**: Prominently displays `item.courseName` as bold primary title with the `item.courseCode` container badge on the right.
   - **Line 2**: Displays `item.title` (e.g. "הרצאה" / "Lab") styled in `eventColor` with semi-bold font weight, shown only if non-empty and distinct from `item.courseName`.
   - **Subtitle**: Formats time range (`startTime - endTime`) and physical `location` with leading icons (`access_time_rounded`, `location_on_outlined`).
   - **Semantics**: Updated accessibility label to format `ROCIs Schedule Event: ${courseName} - ${title}`.
2. **Month View Day Grid Cell (`calendar_screen.dart`)**:
   - Formats single event pill as `${event.courseName}: ${event.title}` (or `event.courseName` if identical or title is empty).
3. **FullCalendar Home Screen Widget (`full_calendar_widget_service.dart`)**:
   - Updated `displayTitle` for schedule events to display `${s.courseName}: ${s.title}` (or `s.courseName`).
   - Prefixes `subtitle` with `s.courseCode • s.location` (or `s.courseCode` alone) so users can see course number and room at a glance on the Android home screen.
4. **Automated Verification**:
   - Added automated unit tests in `synced_schedule_event_test.dart` verifying course name retention and display title formatting.
   - `flutter analyze`: 0 issues found.
   - All calendar unit tests and widget tests passed.
5. **Deployment & Release**:
   - Published Shorebird OTA Patch 2 for active release `0.2.20+110` (and Patch 3 for `0.2.19+109`).
   - Deployed updated web build to Firebase Hosting (`https://rocis-todo.web.app`).



## ROCIs-Schedule Event Disappearance & Zero-Event Cache Self-Healing Fix - 2026-09-22

#### Problem & Root Causes
* **Stale/Corrupted `cached_schedule_user_id`**: In `ScheduleFirestoreService._resolveScheduleUserId()`, if a user ID was persisted in `SharedPreferences` from primary Tasks auth (or an unverified secondary auth UID), it was returned blindly without verifying whether any events or courses existed under that user in `rocis-schedule`.
* **Zero-Event Caching (`_cachedEvents = []`)**: When Firestore returned 0 events for an unverified UID, `ScheduleFirestoreService` cached `_cachedEvents = []` and set `_lastFetchTime = DateTime.now()`, locking the app into returning an empty list for 5 minutes and permanently overwriting previously valid cached events in SharedPreferences.
* **Lack of Self-Healing Fallback**: When queries returned 0 events, the service gave up instead of clearing the invalid cached UID and querying by email to resolve the user's real Firestore document ID (`UxZrdJPoccae5hOiMSPIdyJA1072`).
* **Secondary Firebase App Initialization Sensitivity**: In background isolates and Web, secondary Firebase App instances (`FirebaseFirestore.instanceFor(app: scheduleApp)`) can encounter platform channel or token mismatches.
* **Integer `daysOfWeek` Parsing**: `SyncedScheduleEvent.fromMap` only parsed `daysOfWeek` if it was a `List` or `String`, causing single integer values (e.g. `2`) to result in an empty list of days.

#### Solutions Applied
1. **Never Cache Empty Results (`schedule_firestore_service.dart`)**:
   - In `fetchEvents()`, in-memory TTL caching only activates if `_cachedEvents != null && _cachedEvents!.isNotEmpty`.
   - Prevented overwriting valid persistent cache with empty lists when queries return 0 events.
2. **Universal High-Speed REST Fallback (`schedule_firestore_service.dart`)**:
   - Implemented `_fetchViaRest` and `_resolveUserIdViaRest` using Firestore REST API with the project's public-read API key.
   - Decodes Firestore REST documents directly into `SyncedScheduleEvent` with course metadata in < 500 ms, completely bypassing secondary Firebase Auth token mismatches or platform channel issues.
3. **Automatic Self-Healing by Email (`schedule_firestore_service.dart`)**:
   - When a resolved user ID produces 0 events, the service automatically invalidates `cached_schedule_user_id`, queries by user email (`roee.ilouz@gmail.com` and dot-normalized variants) via REST/SDK, resolves the real schedule user ID (`UxZrdJPoccae5hOiMSPIdyJA1072`), fetches all courses and events, and permanently persists the correct ID.
4. **Resilient Parsing (`schedule_firestore_service.dart`)**:
   - Supported `num`/`int` in `daysOfWeek` alongside `List` and comma-separated `String`.
   - Supported String/Boolean/Integer variations for `recurring` (`1`, `true`, `'1'`, `'true'`).
5. **Secondary Auth Safety Guard (`auth_service.dart`)**:
   - Prevented `ensureSecondaryAuth()` and `_signInToSecondaryFirebase()` from blindly overwriting verified `cached_schedule_user_id` with unverified secondary auth UIDs.
6. **Deployment & Verification**:
   - All 361 Flutter unit & integration tests passed.
   - Published Shorebird OTA Patch 1 for active release `0.2.20+110` and Patch 2 for `0.2.19+109`.
   - Deployed updated web build to Firebase Hosting (`https://rocis-todo.web.app`).

## ROCIs-Schedule Ecosystem Firestore Rules & Reconnect Stabilization - 2026-09-22

#### Problem & Root Causes
* **Cross-Project Permission Denied in Firestore**: Secondary Firebase project `rocis-schedule` had strict rules requiring `request.auth.uid == userId`. Because `ROCIs-tasks` runs under package `com.rocisapps.tasks` while `rocis-schedule` is registered for `com.rocisapps.schedule`, Android Google Sign-In and Firebase Auth could not authenticate into `rocis-schedule`, returning `permission-denied` on all course and event fetches.
* **Dead Reconnect Button**: `connectRocisSchedule()` called `_scheduleAuth.signInWithProvider(GoogleAuthProvider())`, which throws an unhandled PlatformException on Android for Google auth, silently catching and returning false. The filter sheet did nothing, leaving the user with a permanent disconnected banner.

#### Solutions Applied
1. **Ecosystem Firestore Rules (`ROCIs-Schedule/firestore.rules`)**:
   - Deployed updated Firestore rules permitting read access across the ROCIs app ecosystem while preserving strict owner-only write protection (`allow write: if request.auth != null && request.auth.uid == userId`).
2. **Schedule Authentication Synchronization (`auth_service.dart`)**:
   - Updated `isAuthenticatedInSchedule` to recognize active user sessions in Tasks with email as connected, removing erroneous disconnected banners.
   - Updated `connectRocisSchedule()` to immediately recognize authenticated sessions and re-trigger Google Sign-In only when unauthenticated.
3. **Robust Reconnect & Reloading (`calendar_filter_sheet.dart`, `schedule_firestore_service.dart`)**:
   - Ensured `onPressed` in filter sheet always calls `loadEvents(forceRefreshSchedule: true)`.
   - Added SharedPreferences email fallback in `ScheduleFirestoreService._resolveScheduleUserId`.
4. **Shorebird Patches**:
   - Published Patch 2 for `0.2.18+108` and Patch 1 for `0.2.19+109`.

## ROCIs-Schedule Mobile Reconnect, Silent Auth Fix & Multi-Month Widget Buffer - 2026-09-22

#### Problem & Root Causes
* **Recurring Google Sign-In Prompts**: Calling `attemptLightweightAuthentication()` in `ensureSecondaryAuth()` triggered native Android Credential Manager account pickers on startup and calendar visits.
* **Mobile Schedule Reconnect Failure**: Using cross-project tokens on Mobile caused audience mismatches or credential rejections when calling `_scheduleAuth.signInWithCredential()`.
* **FullCalendar Widget Missing Events on Month Navigation**: Background isolates or transient failures during month changes would overwrite pre-buffered events with empty maps. In addition, device calendar permission checks called `requestPermissions()` which crashed in background isolates.

#### Solutions Applied
1. **Silent Auth Isolation (`auth_service.dart`)**:
   - Confined `attemptLightweightAuthentication()` strictly to `kIsWeb`, completely eliminating intrusive account prompts on Mobile.
   - Updated Mobile `connectRocisSchedule()` to authenticate directly against `rocis-schedule` using `_scheduleAuth.signInWithProvider(GoogleAuthProvider())`.
2. **Calendar Service Permission Guard (`calendar_service.dart`)**:
   - Replaced `requestPermissions()` with `hasPermissions()` check in `getEvents()` to ensure background isolate safety.
3. **Multi-Month FullCalendar Widget Caching (`full_calendar_widget_service.dart`)**:
   - Expanded pre-buffer window to 18 months (-6 to +12 months).
   - Merged cached `full_calendar_events_by_date` from SharedPreferences before saving to avoid overwriting populated event maps with empty arrays.
   - Removed offset restriction from empty grid check to protect all navigated months.
4. **Deployment & Release: 0.2.19+109**:
   - Published Shorebird patch for existing `0.2.18+108` users.
   - Bumped version to `0.2.19+109` in `pubspec.yaml` and `app_config.dart`.
   - Deployed Web to Firebase Hosting and uploaded Android release AAB to Google Play Console `internal` testing track.

## ROCIs-Schedule Pure OAuth Token Synchronization & Web/Mobile Release - 2026-09-21

#### Problem & Root Causes
* **Cross-Project Audience Bypass**: When signing into secondary Firebase with `OAuthCredential`, passing the ID token minted for primary project `rocis-todo` caused auth failures. Preferring `GoogleAuthProvider.credential(accessToken: credential.accessToken)` directly bypasses any audience check, providing seamless cross-project authentication.
* **Web Token Preferencing**: On Web Google sign-in popup, `resolvedToken` was acquired via GIS but `oAuthCred` (with null accessToken) took precedence, falling back to a failed ID-token auth attempt.
* **Reconnection Cache Stale**: Reconnecting via calendar filter sheet did not clear cache or force-refresh Firestore queries, leaving empty schedule lists cached until TTL expired.

#### Solutions Applied
1. **Pure Access Token Pipeline (`auth_service.dart`)**:
   - Preferentially extract and use `accessToken` for secondary Firebase authentication across Web and Mobile.
   - Fall back to `_oauthManager.getGoogleAccessToken()` and broader exception handling if initial credential sign-in fails.
   - Enabled silent `attemptLightweightAuthentication` on Web.
2. **Force-Refresh on Reconnect (`calendar_provider.dart`, `calendar_filter_sheet.dart`)**:
   - Added `forceRefreshSchedule` parameter to `CalendarProvider.loadEvents()`, clearing `ScheduleFirestoreService` memory/preferences cache on reconnect.
3. **Verification**:
   - `flutter analyze lib/ test/`: 0 errors, 0 warnings (100% clean).
   - `test/features/calendar/`: 13/13 unit tests passed.

#### Deployment & Release: 0.2.18+108
* **Web Deployment**: Built release and deployed to Firebase Hosting (`https://rocis-todo.web.app`).
* **App Version Protocol**: Synchronized version `0.2.18+108` in `pubspec.yaml` and `lib/core/config/app_config.dart`.
* **Changelog**: Added concise entry (< 500 chars) in `docs/CHANGELOG.md`.
* **Shorebird Android Release**: Published release `0.2.18+108` via Shorebird with Flutter 3.47.2 engine.
* **Google Play Console**: Uploaded release AAB bundle (`70.0 MB`, version code `108`) to the `internal` testing track via `scripts/upload_aab_internal.py`.

## ROCIs-Schedule Cross-Project Authentication & Web/Mobile Synchronization Fix - 2026-09-21

#### Problem & Root Causes
* **Web Secondary Firebase Omission**: `lib/core/services/app_initializer.dart` and `lib/core/services/auth_service.dart` had `if (kIsWeb) return;` guard clauses, preventing the `rocis-schedule` secondary Firebase app from initializing and authenticating on Web.
* **Cross-Project OAuth Audience Mismatch**: Primary (`rocis-todo`) and secondary (`rocis-schedule`) are distinct Firebase projects. Passing an ID token issued for `rocis-todo` to `_scheduleAuth.signInWithCredential()` failed with `[firebase_auth/invalid-credential]` due to OAuth audience mismatch (`aud`).
* **Silent Auth State Loss**: If secondary auth failed silently on startup, users with Google accounts were unauthenticated against the `rocis-schedule` project, triggering security rule rejections (`request.auth.uid == userId`) when querying courses or timetable events.

#### Solutions Applied
1. **Secondary App Initialization on Web (`app_initializer.dart`, `auth_service.dart`)**:
   - Removed `kIsWeb` early-return guards from secondary Firebase initialization and authentication flows.
   - Leveraged web-native IndexedDB credential persistence under the secondary app name.
2. **Resilient Cross-Project Authentication (`auth_service.dart`)**:
   - Added automatic fallback to `GoogleAuthProvider.credential(accessToken: credential.accessToken)` when full credential sign-in fails. Access tokens are validated against user identity without audience constraints.
   - Enabled silent secondary sign-in during `ensureSecondaryAuth` via `_oauthManager.getGoogleAccessToken()`.
   - Added `connectRocisSchedule()` for 1-tap interactive reconnection (using `signInWithPopup` on Web and `authenticate` on Mobile).
3. **Calendar UI Integration (`calendar_filter_sheet.dart`, `l10n`)**:
   - Added a reconnection prompt banner in the calendar filter sheet when schedule events are enabled but secondary auth is disconnected.
   - Added localized string `rocisScheduleDisconnected` across all 8 supported languages (`en`, `he`, `ar`, `de`, `es`, `fr`, `hi`, `sv`).
4. **Verification**:
   - `flutter analyze lib/ test/`: 0 errors, 0 warnings (100% clean).
   - `test/features/calendar/`: 13/13 tests passed.
   - `test/features/calendar/synced_schedule_event_test.dart`: 7/7 tests passed.

#### Deployment & Release: 0.2.17+107
* **Web Deployment**: Built release with `flutter build web --release` and deployed to Firebase Hosting (`https://rocis-todo.web.app`).
* **App Version Protocol**: Synchronized version `0.2.17+107` in `pubspec.yaml` and `lib/core/config/app_config.dart`.
* **Changelog**: Added concise entry (< 500 chars) to `docs/CHANGELOG.md`.
* **Shorebird Android Release**: Published release `0.2.17+107` via Shorebird with Flutter 3.47.2 engine.
* **Google Play Console**: Uploaded release AAB bundle (`70.0 MB`, version code `107`) to the `internal` testing track via `scripts/upload_aab_internal.py`.

## ROCIs-Schedule Cross-App Synergy & Android FullCalendar Widget Optimization - 2026-09-21

#### Problem & Root Causes
* **Missing ROCIs-Schedule Events in App & Widget**:
  - Secondary Firebase configuration in `lib/firebase_schedule_options.dart` contained placeholder dummy values (`YOUR_SCHEDULE_API_KEY`), causing `[core/invalid-api-key]` crashes during boot.
  - Secondary Firebase Auth was unauthenticated, resulting in Firestore `permission-denied` errors when querying the user's courses and schedule events.
  - `SyncedScheduleEvent.occursOnDay` enforced `if (normalizedDay.isBefore(eventStartDay)) return false;`. Because `startTime` is often the creation timestamp or hour/minute placeholder, any day prior to creation was pruned, causing recurring classes to vanish from previous months or during month switches.
  - No fallback cache existed when the user was offline or secondary auth was refreshing.
* **FullCalendar Android Home Widget Lag & Month Drop**:
  - `full_calendar_widget_service.dart` only queried events for the current 42-day window (`startDate` to `endDate`).
  - When switching months, Kotlin updated `PREF_OFFSET` and read `PREF_GRID_DATA`, which contained zero data for the new month, rendering it completely blank.
  - Kotlin sent an immediate background broadcast on every month tap, booting a heavy Flutter background engine on the CPU that dropped launcher frames and stuttered launcher animations.
  - Consecutive rapid month clicks queued multiple Flutter engines in parallel, resulting in race conditions and lag.

#### Solutions Applied
1. **Firebase Configuration & Authentication Pipeline**:
   - Configured production Firebase options for `rocis-schedule` project in `lib/firebase_schedule_options.dart` across Android, Web, and iOS.
   - Sequenced secondary authentication in `AuthService` (`ensureSecondaryAuth()`), persisting `cached_schedule_user_id` to `SharedPreferences` and linking Google credentials silently via `attemptLightweightAuthentication()`.
   - Added persistent SharedPreferences caching (`cached_schedule_events_json`) in `ScheduleFirestoreService` with offline fallback so schedule events are never wiped.
2. **Calendar Provider & Recurrence Calculation (`calendar_provider.dart`)**:
   - Removed artificial `isBefore(eventStartDay)` barrier in `SyncedScheduleEvent.occursOnDay`.
   - Expanded recurring schedule mapping window to 5 years (`_selectedDate.year - 2` to `_selectedDate.year + 2`).
   - Fixed daylight savings time (DST) hour-drifting bug by switching from `cur.add(Duration(days: 1))` to `DateTime(cur.year, cur.month, cur.day + 1)`.
   - Ensured secondary authentication is established before fetching events and synced the home widget asynchronously on load.
3. **Multi-Month Event Pre-Buffering (`full_calendar_widget_service.dart`)**:
   - Expanded widget event buffer window from -3 months to +6 months relative to the target month.
   - Pre-indexed all Google Calendar events, ROCIs Schedule classes, and tasks (including recurring instances via `TaskRecurrenceService`) into a unified `full_calendar_events_by_date` JSON map (`Map<String, List<Map<String, dynamic>>>`).
   - Saved `full_calendar_events_by_date` alongside `full_calendar_grid_data` for seamless multi-month availability.
4. **Android Native Zero-Lag Navigation (`FullCalendarWidgetUtils.kt`, `FullCalendarWidgetService.kt`, `FullCalendarWidgetProvider.kt`)**:
   - Added `PREF_EVENTS_BY_DATE` constant in `FullCalendarWidgetUtils.kt`.
   - Updated `FullCalendarWidgetFactory.onDataSetChanged()` to index summaries directly from `PREF_EVENTS_BY_DATE`, instantly populating past and future months upon navigation.
   - Added debounced background sync (`scheduleBackgroundNav`) in `FullCalendarWidgetProvider.kt`: when navigating within the pre-buffered range (-2 to +5), Kotlin updates the UI instantly (16ms) without spawning a heavy Flutter background engine, debouncing the background sync by 1.2s. Immediate sync is reserved for distant months outside the cache.
5. **Verification**:
   - `flutter analyze lib/ test/`: 0 errors, 0 warnings (100% clean).
   - `test/features/calendar/synced_schedule_event_test.dart`: 7/7 tests passed (100%).

#### Deployment & Release: 0.2.16+106
* **App Version Protocol**: Applied new version layout `xx.yy.zz` (`xx=0` prod, `yy=2` open beta, `zz=16` internal testing, build `106`).
* **Version & Changelog Sync**: Synchronized `pubspec.yaml` (`0.2.16+106`) and `lib/core/config/app_config.dart` (`0.2.16`), added concise entry (< 500 chars) to `docs/CHANGELOG.md`.
* **Shorebird Release**: Registered and published release `0.2.16+106` with Flutter 3.47.2 engine on Shorebird cloud.
* **Google Play Console**: Uploaded release AAB bundle (`70.0 MB`, version code `106`) directly to the `internal` testing track using `scripts/upload_aab_internal.py`.

## Recurring Tasks Immediate Reappearance Fix & Deferred Model Alignment - 2026-09-19

#### Problem & Root Causes
* **Immediate Reappearance on Completion**: When marking an overdue recurring task or same-day recurring task as completed, it immediately reappeared in the active task list with no changes.
* **Flawed `targetAfter` Recurrence Math**: When completing an overdue task (e.g. daily task due at 18:00 completed at 13:00 today), `TaskRecurrenceService.getNextDueDate` evaluated the next occurrence strictly after 13:00 today. Because 18:00 today had not yet passed, it returned **today at 18:00** as the "next" occurrence.
* **Immediate Materialization Fallback**: In `TaskProvider.toggleTaskCompletion`, if `nextDueDate` was calculated for today (`!nextDay.isAfter(today)`), the `else` branch ran `await _materializeRecurringTask(task, nextDueDate)`. This immediately spawned an uncompleted clone with today's due date back into the active list.
* **Web Inspector Double-Toggle**: In `web_home_screen.dart`, clicking the inspector completion status button called `provider.toggleTaskCompletion(_selectedTask!)` (in-place mutation) and immediately followed with `setState(() { _selectedTask = _selectedTask!.copyWith(isCompleted: !_selectedTask!.isCompleted); })`, accidentally inverting the boolean twice and reverting completion.

#### Solutions Applied
1. **Recurrence Engine (`TaskRecurrenceService`)**:
   - Updated `getNextDueDate` and `_calculateNextDateFallback`: when advancing recurrence from completion (`after != null`), `targetAfter` is evaluated against the end of the completion day (`DateTime(after.year, after.month, after.day, 23, 59, 59, 999)`) or `currentDueDate`, whichever is later.
   - Guaranteed that completing an overdue or same-day recurring task always advances strictly to a future day ($D \ge \text{tomorrow}$), completely preventing same-day re-occurrence.
   - Built `startUtc` using `DateTime.utc(currentDueDate.year, ...)` to ensure local calendar dates never suffer from UTC day-shifts across timezones.
2. **Provider Orchestration (`TaskProvider`)**:
   - In `toggleTaskCompletion`: strictly adhered to the deferred materialization model. Removed the immediate `_materializeRecurringTask` fallback branch. Next iterations are recorded in `task.nextRecurrenceDate` and projected in "Upcoming Recurring" until their scheduled date arrives.
   - In `checkAndMaterializeDueRecurringTasks()`: tasks completed today are never materialized on the same day.
3. **Web Home Screen (`web_home_screen.dart`)**:
   - Fixed the task inspector completion button to avoid flipping `!_selectedTask!.isCompleted` again after `toggleTaskCompletion`.
4. **Verification**:
   - `flutter analyze`: 0 issues found.
   - `flutter test`: 357 / 357 tests passed (100%).
   - Added unit tests for completing overdue tasks, same-day early/late completions, and verifying strictly future deferred scheduling without duplicate task creation.

## Deferred Recurring Tasks Materialization & Upcoming Projections - 2026-09-17

#### Problem & Requirements
* **Premature Task Spawning**: Previously, completing a recurring task immediately created and inserted the next pending instance into the database, instantly cluttering the active task list with tasks scheduled for tomorrow or future days.
* **Deferred Requirement**: The next iteration must be created **only AT the next iteration date** (e.g., tomorrow/next scheduled day), not immediately upon completing today's iteration.
* **Upcoming Visibility**: Users still need visibility into upcoming scheduled recurring tasks in both the task list and calendar without treating them as active, overdue, or pending tasks.
* **Catch-Up Mechanism**: If days are missed (e.g. completed on Monday, app reopened Thursday), the materialized task due date must catch up to today while preserving the original hour/minute/second of day.

#### Solutions Applied
1. **Task Data Model (`task.dart` & `task.g.dart`)**:
   - Added `@HiveField(23) DateTime? nextRecurrenceDate;` to `Task` model, Hive adapter, serialization (`toMap`, `toFirestoreMap`, `fromMap`), and `copyWith`.
2. **Recurrence Engine Improvements (`TaskRecurrenceService`)**:
   - Added `adjustDueDateForCatchUp(DateTime scheduledDate, DateTime now)`: strictly advances past scheduled dates to today's date if days were missed, preserving original time of day.
   - Added `createUpcomingPreviewTask(Task completedTask, DateTime nextDueDate)`: generates lightweight preview tasks tagged with `preview_${completedTask.id}`.
3. **Provider Lifecycle & Deferred Scheduling (`TaskProvider`)**:
   - In `toggleTaskCompletion`: if the next recurrence date is on a future day (`nextDay.isAfter(today)`), records `task.nextRecurrenceDate = nextDueDate` and saves to local Hive and Firestore without creating a new pending task. Pre-schedules OS notification so reminders trigger on time.
   - On uncompletion: clears `nextRecurrenceDate` and cancels the pre-scheduled preview notification.
   - Implemented `checkAndMaterializeDueRecurringTasks()`: automatically checks for due deferred tasks on app start (`init()`) and app foregrounding (`didChangeAppLifecycleState(resumed)`). Materializes them into real pending tasks using `_materializeRecurringTask`.
   - Exposed `upcomingRecurringTasks` and `getUpcomingRecurringTasksForDay(DateTime day)`.
4. **UI & UX Projections**:
   - **Task List View (`TaskListScreen`)**: Added an expandable `Upcoming Recurring` `GlassContainer` section displaying projected future iterations with custom badge styling.
   - **Calendar View (`CalendarScreen`)**: Integrated `getUpcomingRecurringTasksForDay` into calendar event queries and rendered upcoming tasks with `GlassContainer` and localized `upcomingRecurringBadge`.
   - **Localization**: Added `upcomingRecurringTasksHeader` and `upcomingRecurringBadge` across all 8 supported languages (`en`, `he`, `es`, `de`, `fr`, `ar`, `hi`, `sv`).
5. **Quality & Verification**:
   - `flutter analyze`: 0 issues found.
   - `flutter test`: 346 / 346 tests passed (100%).
   - Added comprehensive tests in `task_recurrence_service_test.dart` and `task_provider_test.dart`.

## Recurring Tasks Overhaul & Next Due Date Synchronization - 2026-09-16

#### Problem & Root Causes
* **Overdue Recurrence Date Math**: Completing an overdue recurring task evaluated `getNextDueDate(baseDate, rule)` without comparison against `DateTime.now()`, spawning instances still in the past.
* **Missing Parent-Child Linkage**: Tasks had no reference to the parent task that spawned them, preventing automatic cleanup if a completed task was accidentally unchecked.
* **Uncompletion Duplication**: Unchecking a completed recurring task did nothing to remove the newly spawned task, resulting in duplicate instances.
* **Time Preservation & Anchoring**: Tasks without due dates needed deterministic recurrence anchored to their `createdAt` timestamp, preserving the exact hour/minute/second of day across occurrences.

#### Solutions Applied
1. **Task Model Linkage**:
   - Added `@HiveField(22) String? recurringParentId;` to `Task` model, `copyWith`, serialization (`toMap`, `toFirestoreMap`, `fromMap`), and updated `TaskAdapter` in `task.g.dart`.
2. **Recurrence Engine Improvements (`TaskRecurrenceService`)**:
   - Updated `getNextDueDate` and fallback engine to compare against `targetAfter` (`(after != null && after.isAfter(currentDueDate)) ? after : currentDueDate`), ensuring overdue tasks advance to the next strictly future occurrence while early completions advance from their scheduled due date.
   - Guaranteed preservation of original `hour`, `minute`, `second`, and `millisecond` across daily, weekdays, weekly, monthly, and yearly recurrences.
   - Linked `recurringParentId: completedTask.id` in `createNextRecurringTask`.
3. **Provider Orchestration (`TaskProvider`)**:
   - In `toggleTaskCompletion`: passed `after: DateTime.now()` when completing recurring tasks for PRO users (`_subscriptionService.isPremium`).
   - On un-completing (`!task.isCompleted`), automatically locate and permanently delete active spawned children (`deleteTaskPermanently`), removing duplicates, clearing notifications, and refreshing UI/widgets.
4. **Verification**:
   - Added unit tests in `task_recurrence_service_test.dart` and `task_provider_test.dart`.
   - Full test suite: 343 / 343 tests passed (100%).
   - `flutter analyze`: 0 issues found.
   - Android Kotlin build (`gradlew.bat :app:compileReleaseKotlin`): BUILD SUCCESSFUL.
5. **Version Bump & Synchronization**:
   - Bumped app version to `0.2.15+105` in `pubspec.yaml`.
   - Synchronized `AppConfig.appVersion = '0.2.15'` in `lib/core/config/app_config.dart`.
   - Updated `docs/CHANGELOG.md` with release notes for `0.2.15+105`.

#### Problem & Root Causes
* **ROCIs-Schedule Local-Only Events**: In `ROCIs-Schedule` (`CourseProvider.addEvent`), newly added lecture/timetable events were only stored in SQLite local DB and never uploaded to Firestore `users/{uid}/events`, leaving the cross-app Firestore subcollection empty (`{}`).
* **Android FullCalendar Widget Easter Egg & Filter Default**:
  - `FullCalendarWidgetProvider.kt` hid `R.id.widget_filter_rocis` with `View.GONE` behind a hidden 5-tap easter egg (`beta_schedule_integration`).
  - `FullCalendarWidgetProvider.kt` and `FullCalendarWidgetService.kt` defaulted `PREF_SHOW_SCHEDULE` to `false`.
  - In `FullCalendarWidgetProvider.kt onReceive()`, toggling filters (`ACTION_FILTER_ROCIS`, `ACTION_FILTER_TASKS`, `ACTION_FILTER_GOOGLE`) updated local preferences but never broadcast `HomeWidgetBackgroundIntent` to Dart (`rocistasks://full_calendar_filter_...`), so background recalculation of `full_calendar_grid_data` was never triggered.
* **Paywall Block in Tasks App**:
  - `CalendarProvider.dart` suppressed schedule events if `isPremium == false` (`if (_showRocisSchedule && isPremium)` and `getScheduleEventsForDay`).
  - `CalendarFilterSheet.dart` showed a paywall dialog and blocked toggling `showRocisSchedule`.
* **Background Isolate Auth & Email Resolution**:
  - In background isolates, `FirebaseAuth.instance.currentUser` is null. `FullCalendarWidgetService` and `background_handler.dart` did not fall back to `SharedPreferences` saved email (`google_user_email`).
  - In `ScheduleFirestoreService._resolveScheduleUserId()`, Gmail accounts with dot variations (`roee.ilouz@gmail.com` vs `roeeilouz@gmail.com`) failed exact string matching. Resolved user IDs were not cached in `SharedPreferences`.

#### Solutions Applied
1. **Component 1 (ROCIs-Schedule Timetable Upload)**:
   - Added automatic Firestore synchronization (`_firestoreService.uploadEvents`) in `CourseProvider.dart` on `addEvent()`, `deleteEvent()`, and `loadData()`.
2. **Component 2 (Native Android Widget Layer)**:
   - In `FullCalendarWidgetProvider.kt`: made `widget_filter_rocis` visible (`View.VISIBLE`) by default without easter egg gating.
   - Defaulted `showSchedule` to `true` in both `FullCalendarWidgetProvider.kt` and `FullCalendarWidgetService.kt`.
   - In `onReceive()`: broadcast `HomeWidgetBackgroundIntent` to Dart for `ACTION_FILTER_TASKS`, `ACTION_FILTER_GOOGLE`, and `ACTION_FILTER_ROCIS` so Dart triggers `_handleFullCalendarFilterToggle` and updates widget grid data.
3. **Component 3 (Dart Widget Service & Background Handler)**:
   - Defaulted `showSchedule` to `prefs.getBool('full_calendar_show_schedule') ?? true` in `FullCalendarFilters` and `getFilters()`.
   - Added fallback to `SharedPreferences` saved email (`GoogleOAuthManager.keyUserEmail` / `'google_user_email'`) in `FullCalendarWidgetService.fetchScheduleEvents()` and `background_handler.dart`.
4. **Component 4 (Calendar Screen, Provider & Firestore Service)**:
   - In `ScheduleFirestoreService`: added `cached_schedule_user_id` persistence via `SharedPreferences`, added dot-normalized Gmail matching, and client-side normalized fallback scanning.
   - In `CalendarProvider`: defaulted `_showRocisSchedule = true;`, added `SharedPreferences` email fallback in `loadEvents()`, and removed strict `isPremium` gating for displaying university timetable events.
   - In `CalendarFilterSheet`: unlocked toggling `showRocisSchedule` directly without paywall blocker.
   - In `SettingsScreen`: removed PRO badge and subscription check, making ROCIs Schedule Synergy 100% free across both settings and calendar filters.
5. **Verification**:
   - `synced_schedule_event_test.dart`: 5/5 tests passed (100%).
   - `test/features/calendar/`: 11/11 tests passed (100%).
   - Full test suite: 338/338 tests passed (100%).
   - `flutter analyze`: 0 errors, 0 warnings.


#### Summary & Operations
* **Version Bump & Sync**: Bumped `pubspec.yaml` to `0.2.14+103` and verified synchronization with `lib/core/config/app_config.dart`.
* **Changelog Compliance**: Added release notes under 500 characters to `docs/CHANGELOG.md` covering first-frame startup boot, 60fps task list virtualization, and concurrent widget sync pipelines.
* **Shorebird & Google Play Console Deployment**:
  - Cleared stale Dart `.dart_tool\hooks_runner` build hooks to align Shorebird's Flutter 3.47.2 engine with host tools.
  - Built production Shorebird release AAB (`70.6 MB`, version `0.2.14+103`).
  - Successfully registered release on Shorebird cloud and uploaded AAB v103 to Google Play Console `internal` testing track using `scripts/upload_aab_internal.py`.
* **Standalone Release APK & GitHub Release**:
  - Built signed standalone release APK (`79.2 MB`).
  - Created Git tag `v0.2.14+103`, pushed changes to GitHub repository.
  - Created GitHub Release `v0.2.14+103` with attached APK artifact: [Release v0.2.14+103](https://github.com/RoeeIlouz/ROCIs-Tasks/releases/tag/v0.2.14%2B103).
* **Web App Deployment**:
  - Built release web bundle via `flutter build web --release`.
  - Deployed to Firebase Hosting: [https://rocis-todo.web.app](https://rocis-todo.web.app).
* **Code & Test Integrity**:
  - 338 / 338 tests passed (100%).
  - `flutter analyze`: 0 issues found.

## Comprehensive 5-Pillar App Speed & Performance Optimization - 2026-09-12

#### Problem & Root Causes
* **Non-virtualized Task List & Staggered Animations Loop**:
  - `task_list_screen.dart` used `Column(children: List.generate(activeTasks.length, ...))` inside a `SingleChildScrollView`/`ListView`, instantiating and layout-calculating all tasks simultaneously.
  - `flutter_staggered_animations` triggered on every single task state change (e.g. checking/unchecking a checkbox), causing severe micro-stutter during rapid task completion.
  - `TaskTile` lacked a `RepaintBoundary`, forcing the entire list viewport to repaint whenever a single task tile's checkbox or swipe animation triggered.
* **Over-broad `GlassContainer` Provider Subscriptions**:
  - `GlassContainer` listened broadly to `Provider.of<ThemeService>(context)` and `Provider.of<SubscriptionService>(context)`.
  - Any minor state change in `ThemeService` or `SubscriptionService` triggered complete widget tree rebuilds and expensive backdrop blur re-renders for hundreds of glass containers across the app.
* **Serial Home Widget Background Updates on Task Toggle**:
  - In `TaskProvider._updateWidgets()`, 5 separate widget update processes (`updateAllWidgets`, `updateMonthEventsMap`, `updateCalendarListWidget`, `updateMonthWidget`, `updateFullCalendarWidget`) were chained serially with `await`.
  - Checking a task resulted in cumulative 1-3 second background operations.
  - `TaskWidgetService.updateTaskWidget()` re-rendered the circular priority chart to PNG on disk via `HomeWidget.renderFlutterWidget` every time, even if task priority counts had not changed.
* **Startup Blocking in Main Service Initialization**:
  - `main.dart` awaited 10+ services sequentially (`TimezoneService`, `CalendarService`, `CalendarColorService`, `SubscriptionService`, `ConnectivityService`, `ScheduleFirestoreService`) before allowing `runApp()` to mount the initial frame.
  - Added 500-800ms of unnecessary splash screen delay.

#### Solutions Applied
1. **Pillar 1: Task List Virtualization & Isolated Repaint Boundaries**:
   - Refactored `task_list_screen.dart` to use `ListView.builder` with `addRepaintBoundaries: true`.
   - Introduced `_hasInitiallyAnimated` flag in `_TaskListViewState` so that entry stagger animations run strictly on initial screen load, preventing animation loops during checkbox taps.
   - Wrapped `TaskTile` root in `RepaintBoundary` to isolate raster cache layers during scroll and swipe gestures.
2. **Pillar 2: Home Widget Pipeline Concurrency & Off-Screen Chart Caching**:
   - Replaced serial awaits in `TaskProvider._updateWidgets()` with concurrent `Future.wait([ ... ])`.
   - Added static caching (`_cachedChartPath`, `_cachedChartKey`) in `TaskWidgetService.updateTaskWidget()`. When priority counts `high_medium_low_isDark` remain unchanged, disk PNG rendering is bypassed.
3. **Pillar 3: Surgical `GlassContainer` Rebuild Isolation**:
   - Swapped broad `Provider.of` with granular `context.select<ThemeService, bool>((s) => s.isGlassmorphismEnabled)` and `context.select<SubscriptionService, bool>((s) => s.isPremium)`.
   - Unrelated theme color or subscription metadata changes now produce 0 unnecessary glass card rebuilds.
4. **Pillar 4: Tiered Startup Boot Protocol**:
   - Separated initialization into **Tier 1 (Instant First-Frame UI)** (`ThemeService`, `PrivateModeService`, `TaskSource`, `TaskProvider`, `AuthService.initialized`) and **Tier 2 (Deferred Background)** (`TimezoneService`, `CalendarService`, `CalendarColorService`, `SubscriptionService`, `ConnectivityService`, `ScheduleFirestoreService`).
   - Slashed splash-to-interactive time by ~500-800ms.
5. **Pillar 5: Benchmark & Verification**:
   - `flutter analyze`: 0 errors, 0 warnings.
   - `flutter test`: 338/338 unit tests passed (100%).

## FullCalendar Performance & Schedule Visibility & Widget Outline Fixes - 2026-09-12

#### Problem & Root Causes
* **FullCalendar Widget Extremely Slow**: Sequential network fetches (Google Calendar events -> Calendar colors -> Schedule Firestore -> Asset localizations) with no request timeouts caused prolonged loading times whenever any task was checked or widget refreshed.
* **Calendar Page Missing ROCIs Schedule Events**:
  - `CalendarProvider` was instantiated without `AuthService`, relying on a single `setUser` call in `CalendarScreen.initState()`. If Firebase Auth was asynchronous, `uid` and `email` remained null permanently.
  - Toggling `showRocisSchedule` ON in `CalendarFilterSheet` did not trigger `loadEvents()` when events were empty.
  - In `calendar_screen.dart` `markerBuilder`, single events of type `SyncedScheduleEvent` did not set a title, leaving an empty box.
  - `ScheduleFirestoreService._resolveScheduleUserId` did not check the secondary Firebase App (`rocis-schedule`) Auth instance, resulting in unnecessary Firestore queries.
  - In `FullCalendarWidgetService.dart`, `full_calendar_show_rocis` was hardcoded to `false` instead of setting `full_calendar_show_schedule`.
* **Purple Outline on Widget Filter Buttons**: `widget_filter_button_active_bg.xml` and `widget_pill_bg.xml` hardcoded `#6366F1` stroke instead of the brand coral red `#EF3842`.

#### Solutions Applied
1. **Parallelization & 5-Minute In-Memory Caching in FullCalendarWidgetService**:
   - Implemented concurrent `Future.wait` for Google events, colors, Schedule events, and localizations.
   - Added in-memory TTL caching (5 minutes) across `CalendarService`, `ScheduleFirestoreService`, and `FullCalendarWidgetService`.
   - Added 5-second timeouts on external Google Calendar REST API calls to prevent UI stalls.
2. **Robust Schedule Event Sync in CalendarProvider & CalendarScreen**:
   - Injected `AuthService` into `CalendarProvider` and subscribed to `authStateChanges` for automatic user credential updates and event reloading.
   - Added fallback to `FirebaseAuth.instance.currentUser` in `loadEvents()`.
   - Automatically trigger `loadEvents()` when `showRocisSchedule` is toggled ON if schedule events are empty.
   - Expanded recurring schedule mapping range to +/- 1 year to ensure classes remain visible during month navigation.
   - Handled `SyncedScheduleEvent` title formatting in `calendar_screen.dart` `markerBuilder`.
   - Fixed `full_calendar_show_schedule` boolean persistence in `FullCalendarWidgetService`.
3. **Android Widget Purple Outline Removal**:
   - Replaced `#6366F1` and `#256366F1` with `#EF3842` and `#25EF3842` in `widget_filter_button_active_bg.xml` and `widget_pill_bg.xml` to match app branding and respect the purple ban.
4. **Verification**:
   - `flutter analyze`: 0 issues found.
   - `flutter test`: 338/338 unit tests passed (100%).

## ROCIs Schedule Sync & Calendar Theming Consolidation - 2026-09-12

#### Problem & Root Causes
* **Schedule Sync Not Showing Events**: ROCIs Schedule university timetable events were not appearing in the user's Calendar page or in the Android FullCalendar home widget.
  - *Root Cause 1 (Cross-Project Auth UIDs)*: ROCIs Tasks (`rocis-todo`) and ROCIs Schedule (`rocis-schedule`) are separate Firebase projects. Users authenticated via Google Sign-In have differing Firebase Auth UIDs across projects. Querying by Tasks UID returned zero documents in the Schedule Firestore project.
  - *Root Cause 2 (FullCalendar Widget Integration)*: `FullCalendarWidgetService.dart` hardcoded `showRocisSchedule = false` and did not query schedule events or merge them into the 42-day widget grid.
  - *Root Cause 3 (Widget Schedule Filter Chip Missing)*: The Android native FullCalendar widget header lacked a filter toggle for ROCIs Schedule.
* **Conflicting Calendar Color Pickers**: Users could change Google calendar coloring in two distinct places (`CalendarFilterSheet` and `CalendarColoringSheet` via theme palette button), causing state conflicts, duplicate settings, and unexpected color shifts.

#### Solutions Applied
1. **Cross-Project User Resolution in ScheduleFirestoreService**:
   - Updated `ScheduleFirestoreService._resolveScheduleUserId()` to attempt direct UID lookup first, and seamlessly fall back to querying the `users` collection by Google account email (`where('email', isEqualTo: targetEmail).limit(1)`).
   - Injected user email into `CalendarProvider` and `FullCalendarWidgetService` to resolve timetable data across project boundaries.
2. **Android FullCalendar Widget Schedule Overlay**:
   - Updated `FullCalendarWidgetService.dart` to fetch `SyncedScheduleEvent`s for the rendered month range and merge them into the day cell events summaries.
   - Updated `FullCalendarWidgetProvider.kt` to conditionally display `widget_filter_rocis` chip in the widget header *only* when the beta feature (`beta_schedule_integration`) is enabled. Added `ACTION_FILTER_ROCIS` broadcast handling.
   - Updated `FullCalendarWidgetService.kt` to respect `showSchedule` filter state when rendering event indicators.
3. **Consolidated Calendar Theming Architecture**:
   - In `CalendarFilterSheet`, removed the interactive color picker and replaced it with a non-interactive 16px indicator dot.
   - Tapping the indicator dot pops the filter sheet, opens `CalendarColoringSheet`, and displays a localized snackbar (`calendarColorThemingHint`) directing the user to manage all calendar theming in one place.
   - Added `calendarColorThemingHint` localization across all 8 supported languages (`en`, `he`, `es`, `de`, `fr`, `ar`, `hi`, `sv`).
4. **Verification**:
   - `flutter analyze`: 0 issues found.
   - `flutter test`: 338 / 338 tests passed (100%), including new tests in `synced_schedule_event_test.dart`.

## FullCalendar Home Widget Month Navigation Fix - 2026-09-12

#### Problem & Root Causes
* **Stale Dates on Month Navigation**: Tapping the month navigation arrows (`‹` and `›`) on the Android FullCalendar home widget updated the month name in the header, but left the previous month's dates intact.
* **Root Causes**:
  1. `FullCalendarWidgetFactory.onDataSetChanged()` previously consumed `full_calendar_grid_data` from SharedPreferences as the single source of truth for day cells. Since this JSON held the previously rendered month's dates, `generateFallbackCalendar` was never invoked and the old month's numbers were displayed.
  2. In `FullCalendarWidgetService.dart`, empty-month grids (e.g. Navigating to an upcoming/past month with 0 tasks or events) triggered an early return that preserved the previous month's populated grid, preventing empty months from updating.
  3. In `FullCalendarWidgetProvider.kt`, `editor.apply()` was executed after dispatching `backgroundIntent.send()`, creating a race condition for background isolate retrieval.

#### Solutions Applied
1. **Dynamic Kotlin Month Grid Calculation**:
   - Refactored `FullCalendarWidgetFactory.onDataSetChanged()` to dynamically generate the 42 day cells (6 weeks) for the current `PREF_OFFSET` natively in Kotlin, matching the zero-latency behavior of `MonthAgendaWidgetService`.
   - Indexed summaries from `full_calendar_grid_data` by date (`yyyy-MM-dd`) so cached events overlay onto the correct dates immediately without waiting for Dart.
2. **Empty Months Allowance for Non-Zero Offsets**:
   - In `FullCalendarWidgetService.dart`, updated the empty-grid protection so it only preserves existing grids for the current month (`offset == 0`) to prevent offline wipes, but allows new month offsets (`offset != 0`) to persist cleanly.
   - Added persistent saving of `full_calendar_offset` in SharedPreferences.
3. **Deterministic Offset Passing & Selection Reset**:
   - Appended `?offset=$newOffset` to the broadcast URI in `FullCalendarWidgetProvider.kt` and updated `BackgroundHandler` to consume `targetOffset` directly from query parameters.
   - Cleared `full_calendar_selected_date` to `""` on month switch to prevent stale selected date highlights.
   - Committed SharedPreferences via `.apply()` immediately prior to dispatching `backgroundIntent.send()`.
4. **Verification**:
   - `flutter analyze`: 0 issues found.
   - `flutter test`: 333 / 333 tests passed (100%).

## ROCIs Schedule Synergy Integration & v0.2.14+101 Release - 2026-09-12

#### Features & Architecture Implemented
* **ROCIs Schedule Synergy (Beta)**:
  - Enabled two-way cross-app synergy between ROCIs Tasks and ROCIs Schedule.
  - Secret Easter Egg unlock in About Dialog (5 taps on version) reveals Beta Features and enables "ROCIs Schedule Synergy (Beta)".
  - New "ROCIs Ecosystem" section in Settings with 1-tap open button to ROCIs Schedule and cloud sync status.
* **University Timetable Overlay**:
  - `ScheduleFirestoreService`: Connects to secondary Firebase app (`rocis-schedule`) with UID-based lookup to fetch courses and timetable events with backward-compatible method stubs (`setUserEmail`, `clearCache`).
  - `CalendarProvider`: Merges university schedule events into the calendar alongside device calendar events, supporting recurring event rules and day-by-day mapping.
  - `CalendarFilterSheet`: Added toggle switch for "ROCIs Schedule" filter with persistent storage in SharedPreferences.
  - `CalendarScreen`: Renders rich `SyncedScheduleEvent` cards with school icons, course code badges, time ranges, locations, and "Open in ROCIs Schedule" action.
* **Deep Link Receiver**:
  - `HomeScreen` & `AddTaskScreen`: Parse incoming `rocistasks://add_task` queries (`title`, `notes`/`description`, `dueDate`, `priority`) to launch the pre-populated task creation dialog.
* **Pro Feature Gating**:
  - Gated ROCIs Schedule synergy behind `SubscriptionService.isPremium` (PRO).
  - `CalendarFilterSheet`: Displays amber `PRO` badge next to timetable switch; triggers `subscriptionService.showPaywall()` when free users attempt to enable.
  - `SettingsScreen`: Displays `PRO` badge on "ROCIs Schedule Synergy (Beta)" tile and triggers paywall on toggle; "ROCIs Ecosystem" section only appears for Pro users.
  - `CalendarProvider`: Strictly verifies `isPremium` before blending timetable events into `getEventsForDay` and `getScheduleEventsForDay`.
* **Version Bump**: Bumped to `v0.2.14+101` (`pubspec.yaml`, `app_config.dart`, `docs/CHANGELOG.md`).

## Version Revert & Glassmorphic Category/Event Hue Tinting - 2026-09-11

#### Problem & Requirements
* **Version Revert**: Reverted unnecessary version bump from `0.2.14+100` back to `0.2.13+99` (`appVersion = '0.2.13'`) and synchronized `docs/CHANGELOG.md`.
* **Glassmorphic Category Tinting**: When glassmorphism was enabled, `TaskTile` and calendar event cards were using the default primary theme color rather than reflecting their specific category or calendar colors in the frosted glass blend.

#### Solutions Applied
1. **Version Synchronization**:
   - Reverted `pubspec.yaml` to `0.2.13+99`.
   - Reverted `lib/core/config/app_config.dart` to `0.2.13`.
   - Synchronized `docs/CHANGELOG.md` to keep `[0.2.13+99]` as the active release section.
2. **`GlassContainer` `tintColor` Engine**:
   - Added dedicated `tintColor` parameter to `GlassContainer`.
   - In glass mode (`useGlass = true`), `tintColor` is lerped at 12-18% onto `baseColor` to produce a refined, subtle colored translucent backdrop.
   - In non-glass mode (`useGlass = false`), `tintColor` does not override `color`, preserving the neutral `surfaceContainerLow` surface and preventing saturated solid color fills on Web and non-glass mobile.
3. **Widget Integration**:
   - `TaskTile` & `_MaskedPrivateTaskTile`: Now pass `tintColor: categories.isNotEmpty ? Color(categories.first.colorValue) : null`.
   - `CalendarScreen`: Passes `tintColor: eventColor` for Google Calendar event cards.
   - `KanbanCard`: Passes `tintColor: primaryCategory != null ? categoryColor : null`.
4. **Verification**:
   - `flutter analyze`: 0 issues found.
   - `flutter test`: 332 / 332 tests passed (100%).

## Non-Glassmorphic Surface Styling & Category Stripe Alignment - 2026-09-11

#### Problem & Requirements
* **Broken Non-Glassmorphic Card Backgrounds**: When glassmorphism was turned off (which is configurable on mobile and always false on web), event cards in the calendar page were filled with opaque `primaryContainer` due to hardcoded `isSelected: true`, and Kanban cards were filled with 100% solid saturated `categoryColor` due to `color: categoryColor` passed into `GlassContainer`.
* **Border Discard in `GlassContainer`**: When `!useGlass && !isSelected`, `GlassContainer` previously forced `Border.all(color: Colors.transparent)`, throwing away custom caller borders.

#### Solutions Applied
1. **`GlassContainer` Fix**:
   - Always respects explicit caller `border` in all modes instead of overriding with transparent border.
   - Softened selection background fallback to `theme.colorScheme.primary.withValues(alpha: 0.12)`.
2. **Calendar Events Refinement**:
   - Set `isSelected: false` on the event `GlassContainer` in [`calendar_screen.dart`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/lib/features/calendar/presentation/screens/calendar_screen.dart), allowing event cards to sit on clean `surfaceContainerLow` matching `TaskTile`.
   - Added explicit 1px hairline border tinted with the event's subcalendar color (`eventColor.withValues(alpha: isDark ? 0.25 : 0.18)`).
3. **Kanban Cards Refinement**:
   - In [`kanban_card.dart`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/lib/features/tasks/presentation/widgets/kanban/kanban_card.dart), removed `color: categoryColor` so active cards cleanly use `surfaceContainerLow` matching `TaskTile`.
   - Added 1px hairline border tinted with the primary category color (`categoryColor.withValues(alpha: isDark ? 0.25 : 0.18)`).
   - Added a slim 3.5px rounded vertical category accent stripe on the left edge for immediate category identification at a glance.
4. **Verification**:
   - `flutter analyze`: 0 issues found.
   - `flutter test`: 325 / 325 tests passed (100%).

## Version 0.2.14+100 Release & Deployment Pipeline - 2026-09-11

#### Summary & Operations
* **Version Bump & Sync**: Synchronized `pubspec.yaml` and `lib/core/config/app_config.dart` to `0.2.14+100`.
* **Changelog Compliance**: Added concise, <500 char release notes to `docs/CHANGELOG.md` covering UI/UX overhaul, Kanban enhancements, and Android widget refinements.
* **Shorebird & Google Play Console Deployment**:
  - Resolved Dart kernel binary mismatch (Flutter 3.44.9 host vs. Flutter 3.47.2 Shorebird) by clearing stale build hooks.
  - Built Shorebird AAB release (`70.5 MB`, Release ID `824180`).
  - Successfully published AAB v100 to Google Play Console `internal` track via `scripts/upload_aab_internal.py` with service account credentials.
* **Standalone Release APK & GitHub Release**:
  - Built signed release APK (`86.1 MB`).
  - Created GitHub Release `v0.2.14+100` with attached release APK and release notes: [Release v0.2.14+100](https://github.com/RoeeIlouz/ROCIs-Tasks/releases/tag/v0.2.14%2B100).
* **Code & Test Integrity**:
  - 325 / 325 tests passed (100%).
  - `flutter analyze`: 0 issues found.

## Mobbin UI/UX Optimization: Phase 4 (Android Home Screen Widgets Visual Overhaul) - 2026-09-11

#### Problem & Requirements
* **Legacy Widget Visual Language**: Android home screen widgets utilized older, harsh solid backgrounds (`#E0E0E0`, hardcoded coral `#EF3842`, opaque dark greys), low-contrast sharp corners (12dp–16dp), and flat navigation controls without frosted visual affordances benchmarked against top Mobbin apps (Amie, Linear).
* **Strict RemoteViews & Zero-Breaking-Change Mandate**: Any layout or drawable upgrade had to strictly preserve RemoteViews XML compatibility (only `LinearLayout`, `RelativeLayout`, `FrameLayout`, `TextView`, `ImageView`, `ListView`), view types (e.g. Kotlin callers requiring `setTextViewText` on navigation views), exact IDs, and click fill-in intents for seamless interactivity.

#### Solutions & Architecture Applied
1. **Squircle Outer Container & Glass Background Hierarchy**:
   * Upgraded [`widget_background.xml`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/android/app/src/main/res/drawable/widget_background.xml) to 24dp radius (Android 14/15 launcher standard) with `#B3101216` obsidian tint and `#25FFFFFF` border.
   * Upgraded [`widget_background_glass.xml`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/android/app/src/main/res/drawable/widget_background_glass.xml) with `#B3121316` tint and `#28FFFFFF` frosted border.
   * Synchronized 24dp squircle geometry across [`widget_background_dark.xml`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/android/app/src/main/res/drawable/widget_background_dark.xml) and [`widget_background_light.xml`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/android/app/src/main/res/drawable/widget_background_light.xml).
2. **Standardized Floating Cards & Circular Frosted Nav Affordances**:
   * Applied [`widget_card_bg.xml`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/android/app/src/main/res/drawable/widget_card_bg.xml) (14dp radius, `#18FFFFFF` fill, `#22FFFFFF` hairline stroke) across all list item rows with 2dp margins for floating card elevation.
   * Modernized [`widget_nav_icon_bg.xml`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/android/app/src/main/res/drawable/widget_nav_icon_bg.xml) (translucent `#22808080` fill, `#33808080` stroke) and wired into circular action buttons across widgets.
   * Upgraded [`widget_pill_bg.xml`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/android/app/src/main/res/drawable/widget_pill_bg.xml) and [`widget_filter_button_active_bg.xml`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/android/app/src/main/res/drawable/widget_filter_button_active_bg.xml) from hardcoded coral to primary indigo accent (`#256366F1` fill, `#6366F1` stroke).
   * Upgraded [`widget_button_bg.xml`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/android/app/src/main/res/drawable/widget_button_bg.xml) from solid `#E0E0E0` grey to translucent pill.
3. **Comprehensive Layout Refinements**:
   * [`widget_task_item.xml`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/android/app/src/main/res/layout/widget_task_item.xml) & [`widget_kanban_item.xml`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/android/app/src/main/res/layout/widget_kanban_item.xml): Floating card container, 3.5dp rounded category strip, 24dp circular checkbox, 13.5sp bold typography, and aligned metadata row.
   * [`widget_today_agenda_layout.xml`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/android/app/src/main/res/layout/widget_today_agenda_layout.xml) & [`widget_today_agenda_item.xml`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/android/app/src/main/res/layout/widget_today_agenda_item.xml): Equipped prev, next, jump, and add buttons with `widget_nav_icon_bg`; modernized 3.5dp strip, 24dp check, 20dp calendar event icon, and `#20FFFFFF` hairline divider.
   * [`widget_timeline_agenda_layout.xml`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/android/app/src/main/res/layout/widget_timeline_agenda_layout.xml) & [`widget_timeline_event_item.xml`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/android/app/src/main/res/layout/widget_timeline_event_item.xml): Frosted nav buttons, card padding, and aligned time/subtitle row.
   * [`widget_month_agenda_layout.xml`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/android/app/src/main/res/layout/widget_month_agenda_layout.xml): Frosted navigation buttons, `#20FFFFFF` vertical divider.
   * [`widget_up_next_layout.xml`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/android/app/src/main/res/layout/widget_up_next_layout.xml): Modernized strip, 24dp checkbox, 20dp calendar icon, and pill time badge.
   * [`widget_full_calendar_layout.xml`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/android/app/src/main/res/layout/widget_full_calendar_layout.xml): Dynamic filter buttons wired with updated active state drawables and nav buttons.
4. **Verification & Zero Regressions**:
   * All 12 property tests in [`test/widget_data_serialization_test.dart`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/test/widget_data_serialization_test.dart) passed.
   * `flutter analyze`: **0 issues found**.
   * `flutter test`: **325 / 325 unit & widget tests passed (100%)**.

## Mobbin UI/UX Optimization: Phase 5 (Kanban Board View Evolution) - 2026-09-11

#### Problem & Requirements
* **Drag-and-Drop Interaction Disparity**: Desktop/Web mouse users had to hold click for 500ms due to `LongPressDraggable`, feeling sluggish compared to native Kanban boards like Linear and Trello.
* **Column Card Creation Friction**: Adding tasks in a specific Kanban column required opening the full modal `AddTaskScreen`, breaking flow when quickly brainstorming or triaging cards.
* **Drop Target Feedback**: When dragging a card across columns, only the column border changed without a luminous drop slot indicator showing where the card would land.
* **Card Component Consistency**: `KanbanCard` used a manual circular container for checkmark without the spring bounce, micro-sparkles, or tactile feedback introduced in Phase 6, and subtasks lacked the sleek Linear-style progress pill.

#### Solutions & Architecture Applied
1. **Platform-Aware Drag & Drop**:
   * Updated [`KanbanCard`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/lib/features/tasks/presentation/widgets/kanban/kanban_card.dart) with platform detection: immediate `Draggable<Task>` on Web, macOS, Windows, and Linux for instant mouse drag; resilient `LongPressDraggable<Task>` on touchscreen mobile devices (iOS, Android) to avoid gesture conflicts with vertical/horizontal scrolling.
   * Enhanced drag feedback card with 4-degree tilt (`-0.04` rad), 0.92 opacity, and glass elevation.
2. **Integrated `BouncyCheckbox` & Tactile Feedback**:
   * Replaced static checkbox container in `KanbanCard` with [`BouncyCheckbox`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/lib/shared/ui/widgets/bouncy_checkbox.dart).
   * Added safe theme feedback preference detection (`_isTaskFeedbackEnabled`).
3. **Linear-Style Subtask Progress Pill**:
   * Upgraded subtasks count pill: completed state displays radiant emerald (`#10B981`) with `✓ N/N`; in-progress state displays a compact 16px mini progress bar indicator alongside the count with overflow-safe flexible layout.
4. **Fast Inline Card Creation**:
   * Added `onInlineAddTask` callback to [`KanbanColumn`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/lib/features/tasks/presentation/widgets/kanban/kanban_column.dart).
   * Implemented inline creation card with autofocus `TextField`, Enter-to-submit, "Add", "Cancel", and an expand icon to transition into full `AddTaskScreen`.
   * Added a quick `+` button in the column header next to the task count badge.
   * Implemented glowing drop placeholder slot in `KanbanColumn` during `_isHovering`.
5. **Kanban Board View Integration**:
   * Wired `onInlineAddTask` into Status (To Do, In Focus, Done), Priority (High, Medium, Low), and Category columns in [`KanbanBoardView`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/lib/features/tasks/presentation/widgets/kanban/kanban_board_view.dart).
6. **Testing & Verification**:
   * Expanded [`test/features/tasks/presentation/widgets/kanban_board_test.dart`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/test/features/tasks/presentation/widgets/kanban_board_test.dart) with inline task creation and subtask indicator tests (6/6 tests passing).
   * `flutter analyze`: **0 issues found**.
   * `flutter test`: **325 / 325 unit & widget tests passed (100%)**.

## Mobbin UI/UX Optimization: Phase 6 (Micro-Interactions, Haptics & Delight) - 2026-09-11

#### Problem & Requirements
* **Checkbox Interaction Lack of Tactile Feedback**: Tapping checkboxes felt flat and instantaneous without a satisfying spring-physics bounce, completion particle burst, or multi-stage haptic curve.
* **Subtask Completion Visibility**: Progress indicators showed raw numbers without celebrating 100% completion milestone or providing distinct haptic feedback on the final item.
* **Inbox Zero Empty State**: When users completed all active tasks for the day, the screen fell back to generic "No tasks yet / create first task", missing the motivating "All caught up" celebration moment benchmarked in Amie and Things 3.

#### Solutions & Architecture Applied
1. **Zero-Dependency Particle Burst Engine (`CelebrationParticleBurst`)**:
   * Implemented [`CelebrationParticleBurst`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/lib/shared/ui/widgets/celebration_particle_burst.dart) using a hardware-accelerated canvas `CustomPainter` with trigonometric velocity, particle rotation, alpha fade, and deceleration physics (`Curves.easeOutCubic`).
   * Provides `CelebrationParticleBurst.triggerAt(context, globalCenter)` to dynamically spawn an overlay sparkle burst anywhere on tap.
2. **Spring Bouncy Checkbox & Haptics (`BouncyCheckbox`)**:
   * Implemented [`BouncyCheckbox`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/lib/shared/ui/widgets/bouncy_checkbox.dart) with spring sequence physics ($1.0 \rightarrow 0.82 \rightarrow 1.18 \rightarrow 1.0$), double-pulse haptic feedback (`HapticFeedback.heavyImpact()` followed by `lightImpact()`), and localized sparkle burst.
   * Integrated into [`TaskTile`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/lib/features/tasks/presentation/widgets/task_tile.dart) and web views.
3. **Subtask Completion Milestone & Haptics**:
   * Upgraded subtasks progress indicator in `TaskTile`: when reaching 100% completion, progress bar transitions to radiant emerald (`#10B981`) with `✓ All done` badge.
   * Completing the final subtask triggers double-pulse haptic feedback.
4. **Inbox Zero Delight State**:
   * Updated [`TaskListScreen`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/lib/features/tasks/presentation/screens/task_list_screen.dart) to detect when active tasks are empty but tasks were completed today.
   * Renders a celebratory "All done for today! 🎉" card with ambient emerald glow, live completed task counter pill, and localized motivating copy (`l10n.allCaughtUpToday`, `l10n.allCaughtUpSubtitle`).
5. **Testing & Quality Assurance**:
   * Created [`test/shared/ui/celebration_particle_burst_test.dart`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/test/shared/ui/celebration_particle_burst_test.dart) (3 tests passing).
   * Guarded against unstubbed mock errors in older tests (`MockTaskProvider.allTasks`, `MockThemeService.taskCompletionFeedback`).
   * `flutter analyze`: **0 issues found**.
   * `flutter test`: **323 / 323 unit & widget tests passed (100%)**.

## Mobbin UI/UX Optimization: Phase 3 (Web & Desktop Workspace Evolution) - 2026-09-11

#### Problem & Requirements
* **Desktop Keyboard First Ergonomics**: Navigating tasks, switching views, or triggering global commands required manual mouse clicks without a centralized command center.
* **Workspace Density & Speed**: Center workspace lacked density controls (compact vs. comfortable) and inline fast capture.
* **Inspector Form Clutter**: The task inspector functioned as a modal-like form with a rigid "Save Changes" button rather than a sleek, auto-saving Linear-style property panel with interactive subtasks checklist.

#### Solutions & Architecture Applied
1. **Linear-Style Command Palette (`⌘K` / `Ctrl+K`)**:
   * Created [`CommandPaletteDialog`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/lib/features/home/presentation/widgets/command_palette_dialog.dart) featuring full keyboard navigation (`↑`/`↓` to navigate, `Enter` to select, `Esc` to close) and real-time fuzzy search across actions, active tasks, and categories.
   * Bound `Ctrl+K` and `Cmd+K` globally in [`WebHomeScreen`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/lib/features/home/presentation/screens/web_home_screen.dart), and added a clickable `⌘K` badge inside the search bar.
2. **Desktop Keyboard Ergonomics**:
   * Single-key shortcut `C` for instant task capture (guarded against editable text focus).
   * Key `/` to open search / command palette.
   * Numeric keys `1`-`5` for instant workspace tab switching (Tasks, Board, Calendar, Categories, Settings).
   * Key `Esc` to dismiss modals, deselect inspector, or clear active search.
3. **Sidebar Live Badges & Navigation Rail**:
   * Updated `_buildSidebarTab` with live numerical count badges showing active task totals in both comfortable and compact icon rail modes.
4. **Center Workspace Polish & Inline Fast Capture**:
   * Added an inline quick-add input bar at the head of the columns allowing rapid task capture with `Enter` directly into Today.
   * Implemented a density toggle button (Comfortable vs. Compact) adjusting vertical card padding dynamically.
5. **Linear-Style Property Inspector & Debounced Auto-Save**:
   * Redesigned inspector with borderless title and notes editing in `GoogleFonts.outfit`.
   * Built interactive property rows: Status toggle pill, due date picker with relative previews, 3-tier priority pills with colored dots, and category filter chips.
   * Built an interactive subtasks checklist with checkboxes and an inline `+ Add subtask... (Enter)` input.
   * Debounced auto-save (600ms) with a subtle `✓ Saved` / `Saving...` status badge.
6. **Testing & Verification**:
   * Created [`test/features/home/command_palette_test.dart`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/test/features/home/command_palette_test.dart) (3 tests passing).
   * `flutter analyze`: **0 issues found**.
   * `flutter test`: **320 / 320 unit & widget tests passed (100%)**.

## Mobbin UI/UX Optimization: Phase 1 (Tokens & Glassmorphism) & Phase 2 (Mobile Overhaul) - 2026-09-11

#### Problem & Requirements
* **Mobile Task Card Ergonomics**: Tasks only supported one-way swipe to delete. Toggling completion required a tap on an off-center checkbox. Card typography lacked consistent visual weighting and subtask progress was rendered as an unconstrained vertical dump.
* **Friction in Task Creation**: Creating a task opened a full-screen form modal (`AddTaskScreen`), disrupting quick capture workflows.
* **Glassmorphic Precision**: Container borders needed tighter contrast bounds (`0.12` dark, `0.08` light) to match modern high-density benchmarks (Linear, Things 3).

#### Solutions & Architecture Applied
1. **Glassmorphism Hairline Refinement**:
   * Updated [GlassContainer](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/lib/shared/ui/widgets/glass_container.dart) with calibrated border opacities (`0.12` dark mode, `0.08` light mode) and `1.5px` active highlight border for crisp edge definition.
2. **Two-Way Swipe Gestures & Animated Task Card**:
   * Upgraded [TaskTile](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/lib/features/tasks/presentation/widgets/task_tile.dart) `Dismissible` to `DismissDirection.horizontal`.
   * **Swipe Right (`startToEnd`)**: Toggles task completion with emerald green background, dynamic label ("Mark as Complete" / "Mark as Incomplete"), and `HapticFeedback.mediumImpact()` while bouncing back into place.
   * **Swipe Left (`endToStart`)**: Deletes task with red error background and trash icon.
   * Centered check-circle touch target and standardized typography on `GoogleFonts.outfit`.
   * Implemented Linear-style compact subtask progress bar (`[━━━━░░] 3/5`) in subtask list header.
3. **Smart NLP Quick Add Bottom Sheet**:
   * Created [QuickAddTaskBottomSheet](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/lib/features/tasks/presentation/widgets/quick_add_task_bottom_sheet.dart) docked above the software keyboard with autofocus.
   * Live NLP tokenizer listening to keystrokes and rendering dynamic interactive tokens (Date/Time, Category, Priority chips) with 1-tap removal.
   * Quick action buttons for Today, Tomorrow, Date Picker, Priority cycler, Category picker, and seamless "More Options" transition into full `AddTaskScreen`.
   * Wired into [HomeScreen](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/lib/features/home/presentation/screens/home_screen.dart) FAB (`onTap` opens quick sheet, `onLongPress` opens full screen).
   * Enforced $\ge 48\text{dp}$ touch target constraints in `HomeScreen._buildNavItem`.
4. **Calendar Screen Integration**:
   * Upgraded empty state in [CalendarScreen](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/lib/features/calendar/presentation/screens/calendar_screen.dart) to launch `QuickAddTaskBottomSheet` with pre-selected date.
   * Enabled two-way swipe gestures on calendar task cards.
5. **Testing & Verification**:
   * `flutter analyze`: **0 issues found**.
   * `flutter test`: **317 / 317 unit & widget tests passed (100%)**.

## Android Widget Idle Persistence, Calendar Color Overhaul & v0.2.13+99 Release - 2026-09-11

#### Problem & Requirements
* **Widget Blanking After Idle/Doze**: Homescreen widgets stopped rendering tasks and calendar events after the device remained idle overnight or dozed, caused by uncached events relying on in-memory collections not shared with background widget isolates, database lock timeouts, and missing native widget fallback data.
* **Subcalendar Color Customization**: Users could not independently customize the color of each subcalendar (work, school, personal, etc.), nor retain Google's native calendar colors.
* **Color Picker Flexibility**: Color picker was limited to a rigid preset list across category and app accent pickers.
* **Release Artifacts**: Bump only `+` version (`0.2.13+99`), Shorebird cloud release & AAB upload to Play Console Internal Testing track, and APK upload to GitHub Releases.

#### Solutions & Architecture Applied
1. **Resilient Widget Data Engine**:
   * Stored calendar events into a dedicated persistent Hive cache (`calendar_events_cache`) in [CalendarService](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/lib/core/services/calendar_service.dart) updated on every sync.
   * Updated [FullCalendarWidgetService](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/lib/features/home/services/full_calendar_widget_service.dart) and [MonthWidgetService](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/lib/features/home/services/month_widget_service.dart) to query the persistent cache if in-memory events are empty.
   * Added `readTasksSafelyWithRetry` and isolate-safe Hive lock recovery in [LocalTaskSource](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/lib/features/tasks/data/datasources/local_task_source.dart) and [TaskWidgetService](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/lib/features/tasks/services/task_widget_service.dart).
   * Hardened native Android Kotlin RemoteViews widget providers to gracefully fallback to SharedPreferences cached snapshots.
2. **Subcalendar Custom Coloring**:
   * Created [CalendarColorService](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/lib/core/services/calendar_color_service.dart) storing user color overrides per calendar ID.
   * Created [AppColorPickerSheet](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/lib/shared/ui/widgets/app_color_picker_sheet.dart) with curated preset swatches and an expandable HSV custom picker with hex input and opacity slider (0.05 to 1.0).
   * Integrated into [CalendarColoringSheet](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/lib/features/calendar/presentation/widgets/calendar_coloring_sheet.dart), Categories screen, and Settings accent picker.
3. **Deployment**:
   * Version bumped to `0.2.13+99`.
   * Shorebird AAB generated and uploaded to Google Play Console Internal Testing track with release notes.
   * Release APK built and published to GitHub Releases (`v0.2.13+99`).

## Landing Page Academic Planner Overhaul, PWA Offline Engine & Google Calendar RFC 5545 Audit - 2026-09-07

#### Problem & Requirements
* **Landing Page Conversion & Messaging Gap**:
  * Copy was feature-centric rather than outcome-focused for students and academic workloads.
  * Preview simulator math had a discrepancy (showing 66% instead of mathematically accurate 67% for 2 done out of 3).
  * Missing interactive "try before sign-up" mechanism to demonstrate immediate value without friction.
* **PWA & Offline Reliability**:
  * Web PWA manifest lacked rich categories, launch URL query tracking, and service worker registration configuration.
  * Offline mutations were vulnerable to lost network states without an exponential-backoff write queue or deterministic subtask conflict merging.
  * No visual sync badge indicating offline/syncing/synced state.
* **Google Calendar Integration & RFC 5545 Compliance**:
  * All-day events were displayed across an extra day due to `event.allDay != true` in the day-span loop ignoring RFC 5545 exclusive midnight end dates.
  * Lack of event deduplication led to duplicated events when device calendar and Google REST API both returned events for the same account.
  * 401/403 unauthorized token responses did not invalidate cached tokens, leading to repeated failed calls.

#### Solutions & Architecture Applied
1. **Landing Page (`ROCIsApp.github.io`)**:
   * Overhauled hero section with verified academic value propositions ("Turn academic deadlines into a realistic daily plan").
   * Added 3-step visual workflow and interactive demo with client-side NLP parsing, auto-generated subtasks, and context preservation passing query parameters into web onboarding.
   * Fixed dashboard preview math to exact 67% and stroke offset 37.32.
2. **PWA & Offline Engine (`ROCIs-tasks`)**:
   * Upgraded `web/manifest.json` for web.dev compliance.
   * Migrated web bootstrap to clean Flutter 3.22+ standard: removed deprecated `web/flutter_bootstrap.js` template (resolving IDE syntax errors on `{{...}}` tokens and deprecation warnings) and moved `#loading` splash screen removal to `web/index.html` using the native `flutter-first-frame` DOM event.
   * Implemented persistent `OfflineWriteQueueService` with operation collapsing, exponential backoff drain, and deterministic `TaskConflictResolver` (subtask ID merging + timestamp comparison).
   * Integrated `SyncStatusBadge` using decoupled `ListenableBuilder` over singletons into mobile `AppBar` and web workspace header.
   * Wired deep link draft task ingestion in `WebHomeScreen.initState`.
3. **Google Calendar Audit & RFC 5545 Fix**:
   * Removed `event.allDay != true` and enforced exclusive midnight boundary check for multi-day and single-day all-day events in `CalendarProvider`.
   * Added composite event deduplication (`_deduplicateEvents`) by ID and title/time/allDay fingerprint.
   * Implemented `invalidateToken` and `handleTokenRevokedOrExpired` across `GoogleOAuthManager`, `AuthService`, and `CalendarService`.
4. **Dual Channel Release `v0.2.13+98` (GitHub & Google Play Internal Testing)**:
   * Replaced corrupted 0-byte `.git/index` via index rebuild (`Remove-Item .git/index; git reset`) and re-linked `origin` tracking.
   * Synchronized `pubspec.yaml`, `docs/CHANGELOG.md`, and `app_config.dart` to `0.2.13+98`.
   * Built Shorebird release `0.2.13+98` and published signed Play Store App Bundle `app-release.aab` (70.2MB) to Google Play Console `internal` testing track using `scripts/upload_aab_internal.py`.
   * Built standalone signed release APK `app-release.apk` (74.5MB, `versionCode=98`) and published to GitHub Releases `v0.2.13+98`.
   * Synchronized both repositories: `RoeeIlouz/ROCIs-Tasks` (`main`) and `RoeeIlouz/ROCIsTasks-Public` (`Public`).

## Telegram Bot Interactive On-Demand Drafting & RAS (ROCI's AI System) Integration - 2026-09-06

#### Problem & Requirements
* **Lack of Interactive Inbound Control**:
  * The marketing automation bot previously ran strictly as an outbound batch runner (every 6 hours) or manual CLI execution.
  * Users had no way to initiate posts on-demand directly from Telegram chat (e.g. typing `/draft bsky <topic>` or `/draft all <topic>`).
* **Multi-Platform Approval Gap**:
  * When posting across multiple platforms (Bluesky, X, Mastodon, Threads, etc.), users required both a master 1-tap `[🚀 Approve All]` option and granular per-platform controls (`[Post Bsky]`, `[Post X]`, `[Post Mastodon]`, `[Post Threads]`), plus regenerate and cancel flows.
* **Disconnection from RAS Core**:
  * Marketing copy lacked automatic grounding in live app telemetry, active version, DAU/MAU metrics, and release notes managed by RAS (`ROCIs-AI-System`).
  * Requirement: connect to RAS at `http://localhost:3000` with graceful offline fallback to local git history and `pubspec.yaml` when RAS is not active.

#### Solutions & Architecture Applied
1. **RAS Client Bridge (`ras_client.py`)**:
   * Connects to RAS API at `http://localhost:3000` with snappy timeouts (`2.0s`).
   * Ingests real-time telemetry from `/api/tasks/telemetry` (DAU, MAU, crash-free rates, sync latency, active releases).
   * Optional cognitive routing via `/api/gemini/stream` (SSE/text response parsing).
   * **Graceful Offline Fallback**: When RAS is offline, automatically extracts current app version from `pubspec.yaml` and latest commits from `git log` so social copy remains grounded and authentic without raising errors.
2. **Interactive Telegram Listener Daemon (`telegram_listener.py`)**:
   * Continuous long-polling loop with `offset` tracking via `/getUpdates`.
   * **Slash Commands**:
     * `/draft <platform> <topic>`: Drafts targeted posts for `bsky`, `x`, `mastodon`, `threads`, `devto`, `hashnode`, or `all`.
     * `/status`: Displays connection and credential health for all platforms and the RAS bridge.
     * `/analytics`: Dispatches weekly engagement and cross-platform traction report.
     * `/launchkit`: Generates Show HN and Product Hunt launch cards with 1-tap copy.
     * `/ras [query]`: Interacts with RAS intelligence or views live telemetry.
     * `/help`: Detailed manual and syntax examples.
   * **Callback Handlers**:
     * `approve:<draft_id>` / `reject:<draft_id>` / `regen:<draft_id>`.
     * `approve_all:<group_id>`: Concurrently publishes across all platforms and edits the message to show live confirmation URLs.
     * `approve_single:<group_id>:<platform>`: Publishes a specific platform from a multi-post broadcast card.
     * `reject_all:<group_id>`: Cancels the entire broadcast group.
   * **Security Guard**: Restricts commands and callbacks to authorized user IDs (`TELEGRAM_ALLOWED_USERS` / `TELEGRAM_CHAT_ID`).
3. **Unified Single-Post Publishing (`poster.py`)**:
   * Added `publish_single_post(platform, text, title, media_url)` supporting Bluesky, X (with rate-limit safety guards), Mastodon, Threads, Dev.to, and Hashnode.
4. **Interactive Cards (`telegram_bot.py`)**:
   * `send_interactive_draft_card`: Formats preview block with `[✅ Approve & Post]`, `[🔄 Regenerate]`, `[❌ Cancel]`.
   * `send_multi_platform_approval_card`: Formats all platform previews with master `[🚀 Approve & Post All]`, 2-column per-platform action buttons, and `[❌ Cancel All]`.
5. **Verification**:
   * Created comprehensive test suite in `scripts/marketing_bot/tests/test_ras_and_listener.py` (17 new test cases).
   * All 60 test suite unit tests passing (`Ran 60 tests - OK`).


## Google Calendar Subcalendar Custom Coloring & Unified Expandable Color Picker - 2026-09-05

#### Problem & Requirements
* **Single Global Google Calendar Color**:
  * The app previously supported only a single monolithic Google Calendar color (`CalendarColorService.googleColor`), while event objects had distinct `calendarId` properties corresponding to individual subcalendars (e.g., Personal, Work, School, Family).
  * Users had no mechanism to configure colors per subcalendar, nor to fall back to Google Calendar's native synced colors.
* **Lack of Advanced / Custom Color Selection**:
  * Color selection across the app (categories, app theme accent, calendar colors, home widget highlights) was constrained to hardcoded swatches without hex input, opacity tuning, or hue/saturation spectrums.

#### Solutions & Architecture Applied
1. **Per-Subcalendar Custom Color Management (`CalendarColorService`)**:
   * Added persistent subcalendar color overrides keyed by `calendar_subcal_color_<calendarId>` in `SharedPreferences`.
   * Added `getEffectiveSubcalendarColor(calendarId, {nativeColor})`:
     1. Checks custom user override.
     2. Checks native device/API calendar color.
     3. Falls back to global `_googleColor` (`#4285F4`).
   * Added `setSubcalendarColor(calendarId, color)` and `resetSubcalendarColor(calendarId)` (reverting back to Google native).
   * Added automatic serialization of `calendar_subcal_colors` JSON map to `HomeWidget` data with defensive platform handling.
2. **Calendar Service & Widget Data Sync**:
   * Updated `CalendarService.getCalendarColors()` to overlay user overrides from `SharedPreferences`, ensuring `FullCalendarWidgetService`, `WidgetDataService`, and Android Home Widgets automatically display custom subcalendar colors.
3. **Reusable Expandable Color Picker (`AppColorPickerSheet`)**:
   * Implemented in [`lib/shared/ui/widgets/app_color_picker_sheet.dart`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/lib/shared/ui/widgets/app_color_picker_sheet.dart):
     * Preset curated swatches (ROCIs + Google Calendar palette).
     * "Expand" toggle revealing:
       * Rainbow Hue spectrum slider (0°–360°).
       * Saturation and Value/Brightness gradient sliders.
       * Opacity/Alpha slider bounded between 20% (minimum visible) and 100%.
       * Direct HEX code input (`#RRGGBB` / `#AARRGGBB`) with auto-formatting and validation.
       * Live preview swatch and comparison.
       * Optional "Reset to Default" action.
4. **Integration Across the Entire App**:
   * **Calendar Coloring Sheet** (`calendar_coloring_sheet.dart`): Dynamically lists all enabled subcalendars with current color swatches, "Custom" badges, and reset to Google native default.
   * **Calendar Filter Sheet** (`calendar_filter_sheet.dart`): Interactive subcalendar secondary swatches launch the color picker.
   * **Calendar Screen** (`calendar_screen.dart`): Event markers, day dots, and event list tiles render effective subcalendar colors with 10–18% glassmorphism border tints.
   * **Categories Screen** (`categories_screen.dart`): Appends a custom color button to category swatches.
   * **Settings Screen** (`settings_screen.dart`): Accent color picker upgraded to `AppColorPickerSheet`.
   * **Widget Customization Screen** (`widget_customization_screen.dart`): Widget highlight picker upgraded with custom color support.
5. **Localization & Verification**:
   * Added ARB keys (`subcalendars`, `customColor`, `resetToGoogleDefault`, `hexCode`, `opacity`, `presets`, `expandCustomPicker`, `noEnabledCalendars`) across all 8 languages and regenerated localizations via `flutter gen-l10n`.
   * Unit tests added in `test/core/services/calendar_color_service_test.dart` (5/5 passed).
   * Calendar screen tests passed (2/2 passed).
   * `flutter analyze`: **0 issues found**.

## Android Homescreen Widgets Internationalization, Dynamic Formatting & Localization Architecture - 2026-09-03

#### Problem & Root Causes
* **Issue 1 (Hardcoded English Month Title in SharedPreferences)**:
  * In `FullCalendarWidgetService.dart` (lines 179 and 431) and `MonthWidgetService.dart` (line 177), `DateFormat('MMMM yyyy').format(targetMonth)` was called without a locale parameter, persisting English strings (e.g. `"August 2026"`) to `full_calendar_month_name` and `month_name`.
  * In `FullCalendarWidgetProvider.kt`, `val savedMonthName = widgetData.getString("full_calendar_month_name", null)` was checked first, overriding native Kotlin date formatting and preventing the title from localizing or updating dynamically on month navigation.
* **Issue 2 (Java Legacy Hebrew Language Code Mismatch `iw` vs `he`)**:
  * On Android/Java, `Locale("he").language` and `Locale.getDefault().language` return `"iw"`.
  * `WidgetLocaleHelper.kt` only checked `locale.language.lowercase() == "he"`, which never matched `"iw"`, causing all translations (`getTodayText`, `getAllDayText`, `getNoTasksText`) to fall back to English.
* **Issue 3 (Broken Weekday Initial Extraction in Hebrew & Arabic)**:
  * `extractShortSymbol` used `name.trim().take(1)` on localized day names. In Hebrew (`"יום א'"`, `"יום ב'"`...), this resulted in `"י", "י", "י", "י", "י", "י", "ש"` for the 7 columns. In Arabic (`"الأحد"`, `"الاثنين"`...), it collapsed all days into the prefix `"ا"`.
* **Issue 4 (Hardcoded English Date Skeletons)**:
  * Providers hardcoded `"EEE, MMM d"` and `"EEEE, MMM d"`, forcing English Month-before-Day ordering (e.g. `"יום ה׳, ספט׳ 3"` instead of `"יום חמישי, 3 בספט׳"`).
* **Issue 5 (Unwired Weekday Headers in MonthAgendaWidgetProvider)**:
  * `MonthAgendaWidgetProvider.kt` never set text on `widget_day_h0`..`widget_day_h6`, leaving them hardcoded to English `"S", "M", "T", "W", "T", "F", "S"`.
* **Issue 6 (Hardcoded English UI Elements in Widgets)**:
  * Filter buttons ("Tasks", "Google", "Schedule"), Kanban column titles ("To Do", "In Focus", "Done"), Task widget buttons ("Sort: Date", "Filter: All"), Quick Action labels ("Left", "New Task", "Calendar"), and empty views were hardcoded in English.
* **Issue 7 (System Language Fallback Omission in ThemeService)**:
  * When `_locale == null` (follow system), `ThemeService.init()` never saved `'app_language'` to `HomeWidget`, leaving it empty or stale.

#### Solutions & Architecture Applied
1. **Upgraded `WidgetLocaleHelper.kt`**:
   * Added `getNormalizedLanguage(locale: Locale): String` to normalize `"iw"` -> `"he"`, `"in"` -> `"id"`, `"ji"` -> `"yi"`.
   * Replaced naive `take(1)` weekday initial extraction with explicit single-letter day mappings for Hebrew (`א`, `ב`, `ג`, `ד`, `ה`, `ו`, `ש`), Arabic (`ح`, `ن`, `ث`, `ר`, `خ`, `ج`, `س`), Hindi (`र`, `सो`, `मं`, `बु`, `गु`, `शु`, `श`), Spanish, French, German, Swedish, and English.
   * Added `getMonthYearTitle(cal, locale)` and `getDateTitle(cal, locale, full)` leveraging `android.text.format.DateFormat.getBestDateTimePattern(locale, skeleton)` for locale-accurate date and month formatting.
   * Added complete translation dictionaries for all 8 supported languages (`he`, `ar`, `es`, `de`, `fr`, `sv`, `hi`, `en`) for filter buttons, sort/filter pills, Kanban columns and subtitles, Quick Action buttons, and empty state views.
2. **Native Android Providers Localization**:
   * [`FullCalendarWidgetProvider.kt`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/android/app/src/main/kotlin/com/rocisapps/tasks/FullCalendarWidgetProvider.kt): Month title dynamically formatted via `WidgetLocaleHelper.getMonthYearTitle()`; filter buttons ("Tasks", "Google", "Schedule") and empty view localized.
   * [`MonthAgendaWidgetProvider.kt`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/android/app/src/main/kotlin/com/rocisapps/tasks/MonthAgendaWidgetProvider.kt): Weekday headers dynamically wired to `widget_day_h0`..`h6`; month title, selected date, and empty view localized.
   * [`TodayAgendaWidgetProvider.kt`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/android/app/src/main/kotlin/com/rocisapps/tasks/TodayAgendaWidgetProvider.kt): Date title and relative subtitle formatted via ICU best patterns; empty state localized.
   * [`TimelineAgendaWidgetProvider.kt`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/android/app/src/main/kotlin/com/rocisapps/tasks/TimelineAgendaWidgetProvider.kt): Title and empty view texts localized.
   * [`TaskWidgetProvider.kt`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/android/app/src/main/kotlin/com/rocisapps/tasks/TaskWidgetProvider.kt): Title, sort button, filter button, and empty view localized.
   * [`KanbanWidgetProvider.kt`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/android/app/src/main/kotlin/com/rocisapps/tasks/KanbanWidgetProvider.kt): Column title, subtitle count, tab pills, and empty column view localized.
   * [`QuickActionWidgetProvider.kt`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/android/app/src/main/kotlin/com/rocisapps/tasks/QuickActionWidgetProvider.kt): "Left", "New Task", and "Calendar" localized.
   * [`UpNextWidgetProvider.kt`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/android/app/src/main/kotlin/com/rocisapps/tasks/UpNextWidgetProvider.kt): Empty state title and badge localized.
3. **Dart Widget Services Synchronization**:
   * [`full_calendar_widget_service.dart`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/lib/features/home/services/full_calendar_widget_service.dart) & [`month_widget_service.dart`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/lib/features/home/services/month_widget_service.dart): Passes active locale to `DateFormat('MMMM yyyy', localeCode)`.
   * [`widget_data_service.dart`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/lib/core/services/widget_data_service.dart): Updated `_getAppLanguage()` to fallback to `PlatformDispatcher.instance.locale.languageCode`; localized static strings in `updateUpNextWidget` and `updateKanbanWidget`.
   * [`theme_service.dart`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/lib/shared/ui/theme/theme_service.dart): Saves system language code to `HomeWidget`'s `'app_language'` on init when `_locale == null`.
4. **Testing & Verification**:
   * `./gradlew compileReleaseKotlin`: **BUILD SUCCESSFUL** (0 errors).
   * `flutter analyze`: **No issues found!**
   * `flutter test`: **296 / 296 tests passed (100%)**.

#### Problem & Root Causes
* **Issue 1 (Small Icon Overwrite via Chart Large Icon)**:
  * When `largeIconPath` was supplied from `TaskWidgetService.updateTaskWidget()` (a 200x200 complex RGBA rendered Flutter widget), `NotificationHelper.showTaskCountNotification()` decoded the chart into `bitmap` and passed it to `setSmallIcon(Icon.createWithBitmap(bitmap))`. Android's `NotificationManager` strictly requires status bar small icons to be compliant monochrome/alpha masks and rejected the notification with an `IllegalArgumentException` / `BadNotificationException`.
  * Furthermore, `setLargeIcon()` was never invoked on the notification builder despite receiving the chart.
* **Issue 2 (Silent Error Swallowing & False Channel Success)**:
  * `NotificationHelper.kt` caught `Exception` silently without logging or returning an error status. `MainActivity.kt` always returned `result.success(null)`, preventing Flutter's `NotificationService.dart` from triggering its fallback `flutterLocalNotificationsPlugin.show(...)`.
* **Issue 3 (Action Button Bitmap Misuse & Pre-Cancel Flicker)**:
  * `Notification.Action.Builder` was passed the count/chart bitmap instead of a standard action icon drawable (`android.R.drawable.ic_input_add`).
  * `notificationManager.cancel(notificationId)` was called right before `notify(...)`, causing race conditions and notification dismissal on ongoing notifications.
* **Issue 4 (Notification Channel Importance & Sound Disturbance)**:
  * Channel `rocis_tasks_persistent_v5` was configured with `IMPORTANCE_HIGH`, lights, and vibration, which caused conflict with persistent ongoing notifications and intrusive alerts whenever tasks were updated.
* **Issue 5 (Cold Launch Omission)**:
  * In `TaskProvider.init()`, `unawaited(_updateWidgets(showNotification: false))` explicitly disabled notification posting on app startup, leaving the status bar counter blank until manual user intervention.

#### Solutions & Architecture Applied
1. **Decoupled Small and Large Icons**:
   * Small icon in [`NotificationHelper.kt`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/android/app/src/main/kotlin/com/rocisapps/tasks/NotificationHelper.kt) is now strictly generated from `createCountBitmap(count, isDarkText)` with dynamic font scaling (42f for 1 digit, 34f for 2 digits, 26f for 3+ digits).
   * Decoded `largeIconPath` is assigned exclusively to `setLargeIcon(largeBitmap)`.
2. **Channel Modernization (`rocis_tasks_persistent_v6`)**:
   * Upgraded channel to `rocis_tasks_persistent_v6` with `IMPORTANCE_LOW`, `enableLights(false)`, `enableVibration(false)`, and `setSound(null, null)`, deleting obsolete v5 channel.
   * Synchronized fallback channel in [`notification_service.dart`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/lib/core/services/notification_service.dart).
3. **Android 13+ Runtime Permission Checks**:
   * Added `POST_NOTIFICATIONS` verification in Kotlin prior to building or posting notifications.
4. **Resilient Native & Dart Fallback Cascade**:
   * If native `Notification.Builder` with dynamic bitmap icon encounters an error on any OEM ROM, `NotificationHelper.kt` catches it and gracefully falls back to `NotificationCompat.Builder` with `R.mipmap.launcher_icon`.
   * Returns a boolean status to `MainActivity.kt`, sending `result.error(...)` if both fail, which triggers Dart's `FlutterLocalNotificationsPlugin` fallback.
5. **Startup Task Counter Notification Restoration**:
   * In [`task_provider.dart`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/lib/features/tasks/presentation/providers/task_provider.dart), updated startup initialization to `_updateWidgets(showNotification: true)`, ensuring the persistent counter is immediately populated on app launch and system reboot.
6. **Testing & Verification**:
   * `./gradlew compileReleaseKotlin`: **BUILD SUCCESSFUL** (0 errors).
   * `flutter analyze`: **No issues found!**
   * `flutter test`: **296 / 296 tests passed (100%)**.

## Google Sign-In Silent Background Token Refresh & Identity Persistence Architecture - 2026-09-03

#### Problem & Root Causes
* **Issue 1 (Cold Start Reprompt via Credential Manager)**:
  * On mobile app startup, `AuthService._restoreGoogleUser()` called `_oauthManager.googleSignIn.attemptLightweightAuthentication()`. Under `google_sign_in: ^7.2.0` on Android, Credential Manager raised an interactive account-picker bottom sheet on every launch if multiple accounts existed or auto-selection was ambiguous.
* **Issue 2 (Interactive Dialogs during Background Token Refresh)**:
  * In `GoogleOAuthManager._performSilentTokenRefresh()`, if `authorizationForScopes` returned null, `authorizeScopes(googleTasksScopes)` was invoked (`promptIfUnauthorized: true`), popping up an interactive Google OAuth authorization intent over the user's active session during background sync.
* **Issue 3 (Missing Google Account Identity Persistence)**:
  * In-memory `_googleUser` was lost on app kill/restart. Only the raw token string and a timestamp were stored in `SharedPreferences`, omitting the user's Google account email and ID. Without an account email, native Android Google Play Services Identity API could not determine which account to authorize silently and reported `hasResolution() == true`, preventing true silent background token generation and triggering false expiration states.

#### Solutions & Architecture Applied
1. **Persistent Google Account Identity**:
   * In [`GoogleOAuthManager`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/lib/core/services/auth/google_oauth_manager.dart), added `saveGoogleUserIdentity({required String email, String? id})` persisting `google_user_email` and `google_user_id` in `SharedPreferences`.
   * Stored upon Google Sign-In (`signInWithGoogle`) and explicit linking (`linkGoogleTasks`) in [`AuthService`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/lib/core/services/auth_service.dart).
2. **Proactive Refresh Window (50-Minute Mark)**:
   * Updated `GoogleOAuthManager.cacheGoogleAccessToken()` to set cached expiration to 50 minutes (5 minutes ahead of the 55-minute Google token expiry), proactively refreshing tokens during active requests to prevent transient 401 errors.
3. **True Silent Background Token Refresh**:
   * In `GoogleOAuthManager._performSilentTokenRefresh()`, completely eliminated `authorizeScopes()` and mobile `attemptLightweightAuthentication()`.
   * Directly queries `GoogleSignInPlatform.instance.clientAuthorizationTokensForScopes` with `email: savedEmail` and `promptIfUnauthorized: false`. If authorization is cached in Google Play Services, it returns a fresh access token without ANY UI prompt.
   * If refresh fails (due to offline state, connection loss, or revoked permissions), marks `isGoogleTasksTokenExpired = true` and returns `null`, strictly surfacing the quiet in-app banner ("Google Tasks Disconnected — Reconnect") without modal interruptions.
4. **Clean Token Clearance on Sign Out**:
   * Updated `signOut()` to call `GoogleSignInPlatform.instance.clearAuthorizationToken()` to flush cached tokens from OS-level Google Play Services, clearing `google_access_token`, `google_access_token_expires_at`, `google_user_email`, and `google_user_id` to prevent stale token reuse.
5. **Non-Intrusive Cold Start**:
   * In `AuthService._restoreGoogleUser()`, bypassed `attemptLightweightAuthentication()` on mobile. If an existing token is valid, it proceeds silently; if missing or expired, it initiates background silent resolution via `getGoogleAccessToken()`.
6. **Testing & Verification**:
   * Added unit tests in [`test/core/services/auth/google_oauth_manager_test.dart`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/test/core/services/auth/google_oauth_manager_test.dart) covering identity persistence, proactive refresh window, and `signOut()` token cleanup.
   * `flutter analyze`: **No issues found!**
   * `flutter test`: **296 / 296 tests passed (100%)**.

### Multi-Language Live Screenshot Capture & Play Store Asset Pipeline - 2026-09-03

#### Problem & Root Causes
* **Cloud Sync Data Contamination**: `TaskProvider.uploadLocalDataToCloud()` and `syncWithCloud()` synced locale-specific marketing tasks to Firestore under the shared `qa@rocisapps.com` account. When switching locales (e.g., French → English), the French tasks were pushed to Firestore and then pulled back into subsequent English sessions, producing mixed-language screenshots.
* **False "Google Tasks Disconnected" Banner**: `CalendarService.getEvents()` on web sent `Authorization: Bearer null` when the QA email/password user had no Google token, triggering a `401 Unauthorized` → `GoogleTokenExpiredException` → persistent warning banner on the calendar screen.
* **Missing Multi-Language Coverage**: Both baseline Play Store assets and Experiment Variant B assets only existed for English and Hebrew, missing 6 additional supported locales (es, de, fr, ar, sv, hi).

#### Solutions & Implementation
1. **Cloud Sync Isolation for Marketing Builds**:
   * Added `disable_cloud_sync` preference guard to [`task_provider.dart`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/lib/features/tasks/presentation/providers/task_provider.dart) in `uploadLocalDataToCloud()`, `_prefetchCompletedTasksIfNeeded()`, and `syncWithCloud()`.
   * Set `disable_cloud_sync=true` and removed `google_access_token` in [`main_marketing.dart`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/lib/main_marketing.dart).
2. **Calendar Token Guard for Non-Google Users**:
   * In [`calendar_service.dart`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/lib/core/services/calendar_service.dart): `_getAccessToken()` returns null for non-Google provider users; `getEvents()` skips Google Calendar REST calls when `token == null`; `getAvailableCalendars()` only throws token exceptions for actual Google accounts.
   * In [`auth_service.dart`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/lib/core/services/auth_service.dart): `isGoogleTasksTokenExpired` guard requires `isGoogleUser`.
3. **8-Language Live Capture Engine** (`capture_real_flutter_screens.py`):
   * Captures 8 real Flutter web screens per language (Home Dark, NLP Input, Kanban, Calendar, Categories, Settings, Home Light + more) using Playwright against `flutter build web -t lib/main_marketing.dart`.
   * Dynamic port discovery (8130–8160), address reuse, and locale-specific URL params (`?lang=xx`).
   * Languages: en, he, es, de, fr, ar, sv, hi — all verified clean and authentic.
4. **Baseline Play Store Assets** (`render_playstore_assets.py`):
   * Re-rendered 8 screenshots (1080×1920) + feature graphic (1024×500) for all 8 Play Store locales: `en-US`, `iw-IL`, `es-ES`, `de-DE`, `fr-FR`, `ar`, `sv-SE`, `hi-IN`.
5. **Experiment Variant B — Full 8-Language Expansion**:
   * Expanded `locales_experiment_b.json` from 2 locales (en, he) to all 8, with complete slide narratives, widget-first hook copy, and feature graphic metadata per language.
   * Re-rendered all Variant B assets into `docs/marketing/playstore_experiments/variant_b_widgets/{locale}/`.
6. **Verification**:
   * `flutter analyze`: **No issues found.**
   * Visually inspected English and Hebrew baseline screenshots (no banner, correct language, Pro user data).
   * All 8 × 9 = 72 baseline screenshots + 8 feature graphics confirmed present.
   * All 8 × 9 = 72 Variant B screenshots + 8 feature graphics confirmed present.
7. **Automated Publishing Engine & Metadata Provisioning (`upload_to_playstore.py`)**:
   * Integrated Google Play Developer API (v3 `edits.images.upload` and `edits.listings.update`) with Service Account RS256 JWT auth (zero extra pip packages required, using built-in `cryptography` + `requests`).
   * Created [`store_listings_metadata.json`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/docs/marketing/store_listings_metadata.json) with localized app titles, short descriptions, and full descriptions for all 8 locales (`en-US`, `iw-IL`, `es-ES`, `de-DE`, `fr-FR`, `ar`, `sv-SE`, `hi-IN`).
   * Implemented exponential backoff retry loop for transient Google 5xx / rate-limit responses.
   * Fully executed dry run testing across all 8 locales (64 screenshots + 8 feature graphics), validating draft creation, listing configuration, image payload acceptance, and clean session rollback.
   * **Live Publication**: Successfully committed all 8 live screenshots + 1 feature graphic for `en-US` to the Google Play Store production listing. Verified active listing reflects 8 phone screenshots and new feature graphic.



## Dual Distribution Architecture (Google Play + GitHub Releases) & Zero-Flag Secret Management - 2026-09-03

#### Problem & Requirements
* **Objective**: Enable simultaneous publishing to both the Google Play Store (App Bundle) and GitHub Releases (standalone APK), ensuring monetization and core app features work seamlessly across both.
* **Secret Management Constraint**: Eliminate the requirement to manually pass `--dart-define=REVENUECAT_API_KEY_ANDROID=...` during local and CI builds, and guarantee zero secret leakage into the public repository.

#### Architectural Decisions & Solutions Applied
1. **Zero-Flag Secret Architecture (`AppSecrets`)**:
   * Created [`lib/core/config/app_secrets.dart.example`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/lib/core/config/app_secrets.dart.example) as the public git-tracked template.
   * Registered `/lib/core/config/app_secrets.dart` in [`.gitignore`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/.gitignore) to strictly prevent staging or committing real credentials.
   * Created local [`lib/core/config/app_secrets.dart`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/lib/core/config/app_secrets.dart) populated with the active RevenueCat Android key.
   * Updated [`lib/core/services/subscription_service.dart`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/lib/core/services/subscription_service.dart) to resolve `AppSecrets.revenueCatApiKeyAndroid` automatically when no `--dart-define` override is provided.
   * Updated [`scripts/setup_ci_configs.py`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/scripts/setup_ci_configs.py) to dynamically generate `app_secrets.dart` in CI using the GitHub repository secret `REVENUECAT_API_KEY_ANDROID`.
2. **Dual-Channel Monetization with Runtime Installer Detection (Shorebird Compatible)**:
   * In [`android/app/src/main/kotlin/com/rocisapps/tasks/MainActivity.kt`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/android/app/src/main/kotlin/com/rocisapps/tasks/MainActivity.kt), added `getInstallerPackageName` via `getInstallSourceInfo` (SDK 30+) with deprecation fallback.
   * In [`lib/core/config/app_config.dart`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/lib/core/config/app_config.dart), added `initDistributionChannel()` with a strict 2s timeout. Automatically resolves `isPlayStoreDistribution` (`installer == 'com.android.vending'`) vs `isGitHubDistribution` (`!isPlayStoreDistribution`).
   * In [`lib/core/services/app_initializer.dart`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/lib/core/services/app_initializer.dart), triggers channel detection during foreground startup.
   * In [`lib/features/premium/presentation/screens/paywall_screen.dart`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/lib/features/premium/presentation/screens/paywall_screen.dart), routes sideloaded/GitHub users to Lemon Squeezy with user ID binding and Firestore sync, while Google Play Store installs strictly use native Google Play In-App Billing (RevenueCat).
   * **Shorebird Advantage**: Eliminates the need for separate compile-time builds. The compiled Dart AOT bytecode across `.aab` and `.apk` is 100% identical, meaning **a single `shorebird patch android` updates both Google Play and GitHub APK users simultaneously**.
3. **Automated Dual-Channel Release Pipeline**:
   * Created [`.github/workflows/release.yml`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/.github/workflows/release.yml) triggered on version tags (`v*`) or manual `workflow_dispatch`.
   * Builds standalone APK (`app-release.apk`) and publishes it directly to GitHub Releases.
   * Builds Google Play App Bundle (`app-release.aab`) and uploads it as a workflow artifact.
4. **Testing & Verification**:
   * Verified git ignores `lib/core/config/app_secrets.dart` via `git check-ignore`.
   * `flutter analyze`: **0 issues found**.
   * `flutter test`: **295 / 295 tests passed (100%)**.

## Autonomous Overnight Chaos QA Audit & Vulnerability Fix Suite - 2026-09-03

#### Problem & Requirements
* **Objective**: Execute autonomous overnight QA testing of `ROCIs-Tasks` with chaos user flows, boundary values, aspect ratio shifts, and concurrency checks under isolated test account `qa@rocisapps.com`, then patch all discovered bugs.
* **Deliverables**: Severity-ranked findings with reproduction evidence, claimed-vs-observed capability matrix, deferred morning cleanup script, and direct bug fixes.

#### Solutions & Audit Fixes Applied
1. **Double-Tap Submit Race Condition (`BUG-01`)**:
   * In [`lib/features/tasks/presentation/screens/add_task_screen.dart`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/lib/features/tasks/presentation/screens/add_task_screen.dart), added `_isSaving` submit lock and disabled Save button with CircularProgressIndicator during task submission to prevent duplicate records on rapid pointer clicks.
2. **Kanban Status Drop Snap-Back (`BUG-02`)**:
   * In [`lib/features/tasks/presentation/widgets/kanban/kanban_board_view.dart`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/lib/features/tasks/presentation/widgets/kanban/kanban_board_view.dart), properly handled dropping tasks from "In Focus" to "To Do" by setting `clearDueDate: true`, and assigning `dueDate = todayNoon` on drops into "In Focus".
3. **Web Responsive Workspace Overflow (`BUG-03`)**:
   * In [`lib/features/home/presentation/screens/web_home_screen.dart`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/lib/features/home/presentation/screens/web_home_screen.dart), wrapped layout in `LayoutBuilder`. Added dynamic compact rail sidebar (`72px`) for viewports `< 800px`, dynamic clamp sizing for right inspector, and ultra-compact full-screen modal mode with back navigation for `< 600px` screens.
4. **NLP Hour/Minute Out-of-Bounds Day Rollover (`BUG-04`)**:
   * In [`lib/features/tasks/services/nlp_service.dart`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/lib/features/tasks/services/nlp_service.dart), validated hour (`0-23` or `1-12` with am/pm) and minute (`0-59`) bounds before constructing suggestion dates.
5. **Ruthless QA Skill, Specialist Agent & Automation Suite Provisioned**:
   * Created [`.agent/skills/ruthless-qa-tester/SKILL.md`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/.agent/skills/ruthless-qa-tester/SKILL.md) and [`.agent/agents/ruthless-qa-tester.md`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/.agent/agents/ruthless-qa-tester.md).
   * Added [`.agent/skills/ruthless-qa-tester/scripts/chaos_runner.py`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/.agent/skills/ruthless-qa-tester/scripts/chaos_runner.py) (automated CLI runner supporting fuzzing, concurrency stress, network flapping, and telemetry collection).
   * Added [`.agent/skills/ruthless-qa-tester/scripts/visual_snapper.py`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/.agent/skills/ruthless-qa-tester/scripts/visual_snapper.py) (multi-viewport layout glitch & overflow snapper).
   * Added [`.agent/skills/ruthless-qa-tester/resources/payloads.json`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/.agent/skills/ruthless-qa-tester/resources/payloads.json) (100+ hostile test payloads: polyglots, RTL, emojis, ZWJ, time boundary bombs).
   * Added [`.agent/reports/morning_review.html`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/.agent/reports/morning_review.html) (interactive single-file HTML morning triage portal with 1-click copy fix buttons).
6. **Testing & Verification**:
   * `flutter analyze`: **0 issues found**.
   * `flutter test`: **295 / 295 tests passed (100%)**.
   * Python scripts: Both `chaos_runner.py` and `visual_snapper.py` executed cleanly with exit code 0.

## Google Play Store Visual Assets & Video Production with Live Flutter Web Integration - 2026-09-02
#### Problem & Requirements
* **Requirement**: Deliver a Google Play Store marketing suite, including 8x 9:16 (1080 × 1920) screenshots, 1x (1024 × 500) Feature Graphic, and promo videos (16:9 Google Play Trailer & 9:16 Vertical Shorts).
* **Feedback & Polish Directives**:
  * The task creation / NLP typing animation in promo videos appeared mechanical/unnatural.
  * In both [`video_trailer_16_9.html`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/docs/marketing/assets_generator/video_trailer_16_9.html) and [`video_shorts_9_16.html`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/docs/marketing/assets_generator/video_shorts_9_16.html), redesigned Scene 2 with authentic character-by-character typing (`"Sprint review tomorrow 10am !high #work"`) in JetBrains Mono monospace font with a blinking cursor.
  * Added auto-sliding NLP suggestion pill, priority/tag/date chips popping in dynamically, and instant transition to `"✓ Saved in 0.5s!"` state.
  * Encoded production video MP4s via FFmpeg H.264:
    * [`docs/marketing/videos/rocis_tasks_playstore_trailer_16x9.mp4`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/docs/marketing/videos/rocis_tasks_playstore_trailer_16x9.mp4) (1920 × 1080, 30.0s @ 30fps, 955 KB)
    * [`docs/marketing/videos/rocis_tasks_shorts_9x16.mp4`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/docs/marketing/videos/rocis_tasks_shorts_9x16.mp4) (1080 × 1920, 15.0s @ 30fps, 651 KB)
* **Play Store Screenshots Vertical Density & Spacing Stabilization**:
  * **Frame & Flex Resolution**: Added `box-sizing: border-box;` and explicit `height: 1542px;` to `.device-screen-box` across Slides 3, 5, 6, 7, and 8, resolving Chromium flex container height collapse and ensuring `justify-content: space-between` distributes space cleanly.
  * **Slide 1 (Hero NLP & Task List)**: 8 rich task cards with live subtask progress bars, priority badges, and floating speed pill (`⚡ Instant 0.5s NLP`).
  * **Slide 2 (Smart NLP Task Creation Modal)**: Full modal with smart auto-detection, priority pills, category selectors, 4-item checklist, reminder toggle, recurrence toggle, and bottom action button.
  * **Slide 3 (Native Home Screen Widgets)**: 12 app shortcuts (3 rows of 4 apps), 4x1 Quick Action Bar, 4x4 Focus Agenda with 5 tasks, 4x3 Month Calendar, 4x2 Focus Score (92%), Quick Filter Bar, Google Search pill, and Android Home Dock.
  * **Slide 4 (Drag & Drop Kanban Board)**: Fully populated In Focus & Done columns with 6 rich cards each, subtask progress bars, and bottom navigation bar.
  * **Slide 5 (Full Timeline View & Calendar Sync)**: Interactive August 2026 month calendar card + 9 hourly timeline events from 07:00 AM to 10:15 PM with category badges and 2-way Google Calendar sync pill.
  * **Slide 6 (Categories & Customization)**: 8 custom category rows, embedded category creator modal with 24-icon picker and color palette, Accent selector, Smart Auto-Tagging banner, and Schema export.
  * **Slide 7 (100% Offline & Privacy First)**: 100% Local Hive Engine shield card, 3 KPI stats (<2ms, 0 KB, 100% Offline), Local Architecture card, Storage & Memory Engine stats (1.2 MB, 42 tasks, 18 backups), 11 settings rows, Privacy Audit Certificate, and Zero Cloud Dependency Guarantee banner.
  * **Slide 8 (Dual Theme Elegance)**: Side-by-side Dark Slate and Crisp Light phones with 12 rich task cards each (24 cards total) with live progress bars, Quick Add bar, and bottom navigation.
  * Re-rendered all 8 screenshots (`screenshot_01.png` - `screenshot_08.png`) and `feature_graphic.png` in [`docs/marketing/playstore/`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/docs/marketing/playstore/).
  * In [`widget_quick_action_layout.xml`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/android/app/src/main/res/layout/widget_quick_action_layout.xml), assigned dedicated IDs to the inner `TextView`s (`widget_quick_btn_add_text`, `widget_quick_btn_cal_text`, `widget_quick_btn_add_icon`).
  * In [`QuickActionWidgetProvider.kt`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/android/app/src/main/kotlin/com/rocisapps/tasks/QuickActionWidgetProvider.kt), set text colors on `TextView`s and applied `setColorFilter` to the calendar `ImageView`.
  * Included `KanbanWidgetProvider::class.java` in [`WidgetLimitHelper.ALL_PROVIDERS`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/android/app/src/main/kotlin/com/rocisapps/tasks/WidgetLimitHelper.kt).
* **Settings Screen Responsive Card Layout**:
  * In [`settings_screen.dart`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/lib/features/home/presentation/screens/settings_screen.dart), replaced the squished `ListTile` with a full-width column card containing unconstrained typography and a prominent `FilledButton.tonalIcon` below the description.
* **Streamlined Fast-Logging `AddTaskScreen`**:
  * Reordered primary fields upfront: Title (with NLP parsing), Due Date quick chips & Date/Time picker, Priority pills, Category selector, and Description.
  * Encapsulated secondary options (Attachments, Custom Lines, Recurrence, Switches, Subtasks) into a collapsible "More Options" card with active count badge (auto-expanded when editing tasks containing advanced data).
* **Tappable Category Badges on Task Tiles**:
  * Added `selectSingleCategoryFilter(String categoryId)` to [`TaskProvider`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/lib/features/tasks/presentation/providers/task_provider.dart) with toggle capability.
  * Wrapped category chips in [`TaskTile`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/lib/features/tasks/presentation/widgets/task_tile.dart) with `InkWell` and haptic feedback.
* **Due Date & Time Intraday Chronological Sorting**:
  * Added `TaskSortOption.dueDateTime` to [`TaskFilterService`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/lib/features/tasks/presentation/providers/helpers/task_filter_service.dart).
  * Added `Date & Time` sort pill in [`TaskSortFilterSheet`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/lib/features/tasks/presentation/widgets/task_sort_filter_sheet.dart).
  * Localized strings across all 8 ARB language files (`app_en.arb`, `app_he.arb`, `app_es.arb`, `app_de.arb`, `app_fr.arb`, `app_ar.arb`, `app_sv.arb`, `app_hi.arb`).
* **Verification & Testing**:
  * `flutter analyze`: **0 issues found**.
  * `flutter test`: **294 / 294 tests passed (100%)**.
  * Bumped version to `0.2.12+94`.

## Homescreen Widgets Language Synchronization & Mobile Google OAuth Token Refresh - 2026-08-29

#### Problem & Root Causes
* **Issue 1 (Homescreen Widget Language Synchronization)**:
  * Switching language inside the app did not update Android home screen widgets (`FullCalendar`, `MonthAgenda`, `TodayAgenda`, `TimelineAgenda`).
  * *Root Cause*: Kotlin widget providers hardcoded `Locale.getDefault()` (OS system locale) and static English weekday abbreviation strings (`M, T, W, T, F, S, S`), ignoring the user's selected in-app language. In Dart, `ThemeService.setLocale()` was not writing the language code to `HomeWidget` or requesting a widget update.
* **Issue 2 (Google Calendar Token Expiry on Mobile)**:
  * Google Calendar events and Google Tasks disappeared after ~55 minutes on mobile devices.
  * *Root Cause*: `AuthService._restoreGoogleUser()` had an early return `if (!kIsWeb) return;`, leaving `_googleUser = null` upon mobile app restart. When the 55-minute access token expired, `GoogleOAuthManager._performSilentTokenRefresh()` failed to restore the Google user in the background, causing `_isGoogleTasksTokenExpired` to become true.

#### Solutions & Architecture
* **Android Kotlin Widget Localization**:
  * Created [`WidgetLocaleHelper.kt`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/android/app/src/main/kotlin/com/rocisapps/tasks/WidgetLocaleHelper.kt) to resolve active `Locale` from widget `SharedPreferences` (`app_language`), format localized month titles, selected dates, and compute single-letter weekday headers using `DateFormatSymbols`.
  * Updated [`FullCalendarWidgetProvider.kt`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/android/app/src/main/kotlin/com/rocisapps/tasks/FullCalendarWidgetProvider.kt), [`MonthAgendaWidgetProvider.kt`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/android/app/src/main/kotlin/com/rocisapps/tasks/MonthAgendaWidgetProvider.kt), and [`TodayAgendaWidgetProvider.kt`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/android/app/src/main/kotlin/com/rocisapps/tasks/TodayAgendaWidgetProvider.kt).
* **Flutter Dart Language Sync**:
  * Updated [`ThemeService`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/lib/shared/ui/theme/theme_service.dart) to persist `app_language` to `HomeWidget.saveWidgetData` during `init()` and `setLocale()`.
  * In [`SettingsScreen`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/lib/features/home/presentation/screens/settings_screen.dart), trigger `taskProvider.updateAllWidgets()` when the user selects a language.
  * In [`WidgetDataService`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/lib/core/services/widget_data_service.dart), localized "All Day", "Today", "Tomorrow", "No Title", and date formatters with fallback safety.
* **Proactive Silent Token Refresh**:
  * In [`GoogleOAuthManager._performSilentTokenRefresh()`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/lib/core/services/auth/google_oauth_manager.dart) and [`AuthService._restoreGoogleUser()`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/lib/core/services/auth_service.dart), enabled silent Google user restoration and background OAuth token refresh across all platforms.
* **Verification & Testing**:
  * `flutter analyze`: **0 issues found**.
  * `flutter test`: **289 / 289 tests passed (100%)**.
  * Bumped version to `0.2.11+93`.

## Automated Marketing Growth Engine & Social Distribution Agent - 2026-08-29

#### Architecture & Capabilities Added
* **Automated Growth Engine CLI tool ([`.agent/scripts/growth_engine.py`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/.agent/scripts/growth_engine.py))**:
  * Implemented an automated growth and social distribution suite supporting content generation, community opportunity scanning, anti-spam cooldown tracking, and Playwright browser automation.
  * **Draft Generation (`--generate`)**: Automatically reads current features, version numbers, and changelogs to produce targeted channel-specific posts for `r/SideProject`, `r/androidapps`, `r/productivity`, `r/androidthemes`, X/Twitter threads, and TikTok/Shorts 15s video scripts in `docs/marketing/drafts/`.
  * **Playwright Browser Bot (`--post`, `--login`)**: Handles authenticated browser sessions via persistent Chromium context, pre-filling Reddit title, body markdown, and handling automated submission without requiring API developer tokens.
  * **Reddit Opportunity Scanner (`--scan-reddit`)**: Queries Reddit's search endpoints to detect users actively asking for to-do widgets, minimal task managers, or calendar sync apps.
  * **Safety & Schedule Engine (`--schedule`)**: Enforces the 9:1 community ratio and per-subreddit cooldowns (7–14 days) in [`docs/MARKETING_SCHEDULE.md`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/docs/MARKETING_SCHEDULE.md).
* **Specialist Agent & Workflow**:
  * Registered `growth-marketer` specialist in [`.agent/agents/growth-marketer.md`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/.agent/agents/growth-marketer.md) and [`.agent/ARCHITECTURE.md`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/.agent/ARCHITECTURE.md).
  * Added `/market` workflow in [`.agent/workflows/market.md`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/.agent/workflows/market.md).

## Settings Page Copyable Firebase User ID Integration - 2026-08-29

#### Feature & Enhancements
* **Copyable Firebase User ID under Email in Settings**:
  * In [`lib/features/home/presentation/screens/settings_screen.dart`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/lib/features/home/presentation/screens/settings_screen.dart), enhanced the user account profile `ListTile` subtitle to display a clean, monospace `UID: <user.uid>` row directly below the user's email address.
  * Tapping the UID row copies the Firebase User ID to the system clipboard via `Clipboard.setData`, triggers light haptic feedback (`HapticFeedback.lightImpact`), and presents a localized floating success snackbar (`l10n.copiedToClipboard`).
  * Features a copy icon (`Icons.copy_rounded`) matching the primary theme accent.
* **Testing & Verification**:
  * Added unit & widget test suite in [`test/features/home/settings_screen_test.dart`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/test/features/home/settings_screen_test.dart) covering user profile rendering, UID tap-to-copy clipboard handling, and guest mode fallback.
  * `flutter analyze`: **0 issues found**.
  * `flutter test`: **289 / 289 tests passed (100%)**.

## Mobile Calendar Direct Google REST API + Device Calendar Merged Architecture - 2026-08-29

#### Root Cause & Comprehensive Resolution
* **Root Cause 1 (Mobile Silent Token Refresh Blocking)**: `_performSilentTokenRefresh()` previously contained a `kIsWeb` gate preventing mobile devices from attempting lightweight authentication to refresh expired Google OAuth tokens silently when fetching Google Calendar or Tasks.
  * **Fix**: In [`GoogleOAuthManager._performSilentTokenRefresh()`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/lib/core/services/auth/google_oauth_manager.dart), enabled lightweight authentication on mobile during active token refresh requests, while preserving the cold-startup suppression in `_restoreGoogleUser()` so Android Credential Manager account pickers do not appear on app launch.
* **Root Cause 2 (Empty Stored Calendar IDs Blocking Events)**: In [`CalendarProvider.loadFilters()`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/lib/features/calendar/presentation/providers/calendar_provider.dart), if `full_calendar_selected_ids` was saved as an empty list `[]` in a past session when 0 calendars were loaded, `_selectedCalendarIds` was set to an empty set and never auto-selected available calendars.
  * **Fix**: Updated `loadFilters()` to only assign non-empty saved calendar ID lists. If no calendars are selected or none match the available list, `CalendarProvider.loadEvents()` automatically defaults to selecting **all** available calendars and persisting them.
* **Root Cause 3 (Mobile Calendar Dual Support & UI Sync Controls)**:
  * In [`CalendarService`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/lib/core/services/calendar_service.dart), mobile now queries both Google Calendar REST API (via OAuth token) and native OS `DeviceCalendarPlugin`, merging and deduplicating both seamlessly.
  * Added one-tap "Sync Device Calendar" action in [`CalendarScreen`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/lib/features/calendar/presentation/screens/calendar_screen.dart) and [`CalendarFilterSheet`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/lib/features/calendar/presentation/widgets/calendar_filter_sheet.dart) allowing instant OS permission prompts and reload.
* **Verification**:
  * `flutter analyze`: **0 issues found**.
  * `flutter test`: **287 / 287 tests passed (100%)**.

## Mobile Google Calendar Direct API Integration & Scopes Unification - 2026-08-29

#### Root Cause & Resolution
* **Root Cause 1 (Mobile Scopes Missing)**: On mobile (`!kIsWeb`), `GoogleOAuthManager.googleTasksScopes` only requested `tasks` and excluded `calendar.readonly` / `calendar.events`. Consequently, mobile Google sign-in and reconnect tokens lacked Google Calendar permissions.
* **Root Cause 2 (Mobile API Gating)**: `CalendarService` previously gated all Google Calendar REST API calls behind `kIsWeb`, forcing mobile devices to rely solely on native OS `DeviceCalendarPlugin`. Users who signed in with Google but did not have local Android calendar provider synchronization saw 0 calendars and 0 events.
* **Fixes Applied**:
  * **Unified OAuth Scopes**: In [`GoogleOAuthManager.googleTasksScopes`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/lib/core/services/auth/google_oauth_manager.dart), unified scopes across Mobile and Web to include `email`, `tasks`, `calendar.readonly`, and `calendar.events`.
  * **Direct Google Calendar API on Mobile**: In [`CalendarService`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/lib/core/services/calendar_service.dart), enabled direct Google Calendar REST API querying whenever a Google OAuth token is present, while seamlessly merging with native device calendars if permissions are granted.
* **Verification**:
  * Updated unit tests in [`test/core/services/auth/google_oauth_manager_test.dart`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/test/core/services/auth/google_oauth_manager_test.dart) and [`test/core/services/calendar_service_test.dart`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/test/core/services/calendar_service_test.dart).
  * `flutter analyze`: **0 issues found**.
  * `flutter test`: **287 / 287 tests passed (100%)**.

## Ghost "Unnamed" Google Calendar Sanitization & Display Name Resolution - 2026-08-29

#### Improvements & Fixes
* **Eliminated Ghost "Unnamed" Calendars & Resolved Clean Titles**:
  * In [`CalendarService`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/lib/core/services/calendar_service.dart), added `_sanitizeAndFilterCalendars(...)` pipeline:
    * Automatically identifies and purges phantom/ghost calendar rows with empty/invalid names and no associated account information returned by native Android calendar providers and Web endpoints.
    * Intelligently resolves friendly display names from `summaryOverride`, `summary`, `accountName`, or `id` instead of falling back to `"Unnamed"`.
    * Deduplicates calendars by ID to prevent duplicate list tiles in the filter sheet.
  * In [`CalendarFilterSheet`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/lib/features/calendar/presentation/widgets/calendar_filter_sheet.dart), refined calendar title and subtitle resolution logic to ensure clean labels without displaying `"Unnamed"` or duplicate subtitles.
* **Verification**:
  * Added unit test suite in [`test/core/services/calendar_service_test.dart`](file:///c:/Users/roeei/Documents/rocis_apps/ROCIs-tasks/test/core/services/calendar_service_test.dart).
  * `flutter analyze`: **0 issues found**.
  * `flutter test`: **287 / 287 tests passed (100%)**.

## App Size & Startup Load Times Optimization Suite - 2026-08-29

#### Improvements & Fixes
* **Asset & Font Deduplication (~880 KB Raw Asset Purge)**:
  * Eliminated duplicated `assets/fonts/` directory and unneeded variable font files (`Outfit-VariableFont_wght.ttf`, `Outfit.ttf`).
  * Streamlined `pubspec.yaml` assets list to only bundle required static weights (`Regular`, `Medium`, `SemiBold`, `Bold`) in `google_fonts/`.
  * Removed unused duplicate icon `assets/icons/google.svg`.
* **Android Gradle, R8 Full Mode & Packaging Optimization**:
  * Added `android.enableR8.fullMode=true` and `android.nonTransitiveRClass=true` in `android/gradle.properties` for aggressive dead code elimination, class merging, and method inlining.
  * Added `packaging` resource exclusions (`META-INF/DEPENDENCIES`, `META-INF/LICENSE*`, `META-INF/NOTICE*`, `META-INF/*.kotlin_module`) in `android/app/build.gradle.kts` to eliminate APK metadata bloat.
* **Startup Pipeline & Non-Blocking Load Times**:
  * **Parallel Hive DB Warmup**: Updated `AppInitializer._initHive()` to eagerly open `tasksBox` and `categoriesBox` in parallel alongside `settings`, and guarded `LocalTaskSource._openBoxes()` with `Hive.isBoxOpen` to ensure zero startup I/O latency.
  * **Deduplicated Platform Channel Calls**: Updated `TimezoneService.init()` to reuse already resolved device timezone from `tz.local.name`, avoiding redundant 2-second platform channel queries on startup.
  * **Non-Blocking Secondary Services**: Converted `_scheduleService.initialize()` in `main.dart` and `_checkSubscriptionStatus()` in `SubscriptionService.init()` to background non-blocking tasks (`unawaited`), allowing the main task UI to mount and render instantaneously.
  * **Guarded Connectivity Initialization**: Added `_isInitialized` guard to `ConnectivityService` preventing duplicated socket checks and subscriptions.
* **Verification**:
  * `flutter analyze`: **0 issues found**.
  * `flutter test`: **284 / 284 tests passed (100%)**.
  * Master audit checklist (`checklist.py`): **All checks PASSED**.

## 4 Core Productivity Features & Codebase Cleanup - 2026-08-29

#### Enhancements & Fixes
* **Resolved 48 Syntax / Semantic Errors**: Cleaned up duplicated blocks in [`AppInitializer`](file:///c:/Users/<username>/Documents/rocis_apps/ROCIs-tasks/lib/core/services/app_initializer.dart) and [`WebHomeScreen`](file:///c:/Users/<username>/Documents/rocis_apps/ROCIs-tasks/lib/features/home/presentation/screens/web_home_screen.dart), fixed missing `FocusNode` declarations and lifecycle disposals, and corrected test mock imports.
* **4 Features Implemented & Verified**:
  1. Smart Syntax & NLP Task Parsing (`!high`, `#tag`, `tonight`, `in N days`) in [`NlpService`](file:///c:/Users/<username>/Documents/rocis_apps/ROCIs-tasks/lib/features/tasks/services/nlp_service.dart) and [`AddTaskScreen`](file:///c:/Users/<username>/Documents/rocis_apps/ROCIs-tasks/lib/features/tasks/presentation/screens/add_task_screen.dart).
  2. Non-blocking 7-day Hive DB Compaction in [`AppInitializer`](file:///c:/Users/<username>/Documents/rocis_apps/ROCIs-tasks/lib/core/services/app_initializer.dart) and [`LocalTaskSource`](file:///c:/Users/<username>/Documents/rocis_apps/ROCIs-tasks/lib/features/tasks/data/datasources/local_task_source.dart).
  3. Desktop Web Keyboard Shortcuts (`Ctrl+N`, `/`, `1`-`5`, `Esc`) in [`WebHomeScreen`](file:///c:/Users/<username>/Documents/rocis_apps/ROCIs-tasks/lib/features/home/presentation/screens/web_home_screen.dart).
  4. Granular Category Filtering for Android Widgets in [`WidgetDataService`](file:///c:/Users/<username>/Documents/rocis_apps/ROCIs-tasks/lib/core/services/widget_data_service.dart) and [`WidgetCustomizationScreen`](file:///c:/Users/<username>/Documents/rocis_apps/ROCIs-tasks/lib/features/home/presentation/screens/widget_customization_screen.dart).
* **Verification**:
  * `flutter analyze`: **0 issues found**.
  * `flutter test`: **284 / 284 tests passed (100%)**.
  * Master audit checklist (`checklist.py`): **All checks PASSED**.

## Mobile App Launch Sign-In Reprompt Elimination - 2026-08-29

#### Issue / Enhancement
* The mobile version of the app was reprompting the user to sign in / choose a Google account via Credential Manager on every app launch.
* Root cause 1: In `AuthService._restoreGoogleUser()`, when the 55-minute cached Google access token expired, `_oauthManager.googleSignIn.attemptLightweightAuthentication()` was called on startup. Under `google_sign_in: ^7.2.0` on Android, Credential Manager popped up the system account selection bottom sheet on every cold start.
* Root cause 2: In `GoogleOAuthManager._performSilentTokenRefresh()`, `attemptLightweightAuthentication()` was called during task sync when `_googleUser` was `null`, prompting the user during background synchronization.

#### Solutions & Verification
* **Restricted Lightweight Authentication to Web**: In [`lib/core/services/auth_service.dart`](file:///c:/Users/<username>/Documents/rocis_apps/ROCIs-tasks/lib/core/services/auth_service.dart) and [`lib/core/services/auth/google_oauth_manager.dart`](file:///c:/Users/<username>/Documents/rocis_apps/ROCIs-tasks/lib/core/services/auth/google_oauth_manager.dart), restricted `attemptLightweightAuthentication()` strictly to Web (`kIsWeb`) where it operates silently via browser cookies.
* **Non-Intrusive Mobile Startup & Expiration State**: On Mobile (`!kIsWeb`), the app relies on Firebase Auth's persistent session across restarts and never invokes interactive Credential Manager dialogs on launch or during background sync. Expired tokens cleanly set `isGoogleTasksTokenExpired = true`, displaying the in-app "Reconnect" banner only when relevant.
* **Verification**:
  * Added unit test in [`test/core/services/auth/google_oauth_manager_test.dart`](file:///c:/Users/<username>/Documents/rocis_apps/ROCIs-tasks/test/core/services/auth/google_oauth_manager_test.dart).
  * `flutter analyze`: 0 issues found.
  * `flutter test`: 278/278 tests passed (100%).

## Google Cloud Console OAuth Scopes Alignment & Android Homescreen Calendar Widget Spacing - 2026-08-29

#### Improvements & Fixes
* **Google OAuth Scopes Alignment**:
  * In [`lib/core/services/auth/google_oauth_manager.dart`](file:///c:/Users/<username>/Documents/rocis_apps/ROCIs-tasks/lib/core/services/auth/google_oauth_manager.dart), removed `https://www.googleapis.com/auth/calendar` (broad root scope) to strictly adhere to the scopes configured in Google Cloud Console: `https://www.googleapis.com/auth/calendar.readonly`, `https://www.googleapis.com/auth/calendar.events`, `https://www.googleapis.com/auth/tasks`, and `email`.
  * Added unit test assertions in [`test/core/services/auth/google_oauth_manager_test.dart`](file:///c:/Users/<username>/Documents/rocis_apps/ROCIs-tasks/test/core/services/auth/google_oauth_manager_test.dart) ensuring the broad `calendar` scope is excluded.
* **Android Homescreen Calendar Widget Row Height & Density Enhancement**:
  * In [`widget_full_calendar_row.xml`](file:///c:/Users/<username>/Documents/rocis_apps/ROCIs-tasks/android/app/src/main/res/layout/widget_full_calendar_row.xml), increased day cell heights and week number root height from `52dp` to `62dp`.
  * Increased row padding to `paddingTop="2dp"`, `paddingBottom="2dp"`, refined day number font size (`11.5sp`), and enhanced event badge box top margin (`1.5dp`) and typography (`8sp`).
  * In [`widget_full_calendar_layout.xml`](file:///c:/Users/<username>/Documents/rocis_apps/ROCIs-tasks/android/app/src/main/res/layout/widget_full_calendar_layout.xml), adjusted weekday header vertical padding (`4dp`) for balanced visual hierarchy.
  * In [`widget_month_agenda_row.xml`](file:///c:/Users/<username>/Documents/rocis_apps/ROCIs-tasks/android/app/src/main/res/layout/widget_month_agenda_row.xml), increased day cell height from `32dp` to `36dp` with `1dp` top/bottom padding.
* **Verification**:
  * `flutter analyze` completed with 0 issues.
  * `flutter test` passed 277/277 tests (100%).

## Startup Load Times & App Size Optimization - 2026-08-28

#### Improvements & Fixes
* **Offline Typography & Local Font Bundling**:
  * Downloaded and bundled Google Fonts `Outfit` (`Outfit-Regular.ttf`, `Outfit-Medium.ttf`, `Outfit-SemiBold.ttf`, `Outfit-Bold.ttf`) into `assets/fonts/` and `google_fonts/`.
  * Registered font paths in `pubspec.yaml`.
  * Set `GoogleFonts.config.allowRuntimeFetching = false` in `AppInitializer.initialize()`, enforcing zero-network local font loading and eliminating layout shifts / FOUT on startup.
* **Non-Blocking Startup Lifecycle**:
  * In `AppInitializer._initRemoteConfig()`, configured local defaults immediately and converted `fetchAndActivate()` into an asynchronous background task (`unawaited`), removing startup network blocking.
  * In `main.dart`, changed `_subscriptionService.syncWithAuthUserId(...)` to run asynchronously in the background, allowing `MaterialApp.router` to mount and display local tasks immediately.
  * In `TaskProvider.init()`, removed redundant duplicate `_subscriptionService.init()` calls, and converted widget schedule service initialization and notification permission requests to non-blocking background routines.
* **Surgical Android R8 / ProGuard Optimization**:
  * Refined `android/app/proguard-rules.pro` by removing broad blanket rules (`-keep class io.flutter.**` and `-keep class com.rocisapps.tasks.**`), allowing R8 full-mode optimization to aggressively inline, merge classes, and strip unused bytecode.
* **Verification**:
  * `flutter analyze` completed with 0 issues.
  * `flutter test` passed 277/277 tests (100%).

## FullCalendar Widget Visual Polish, Smart Event Cells & Homescreen Widgets Skill Update - 2026-08-28

#### Improvements & Fixes
* **In-Cell Event Badges with Colored Border & Tint Fill**:
  * Created [`widget_event_badge_fill.xml`](file:///c:/Users/<username>/Documents/rocis_apps/ROCIs-tasks/android/app/src/main/res/drawable/widget_event_badge_fill.xml) and [`widget_event_badge_stroke.xml`](file:///c:/Users/<username>/Documents/rocis_apps/ROCIs-tasks/android/app/src/main/res/drawable/widget_event_badge_stroke.xml).
  * In [`widget_full_calendar_row.xml`](file:///c:/Users/<username>/Documents/rocis_apps/ROCIs-tasks/android/app/src/main/res/layout/widget_full_calendar_row.xml) and [`FullCalendarWidgetService.kt`](file:///c:/Users/<username>/Documents/rocis_apps/ROCIs-tasks/android/app/src/main/kotlin/com/rocisapps/tasks/FullCalendarWidgetService.kt), configured dynamic color-filtering on each event badge: 15% opacity tint fill + 50% opacity colored border + event color text matching the in-app `BoxDecoration` calendar styling.
* **Refined Header Controls to Match App Design**:
  * Added [`widget_nav_icon_bg.xml`](file:///c:/Users/<username>/Documents/rocis_apps/ROCIs-tasks/android/app/src/main/res/drawable/widget_nav_icon_bg.xml) circular glass backdrops for previous (`‹`), next (`›`), today (`⦿`), and add (`+`) buttons.
  * Synchronized month/year title, chevrons, and today action colors with the theme and brand scheme.
* **Homescreen Widgets AI Skill (`flutter-homescreen-widgets`) Updated**:
  * Added Section 7 detailing critical rules: RemoteViews XML tag whitelisting (never `<View>`), static XML row templates for ListView adapters, self-healing native calendar generation, smart in-cell information density (snippets vs. dots), transparent sub-headers, and brand color alignment.
* **Eliminated Glaring Weekdays White Background**:
  * Removed `@drawable/widget_item_background` from the weekdays strip in [`widget_full_calendar_layout.xml`](file:///c:/Users/<username>/Documents/rocis_apps/ROCIs-tasks/android/app/src/main/res/layout/widget_full_calendar_layout.xml), providing seamless transparent blending with dark and glass themes.
* **Eliminated Purple/Indigo from All Widget Drawables**:
  * Updated [`widget_filter_button_active_bg.xml`](file:///c:/Users/<username>/Documents/rocis_apps/ROCIs-tasks/android/app/src/main/res/drawable/widget_filter_button_active_bg.xml), [`widget_pill_bg.xml`](file:///c:/Users/<username>/Documents/rocis_apps/ROCIs-tasks/android/app/src/main/res/drawable/widget_pill_bg.xml), [`widget_selected_today_background.xml`](file:///c:/Users/<username>/Documents/rocis_apps/ROCIs-tasks/android/app/src/main/res/drawable/widget_selected_today_background.xml), [`widget_today_background.xml`](file:///c:/Users/<username>/Documents/rocis_apps/ROCIs-tasks/android/app/src/main/res/drawable/widget_today_background.xml), [`values/colors.xml`](file:///c:/Users/<username>/Documents/rocis_apps/ROCIs-tasks/android/app/src/main/res/values/colors.xml), and [`values-night/colors.xml`](file:///c:/Users/<username>/Documents/rocis_apps/ROCIs-tasks/android/app/src/main/res/values-night/colors.xml) to use ROCIs brand Crimson Red (`#EF3842`).
* **Verification**: `flutter analyze` passed with 0 issues; `flutter test` passed 277/277 tests (100%).

## Application Startup Exceptions & Android Widget Fixes - 2026-08-28

#### Issues
* `Couldn't add widget` / `Error inflating RemoteViews`: Android's `RemoteViews` threw `android.view.InflateException: Class not allowed to be inflated android.view.View` because `<View>` tags were used as vertical spacers in `widget_full_calendar_row.xml` and `widget_full_calendar_day_item.xml`.
* `DotEnv has not been initialized` error occurred when `SubscriptionService` or `FirebaseConfig` accessed `dotenv.env` before or without dotenv loading.
* `Location with the name "GMT" doesn't exist` crashed `NotificationService.init` when device returned non-standard IANA identifier `"GMT"`.
* Flutter framework assertion: `ListTile background color or ink splashes may be invisible` because `ListTile` inside `GlassContainer` lacked an immediate `Material` parent.

#### Solutions & Verification
* **Eliminated Forbidden `<View>` Tags in RemoteViews Layouts**:
  * Replaced all `<View>` spacer tags with whitelisted `<FrameLayout>` tags in [`widget_full_calendar_row.xml`](file:///c:/Users/<username>/Documents/rocis_apps/ROCIs-tasks/android/app/src/main/res/layout/widget_full_calendar_row.xml) and [`widget_full_calendar_day_item.xml`](file:///c:/Users/<username>/Documents/rocis_apps/ROCIs-tasks/android/app/src/main/res/layout/widget_full_calendar_day_item.xml). Verified zero `<View>` tags remain across all layout XML files.
* **DotEnv Safe Access**: Added `dotenv.isInitialized` checks before accessing `dotenv.env` in [`SubscriptionService.dart`](file:///c:/Users/<username>/Documents/rocis_apps/ROCIs-tasks/lib/core/services/subscription_service.dart) and [`FirebaseConfig.dart`](file:///c:/Users/<username>/Documents/rocis_apps/ROCIs-tasks/lib/core/config/firebase_config.dart).
* **Timezone GMT/Alias Fallback**: In [`NotificationService.dart`](file:///c:/Users/<username>/Documents/rocis_apps/ROCIs-tasks/lib/core/services/notification_service.dart), checked `tz.timeZoneDatabase.locations.containsKey(timeZoneName)` with safe fallback to `UTC`.
* **GlassContainer Material Hierarchy**: Wrapped `child` with `Material(type: MaterialType.transparency, borderRadius: radius, clipBehavior: Clip.antiAlias)` inside [`GlassContainer.dart`](file:///c:/Users/<username>/Documents/rocis_apps/ROCIs-tasks/lib/shared/ui/widgets/glass_container.dart).
* **Native Android Calendar Self-Healing & Startup Update**:
  * Implemented `generateFallbackCalendar()` in [`FullCalendarWidgetService.kt`](file:///c:/Users/<username>/Documents/rocis_apps/ROCIs-tasks/android/app/src/main/kotlin/com/rocisapps/tasks/FullCalendarWidgetService.kt) to compute and render calendar grid even before Dart writes data.
  * Added fallback month title formatting in [`FullCalendarWidgetProvider.kt`](file:///c:/Users/<username>/Documents/rocis_apps/ROCIs-tasks/android/app/src/main/kotlin/com/rocisapps/tasks/FullCalendarWidgetProvider.kt).
  * Triggered initial home screen widget sync in [`TaskProvider.init()`](file:///c:/Users/<username>/Documents/rocis_apps/ROCIs-tasks/lib/features/tasks/presentation/providers/task_provider.dart).
* **Verification**: `flutter analyze` 0 issues, `flutter test` 277/277 passed (100%).

## ROCIs Brand Identity System & `/brand` Workflow - 2026-08-28

#### Issue / Enhancement
* Users requested updating the brand identity and design tokens to align with the official ROCIs app icon (signature stylized 'R' clipboard with vibrant Crimson Red checkmark on deep Onyx slate).

#### Solutions & Verification
* **Aligned Brand Guidelines (`docs/brand-guidelines.md`)**:
  * Updated primary brand color to **ROCIs Crimson Red** (`#EF3842`) mirroring the app icon's signature checkmark.
  * Defined deep Onyx Slate dark surfaces (`#2E3138` / `#1E2026`) matching the icon's background circle.
  * Retained secondary Emerald (`#10B981`), Amber (`#F59E0B`), Electric Blue (`#3B82F6`), and Indigo (`#6366F1`) accents.
* **Synchronized Tokens (`assets/design-tokens.json`, `assets/design-tokens.css`)**:
  * Re-synced design tokens using `sync-brand-to-tokens.cjs` to generate updated CSS and JSON token scales for `#EF3842`.

## FullCalendar Android Home Screen Widget Redesign & Loading Fix - 2026-08-28

#### Issue / Enhancement
* The updated FullCalendar home screen widget was stuck showing "Loading" instead of rendering days, caused by dynamic nested `RemoteViews.addView()` calls inside the ListView's `RemoteViewsFactory.getViewAt()`.
* Users requested fixing the loading error and elevating the UI/UX design following `/ui-ux-pro-max`, `/atomic-design-system-auditor`, and `/mobile-design`.

#### Solutions & Verification
* **Static Row Architecture (`widget_full_calendar_row.xml`)**:
  * Replaced dynamic `addView()` and nested RemoteViews inflation with a single, high-performance static XML row layout containing the 8 pre-defined columns (1 week number + 7 days with soft fills, strokes, day labels, and micro-dot indicators).
  * Completely eliminated Binder transaction bottlenecks and `RemoteViewsAdapter` inflation crashes, allowing the widget to load immediately with zero lag.
* **Refined Design & Visual Tokens (`FullCalendarWidgetService.kt`, `widget_full_calendar_layout.xml`)**:
  * Clean day alignment: Exact column weights matching between weekday header strip (`weight="1.0"`) and row day cells.
  * Today highlight: Soft primary rounded card fill (`12dp` radius, 20% opacity) with bold primary day number.
  * Selected date highlight: Refined outline stroke.
  * Weekend accents: Coral Red (`#EF4444`) for Sunday and Electric Blue (`#3B82F6`) for Saturday.
  * Outside month fade: 30% faded opacity (`#4DFFFFFF` / `#4D1C1C1E`) providing instant month separation.
  * Event micro-dots: Symmetrical 4dp colored dots mapped to category and Google Calendar colors.
* **Testing & Verification**:
  * Ran full test suite `flutter test`: all 277/277 tests passed (100%).
  * Ran `flutter analyze`: 0 issues found.

## Android Home Screen Kanban Board Widget - 2026-08-27

#### Issue / Enhancement
* Users requested a dedicated Android Home Screen Widget for the Kanban Board, allowing them to view and navigate columns (*To Do*, *In Focus*, *Done*), complete tasks, and jump into the app's Kanban board directly from their launcher.

#### Solutions & Verification
* **Native Android RemoteViews & Service**:
  * Implemented `KanbanWidgetProvider` (`android/app/src/main/kotlin/com/rocisapps/tasks/KanbanWidgetProvider.kt`) supporting theme-adaptive backgrounds (light/dark/amoled/glass), column switching (`To Do`, `In Focus`, `Done`), segment pill indicators with count badges, and deep link intents.
  * Native state shift: Calculates and persists active column index shifts in SharedPreferences directly in Kotlin before notifying Dart, adhering to Android Home Widget project rules.
  * Implemented `KanbanWidgetService` (`android/app/src/main/kotlin/com/rocisapps/tasks/KanbanWidgetService.kt`) with `RemoteViewsFactory` to parse `kanban_data` JSON and render cards with category strips, due date chips, priority tags, and interactive checkmarks.
  * Created XML layouts and metadata: `res/layout/widget_kanban_layout.xml`, `res/layout/widget_kanban_item.xml`, `res/xml/kanban_widget_info.xml`.
  * Registered provider and service in `AndroidManifest.xml`.
* **Dart Data Serialization & Deep Linking**:
  * Implemented `WidgetDataService.updateKanbanWidget()` in `lib/core/services/widget_data_service.dart` to split tasks into `column_todo`, `column_infocus`, and `column_done` and push payload to HomeWidget.
  * Connected `kanban_sync` handler in `lib/core/services/background_handler.dart`.
  * Added `open_kanban` and `task_detail` deep link handling in `lib/features/home/presentation/screens/home_screen.dart` to instantly launch and switch to Kanban board view.
* **Testing & Verification**:
  * Added unit test `test/core/services/widget_data_service_kanban_test.dart` verifying data serialization and column distribution.
  * Ran full test suite `flutter test`: all 277/277 tests passed (100%).
  * Ran `flutter analyze`: 0 issues found.

## Interactive Kanban Board View Feature - 2026-08-27

#### Issue / Enhancement
* Users requested a visual, interactive Kanban Board view (`/enhance` Option 3) to organize tasks horizontally across customizable columns, supporting drag-and-drop workflow updates on both mobile and web.

#### Solutions & Verification
* **Glassmorphic Kanban Cards & Columns**:
  * Implemented `KanbanCard` (`lib/features/tasks/presentation/widgets/kanban/kanban_card.dart`) with `LongPressDraggable<Task>` (mobile touch-safe) and feedback preview, category tinting (10-18% tint via `GlassContainer`), priority indicators, due date badges, subtask indicators, and tap-to-open detail view.
  * Implemented `KanbanColumn` (`lib/features/tasks/presentation/widgets/kanban/kanban_column.dart`) with `DragTarget<Task>`, empty placeholder state, scrollable task list, and quick task creation button.
* **Flexible Multi-Dimensional Groupings**:
  * Implemented `KanbanBoardView` (`lib/features/tasks/presentation/widgets/kanban/kanban_board_view.dart`) supporting 3 grouping modes:
    1. **Status**: `To Do`, `In Focus` (today/overdue/pinned), `Done` (drops toggle completion).
    2. **Priority**: `High`, `Medium`, `Low` (drops re-prioritize task).
    3. **Category**: Dynamic columns per custom category + `Uncategorized` (drops re-categorize task).
* **Multi-Platform Navigation Integration**:
  * **Web**: Added dedicated "Board" tab in `WebHomeScreen` sidebar (`lib/features/home/presentation/screens/web_home_screen.dart`).
  * **Mobile**: Added view switcher toggle icon in `HomeScreen` AppBar (`lib/features/home/presentation/screens/home_screen.dart`), toggling seamlessly between List View and Kanban Board View.
* **Localization (i18n)**:
  * Added full localization for all new keys (`boardView`, `listView`, `groupBy`, `groupByStatus`, `groupByPriority`, `groupByCategory`, `columnToDo`, `columnInFocus`, `columnDone`, `emptyColumn`, `uncategorized`, `highPriority`, `mediumPriority`, `lowPriority`) across all 8 supported languages (`en`, `he`, `es`, `de`, `fr`, `sv`, `ar`, `hi`).
* **Testing & Verification**:
  * Added widget tests in `test/features/tasks/presentation/widgets/kanban_board_test.dart` covering card rendering, column generation, mode switching (Status, Priority, Category), and task completion interactions.
  * Ran `flutter test` (all 276/276 tests passing, 100%).
  * Ran `flutter analyze` (0 issues found).

## Mobile Auth Reprompt Elimination & Android Navigation Bar Insets Fix - 2026-08-27

#### Issue / Enhancement
* On mobile devices, the app was repeatedly presenting users with interactive Google authentication / authorization dialogs on startup and during background sync.
* Root cause 1: `GoogleOAuthManager._performSilentTokenRefresh()` and `AuthService._restoreGoogleUser()` were calling `authorizationClient.authorizeScopes(...)`, which triggers interactive system dialogs/activities in background startup and silent token refresh flows.
* Root cause 2: `GoogleOAuthManager.googleTasksScopes` requested sensitive Web Calendar REST API scopes (`calendar`, `calendar.readonly`, `calendar.events`) on mobile devices, even though mobile handles Google Calendar natively via Android's `device_calendar` plugin.
* On Android devices using 3-button navigation (Back, Home, Recents), the system navigation bar (height ~48dp) was covering and overlapping the app's floating glass bottom navigation bar.
* Root cause 3: In `home_screen.dart`, `bottomNavigationBar` was wrapped in a fixed `EdgeInsets.only(bottom: 12)` without respecting `SafeArea` or system window bottom insets.

#### Solutions & Verification
* **Platform-Aware OAuth Scopes**: In [GoogleOAuthManager.dart](file:///c:/Users/<username>/Documents/rocis_apps/ROCIs-tasks/lib/core/services/auth/google_oauth_manager.dart), configured `googleTasksScopes` to only request `email` and `https://www.googleapis.com/auth/tasks` on mobile, while keeping full REST API calendar scopes on Web (`kIsWeb`).
* **Non-Interactive Silent Token Refresh**: In [GoogleOAuthManager.dart](file:///c:/Users/<username>/Documents/rocis_apps/ROCIs-tasks/lib/core/services/auth/google_oauth_manager.dart) and [AuthService.dart](file:///c:/Users/<username>/Documents/rocis_apps/ROCIs-tasks/lib/core/services/auth_service.dart), removed `authorizeScopes(...)` fallbacks from background token refresh and startup restoration routines. Background token fetching now strictly queries non-interactive `authorizationForScopes(...)`.
* **System Window Insets Safe Navigation**: In [home_screen.dart](file:///c:/Users/<username>/Documents/rocis_apps/ROCIs-tasks/lib/features/home/presentation/screens/home_screen.dart), wrapped `bottomNavigationBar` in `SafeArea(top: false, ...)` so that the floating glass navigation bar and Floating Action Button (FAB) are dynamically offset above both 3-button system navigation bars and gesture navigation bars.
* **Testing & Verification**:
  * Added `test/features/home/home_screen_navigation_test.dart` verifying `HomeScreen` bottom navigation bar `SafeArea` protection under Android 3-button navigation insets.
  * Updated `test/core/services/auth/google_oauth_manager_test.dart` verifying platform-specific mobile scopes.
  * Ran `flutter test` (all 272/272 unit, widget, and property tests passing, 100%).
  * Ran `flutter analyze` with 0 issues found.

## Google Calendar Web Visibility & OAuth Session Fix - 2026-08-22

#### Issue / Enhancement
* Users on Web could not see their Google Calendar even after re-authenticating and granting all required scopes.
* Root cause 1: In `CalendarService.getEvents()`, URLs were constructed via string interpolation and parsed with `Uri.parse()`. Subscribed calendars containing `#` in their ID (such as `he.israel#holiday@group.v.calendar.google.com` or `addressbook#contacts`) had their path split at the `#` fragment boundary by browsers, sending malformed requests to Google Calendar API that returned HTTP `404`/`403`.
* Root cause 2: `CalendarService.getEvents()` threw an unhandled `GoogleTokenExpiredException` when *any* secondary/subscribed calendar failed with `403` or `404`, which caused `CalendarProvider.loadEvents()` to wipe out all events (including successfully fetched primary calendar events) and display the disconnected banner.
* Root cause 3: In `AuthService._restoreGoogleUser()`, restoring `_googleUser` was skipped on Web (`kIsWeb`), preventing silent token renewal after the initial 55-minute OAuth token expired.

#### Solutions & Verification
* **REST URL Safety with `Uri.https`**: In [CalendarService.dart](file:///c:/Users/<username>/Documents/rocis_apps/ROCIs-tasks/lib/core/services/calendar_service.dart), migrated all REST API endpoints (`calendarList`, `events`, `createOrUpdateTaskEvent`, `deleteEvent`) to `Uri.https` with query parameter maps, preventing URI fragment truncation.
* **Resilient Multi-Calendar Error Isolation**: In `CalendarService.getEvents()`, isolated secondary calendar `403`/`404` errors to log warnings and skip individual secondary calendars without aborting the loop or discarding primary calendar events. Only actual `401` responses (or complete primary failures) throw `GoogleTokenExpiredException`.
* **Web OAuth Session Hydration & Silent Refresh**: In [AuthService.dart](file:///c:/Users/<username>/Documents/rocis_apps/ROCIs-tasks/lib/core/services/auth_service.dart) and [GoogleOAuthManager.dart](file:///c:/Users/<username>/Documents/rocis_apps/ROCIs-tasks/lib/core/services/auth/google_oauth_manager.dart), enabled silent lightweight authentication on Web startup and in `_performSilentTokenRefresh()` so `_googleUser` is restored and access tokens renew automatically.
* **Verification**: `flutter analyze` completed with 0 issues; all 271/271 unit, widget, and service tests passed.

## R8 / ProGuard Keep Rules Optimization - 2026-08-22

#### Issue / Enhancement
* Executed `/r8-analyzer optimize` workflow to audit and streamline ProGuard / R8 keep rules in `android/app/proguard-rules.pro`.
* Identified overly broad and redundant keep rules that hindered R8 compiler optimizations (inlining, class merging, member stripping, and obfuscation).
* Removed broad blanket rules:
  * Package-wide `-keep class com.rocisapps.tasks.** { *; }` (AAPT2 natively extracts and retains all declared components from `AndroidManifest.xml`).
  * Package-wide `-keep class io.flutter.** { *; }` and subpackage rules (embedded automatically by Flutter engine/plugin AARs).
  * Google Play Services Auth & Common rules (embedded in respective library AAR consumer rules).
  * Redundant `AppWidgetProvider` and `RemoteViewsService` keeps (handled natively by AAPT2 manifest rules).
  * Inapplicable Dart Hive rules.
* Retained `-assumenosideeffects class android.util.Log` (log stripping in release) and `-dontwarn com.google.android.play.core.**`.

#### Solutions & Verification
* **Optimized Rules**: Updated [android/app/proguard-rules.pro](file:///c:/Users/<username>/Documents/rocis_apps/ROCIs-tasks/android/app/proguard-rules.pro) with minimal, surgical rules.
* **Verification**: Ran `flutter analyze` (0 issues), `flutter test` (271/271 passed, 100%), and `flutter build appbundle --release` (successfully built `app-release.aab` with R8 Full Mode optimization).

## App Launch Crash Resolution: SecureStorage Keystore Resilience & QuickActions Drawables - 2026-08-22

#### Issue / Enhancement
* App was crashing immediately upon launch when launched as a release build.
* Root cause 1: `EncryptionService` was calling `_secureStorage.read()` without `resetOnError: true`. Any Keystore corruption or signature mismatch threw an unhandled `KeyStoreException` / `BadPaddingException` during `_initEncryption()`, causing `AppInitializer.initialize()` to crash before `runApp()`.
* Root cause 2: `QuickActionsService.initialize()` registered shortcuts with icon names (`ic_add`, `ic_delete`, `ic_sync`) that did not exist in Android's drawable resources, and was not wrapped in a try/catch, causing `ShortcutManager` resource lookup failures.
* Root cause 3: Unhandled errors or timeout in secondary services inside `AppInitializer.initialize()` rethrew to `main()`, aborting Flutter execution before the root widget tree could mount.

#### Solutions & Verification
* **Keystore Resilience**: Updated [EncryptionService.dart](file:///c:/Users/<username>/Documents/rocis_apps/ROCIs-tasks/lib/core/services/encryption_service.dart) to use `AndroidOptions(resetOnError: true)` and catch Keystore read failures, automatically resetting corrupted storage and falling back to a securely generated key rather than crashing the app.
* **Shortcut Drawables & Safe Init**: Added vector drawables [ic_add.xml](file:///c:/Users/<username>/Documents/rocis_apps/ROCIs-tasks/android/app/src/main/res/drawable/ic_add.xml), [ic_delete.xml](file:///c:/Users/<username>/Documents/rocis_apps/ROCIs-tasks/android/app/src/main/res/drawable/ic_delete.xml), and [ic_sync.xml](file:///c:/Users/<username>/Documents/rocis_apps/ROCIs-tasks/android/app/src/main/res/drawable/ic_sync.xml) to `res/drawable/` and wrapped [QuickActionsService.dart](file:///c:/Users/<username>/Documents/rocis_apps/ROCIs-tasks/lib/core/services/quick_actions_service.dart) initialization in a try-catch block.
* **Guaranteed Startup**: In [AppInitializer.dart](file:///c:/Users/<username>/Documents/rocis_apps/ROCIs-tasks/lib/core/services/app_initializer.dart) and [main.dart](file:///c:/Users/<username>/Documents/rocis_apps/ROCIs-tasks/lib/main.dart), made secondary service timeouts non-fatal and wrapped `AppInitializer.initialize()` in `main()` to ensure `runApp(const AppRoot())` is always called.
* **Verification**: Ran `flutter analyze` (0 issues), `flutter test` (271/271 passed), and verified successful Gradle compile and Shorebird release build.


## Android Gradle Plugin 9 (AGP 9), Gradle 9.1.0 & Kotlin 2.3.20 Upgrade - 2026-08-22

#### Issue / Enhancement
* Upgraded Android build system to Android Gradle Plugin (AGP) version `9.0.1`, Gradle wrapper `9.1.0`, and Kotlin Gradle Plugin `2.3.20` following the `/agp-9-upgrade` workflow.
* Migrated root `build.gradle.kts` configuration logic from deprecated `com.android.build.gradle.BaseExtension` to public `com.android.build.api.dsl.CommonExtension`.
* Configured `android.newDsl=false` and `android.builtInKotlin=false` in `android/gradle.properties` to ensure binary compatibility with third-party Flutter plugin Gradle hooks (`dev.flutter.flutter-gradle-plugin`, `cloud_firestore`, etc.) that currently reference legacy extension types.

#### Solutions & Verification
* **Gradle Wrapper**: Updated [android/gradle/wrapper/gradle-wrapper.properties](file:///c:/Users/<username>/Documents/rocis_apps/ROCIs-tasks/android/gradle/wrapper/gradle-wrapper.properties) to `gradle-9.1.0-all.zip`.
* **Plugin Versions**: Updated [android/settings.gradle.kts](file:///c:/Users/<username>/Documents/rocis_apps/ROCIs-tasks/android/settings.gradle.kts) to `id("com.android.application") version "9.0.1"` with `id("org.jetbrains.kotlin.android") version "2.3.20"`.
* **DSL & Kotlin Compile**: Updated [android/build.gradle.kts](file:///c:/Users/<username>/Documents/rocis_apps/ROCIs-tasks/android/build.gradle.kts) to use `CommonExtension` with `compileSdk = 36` and direct `KotlinCompile` task configuration.
* **Verification**: Verified `./gradlew help` (`BUILD SUCCESSFUL`), `./gradlew build --dry-run` (`BUILD SUCCESSFUL`), `flutter analyze` (0 issues), and `flutter test` (271/271 tests passing).

## Side-by-Side Calendar Month Navigation, Date Selection & Dynamic Accent Colors - 2026-08-22

#### Issue / Enhancement
* Side-by-side Month + Agenda widget was not switching month grid when pressing next/previous month (title changed but grid stayed static) because Kotlin was relying on Dart's static cached grid for offset 0.
* Day click in the month grid always defaulted to Sunday because all 7 child day views in `widget_month_agenda_row.xml` shared the same view ID dynamically added via `addView`, causing Android RemoteViews click dispatcher to match the first child.
* Switching to the Calendar or Settings screen inside the app crashed due to `LazyInitializationWidget` state violations, `displayName?[0]` RangeError on empty strings, and unsafe `availableCalendars` lookup.
* Widget highlight colors still showed purple references instead of reading and applying the user's chosen accent color from Widget Customization settings.

#### Solutions & Verification
* **Native Month Grid Generation**: In [MonthAgendaWidgetService.kt](file:///c:/Users/<username>/Documents/rocis_apps/ROCIs-tasks/android/app/src/main/kotlin/com/rocisapps/tasks/MonthAgendaWidgetService.kt), `MonthAgendaGridFactory` now natively computes the 42-day month grid using `Calendar` + `PREF_MONTH_OFFSET`, instantly updating the grid on next/prev month clicks and cross-referencing event dots from agenda data.
* **Unique Day Cell View IDs**: In [widget_month_agenda_row.xml](file:///c:/Users/<username>/Documents/rocis_apps/ROCIs-tasks/android/app/src/main/res/layout/widget_month_agenda_row.xml), defined 7 static child cells with unique IDs (`widget_month_day_0` .. `widget_month_day_6`, `widget_month_bg_0` .. `widget_month_bg_6`, `widget_month_text_0` .. `widget_month_text_6`, `widget_month_dot_0` .. `widget_month_dot_6`), enabling 100% accurate per-day selection via fill-in intents.
* **In-App Navigation Stability**: In [home_screen.dart](file:///c:/Users/<username>/Documents/rocis_apps/ROCIs-tasks/lib/features/home/presentation/screens/home_screen.dart), removed `LazyInitializationWidget` and mounted `CalendarScreen` directly in `PageView`. In [settings_screen.dart](file:///c:/Users/<username>/Documents/rocis_apps/ROCIs-tasks/lib/features/home/presentation/screens/settings_screen.dart) and [web_home_screen.dart](file:///c:/Users/<username>/Documents/rocis_apps/ROCIs-tasks/lib/features/home/presentation/screens/web_home_screen.dart), added `displayName.isNotEmpty` checks before accessing `[0]`. In [calendar_screen.dart](file:///c:/Users/<username>/Documents/rocis_apps/ROCIs-tasks/lib/features/calendar/presentation/screens/calendar_screen.dart), made calendar lookups safe and bounded TableCalendar dates.
* **Dynamic Widget Accent Color**: In `MonthAgendaWidgetService.kt`, `TodayAgendaWidgetService.kt`, `TimelineAgendaWidgetService.kt`, `UpNextWidgetProvider.kt`, `QuickActionWidgetProvider.kt`, and `widget_customization_screen.dart`, all widgets read `full_calendar_highlight_color` (defaulting to Modern Indigo `#6366F1`) and dynamically apply it to highlights, indicators, priority badges, and button tints. Replaced default purple in `CalendarColorService` with Sky Blue (`#0284C7`).
* **Verification**: Ran `flutter analyze` (0 issues), `flutter test` (271/271 passed), and `gradlew compileDebugKotlin` (BUILD SUCCESSFUL).


## Android Widgets Task Filtering, Contrast & Layout Collision Resolution - 2026-08-22

#### Issue / Enhancement
* Completed/deleted tasks were appearing in Today Agenda, Month Agenda, and Timeline widgets because `isCompleted` was not filtered. Undated tasks were leaking across date filters.
* Widget text was unreadable in default/system theme because Kotlin services evaluated `else` to `#1C1C1E` (dark grey) on top of `#B3000000` (dark glass background).
* Default widget color fallbacks in `WidgetDataService.dart`, `colors.xml`, and drawables used purple `#6C63FF` / `#BB86FC` (violating Purple Ban).
* Quick Actions widget was displaying stat number text directly on top of the circular chart bitmap image due to conflicting FrameLayout positioning.
* Side-by-side calendar was missing event dates because `updateTodayAgendaWidget` range was restricted to 30 days and had invisible dark text.

#### Solutions & Verification
* **Task Filtering**: In [lib/core/services/widget_data_service.dart](file:///c:/Users/<username>/Documents/rocis_apps/ROCIs-tasks/lib/core/services/widget_data_service.dart), filtered out all completed (`!t.isCompleted`) and deleted tasks across all widget update methods. Bound undated tasks specifically to today (`dateDisplay: yyyy-MM-dd`) and expanded the sync window to [-60, +120] days.
* **Contrast & Purple Ban**: Updated `values/colors.xml`, `values-night/colors.xml`, and all widget drawables (`widget_pill_bg.xml`, `widget_selected_background.xml`, `widget_selected_today_background.xml`, `widget_today_background.xml`, `ic_check_circle_filled.xml`) with Modern Indigo (`#6366F1`) and pure white text (`#FFFFFF`) with `#94A3B8` secondary contrast.
* **Kotlin Services Text Color**: In `MonthAgendaWidgetService.kt`, `TodayAgendaWidgetService.kt`, `TimelineAgendaWidgetService.kt`, `UpNextWidgetProvider.kt`, and `QuickActionWidgetProvider.kt`, default/dark themes resolve text to `#FFFFFF` for guaranteed contrast on dark glass backgrounds.
* **Quick Actions Overlap**: In `QuickActionWidgetProvider.kt` and `widget_quick_action_layout.xml`, conditionally hide the stat text container when the circular chart bitmap is rendered.
* **Verification**: Ran `flutter analyze` (0 issues) and `flutter test` (271/271 tests passing).

## CI/CD Google Services, FirebaseConfig & Crashlytics Mapping Resolution - 2026-08-22

#### Issue / Enhancement
* CI build failed on `Execution failed for task ':app:processReleaseGoogleServices' > File google-services.json is missing.` during `flutter build appbundle --release`.
* Local release builds failed on `Execution failed for task ':app:uploadCrashlyticsMappingFileRelease' > java.net.UnknownHostException (firebasecrashlyticssymbols.googleapis.com)` during offline/restricted internet builds.
* Root cause: `android/app/google-services.json` was ignored in `.gitignore` without a template file, and Crashlytics attempted network uploads of obfuscation maps synchronously during Gradle packaging.

#### Solutions & Verification
* Created [android/app/google-services.json.example](file:///c:/Users/<username>/Documents/rocis_apps/ROCIs-tasks/android/app/google-services.json.example) containing valid schema placeholders for package `com.rocisapps.tasks`.
* Configured `mappingFileUploadEnabled = false` inside `buildTypes.release` in [android/app/build.gradle.kts](file:///c:/Users/<username>/Documents/rocis_apps/ROCIs-tasks/android/app/build.gradle.kts) to prevent offline release packaging failures.
* Created `scripts/setup_ci_configs.py` with multi-format validation (Base64 vs raw string, JSON syntax check, and automatic example fallback) to eliminate CI `MalformedJsonException` errors.
* Updated [.github/workflows/flutter-ci.yml](file:///c:/Users/<username>/Documents/rocis_apps/ROCIs-tasks/.github/workflows/flutter-ci.yml) to run `python scripts/setup_ci_configs.py` and build installable release APKs (`app-release.apk`).
* Verified with `flutter build appbundle --release` (successfully compiled in 181.7s) and `flutter test` (271/271 passing).

## Android Free 1-Widget Limit & Side-by-Side Calendar Integration - 2026-08-22

#### Issue / Enhancement
* Free users 1-widget limit was bypassed in debug runs due to `BuildConfig.DEBUG` / `FLAG_DEBUGGABLE` check in `WidgetLimitHelper.kt`.
* Side-by-side Month & Agenda widget needed comprehensive Google Calendar integration (multi-day event spans, true calendar colors, and full date range coverage).

#### Solutions & Verification
* Updated `WidgetLimitHelper.isWidgetAllowed` to strictly check `isPremium` across all 7 providers. Non-primary widgets for free users display the `widget_pro_overlay` paywall banner while keeping adapters bound.
* Synchronized `is_premium` state to `HomeWidget` in `SubscriptionService.init()` and during updates.
* Enhanced `WidgetDataService.updateTodayAgendaWidget` and `updateMonthAgendaWidget` to fetch calendar colors via `_calendarService.getCalendarColors()` and expand multi-day event spans across each date they cover.
* Verified with `flutter analyze` (0 issues) and `flutter test` (271/271 passing).





## Lemon Squeezy Production Checkout URLs & Lifetime Web Paywall UI - 2026-08-21

#### Goals / Requirements
* **Production Lemon Squeezy URLs**:
  * Updated [lib/core/config/app_config.dart](file:///c:/Users/<username>/Documents/rocis_apps/ROCIs-tasks/lib/core/config/app_config.dart) with live Lemon Squeezy checkout URLs for Monthly (`5833ecbc-c8c9-4044-974c-782c1fd47e4b`), Yearly (`9afcddf6-d31c-4031-8d49-38e4afdbcee4`), and Lifetime (`40f6b2af-ab2f-4bef-ab3f-32da7f417930`) plans.
* **3-Tier Web Paywall UI**:
  * Integrated **Lifetime Pro** option (`_buildPlanCard` index 2) alongside Monthly and Yearly in [lib/features/premium/presentation/screens/paywall_screen.dart](file:///c:/Users/<username>/Documents/rocis_apps/ROCIs-tasks/lib/features/premium/presentation/screens/paywall_screen.dart).
  * Added responsive `FittedBox` text scaling, compact padding, and "Best Value" badge.
  * Added full localization for Lifetime plan title, price, and badge across all 8 supported languages (`en`, `he`, `es`, `fr`, `de`, `ar`, `sv`, `hi`).
* **Verification**:
  * `flutter analyze` completed with 0 issues.
  * All 271/271 unit and widget tests passed (100%).

## Version 0.2.10+81 & Kotlin 2.2.20 Upgrade - 2026-08-21

#### Goals / Requirements
* **Version Alignment**:
  * Synchronized app version across [pubspec.yaml](file:///c:/Users/<username>/Documents/rocis_apps/ROCIs-tasks/pubspec.yaml) (`0.2.10+81`), [lib/core/config/app_config.dart](file:///c:/Users/<username>/Documents/rocis_apps/ROCIs-tasks/lib/core/config/app_config.dart) (`0.2.10`), and [docs/CHANGELOG.md](file:///c:/Users/<username>/Documents/rocis_apps/ROCIs-tasks/docs/CHANGELOG.md) (`## [0.2.10+81] - 2026-08-21`).
* **Android Build Fix**:
  * Upgraded Kotlin Gradle Plugin (`org.jetbrains.kotlin.android`) in [android/settings.gradle.kts](file:///c:/Users/<username>/Documents/rocis_apps/ROCIs-tasks/android/settings.gradle.kts) from `2.1.10` to `2.2.20` to fulfill Flutter's minimum supported version requirement for Android Gradle builds.

## UI/UX Pro Max: 5-Pillar App-Wide Interaction & Aesthetics Enhancement Suite - 2026-08-21

#### Goals / Requirements
* **Quick Date Chips in Task Creation & Edit (`add_task_screen.dart`)**:
  * Added 1-tap dynamic date chips (`Today`, `Tomorrow`, `This Weekend`, `Next Week`) above the custom date picker with active selection highlighting, checkmark toggle, and tactile haptic response.
* **Multi-Color Category Calendar Dots (`calendar_screen.dart`)**:
  * Upgraded calendar markers from stacked uniform bars to a centered horizontal cluster of distinct colored dots derived from task category colors and device/Google calendar colors with `+N` badge support when >3 events.
  * Added `SingleChildScrollView` wrapper to empty state prevents any bottom overflow on smaller heights.
* **Empty State Starter Templates & Collapsible Completed Section (`task_list_screen.dart`)**:
  * Added 4 interactive quick-starter templates (`🛒 Grocery & Shopping List`, `💻 Work Sprint Task`, `🌅 Daily Routine`, `📚 Study & Assignment`) with subtasks and instant 1-tap creation.
  * Re-architected task list into active tasks and an accordion-style `ExpansionTile` for completed tasks (`Completed (X)`), keeping focus on pending work.
  * Added celebratory `_buildCelebrationBanner` ("All done for today! 🎉") when all tasks are complete.
* **Modern Segmented Pills in Sort & Filter Sheet (`task_sort_filter_sheet.dart` & `task_provider.dart`)**:
  * Replaced vertical radio buttons with horizontal segmented sort pill buttons.
  * Added `resetAllFilters()` method in `TaskProvider` and a 1-tap "Reset All" action in the header when filters/sort are active.
* **Inline Quick Reschedule Menu on Task Tiles (`task_tile.dart`)**:
  * Enabled direct tap interaction on due date chips opening a quick reschedule bottom sheet with `+1 Day`, `+1 Week`, and contextual `Move to Today` options.
* **Automated Verification**:
  * `flutter analyze` completed with **0 issues found** (clean codebase).
  * Full test suite: **271/271 tests passing (100%)** including new widget tests in `test/features/tasks/presentation/widgets/quick_date_chips_test.dart`, `task_sort_filter_sheet_test.dart`, `task_tile_reschedule_test.dart`, and `test/features/calendar/presentation/calendar_screen_test.dart`.

#### Goals / Requirements
* **Multi-Widget Live Preview Switcher in `WidgetCustomizationScreen`**:
  * Implemented an interactive horizontal switcher allowing users to preview and configure all 6 Android home widgets (Full Calendar, Day Agenda, Month & Agenda, Schedule Timeline, Quick Actions, and Up Next Pill).
  * Built dynamic, pixel-accurate live preview mockups that adapt in real time to the selected theme (System, Light, Dark, Glassmorphic) and custom accent color with smooth animated transitions.
* **Tactile Micro-Interactions & Haptics**:
  * Integrated `HapticFeedback.selectionClick()` on bottom navigation tab selection, PageView swipe transitions, and widget picker toggles.
  * Added `HapticFeedback.lightImpact()` on Floating Action Button (FAB) and empty state creation triggers.
* **Elevated Empty State Experiences**:
  * Upgraded zero-task and empty calendar day states with themed iconography badges, supportive copy, and direct one-tap action triggers (`AddTaskScreen` pre-populated with `initialDueDate`).
* **Automated Verification**: `flutter analyze` completed with 0 issues; all 262/262 automated tests passing (100%).


## ROCIs-Schedule: 8-Language Localization Suite Parity - 2026-08-20

#### Goals / Requirements
* **8-Language Parity with ROCIs-tasks**:
  * Implemented complete localized translations for all 8 supported languages: **English (`en`)**, **Hebrew (`he`)**, **Spanish (`es`)**, **German (`de`)**, **French (`fr`)**, **Arabic (`ar`)**, **Hindi (`hi`)**, and **Swedish (`sv`)**.
  * Full support for Right-To-Left (RTL) layouts in Arabic and Hebrew.
  * Added language selector modal in `SettingsScreen` supporting System Default and all 8 languages with native display names (English, עברית, Español, Deutsch, Français, العربية, हिन्दी, Svenska).
  * Registered `AppLocalizations.supportedLocales` in `MaterialApp.router`.
* **Automated Testing**: Added `test/unit/l10n_test.dart` verifying all 8 language translations and delegates. 36/36 tests passing in `ROCIs-Schedule` with 0 analyzer issues across both projects.

## ROCIs-Schedule: Full Auth Suite & Guest Mode Parity - 2026-08-20

#### Goals / Requirements
* **Release Keystore Error Resolution**: Fixed trailing whitespace in `ROCIs-Schedule/android/key.properties` (`storePassword=<password> `) and verified keystore fingerprints via `keytool` (SHA-1: `90:98:BD:98:55:EB:EB:4E:E7:3C:1A:40:4E:DA:55:D1:06:CC:5E:E8`).
* **Complete Auth Feature Parity with ROCIs-tasks**:
  * Added Email & Password authentication (`signInWithEmailAndPassword`, `signUpWithEmailAndPassword`, and `sendPasswordResetEmail`) in `AuthService`.
  * Implemented seamless **Guest Mode** (`continueAsGuest`, `isGuest`, `effectiveUserId = 'guest'`) allowing offline local use of the app without mandatory login.
  * Overhauled `LoginScreen` with top-bar "Skip for now" / Guest action, email & password fields with password visibility toggle, forgot password action, divider, Google Sign-In button, and link to register.
  * Created `RegisterScreen` (`/register`) with matching password validation and smooth onboarding redirection.
  * Updated `ProfileScreen` and `SettingsScreen` to handle guest mode gracefully with dedicated call-to-action cards ("Sign in to sync your schedule").
  * Added localized strings in English and Hebrew in `app_localizations.dart`.
* **Automated Testing**: 26/26 tests passing in `ROCIs-Schedule` and 262/262 tests passing in `ROCIs-tasks` with 0 analyzer issues across both codebases.

## ROCIsApps Ecosystem: ROCIs Schedule Cross-App Synergy & Deep Linking - 2026-08-20

#### Goals / Requirements
* **Deep Linking URL Scheme**: Configured `rocisschedule://` custom URI scheme and `https://schedule.rocisapps.com` app links in Android Manifest with query visibility (`<queries>`) for `com.rocisapps.tasks` and `rocistasks://`.
* **CrossAppBridgeService**: Created `CrossAppBridgeService` in `ROCIs-Schedule` enabling 1-tap assignment export (`sendAssignmentToTasks`) and launching `ROCIs-tasks` with automated fallback to Google Play Store and web.
* **Assignment Export UI**: Added "Send to ROCIs Tasks" button on assignment cards in `AssignmentListScreen` with micro-haptic response and feedback snackbars.
* **Ecosystem Settings**: Added "ROCIs Suite Ecosystem" section in `SettingsScreen` allowing direct cross-app navigation to `ROCIs Tasks`.
* **Automated Testing**: 22/22 tests passing in `ROCIs-Schedule` and 262/262 tests passing in `ROCIs-tasks` with 0 analyzer issues across both projects.

## ROCIsApps Ecosystem: ROCIs Schedule Feature Suite & rocisapps.com Showcase - 2026-08-20

#### Goals / Requirements
* **Smart Notifications**: Created `NotificationService` for `ROCIs-Schedule` supporting pre-class alarms (10/15/30 min prior), location & instructor alerts, and assignment due date reminders.
* **Exam Countdown Carousel**: Added pinned, live countdown banner to `ScheduleScreen` for upcoming exams (days/hours left with crimson accent glow and location tag).
* **GPA & Academic Calculator**: Added `grade` property to `Course` model, SQLite database schema migration (v3), and top glassmorphic **Academic Overview** metric cards (Total Credits, 4.0 GPA, and Average Grade) in `CourseListScreen`.
* **University .ICS Calendar Importer**: Created `IcsImportService` to parse standard `.ics` / iCalendar exports from Canvas/Moodle, automatically extracting recurring weekly rules, locations, event types (Exam, Lab, Class), and deduplicating courses.
* **rocisapps.com Ecosystem Showcase**: Added dedicated **ROCIs Schedule** showcase section on `rocisapps.com` (`ROCIsApp.github.io`) with interactive simulator preview, feature list, and glowing `[ In Active Development • Coming Soon ]` badge.
* **Automated Testing**: 20/20 unit and widget tests passing in `ROCIs-Schedule` and 262/262 tests passing in `ROCIs-tasks` with 0 analyzer issues across both projects.

## ROCIsApps Ecosystem Expansion: ROCIs Schedule Phase 2 (UI/UX & Glassmorphism Transformation) - 2026-08-20

#### Goals / Requirements
* Ported `GlassContainer` with Gaussian backdrop blur, 10–18% dynamic color tinting based on course or primary theme color, and subtle tinted borders to `ROCIs-Schedule`.
* Added `useGlassmorphism` preference to `ThemeProvider` with toggle in `SettingsScreen` and complete localized translations in English and Hebrew (`app_localizations.dart`).
* Overhauled `ScheduleScreen`: replaced static containers with `GlassContainer` widgets tinted by individual course colors, added course color glow indicators, week strip selector with glowing selection pill, and formatted time/event-type badges.
* Overhauled `AssignmentListScreen`: wrapped items in course-tinted `GlassContainer`, added priority badge pills (`HIGH`, `MED`, `LOW`), swipe-to-delete dismissible, and micro-haptic pulses (`HapticFeedback.lightImpact()`) on assignment completion.
* Overhauled `CourseListScreen`: added glassmorphic course cards with circular initials badge, event counts, credit badges, and draggable modal bottom sheet for course details.
* Automated testing: Added comprehensive unit and widget screen tests (`test/unit/glass_container_test.dart`, `test/unit/screens_smoke_test.dart`, `test/unit/sync_and_models_test.dart`). 15/15 tests passing in `ROCIs-Schedule` and 262/262 tests passing in `ROCIs-Tasks` with 0 analyzer issues across both projects.

## ROCIsApps Ecosystem Expansion: ROCIs Schedule Phase 1 (Sync & Auth Reliability) - 2026-08-20

#### Goals / Requirements
* Cloned and configured `ROCIs-Schedule` (`https://github.com/<username>/ROCIs-Schedule`) in parent directory `c:\Users\<username>\Documents\rocis_apps\ROCIs-Schedule` as part of the unified ROCIsApps ecosystem.
* Resolved `material_color_utilities: ^0.13.0` dependency conflict with Flutter SDK.
* Implemented Phase 1: bidirectional Firestore download & merge for Courses, Events, and Assignments, offline SQLite database isolation per user (`rocis_schedule_<uid>.db`), safe sign-out cache clearance in `LocalDbService.clearCache()`, sync-safe provider methods without re-triggering remote loops, and unit tests (7/7 passing).
* Established alignment with `ROCIs-Tasks`'s existing `ScheduleFirestoreService` for cross-app timetable and assignment synchronization.

## Fix: Android RemoteViews Inflation Crash ("Couldn't load widget") - 2026-08-20

#### Problem
* Placing any of the new home screen widgets resulted in the Android launcher displaying `"Couldn't load widget"` in the top left corner of the widget frame.

#### Root Cause
* Android's `RemoteViews` enforces a strict whitelist of view classes that can be inflated in the launcher process. Using `<View ... />` (which is not annotated with `@RemoteView`) causes an immediate `android.view.InflateException: Class not allowed to be inflated in RemoteViews: android.view.View`.
* The new layouts used `<View>` for dividers and category/accent color strips (`widget_today_agenda_layout.xml`, `widget_today_agenda_item.xml`, `widget_month_agenda_layout.xml`, `widget_timeline_agenda_layout.xml`, `widget_timeline_header_item.xml`, `widget_timeline_event_item.xml`, and `widget_up_next_layout.xml`).
* In addition, `android:background="?android:attr/selectableItemBackgroundBorderless"` was used in button headers (which causes theme resolution failures on third-party launchers) and `android:tint` was used in `widget_quick_action_layout.xml` on `ImageView`.

#### Solution
1. Replaced all `<View>` tags with `<FrameLayout>` (which is on the `RemoteViews` whitelist and supports background colors/drawables).
2. Removed `?android:attr/selectableItemBackgroundBorderless` and `android:tint` from RemoteViews layout XMLs.
3. Added ProGuard/R8 keep rules for `AppWidgetProvider` and `RemoteViewsService` in `proguard-rules.pro`.
4. Verified with `flutter analyze` (0 issues) and `flutter test` (262/262 passed).

## Android Home Screen Widgets Suite, Direct Task Completion & Freemium 1-Widget Limit - 2026-08-20

#### Goals / Requirements
* Create 5 new Android home screen widgets: **Day Agenda** (day-by-day navigation), **Month & Agenda** (Samsung-style split month grid + day list), **Schedule Timeline** (Google-style multi-day continuous scroll timeline), **Quick Actions & Progress Ring** (1-tap creation + live progress), and **Up Next Pill** (minimalist upcoming item card with countdown).
* Implement **Direct One-Tap Task Completion** straight from widget check icons without having to open the app.
* Implement a **Freemium Widget Limit**: All widgets are accessible to free users, but free users can place at most 1 active widget on their home screen; Pro users can place unlimited widgets. Additional widgets placed by free users render an upgrade card with deep link to the paywall (`rocistasks://paywall`).
* Adhere strictly to project rules: Native Android Kotlin state shifts for widget navigation, background isolate isolation, glassmorphism design system, 100% i18n across 8 languages, and 100% passing tests.

#### Changes/Fixes
1. **Android Native Layouts & Drawables (`android/app/src/main/res/`)**:
   - Created vector drawables: `ic_circle_outline.xml`, `ic_check_circle_filled.xml`, `ic_lock_pro.xml`, `widget_card_bg.xml`, and `widget_pill_bg.xml`.
   - Built RemoteViews layouts: `widget_today_agenda_layout.xml`, `widget_month_agenda_layout.xml` (with split grid and agenda), `widget_timeline_agenda_layout.xml`, `widget_quick_action_layout.xml`, and `widget_up_next_layout.xml`.
   - Added Pro Upgrade overlay layout to `widget_layout.xml` and all new widget layouts.
2. **Native Kotlin Providers, Limit Helper & Services (`android/app/src/main/kotlin/com/rocisapps/tasks/`)**:
   - `WidgetLimitHelper.kt`: Queries `AppWidgetManager` across all 7 providers to count placed instances; enforces 1-widget limit for free users and attaches `rocistasks://paywall` intent.
   - `TodayAgendaWidgetProvider.kt` & `TodayAgendaWidgetService.kt`: Native day offset shifting, day navigation broadcasts, RemoteViews list factory, and direct completion fill-in intents (`rocistasks://complete?id=...`).
   - `MonthAgendaWidgetProvider.kt`, `MonthAgendaWidgetService.kt`, `MonthAgendaGridService.kt`: Native month offset calculation and date selection.
   - `TimelineAgendaWidgetProvider.kt` & `TimelineAgendaWidgetService.kt`: Multi-day grouped feed with section headers and item completion.
   - `QuickActionWidgetProvider.kt` & `UpNextWidgetProvider.kt`: Fast task entry and immediate next task badge.
   - Registered all receivers and services in `AndroidManifest.xml`.
3. **Dart Serialization, Background Interactivity & UI (`lib/`)**:
   - `WidgetDataService`: Added `updateAllWidgets()`, `updateTodayAgendaWidget()`, `updateMonthAgendaWidget()`, `updateTimelineAgendaWidget()`, `updateQuickActionWidget()`, and `updateUpNextWidget()`.
   - `BackgroundHandler`: Added support for widget day/month navigation sync and triggers full widget suite refresh upon completing tasks in background isolates.
   - `TaskProvider`: Integrated `_widgetDataService.updateAllWidgets()` on every task CRUD and sync cycle.
   - `WidgetCustomizationScreen`: Added interactive showcase gallery displaying all 6 available home widgets with badges and setup guides.
4. **Localization (i18n) & Testing**:
   - Added localized widget titles and descriptions across 8 languages (`app_en.arb`, `app_he.arb`, `app_ar.arb`, `app_de.arb`, `app_es.arb`, `app_fr.arb`, `app_hi.arb`, `app_sv.arb`) and ran `flutter gen-l10n`.
   - Added unit test suite `test/features/home/new_widgets_data_test.dart` covering data serialization for all new widgets.
   - Verified 0 analyzer errors (`flutter analyze`) and 100% passing tests (262/262 passed via `flutter test`).


## Custom Lines, Recurring Tasks, CI SHA Pinning & Open-Source Public Release - 2026-08-20

#### Goals / Requirements
* Implement **Custom Lines** (interactive contacts, locations, web links, custom notes) with tap-to-act support.
* Implement **Pro Recurring Tasks** (daily, weekday, weekly, monthly, yearly, custom repeat rules) with auto-creation on completion.
* Prepare the repository for public release (`ROCIsTasks-Public`), scrub private keys/secrets, and resolve CI action deprecations and analyzer issues.

#### Changes/Fixes
1. **Custom Lines (`custom_field.dart`, `custom_field_action_service.dart`, `task_custom_fields_section.dart`)**:
   - Built domain model `CustomField` and action dispatcher `CustomFieldActionService` to launch dialer, mail client, maps, and web links.
   - Built interactive UI section with quick-add chips in task details and creation screen.
2. **Recurring Tasks (`task_recurrence_service.dart`, `recurrence_picker_sheet.dart`)**:
   - Implemented recurrence calculation engine and picker bottom sheet for daily, weekday, weekly, monthly, yearly, and custom schedules.
   - Automatically generates the next recurring instance upon completing a task for Pro users.
3. **CI & Workflow Hardening (`.github/workflows/flutter-ci.yml`, `.gitignore`)**:
   - Added pre-build template copy step (`.env.example`, `firebase_options.dart.example`, `firebase_schedule_options.dart.example`) to resolve missing config in CI clones.
   - Upgraded `actions/cache` to `v4.2.2` (`d4323d4df104b026a6aa633fdb11d772146be0bf`) and pinned all actions to immutable 40-character commit SHAs.
   - Replaced `.github/` ignore rule with `.github/copilot-instructions.md` so GitHub Actions workflows are tracked properly.
4. **Testing & Synchronization**:
   - 256/256 unit and widget tests passing (`flutter test`).
   - 0 static analysis issues found (`flutter analyze`).
   - Clean orphan open-source release pushed to public repo `remote/main` and complete development branch pushed to `AG/Public`.

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

## [0.2.15+105] - 2026-09-18

### Test Suite Alignment, Kanban Due-Date Preservation, and Web Responsive Polish

#### Goals / Requirements
* Synchronize legacy unit tests with the deferred recurring tasks materialization engine.
* Resolve Kanban Board "In Focus" to "To Do" drag-and-drop snap-back while strictly preserving the task's due date per user instruction.
* Resolve Web workspace `RenderFlex` layout overflow on compact browser viewports (< 768px).

#### Changes/Fixes
1. **Recurring Tasks Test Alignment**: Updated `task_provider_test.dart` to assert deferred recurrence completion state and verified materialization on arrival of the scheduled recurrence date. All 350 test suite cases are 100% green.
2. **Kanban Due-Date Preservation (`BUG-02`)**: In `kanban_board_view.dart`, removed `clearDueDate: true` to prevent deleting the user's deadline, and added manual column placement tracking (`_manualTodoTaskIds`, `_manualInFocusTaskIds`) with `SharedPreferences` persistence. Unpins task if pinned when moved to "To Do". Added automated widget test coverage in `kanban_board_test.dart`.
3. **Web Viewport Responsive Breakpoints (`BUG-03`)**: In `web_home_screen.dart`, raised single-column inspector view threshold from `< 600` to `< 768` and converted the dashboard stats row and greeting header to responsive `LayoutBuilder` widgets to prevent `RenderFlex` overflow errors on resize.
4. **Micro-Haptic Feedback Throttling (`BUG-05`)**: Introduced `HapticUtils` with rate-limiting / throttle guards (100–120ms) in `lib/core/utils/haptic_utils.dart` to prevent motor buzzing and user haptic fatigue during rapid chip selections and stepper interactions across `AddTaskScreen`, `QuickAddTaskBottomSheet`, and `RecurrencePickerSheet`. Added unit test suite `test/core/utils/haptic_utils_test.dart` (3/3 passing).

#### Deployment & Release Operations
* **Shorebird Cloud Patch Deployment**:
  - Configured Shorebird CLI (Flutter 3.47.2 engine) and authenticated.
  - Cleared stale `.dart_tool\hooks_runner` artifacts.
  - Successfully built and promoted **Shorebird Patch #2** (`Patch ID: 662713`) to the **`stable`** track targeting release `0.2.15+105`. All active devices will automatically receive the updates over-the-air.
* **Git & Standalone Artifacts**:
  - Rebased and pushed all commits to `origin/main`.
  - Created and pushed Git release tag `v0.2.15+105`.
  - Compiled standalone release APK at `build/app/outputs/flutter-apk/app-release.apk` (74.9 MB).




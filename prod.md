# Production Readiness Guide

## Overview
This guide outlines the steps needed to make ROCIs Tasks production-ready. Items are prioritized by severity.

---

## Phase 1: Critical Fixes (Must Complete Before Launch)

### 1. Fix Silent Error Handling in Main.dart

**File:** `lib/main.dart:76-93`

**Problem:** Empty catch blocks silently fail critical service initialization.

**Steps:**
1. Open `lib/main.dart`
2. Locate the try-catch blocks in `main()` (lines 76-93)
3. Replace empty catch blocks with proper error handling:
   ```dart
   } catch (e, stackTrace) {
     // Log to Crashlytics
     FirebaseCrashlytics.instance.recordError(e, stackTrace);
     // Show user-friendly error dialog
     runApp(ErrorApp(message: 'Failed to initialize app'));
     return;
   }
   ```
4. Create an `ErrorApp` widget that displays a user-friendly error screen
5. Test each failure scenario (e.g., disabled Firebase, no network)

---

### 2. Implement User-Facing Error States

**Problem:** Users aren't notified when operations fail.

**Steps:**
1. Create a `lib/presentation/common/error_snackbar.dart`:
   ```dart
   void showErrorSnackBar(BuildContext context, String message) {
     ScaffoldMessenger.of(context).showSnackBar(
       SnackBar(
         content: Text(message),
         backgroundColor: Theme.of(context).colorScheme.error,
       ),
     );
   }
   ```
2. Add error handling to each feature's state management:
   - Auth errors (login failures)
   - Task CRUD errors
   - Calendar sync errors
3. Test error scenarios:
   - Network disconnection during sync
   - Permission denied for calendar
   - Firebase quota exceeded

---

### 3. Add Input Validation

**Problem:** No validation on user inputs (tasks, categories, etc.).

**Steps:**
1. Create `lib/core/validation/validators.dart`:
   ```dart
   class Validators {
     static String? validateTaskTitle(String? value) {
       if (value == null || value.trim().isEmpty) {
         return 'Task title is required';
       }
       if (value.length > 100) {
         return 'Task title must be less than 100 characters';
       }
       return null;
     }
   }
   ```
2. Add validation to task creation/editing forms
3. Add validation to category creation
4. Test with edge cases:
   - Empty strings
   - Extremely long inputs
   - Special characters

---

## Phase 2: Testing & Quality Assurance

### 4. Increase Test Coverage

**Current:** 8 test files for 64-file codebase

**Steps:**
1. Create widget tests for each screen:
   - `auth/presentation/login_screen_test.dart`
   - `tasks/presentation/task_list_screen_test.dart`
   - `home/presentation/home_screen_test.dart`
2. Create unit tests for:
   - All repositories
   - All use cases
   - All validators
3. Create integration tests for critical flows:
   - Login → Create Task → Sync
   - Calendar permission → Event creation
4. Set minimum coverage threshold in `pubspec.yaml`:
   ```yaml
   coverage:
     minimum: 80
   ```
5. Run tests and fix failures

---

### 5. Implement Proper Logging

**Problem:** Using `debugPrint` instead of proper logging.

**Steps:**
1. Add logging package to `pubspec.yaml`:
   ```yaml
   dependencies:
     logger: ^2.0.0
   ```
2. Create `lib/core/logging/logger_service.dart`:
   ```dart
   import 'package:logger/logger.dart';

   final appLogger = Logger(
     printer: PrettyPrinter(
       methodCount: 2,
       errorMethodCount: 8,
       lineLength: 120,
       colors: true,
       printEmojis: true,
       printTime: true,
     ),
   );
   ```
3. Replace all `debugPrint` calls with:
   - `appLogger.d()` for debug
   - `appLogger.i()` for info
   - `appLogger.w()` for warnings
   - `appLogger.e()` for errors
4. Configure log levels based on environment (debug vs release)

---

## Phase 3: Performance & Reliability

### 6. Optimize App Startup

**Problem:** Many services initialized simultaneously on startup.

**Steps:**
1. Analyze startup performance with Flutter DevTools
2. Implement lazy initialization for non-critical services:
   ```dart
   // Critical services - initialize immediately
   await Firebase.initializeApp();

   // Non-critical - initialize after UI is ready
   WidgetsBinding.instance.addPostFrameCallback((_) {
     _initializeSecondaryServices();
   });
   ```
3. Add loading screen during initialization
4. Target: App ready in < 2 seconds on mid-range device

---

### 7. Memory Leak Prevention

**Problem:** Potential memory leaks with multiple ChangeNotifier providers.

**Steps:**
1. Review all ChangeNotifier providers for proper disposal
2. Ensure `dispose()` is called on all controllers:
   ```dart
   @override
   void dispose() {
     _taskController.dispose();
     _calendarController.dispose();
     super.dispose();
   }
   ```
3. Test with Flutter DevTools Memory profiler
4. Fix any disposal issues found

---

### 8. Implement Offline-First Architecture Improvements

**Steps:**
1. Ensure all writes go to local Hive DB first
2. Sync to Firestore in background
3. Show sync status indicator in UI
4. Handle merge conflicts when data changes offline and online
5. Test: Create tasks offline, close app, reopen with network

---

## Phase 4: Security Hardening

### 9. Review and Harden Security

**Steps:**
1. **Firestore Rules Review:**
   - Test each rule with Firebase Simulator
   - Ensure user isolation (no cross-user data access)
2. **API Key Protection:**
   - Verify no API keys in git (check `git grep`)
   - Ensure `.env` is in `.gitignore`
3. **Crashlytics:**
   - Verify no sensitive data logged (passwords, tokens)
4. **Analytics:**
   - Review events for PII (personally identifiable information)

---

## Phase 5: Deployment Checklist

### 10. Pre-Release Testing

**Manual Testing Checklist:**
- [ ] Create account (Google Sign-In)
- [ ] Create, edit, delete tasks
- [ ] Create and assign categories
- [ ] Sync with Google Calendar
- [ ] Add/edit/delete calendar events from app
- [ ] Test on slow 3G network
- [ ] Test offline mode
- [ ] Test with low battery
- [ ] Test on low-end device
- [ ] Test phone rotation
- [ ] Test background/foreground switching
- [ ] Verify notifications work
- [ ] Test home widget functionality
- [ ] Verify both English and Hebrew languages

**Platform-Specific:**
- [ ] **Android:** Test on multiple API levels (21, 24, 29, 33)
- [ ] **iOS:** Test on multiple iOS versions
- [ ] **Web:** Test in Chrome, Safari, Firefox

---

### 11. Build and Sign Release

**Android:**
```bash
flutter build apk --release
flutter build appbundle --release
```

**iOS:**
```bash
flutter build ipa --release
```

**Web:**
```bash
flutter build web --release
```

---

### 12. Store Submission Checklist

**Google Play Store:**
- [ ] Create app listing (title, description, screenshots)
- [ ] Set content rating
- [ ] Add privacy policy URL
- [ ] Set target audience
- [ ] Configure in-app purchases (if any)
- [ ] Upload app bundle
- [ ] Complete content questionnaire

**Apple App Store:**
- [ ] Create app listing
- [ ] Upload screenshots (all iPhone sizes)
- [ ] Set age rating
- [ ] Add privacy policy URL
- [ ] Complete App Privacy details
- [ ] Upload IPA via TestFlight first
- [ ] Submit for review

---

### 13. Post-Launch Monitoring

**First Week:**
- [ ] Monitor Firebase Crashlytics daily
- [ ] Check Analytics for user flows
- [ ] Review user feedback (store reviews, support emails)
- [ ] Monitor Firestore usage and costs

**Set Up Alerts:**
- [ ] Crashlytics: Alert on new crash groups
- [ ] Analytics: Alert on unusual user drop-off
- [ ] Firestore: Budget alerts

---

## Phase 6: Future Improvements (Optional)

### 14. Set Up CI/CD Pipeline

**Steps:**
1. Create `.github/workflows/flutter.yml`
2. Configure:
   - Automatic testing on PR
   - Build verification
   - Deployment to beta channels
3. Use GitHub Actions or Bitrise

---

### 15. Add Analytics Events

**Steps:**
1. Define key events to track:
   - `task_created`
   - `task_completed`
   - `calendar_synced`
   - `user_registered`
2. Add events throughout app
3. Create Firebase Analytics funnel

---

## Progress Tracking

| Phase | Task | Status | Notes |
|-------|------|--------|-------|
| 1.1 | Fix main.dart error handling | | |
| 1.2 | Implement error states | | |
| 1.3 | Add input validation | | |
| 2.4 | Increase test coverage | | |
| 2.5 | Implement logging | | |
| 3.6 | Optimize startup | | |
| 3.7 | Fix memory leaks | | |
| 3.8 | Offline-first improvements | | |
| 4.9 | Security hardening | | |
| 5.10 | Pre-release testing | | |
| 5.11 | Build and sign | | |
| 5.12 | Store submission | | |
| 5.13 | Post-launch monitoring | | |
| 6.14 | CI/CD pipeline | | |
| 6.15 | Analytics events | | |

---

## Definitions

- **Critical:** Must fix before launch
- **High:** Should fix before launch
- **Medium:** Fix soon after launch
- **Low:** Nice to have

---

*Last Updated: 2026-02-12*

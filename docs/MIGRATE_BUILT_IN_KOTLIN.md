# Migrate to Built-in Kotlin & Upgrade Packages

Flutter 3.44+ warns that plugins applying the Kotlin Gradle Plugin (KGP) will break future builds. This guide walks through upgrading every affected package and enabling built-in Kotlin, organized into three phases to manage risk.

## Why This Is Needed

AGP 9.0+ includes Kotlin support built-in. Plugins that apply `kotlin-android` in their own Gradle files conflict with this. The current workaround (`android.builtInKotlin=false` in `gradle.properties`) suppresses the error but will be removed in a future Flutter release.

## Migration Phases

| Phase | Scope | Risk | Status |
|---|---|---|---|
| **Phase 1** | Firebase 6.x + device_info_plus + built-in Kotlin | Medium | ✅ Done |
| **Phase 2** | RevenueCat 10.x | High (subscription flows) | ✅ Done |
| **Phase 3** | Remaining packages (8 upgrades) | Medium | ✅ Done (except home_widget) |

---

# Phase 1: Firebase 6.x + Built-in Kotlin

This is the minimum required to fix the KGP warnings and enable built-in Kotlin.

## Phase 1 Packages

| Package | Current | Target | Reason |
|---|---|---|---|
| `firebase_core` | `^3.6.0` | `^4.10.0` | Applies KGP; Firebase 4.x supports built-in Kotlin |
| `cloud_firestore` | `^5.4.4` | `^6.5.0` | Applies KGP; part of Firebase 4.x wave |
| `firebase_auth` | `^5.3.4` | `^6.5.2` | Applies KGP; part of Firebase 4.x wave |
| `firebase_crashlytics` | `^4.1.3` | `^5.2.3` | Applies KGP; part of Firebase 4.x wave |
| `firebase_analytics` | `^11.3.3` | `^12.4.2` | Applies KGP; part of Firebase 4.x wave |
| `firebase_performance` | `^0.10.1+10` | `^0.11.4+2` | Applies KGP |
| `firebase_remote_config` | `^5.5.0` | `^6.5.2` | Applies KGP; part of Firebase 4.x wave |
| `device_info_plus` | `11.1.0` | `^13.1.0` | Applies KGP |

### Step 1.1: Create a Branch

```bash
git checkout -b feat/migrate-built-in-kotlin
```

### Step 1.2: Upgrade Firebase Packages

Update all Firebase packages together — they must be on matching major versions.

```bash
flutter pub upgrade firebase_core cloud_firestore firebase_auth firebase_crashlytics firebase_analytics firebase_performance firebase_remote_config --major-versions
```

If `flutter pub upgrade --major-versions` doesn't resolve cleanly, manually edit `pubspec.yaml`:

```yaml
dependencies:
  firebase_core: ^4.10.0
  cloud_firestore: ^6.5.0
  firebase_auth: ^6.5.2
  firebase_crashlytics: ^5.2.3
  firebase_analytics: ^12.4.2
  firebase_performance: ^0.11.4+2
  firebase_remote_config: ^6.5.2
```

Then run:

```bash
flutter pub get
```

### Step 1.3: Upgrade device_info_plus

```bash
flutter pub upgrade device_info_plus --major-versions
```

Or manually in `pubspec.yaml`:

```yaml
dependencies:
  device_info_plus: ^13.1.0
```

### Step 1.4: Check for Breaking API Changes

#### Firebase 4.x Core Changes

The main breaking change is how `Firebase.initializeApp` works. In most cases, the existing code is fine because it already uses `DefaultFirebaseOptions`. Verify:

- `lib/main.dart` / `lib/core/services/app_initializer.dart` — `Firebase.initializeApp(options: ...)` should still compile
- `lib/firebase_options.dart` — regenerate with `flutterfire configure` if needed

#### cloud_firestore 6.x Changes

- `Timestamp` import: `import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;` — **no change needed**, this still works
- `FirebaseFirestore.instance` — **no change needed**
- `CollectionReference`, `DocumentReference`, `Query` — API is stable
- **Check**: any `FieldValue.serverTimestamp()` calls — still works

#### firebase_auth 6.x Changes

- `FirebaseAuth.instance` — **no change needed**
- `GoogleSignIn` integration — **no change needed** (this is the `google_sign_in` package, not Firebase)
- `User` model — **no change needed**
- **Check**: `authStateChanges()`, `signInWithEmailAndPassword()`, `signInWithCredential()` — all stable

#### firebase_crashlytics 5.x Changes

- `FirebaseCrashlytics.instance.crash()` — **no change needed**
- `FirebaseCrashlytics.instance.recordError()` — **no change needed**
- `FlutterError.onError` — **no change needed**

#### firebase_analytics 12.x Changes

- `FirebaseAnalytics.instance` — **no change needed**
- `logEvent()`, `logTaskCompleted()`, etc. — **no change needed**

#### firebase_performance 0.11.x Changes

- `FirebasePerformance.instance.newTrace()` — **no change needed**
- `Trace.start()`, `Trace.stop()` — **no change needed**
- `FirebasePerformance.instance.setPerformanceCollectionEnabled()` — **no change needed**

#### firebase_remote_config 6.x Changes

- `FirebaseRemoteConfig.instance` — **no change needed**
- `setConfigSettings()`, `setDefaults()`, `fetchAndActivate()` — **no change needed**
- `RemoteConfigSettings` — **no change needed**

#### device_info_plus 13.x Changes

- `DeviceInfoPlugin()` — **no change needed**
- `AndroidDeviceInfo`, `IosDeviceInfo` — **no change needed**
- **Check**: `deviceInfo.androidInfo` / `deviceInfo.iosInfo` — may need `await` if the API changed to async

### Step 1.5: Enable Built-in Kotlin

Once all packages compile without KGP errors:

1. **Edit `android/gradle.properties`**:

```properties
org.gradle.jvmargs=-Xmx8G -XX:MaxMetaspaceSize=4G -XX:ReservedCodeCacheSize=512m -XX:+HeapDumpOnOutOfMemoryError
android.useAndroidX=true
android.builtInKotlin=true
```

Remove the lines:
```
android.newDsl=false
android.builtInKotlin=false
```

2. **Edit `android/app/build.gradle`** — remove `kotlin-android`:

```groovy
plugins {
    id "com.android.application"
    // The Flutter Gradle Plugin must be applied after the Android plugin.
    id "dev.flutter.flutter-gradle-plugin"
    id "com.google.gms.google-services"
    id "com.google.firebase.crashlytics"
}
```

3. **Remove `kotlinOptions` block** from `android/app/build.gradle`:

```groovy
// DELETE this block entirely:
kotlinOptions {
    jvmTarget = "17"
}
```

The root `build.gradle.kts` already forces Kotlin JVM 17 via `afterEvaluate` for all subprojects.

### Step 1.6: Regenerate Code

```bash
dart run build_runner build --delete-conflicting-outputs
```

### Step 1.7: Regenerate Firebase Config (if needed)

If `flutterfire configure` output format changed:

```bash
flutterfire configure
```

This regenerates `lib/firebase_options.dart` and `lib/firebase_schedule_options.dart`.

### Step 1.8: Verify Build

```bash
# Debug build
flutter build apk --debug

# Release build (Android)
flutter build appbundle --release

# Web build (if applicable)
flutter build web
```

### Step 1.9: Run Tests

```bash
flutter test
flutter analyze
```

### Step 1.10: Manual Testing Checklist

Test every Firebase-connected flow:

- [ ] App launches without crash
- [ ] Google Sign-In works
- [ ] Email/Password sign-in works
- [ ] Tasks sync to Firestore (create, update, delete)
- [ ] Tasks appear after cold restart (Hive ↔ Firestore sync)
- [ ] Offline mode works (toggle airplane mode, make changes, reconnect)
- [ ] Crashlytics logs test crash (Settings → Crash Test)
- [ ] Analytics events fire (check Firebase Console DebugView)
- [ ] Remote Config values load
- [ ] Performance traces appear in Firebase Console
- [ ] Home screen widgets update
- [ ] Notifications schedule and fire
- [ ] Calendar integration works
- [ ] Premium subscription check works (RevenueCat)
- [ ] Account deletion works
- [ ] Private mode / biometric unlock works

### Step 1.11: Update CI

Update the Flutter version in `.github/workflows/flutter-ci.yml`:

```yaml
- name: Setup Flutter
  uses: subosito/flutter-action@v2
  with:
    flutter-version: '3.44.2'  # or latest stable
    channel: 'stable'
    cache: true
```

### Step 1.12: Commit and Test

```bash
git add -A
git commit -m "chore: migrate to Firebase 6.x and built-in Kotlin"
git push origin feat/migrate-built-in-kotlin
```

Open a PR and verify CI passes on all platforms.

### Phase 1 Rollback Plan

If the build breaks or Firebase flows fail:

1. Revert `pubspec.yaml` changes
2. Revert `gradle.properties` (`android.builtInKotlin=false`, `android.newDsl=false`)
3. Revert `android/app/build.gradle` (re-add `kotlin-android` and `kotlinOptions`)
4. Run `flutter pub get`
5. Verify build works

---

# Phase 2: RevenueCat 10.x

RevenueCat 10.x is a major version with breaking API changes. Upgrade in a separate PR after Phase 1 is stable.

## Phase 2 Packages

| Package | Current | Target | Reason |
|---|---|---|---|
| `purchases_flutter` | `^9.12.0` | `^10.2.3` | Applies KGP; 10.x has breaking API changes |
| `purchases_ui_flutter` | `^9.12.0` | `^10.2.3` | Paywall UI API changes |

### Step 2.1: Create a Branch

```bash
git checkout -b feat/upgrade-revenuecat-10
```

### Step 2.2: Upgrade RevenueCat Packages

```bash
flutter pub upgrade purchases_flutter purchases_ui_flutter --major-versions
```

Or manually in `pubspec.yaml`:

```yaml
dependencies:
  purchases_flutter: ^10.2.3
  purchases_ui_flutter: ^10.2.3
```

### Step 2.3: Check for Breaking API Changes

#### purchases_flutter 10.x Changes

Review and update `lib/core/services/subscription_service.dart`:

- **Check**: `Purchases.sharedInstance` → may have changed initialization
- **Check**: `getCustomerInfo()`, `getOfferings()` → verify return types
- **Check**: `logIn()`, `logOut()` → verify signature
- **Check**: `purchasePackage()`, `restorePurchases()` → verify callback types
- **Check**: Entitlement checking (`customerInfo.entitlements.active`) → verify API

#### purchases_ui_flutter 10.x Changes

Review and update `lib/features/premium/presentation/screens/paywall_screen.dart`:

- **Check**: `RevenueCatUI.presentPaywall()` → verify parameters
- **Check**: Paywall delegate callbacks → verify types
- **Check**: `PaywallFooter`, `PaywallWall` widgets → verify API

### Step 2.4: Verify Build

```bash
flutter build apk --debug
flutter test
flutter analyze
```

### Step 2.5: Manual Testing Checklist

- [ ] Paywall screen displays correctly
- [ ] Subscription purchase flow works (sandbox)
- [ ] Restore purchases works
- [ ] Premium entitlement unlocks Pro features
- [ ] Account deletion handles subscription cleanup
- [ ] Subscription state syncs across sign-in/sign-out
- [ ] Customer Center opens (if using)

### Step 2.6: Commit

```bash
git add -A
git commit -m "chore: upgrade RevenueCat to 10.x"
git push origin feat/upgrade-revenuecat-10
```

### Phase 2 Rollback Plan

1. Revert `pubspec.yaml` changes
2. Revert any API changes in `subscription_service.dart` and `paywall_screen.dart`
3. Run `flutter pub get`
4. Verify subscription flows work with old version

---

# Phase 3: Remaining Packages

These packages either apply KGP or have newer versions available. Upgrade in a single PR after Phase 1 and 2 are stable.

## Phase 3 Packages

| Package | Current | Target | KGP? | Notes |
|---|---|---|---|---|
| `flutter_timezone` | `^3.0.1` | `^5.1.0` | Yes | Listed in warning |
| `home_widget` | `^0.8.1` | `^0.9.3` | Yes | Listed in warning |
| `connectivity_plus` | `^6.1.2` | `^7.1.1` | Likely | — |
| `local_auth` | `^2.1.8` | `^3.0.1` | Likely | Biometric API changes |
| `google_sign_in` | `^6.2.2` | `^7.2.0` | Likely | Breaking auth flow changes |
| `fl_chart` | `^0.70.2` | `^1.2.0` | No | Major chart API rewrite |
| `flutter_dotenv` | `^5.1.0` | `^6.0.1` | No | — |
| `flutter_local_notifications` | `^19.5.0` | `^22.0.0` | No | Large version jump |
| `flutter_launcher_icons` | `^0.13.1` | `^0.14.4` | No | dev_dependency |

### Step 3.1: Create a Branch

```bash
git checkout -b feat/upgrade-remaining-packages
```

### Step 3.2: Upgrade Packages

Upgrade in groups by risk level. Start with the safest:

```bash
# Low risk — minor/patch bumps
flutter pub upgrade flutter_dotenv flutter_launcher_icons

# Medium risk — major bumps with likely stable APIs
flutter pub upgrade connectivity_plus home_widget flutter_timezone

# Higher risk — breaking API changes
flutter pub upgrade local_auth google_sign_in fl_chart flutter_local_notifications
```

Or edit `pubspec.yaml` manually and run `flutter pub get`.

### Step 3.3: Check for Breaking API Changes

#### flutter_timezone 5.x

- `FlutterTimezone.getLocalTimezone()` — verify still works
- `tz.initializeTimeZones()` — no change expected

#### home_widget 0.9.x

- `HomeWidget.saveWidgetData()`, `HomeWidget.getWidgetData()` — verify API
- `HomeWidget.updateWidget()` — verify parameters
- `HomeWidget.registerInteractivityCallback()` — verify signature
- Review `android/app/src/main/kotlin/.../FullCalendarWidgetProvider.kt` for any API changes

#### connectivity_plus 7.x

- `Connectivity().onConnectivityChanged` — verify stream API

#### local_auth 3.x

- `LocalAuthentication().authenticate()` — verify `AuthenticationOptions`
- `LocalAuthentication().canCheckBiometrics` — verify

#### google_sign_in 7.x

- `GoogleSignIn().signIn()` — verify return type
- `GoogleSignInAuthentication` — verify properties
- `GoogleSignIn().signInSilently()` — verify
- Review `lib/core/services/auth_service.dart` thoroughly

#### fl_chart 1.x

- **Major rewrite** from 0.x to 1.x
- `LineChart`, `BarChart`, `PieChart` — all widget APIs changed
- `FlGridData`, `FlTitlesData`, `FlBorderData` — configuration API changed
- Review `lib/features/analytics/` and any chart widgets

#### flutter_local_notifications 22.x

- `FlutterLocalNotificationsPlugin()` — verify initialization
- `show()`, `zonedSchedule()` — verify parameters
- `AndroidInitializationSettings`, `IOSInitializationSettings` — verify
- Review `lib/core/services/notification_service.dart`

#### flutter_dotenv 6.x

- `dotenv.load()` — verify API
- `env['KEY']` — verify access pattern

### Step 3.4: Verify Build and Tests

```bash
flutter build apk --debug
flutter test
flutter analyze
```

### Step 3.5: Manual Testing Checklist

- [ ] Calendar widget updates and switches months quickly
- [ ] Home screen tasks widget works
- [ ] Connectivity-dependent features work (sync, online-only flows)
- [ ] Biometric unlock works (fingerprint/face)
- [ ] Google Sign-In works
- [ ] Charts render correctly (analytics/insights)
- [ ] Environment variables load from `.env`
- [ ] Notifications schedule and fire correctly
- [ ] Notification actions (complete, snooze) work

### Step 3.6: Commit

```bash
git add -A
git commit -m "chore: upgrade remaining packages to latest major versions"
git push origin feat/upgrade-remaining-packages
```

### Phase 3 Rollback Plan

1. Revert `pubspec.yaml` changes per-package if specific upgrades cause issues
2. Revert any API changes in affected service files
3. Run `flutter pub get`
4. Verify affected flows work

---

# General Notes

- **Dependency overrides**: The `dependency_overrides` for `timezone: ^0.10.1`, `sqflite: ^2.4.2+1`, and `sqflite_android: ^2.4.2+3` should be reviewed after all phases — they may no longer be needed once packages are upgraded.
- **`flutterfire configure`**: After upgrading Firebase packages, run `flutterfire configure` to regenerate `lib/firebase_options.dart` and `lib/firebase_schedule_options.dart` if the output format changed.
- **Code generation**: Run `dart run build_runner build --delete-conflicting-outputs` after each phase to regenerate Hive adapters and any other generated code.
- **Gradle wrapper**: If you encounter Gradle version conflicts, check `android/gradle/wrapper/gradle-wrapper.properties` — the Gradle version may need updating to be compatible with AGP 9.x.

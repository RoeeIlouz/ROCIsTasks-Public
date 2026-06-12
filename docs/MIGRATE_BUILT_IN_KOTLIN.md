# Migrate to Built-in Kotlin

Flutter 3.44+ warns that plugins applying the Kotlin Gradle Plugin (KGP) will break future builds. This guide walks through upgrading every affected package and enabling built-in Kotlin.

## Why This Is Needed

AGP 9.0+ includes Kotlin support built-in. Plugins that apply `kotlin-android` in their own Gradle files conflict with this. The current workaround (`android.builtInKotlin=false` in `gradle.properties`) suppresses the error but will be removed in a future Flutter release.

## Packages Requiring Upgrade

| Package | Current | Target | Reason |
|---|---|---|---|
| `firebase_core` | `^3.6.0` | `^4.10.0` | Applies KGP; Firebase 4.x supports built-in Kotlin |
| `cloud_firestore` | `^5.4.4` | `^6.5.0` | Applies KGP; part of Firebase 4.x wave |
| `firebase_auth` | `^5.3.4` | `^6.5.0` | Applies KGP; part of Firebase 4.x wave |
| `firebase_crashlytics` | `^4.1.3` | `^5.2.0` | Applies KGP; part of Firebase 4.x wave |
| `firebase_analytics` | `^11.3.3` | `^12.4.0` | Applies KGP; part of Firebase 4.x wave |
| `firebase_performance` | `^0.10.1` | `^0.11.4` | Applies KGP |
| `firebase_remote_config` | `^5.5.0` | `^6.5.0` | Applies KGP; part of Firebase 4.x wave |
| `device_info_plus` | `11.1.0` | `^13.1.0` | Applies KGP |

## Step-by-Step Migration

### Step 1: Create a Branch

```bash
git checkout -b feat/migrate-built-in-kotlin
```

### Step 2: Upgrade Firebase Packages

Update all Firebase packages together — they must be on matching major versions.

```bash
flutter pub upgrade firebase_core cloud_firestore firebase_auth firebase_crashlytics firebase_analytics firebase_performance firebase_remote_config --major-versions
```

If `flutter pub upgrade --major-versions` doesn't resolve cleanly, manually edit `pubspec.yaml`:

```yaml
dependencies:
  firebase_core: ^4.10.0
  cloud_firestore: ^6.5.0
  firebase_auth: ^6.5.0
  firebase_crashlytics: ^5.2.0
  firebase_analytics: ^12.4.0
  firebase_performance: ^0.11.4
  firebase_remote_config: ^6.5.0
```

Then run:

```bash
flutter pub get
```

### Step 3: Upgrade device_info_plus

```bash
flutter pub upgrade device_info_plus --major-versions
```

Or manually in `pubspec.yaml`:

```yaml
dependencies:
  device_info_plus: ^13.1.0
```

### Step 4: Check for Breaking API Changes

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

### Step 5: Enable Built-in Kotlin

Once all packages compile without KGP errors:

1. **Edit `android/gradle.properties`**:

```properties
org.gradle.jvmargs=-Xmx8G -XX:MaxMetaspaceSize=4G -XX:ReservedCodeCacheSize=512m -XX:+HeapDumpOnOutOfMemoryError
android.useAndroidX=true
android.builtInKotlin=true
```

Remove the line:
```
android.newDsl=false
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

### Step 6: Regenerate Code

```bash
dart run build_runner build --delete-conflicting-outputs
```

### Step 7: Regenerate Firebase Config (if needed)

If `flutterfire configure` output format changed:

```bash
flutterfire configure
```

This regenerates `lib/firebase_options.dart` and `lib/firebase_schedule_options.dart`.

### Step 8: Verify Build

```bash
# Debug build
flutter build apk --debug

# Release build (Android)
flutter build appbundle --release

# Web build (if applicable)
flutter build web
```

### Step 9: Run Tests

```bash
flutter test
flutter analyze
```

### Step 10: Manual Testing Checklist

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

### Step 11: Update CI

Update the Flutter version in `.github/workflows/flutter-ci.yml`:

```yaml
- name: Setup Flutter
  uses: subosito/flutter-action@v2
  with:
    flutter-version: '3.44.2'  # or latest stable
    channel: 'stable'
    cache: true
```

### Step 12: Commit and Test

```bash
git add -A
git commit -m "chore: migrate to Firebase 6.x and built-in Kotlin"
git push origin feat/migrate-built-in-kotlin
```

Open a PR and verify CI passes on all platforms.

## Rollback Plan

If the build breaks or Firebase flows fail:

1. Revert `pubspec.yaml` changes
2. Revert `gradle.properties` (`android.builtInKotlin=false`, `android.newDsl=false`)
3. Revert `android/app/build.gradle` (re-add `kotlin-android` and `kotlinOptions`)
4. Run `flutter pub get`
5. Verify build works

## Notes

- **RevenueCat** (`purchases_flutter: ^9.12.0`) is **not** part of this migration. It does not apply KGP. Upgrade separately when ready (10.x has breaking API changes).
- **Other plugins** listed in the warning (`device_calendar`, `dynamic_color`, `flutter_timezone`, `home_widget`, `purchases_flutter`, `purchases_ui_flutter`) — check their changelogs. Most should have newer versions that don't apply KGP once the Firebase packages are upgraded. If any still apply KGP after upgrading, report the issue to the plugin author.
- The `dependency_overrides` for `timezone` and `sqflite` should be reviewed after the migration — they may no longer be needed.

# Setup & Development Guide

Follow these steps to set up the **ROCIs Tasks** development environment and configure the backend dependencies on your machine.

---

## 📋 Prerequisites

- **Flutter SDK**: [Install Flutter](https://flutter.dev/docs/get-started/install) (Ensure version complies with `pubspec.yaml` environment SDK: `^3.10.0`).
- **Dart SDK**: Included with the Flutter installation.
- **Editor**: VS Code (recommended with Flutter/Dart extensions) or Android Studio.
- **Firebase Account**: Required for Authentication, Firestore database, Analytics, and Performance monitoring.
- **RevenueCat Account**: Required for managing Pro subscriptions.

---

## 🛠️ Installation & Code Generation

1. **Clone the Repository**:
   ```bash
   git clone <repository-url>
   cd rocis_tasks
   ```

2. **Retrieve Package Dependencies**:
   ```bash
   flutter pub get
   ```

3. **Hive Database Code Generation**:
   This project uses `hive_generator` to compile data storage adapters. Run the build runner command:
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

---

## 🔑 Environment & API Key Configuration

The project relies on external credentials for payment processing and database connections. These are kept out of version control for security.

1. **Copy Settings Templates**:
   ```bash
   cp .env.example .env
   cp lib/firebase_options.dart.example lib/firebase_options.dart
   cp lib/firebase_schedule_options.dart.example lib/firebase_schedule_options.dart
   ```

2. **Configure Environment Variables (`.env`)**:
   Open the `.env` file and populate your RevenueCat credentials:
   ```properties
   REVENUECAT_API_KEY_ANDROID=goog_your_android_api_key
   REVENUECAT_API_KEY_IOS=appl_your_ios_api_key
   ```

---

## 🔥 Firebase Configuration

The app integrates with Firebase using two separate connection profiles:
- **Default Connection**: Main database for user auth, tasks, categories, and analytics.
- **Secondary Connection**: Integrates with the `ROCIs-Schedule` system to pull academic schedules.

### Step 1: Default Firebase Setup
Configure the platforms and download the platform-specific files (`google-services.json` / `GoogleService-Info.plist`) by executing:
```bash
flutterfire configure
```
Follow the interactive prompt to associate the platforms with your Firebase project. This will regenerate the file `lib/firebase_options.dart`.

### Step 2: Secondary Firebase Setup
Edit the file `lib/firebase_schedule_options.dart` and populate the `FirebaseOptions` structures with the credentials corresponding to your secondary `rocis-schedule` Firestore project.

### Step 3: Enable Services in Firebase Console
1. **Authentication**: Enable **Google Sign-In** and **Email/Password** authentication.
2. **Firestore Database**: Initialize Firestore and apply the security rules defined in `firestore.rules`.
3. **Storage**: Enable Firebase Storage for task attachment uploads.

---

## 🏃‍♂️ Running the App

- **Debug Mode**:
  ```bash
  flutter run
  ```
- **Profile / Release Mode**:
  ```bash
  flutter run --release
  ```
  *(Note: Release compilation runs tree-shaking and obfuscation (R8). If you modify model serialization, verify `android/app/proguard-rules.pro` to prevent runtime crashes).*

---

## 🧪 Testing & Code Quality Audits

Run the unit and widget test suite:
```bash
flutter test
```

### Validation Checklists (Antigravity Kit)
The repository is bundled with automated checklist scripts to enforce code styling, dependency checkups, and security guidelines:

```bash
# Run incremental validation checks (Security Scan, Lint Check, Schema, Tests, UX, SEO)
python .agent/scripts/checklist.py .

# Run comprehensive release validation checks (Checklist + Lighthouse, E2E Playwright, Mobile Audit)
python .agent/scripts/verify_all.py . --url <local-server-url>
```

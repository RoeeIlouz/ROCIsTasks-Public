# Setup & Development Guide

Follow these steps to set up the **Roci's Tasks** development environment on your machine.

## Prerequisites

- **Flutter SDK**: [Install Flutter](https://flutter.dev/docs/get-started/install) (Ensure version complies with `pubspec.yaml` environment sdk: `^3.10.0`).
- **Dart SDK**: Included with Flutter.
- **Editor**: VS Code (recommended) or Android Studio.
- **Firebase Account**: Required for backend services.

## 🛠️ Installation

1.  **Clone the Repository**:

    ```bash
    git clone <repository-url>
    cd rocis_tasks
    ```

2.  **Install Dependencies**:

    ```bash
    flutter pub get
    ```

3.  **Code Generation**:
    This project uses `hive_generator` for database adapters. If you encounter errors about missing adapters (like `TaskAdapter`), run:
    ```bash
    dart run build_runner build --delete-conflicting-outputs
    ```

## 🔥 Firebase Configuration

The app relies on Firebase Auth and Firestore.

1.  **Install Firebase CLI**:

    ```bash
    npm install -g firebase-tools
    firebase login
    ```

2.  **Configure Project**:
    Run the FlutterFire CLI to generate the necessary configuration files (`google-services.json` for Android, `GoogleService-Info.plist` for iOS, and `firebase_options.dart`).

    ```bash
    flutterfire configure
    ```

    - Select your Firebase project.
    - Select the platforms (Android, iOS) you want to support.

3.  **Enable Services in Firebase Console**:
    - **Authentication**: Enable **Google Sign-In**.
    - **Firestore Database**: Create a database and set appropriate security rules.

## 🔑 Calendar API Setup

For Google Calendar synchronization to work on Android (via `device_calendar`):

1.  Ideally, this uses the on-device calendar store. Ensure your Android Emulator or Real Device is signed in with a Google Account that has a calendar.
2.  Permissions are handled by the `permission_handler` package.

## 🏃‍♂️ Running the App

- **Debug Mode**:
  ```bash
  flutter run
  ```
- **Profile/Release**:
  ```bash
  flutter run --release
  ```
  _(Note: Release builds invoke code shrinking (R8). If implementing complex reflection, check `android/app/proguard-rules.pro`)_.

## 🧪 Testing

Run unit and widget tests:

```bash
flutter test
```

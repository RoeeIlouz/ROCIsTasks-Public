# Roci's Tasks

**Roci's Tasks** is a modern, feature-rich task management application built with Flutter. It combines robust task tracking with seamless calendar integration, real-time synchronization, and native Android home screen widgets to help you stay organized.

## ✨ Key Features

- **🔐 Authentication**
  - Secure Google Sign-In integration.
  - Persistent session management.

- **✅ Task Management**
  - **CRUD Operations**: Create, read, update, and delete tasks easily.
  - **Organization**: Prioritize tasks (High, Medium, Low) and organize them by due dates.
  - **Synchronization**: Real-time sync between local storage (Hive) and the cloud (Firebase Firestore). Offline-first support ensures data availability anytime.

- **📅 Calendar Integration**
  - **Unified View**: See your tasks alongside your Google Calendar events in a single interface.
  - **Device Sync**: Seamlessly reads events from your device's native calendar.

- **📱 Android Home Screen Widgets**
  - **Interactive Widgets**: View and complete tasks directly from your home screen without opening the app.
  - **Background Updates**: Instant state synchronization between the widget and the main application.

- **🎨 Modern UI/UX**
  - **Material You**: Dynamic color themes derived from your device's wallpaper (Android).
  - **Dark Mode**: Fully supported, eye-friendly dark theme.
  - **Localization**: Support for English and Hebrew.

## 🏗️ Architecture

Roci's Tasks follows a **Feature-First Clean Architecture** to ensure scalability and maintainability.

- **State Management**: Uses `Provider` for dependency injection and state management.
- **Data Layer**: A hybrid approach using **Hive** for local persistence/caching and **Firebase Firestore** as the remote source of truth.
- **Feature Modules**: Code is organized by features (Auth, Tasks, Calendar, Home) with clear separation of concerns (Domain, Data, Presentation layers).

For a deep dive into the system design, check out [ARCHITECTURE.md](docs/ARCHITECTURE.md).

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) (^3.10.0)
- A Firebase project with Authentication (Google) and Firestore enabled.

### Installation

1.  **Clone the repository**:
    ```bash
    git clone https://github.com/yourusername/rocis-tasks.git
    cd rocis_tasks
    ```

2.  **Install dependencies**:
    ```bash
    flutter pub get
    ```

3.  **Generate code adapters** (required for Hive database):
    ```bash
    dart run build_runner build --delete-conflicting-outputs
    ```

### Configuration

1.  **Environment Setup**:
    Copy the example environment file and fill in your details:
    ```bash
    cp .env.example .env
    ```

2.  **Firebase Setup**:
    Use the FlutterFire CLI to configure your app:
    ```bash
    flutterfire configure
    ```
    This will generate the necessary `firebase_options.dart` and platform-specific configuration files.

For detailed setup instructions, please refer to [SETUP.md](docs/SETUP.md).

## 📦 Deployment

This project includes a comprehensive guide for deploying to Android, iOS, and Web.
See [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) for instructions on signing, building release binaries, and configuring Firebase for production.

## 🧪 Testing

To run the test suite:

```bash
flutter test
```

## 📂 Project Structure

```
lib/
├── core/                   # Shared resources (Theme, Config, Services)
├── features/               # Feature modules
│   ├── auth/               # Authentication logic & UI
│   ├── calendar/           # Calendar integration
│   ├── home/               # Home screen container
│   └── tasks/              # Task management (Clean Arch layers)
├── l10n/                   # Localization files
└── main.dart               # App entry point
```

## 📄 License

This project is intended for private use.
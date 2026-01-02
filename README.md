# Roci's Tasks

**Roci's Tasks** is a comprehensive task management application built with Flutter. It is designed to help users organize their life by combining task management with seamless calendar integration, all wrapped in a beautiful Material You interface that adapts to your device's theme.

## 🚀 Key Features

- **Task Management**: Create, edit, prioritize, and complete tasks.
- **Calendar Integration**:
  - View your schedule with a monthly calendar view.
  - **Google Calendar Sync**: Automatically fetch and display events from your Google Calendar.
- **Home Screen Widgets**:
  - Stay updated with interactive Android home screen widgets.
  - View tasks and calendar events directly from your home screen.
  - Mark tasks as complete from the widget without opening the app.
- **Smart Features**:
  - **Soft Delete**: Tasks are moved to a "bin" first, allowing for restoration.
  - **Prioritization**: Organize tasks by priority (High, Medium, Low).
- **Design**:
  - **Material You**: Fully supports Android 12+ dynamic colors, adapting the app's theme to your wallpaper.
  - Dark and Light mode support.
- **Cloud & Offline**:
  - **Firebase Sync**: Data is synced securely using Firebase Firestore.
  - **Local Caching**: Uses Hive for fast local data access and offline capability.

## 📚 Documentation

For more detailed information, check out the documentation in the `docs` folder:

- [**Setup Guide**](docs/SETUP.md): Instructions on how to build and run the app.
- [**Architecture**](docs/ARCHITECTURE.md): An overview of the codebase structure and technical choices.
- [**Features**](docs/FEATURES.md): Detailed breakdown of application features.

## 🛠️ Tech Stack

- **Framework**: [Flutter](https://flutter.dev/)
- **Language**: Dart
- **State Management**: [Provider](https://pub.dev/packages/provider)
- **Backend**: [Firebase](https://firebase.google.com/) (Auth, Firestore)
- **Local Database**: [Hive](https://docs.hivedb.dev/)
- **Widgets**: [home_widget](https://pub.dev/packages/home_widget)
- **Calendar**: [device_calendar](https://pub.dev/packages/device_calendar), [table_calendar](https://pub.dev/packages/table_calendar)

## 📄 License

[Add License Here]

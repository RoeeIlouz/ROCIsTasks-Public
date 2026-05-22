# Architecture & Technical Overview

Roci's Tasks follows a **Feature-First Clean Architecture** approach. This ensures separation of concerns, scalability, and maintainability.

## 📂 Project Structure

The code is organized primarily by **features** within the `lib/features` directory. Each feature contains its own layers (`data`, `domain`, `presentation`). Shared resources are located in `lib/core`.

```
lib/
├── core/                   # Shared resources
│   ├── services/           # Global services (Auth, Calendar, etc.)
│   └── theme/              # App theming and styling logic
├── features/               # Feature modules
│   ├── analytics/          # Productivity charts and insights
│   ├── auth/               # Authentication (Login, User Session)
│   ├── calendar/           # Calendar view and logic
│   ├── home/               # Home screen container
│   └── tasks/              # Task management (Create, Read, Update, Delete)
│       ├── data/           # Repositories, Models (DTOs), Data Sources
│       ├── domain/         # Entities, Use Cases, Repository Interfaces
│       └── presentation/   # Widgets, Screens, Providers (State)
├── main.dart               # App entry point, DI setup
└── firebase_options.dart   # Firebase configuration
```

## 🏗️ Architectural Layers

For complex features like `tasks`, we use a layered approach:

1.  **Domain Layer** (`domain/`):

    - Contains business logic and entities (e.g., `Task` model).
    - Defines Repository interfaces (contracts) for data operations.
    - Pure Dart code, independent of Flutter or external libraries where possible.

2.  **Data Layer** (`data/`):

    - Implements the Domain interfaces.
    - Handles data retrieval from sources (Firebase Firestore, Hive).
    - Converts between Data Models (JSON/Hive) and Domain Entities.

3.  **Presentation Layer** (`presentation/`):
    - **Screens/Widgets**: The UI components.
    - **Providers**: State management using `ChangeNotifier`. They interact with Domain/Data layers to fetch data and notify the UI.

## 🧩 State Management

The app uses the **Provider** package for state management and Dependency Injection.

- **Service & Repository Injection**: created at the root in `main.dart` and provided via `MultiProvider`.
- **UI State**: Features expose specific providers (e.g., `TaskProvider`, `CalendarProvider`) which extend `ChangeNotifier`.
- **Reactive**: UI widgets listen to these providers using `Consumer` or `context.watch<T>()` to rebuild on state changes.

## 💾 Data Strategy

The app employs a **Local-First / Sync** strategy (or Hybrid):

- **Firebase Firestore**: Acts as the single source of truth for cloud storage and multi-device sync.
- **Hive**: Used for local persistence and caching. This allows the app to work offline and load data instantly on startup. The background widget service also relies on Hive to read task data without launching the full Flutter engine UI.

## 🤖 Background Services & Widgets

- **HomeWidget**: The app integrates with Android home screen widgets.
- **WorkManager / Background Isolate**:
  - `interactiveCallback` in `main.dart` handles actions triggered from the widget (e.g., completing a task).
  - Since background isolates don't share memory with the main app, `Hive` is re-initialized in the background to access and update task data.

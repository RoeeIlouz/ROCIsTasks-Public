# Architecture & Technical Overview

ROCIs Tasks is built using a **Feature-First Clean Architecture** approach. This guarantees clean separation of concerns, decouples business logic from external frameworks, and ensures high developer velocity, testability, and stability.

---

## 📂 Directory Structure

The codebase is organized by cohesive features under `lib/features` and shared capabilities under `lib/core`.

```plaintext
lib/
├── core/
│   ├── config/             # System configuration (AppConfig, Router, Firebase Options)
│   ├── models/             # Core shared domain models
│   ├── services/           # Global services (Auth, Calendar, Storage, Notifications)
│   └── theme/              # Typography (Outfit), dark/AMOLED themes, and Glassmorphism specifications
├── features/
│   ├── analytics/          # Productivity trend lines and category distribution charts
│   ├── auth/               # Google & secondary Email/Password login flows
│   ├── calendar/           # Samsung-style table agenda & device calendar mapping
│   ├── categories/         # Category CRUD & limit gating (5 free max)
│   ├── home/               # Navigation container, bottom bar, and bouncy eggs
│   ├── onboarding/         # swipeable PageView onboarding carousel & guards
│   ├── premium/            # RevenueCat paywalls and PRO lock indicators
│   └── tasks/              # Task CRUD, nested subtask checklists, and attachments
│       ├── data/           # Repositories, models (DTOs), and Hive/Firestore data sources
│       ├── domain/         # Entities, use cases, and repository interfaces
│       └── presentation/   # UI widgets, screens, and Provider state wrappers
├── l10n/                   # System localization translation templates (EN, HE, ES)
└── main.dart               # App initialization entry point
```

---

## 🏗️ Architectural Layers

For core feature modules like `tasks`, development is strictly separated into three layers:

```
┌────────────────────────────────────────────────────────┐
│                   Presentation Layer                   │
│         (UI Widgets, Screens, State Providers)          │
└──────────────────────────┬─────────────────────────────┘
                           ▼
┌────────────────────────────────────────────────────────┐
│                      Domain Layer                      │
│        (Pure Dart Entities, Repository Interfaces)     │
└──────────────────────────┬─────────────────────────────┘
                           ▼
┌────────────────────────────────────────────────────────┐
│                       Data Layer                       │
│    (Repository Implementations, DB Sources, API/DTOs)  │
└────────────────────────────────────────────────────────┘
```

1. **Domain Layer** (`domain/`):
   - Contains raw business entities (e.g., `Task` model) and rules.
   - Defines interfaces (contracts) for repositories.
   - Contains zero dependencies on Flutter, local storage libraries, or network clients.

2. **Data Layer** (`data/`):
   - Implements Domain repository interfaces.
   - Manages retrieval, mutation, and syncing between local database sources (**Hive**) and cloud databases (**Firebase Firestore**).
   - Converts between Data transfer objects (DTOs) and Domain entities.

3. **Presentation Layer** (`presentation/`):
   - **Widgets/Screens**: Reusable visual components styled with the custom glassmorphism design system.
   - **State Providers**: Implementations of `ChangeNotifier` that coordinate business use cases and state, notifying the UI to rebuild on changes.

---

## 🧩 State Management & DI

- **Dependency Injection**: Services and repositories are initialized at startup in `main.dart` and injected throughout the widget tree using a root-level `MultiProvider`.
- **Reactive UI**: Components consume providers using `context.watch<T>()` or `Selector<T, V>` to isolate rebuild triggers and maximize scrolling frame rates.

---

## 💾 Local-First Synchronization Strategy

The application leverages a hybrid **Offline-First Caching** model:
- **Write Path**: Task creation, updates, and completions are committed instantly to the local **Hive** box, ensuring zero UI latency. The update is then asynchronously synchronized to **Firebase Firestore**.
- **Read Path**: The app loads initially from Hive cache, showing task lists instantly. It then listens to Firestore streams to pull down external changes and resolve conflicts.
- **Offline Resilience**: When internet access is lost, transactions are held locally. Upon reconnection, the sync manager pushes local changes back to the cloud.

---

## 📱 Interactive Widget & Background Engine

The Android home screen widget integration utilizes a hybrid Kotlin-Dart bridge to guarantee zero lag:

1. **Native Kotlin Interactivity** (`FullCalendarWidgetProvider`):
   - Actions like calendar month navigation (`Prev`/`Next`/`Today`) are handled natively on the Android side in Kotlin. 
   - Kotlin modifies and saves the navigation offset state in the shared widget SharedPreferences *before* invoking the Dart isolate. This prevents double-incrementing state and rendering delay.

2. **Background Dart Isolate** (`BackgroundHandler`):
   - Interactivity callbacks spawn a background Dart isolate.
   - The isolate initializes a lightweight database instance (Hive) to read task data, processes changes (e.g. marking a task complete), updates Firestore, and triggers a widget redrawing command.
   - **Isolate Protection**: To prevent background execution freezes, platform channel queries (such as timezone queries via `FlutterTimezone`) are strictly throttled with a 2-second timeout.

---

## 💰 Monetization & RevenueCat Configuration

ROCIs Tasks employs a hybrid freemium model managed securely through **RevenueCat** (`purchases_flutter`):
- **Free Limits**: Free users are limited to 5 categories, 1 basic widget type, no subtask lists, and no task attachments.
- **Entitlements**: Entitlements are validated reactively via `SubscriptionService`.
- **Lock System**: The app uses visual `PRO` badges and locks in settings and creation sheets. Attempting to access premium features triggers the sliding RevenueCat paywall interface dynamically.
- **Birthday Promo Override**: The system contains a built-in time-based promo override (June 16 to July 16) that unlocks full Pro features automatically without querying subscription stores during the promotional month.

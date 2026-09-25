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
- **Read Path**: The app loads initially from Hive cache, showing task lists instantly. It then listens to Firestore streams to pull down external changes.
- **Conflicts**: last write wins on `Task.modifiedAt`; permanent deletes are `isPurged` tombstones so every device learns about them ([ADR-001](architecture/adr-001-last-write-wins-sync.md)).
- **Offline Resilience**: When internet access is lost, transactions are held locally. Upon reconnection, the sync manager pushes local changes back to the cloud.

---

## 📱 Home Screen Widgets

Eight native **RemoteViews** widgets (Kotlin) render data that Dart writes to the `home_widget` SharedPreferences:

1. **Shared design system** (`WidgetStyle.kt`): the app's palette (synced by `MyApp._syncWidgetTheme`), tinted white drawables, system font families, RTL, localized priorities and the shared free-tier overlay. Layout XML carries default tints so launcher previews render ([ADR-004](architecture/adr-004-widget-design-system.md)).
2. **Native navigation state**: month/day navigation is handled in Kotlin, which saves the offset *before* notifying Dart (prevents double increments).
3. **Task completion runs in the app**: checkbox taps open `MainActivity`, the main engine completes the task through `TaskProvider`, then the app returns to the home screen. A second background engine must not write to Hive while the app is running ([ADR-003](architecture/adr-003-widget-actions-in-running-app.md)).
4. **Background isolate** (`BackgroundHandler`): read-only syncs (navigation, filters) run in a background Dart isolate; platform channel calls there use a 2-second timeout.
5. **Time formatting** follows the app's 12h/24h setting (`use_24h_format`); widgets redraw when app colors or platform brightness change.

---

## 💰 Monetization

- **Free limits**: 5 categories, 1 active home screen widget, no subtasks, recurrence, attachments or private mode.
- **Purchases**: Google Play subscriptions through **RevenueCat** on Android (yearly has a 7-day free trial); **Lemon Squeezy** checkout on web (monthly, yearly, lifetime).
- **Paywall**: every platform shows the app's own `PaywallScreen`, which names the feature that opened it and logs `paywall_shown` / `paywall_result` by source ([ADR-005](architecture/adr-005-in-app-paywall.md)).
- **Entitlements are server-side**: Cloud Functions (`lemonSqueezyWebhook`, `revenueCatWebhook`, `syncPremium`) compute `users/{uid}.is_premium`; Firestore rules forbid clients from writing billing fields ([ADR-002](architecture/adr-002-server-authoritative-premium.md)).
- **Birthday promo override**: a time-based promo (June 16 to July 16) unlocks Pro without querying the stores.
- **Store assets**: localized screenshots and listings are generated and uploaded by `tools/store-screenshots` ([ADR-006](architecture/adr-006-store-asset-pipeline.md)).


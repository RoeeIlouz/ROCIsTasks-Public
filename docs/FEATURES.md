# Features Deep Dive

This document outlines the core capabilities of Roci's Tasks and how they are implemented.

## 🔐 Authentication

_Implementation: `features/auth`_

- **Google Sign-In**: Users can sign in using their Google account. This is the primary method of authentication.
- **Session Management**: handled by `AuthService`. It persists the user session so users remain logged in across app restarts.
- **Protection**: The root widget (`MyApp`) uses a `StreamBuilder` on auth state to redirect unauthenticated users to the Login screen.

## ✅ Task Management

_Implementation: `features/tasks`_

Central to the application, the task system supports a robust workflow:

- **CRUD Operations**:
  - **Create**: Add tasks with Title, Description, Due Date/Time, and Priority.
  - **Update**: Modify any task detail.
  - **Delete**: Soft-delete tasks. They are moved to a "Bin" or marked as deleted rather than legally removed immediately (allowing for restore).
- **Organization**:
  - **Priority**: High, Medium, Low specific visual indicators.
  - **Date-based**: Tasks are sorted and grouped by their due dates.
- **Synchronization**:
  - Tasks are saved locally to **Hive** for instant access.
  - Changes are synced to **Firebase Firestore** real-time.

## 📅 Calendar Integration

_Implementation: `features/calendar`_

The calendar view is not just a date picker but a full agenda interface:

- **UI**: Built using `table_calendar`. It displays indicators (dots/markers) for days with generic events or tasks.
- **Google Calendar Sync**:
  - Uses `device_calendar` plugin to request permission and read events from the user's on-device calendars (which sync with Google/iCal).
  - Events from external calendars are displayed alongside app-specific tasks in the daily view.
- **Unified View**: Tapping a day shows a combined list of that day's Tasks (due that day) and Calendar Events.

## 📱 Home Screen Widgets

_Implementation: Android Native (XML) & `home_widget` package_

Roci's Tasks offers interactive widgets for the Android home screen:

- **Task List Widget**: Shows pending tasks. Users can scroll through the list and check off tasks directly from the home screen.
- **Mechanism**:
  - The Flutter app generates a data snapshot (JSON) and saves it to shared storage.
  - The Android widget reads this data to render the list.
  - Interactions (clicks) send a URI (e.g., `app://complete?id=123`) which the background Flutter isolate intercepts to update the database.

## 🎨 Theming & UI

_Implementation: `core/theme`_

- **Material You**: The app creates a custom `ColorScheme` derived from the user's OS wallaper (using `dynamic_color`).
- **Dark Mode**: Fully supported with a dedicated dark color scheme.
- **Customization**: Custom widget shapes and typography integration (Google Fonts) ensure a modern look.

## 📊 Productivity Analytics & Insights

_Implementation: `features/analytics`_

Helping users understand their work patterns and improve efficiency:

- **Insights Dashboard**: A dedicated tab for visualizing productivity metrics.
- **Completion Trends**: Line charts showing task completion volume over the last 7 days, helping identify peak productivity periods.
- **Category Distribution**: Pie charts visualizing the balance of effort across different categories (e.g., Work, Personal, Education).
- **Stat Summaries**: Instant visibility into total completed and pending tasks.
- **Historical Tracking**: Automatically records completion timestamps (`completedAt`) for all tasks to enable precise trend analysis.

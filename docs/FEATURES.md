# Features Deep Dive

This document outlines the core capabilities of **ROCIs Tasks** and details their design, interaction, and technical implementation.

---

## 🔐 Multi-Tiered Authentication

_Implementation: `lib/features/auth` and `lib/core/services/auth_service.dart`_

- **Primary Google Sign-In**: One-click authentication with Google.
- **Secondary Email & Password**: Secure email registration, sign-in, and password reset capability using Firebase Authentication.
- **Session Persistence**: Managed via `AuthService` using a reactive FirebaseAuth listener. It synchronizes automatically with `SubscriptionService` when user state changes.
- **Entry Guards**: The root router (`AppRouter`) uses route guards to intercept unauthenticated users and redirect them to the Auth flow.

---

## ✅ Task & Category Management

_Implementation: `lib/features/tasks` and `lib/features/categories`_

- **Core CRUD Operations**:
  - **Create / Update**: Add tasks with Title, Description, Due Date/Time, Priority class, Category, Subtasks checklist, and Attachments.
  - **Bin & Soft Delete**: Tasks are soft-deleted and placed in the "Bin" screen, where they can be restored or permanently cleared.
- **Task Organization**:
  - **Priority Indicators**: Red (High), Orange (Medium), and Green (Low) visual tags.
  - **Sorting & Filtering**: Filter list sheets by category, completion status, calendar origin, and sort chronologically.
- **Subtask Checklists**: Nest dynamic checklist items within any task. Progress is calculated as a completion ratio.
- **File Attachments**: Upload and link images or document files directly to tasks, stored securely in Firebase Storage.
- **Recurrence Logic**: Setup recurring schedules (daily, weekly, monthly) using rule definitions parsed via the `rrule` package.

---

## 📅 Calendar Integration

_Implementation: `lib/features/calendar` and `lib/core/services/calendar_service.dart`_

- **Unified Agenda View**: Built using `table_calendar`. Renders due tasks and Google Calendar events concurrently.
- **Device Calendar Sync**: Reads from device-native calendar accounts using the `device_calendar` plugin.
- **Day Markers**: Calendar cells display colored dots or markers indicating the combination of tasks and external events scheduled for that day.

---

## 📱 Interactive Home Screen Widgets

_Implementation: Android Native (`android/app/src/main/...`) & `home_widget` package_

ROCIs Tasks offers dynamic, interactive widgets for the Android home screen:
- **Task List Widget**: Interactive scrollable list of pending tasks. Users can check off tasks directly from the home screen.
- **Calendar Agenda Widget**: Shows a monthly calendar grid and schedule list.
- **Interactivity Engine**:
  - Tapping a task triggers a background broadcast intent (e.g. `complete?id=123`). The Dart `BackgroundHandler` isolate intercepts the intent, completes the task in Hive/Firestore, and refreshes the widget data snapshot.
  - **Native Navigation**: Calendar navigation offsets (Prev/Next/Today) are intercepted and adjusted natively in Kotlin on the Android side before calling Dart. This eliminates UI redraw delay and prevents state double-incrementing.

---

## 🎨 Premium UI & Theming System

_Implementation: `lib/core/theme` and `lib/shared/ui/ui_kit.dart`_

- **Premium Glassmorphism**: Frosted glass panels and dividers built using `GlassContainer`. Backdrop blur interpolation blends 12% tint in light mode and 18% tint in dark mode of the category or primary accent color.
- **Material You Dynamic Colors**: Extracts the Android wallpaper color palette using `dynamic_color` to generate a harmonious theme.
- **System Default Support**: Theme modes (ThemeMode.system, ThemeMode.light, ThemeMode.dark) transition automatically based on OS preferences.
- **Completion Haptics**:satisfying physical vibration responses on interactions (medium pulse for completing, light pulse for uncompleting), configurable in Settings.
- **Bouncy Animations**: Elastic bouncy spin animations triggered by double-tapping or long-pressing FABs and icons.

---

## 📊 Productivity Analytics & Insights

_Implementation: `lib/features/analytics`_

- **Completion Trends**: Staggered line charts (via `fl_chart`) plotting completed task counts over the last 7 days.
- **Category Balancing**: Pie charts illustrating effort distribution across different categories.
- **Historical Analysis**: Tracks completion timestamps (`completedAt`) for precise productivity measurements.

---

## 🚀 Interactive Onboarding Carousel

_Implementation: `lib/features/onboarding` and `lib/core/config/router.dart`_

- **Slide Walkthrough**: Sliding tutorial pages (`PageView`) introducing Smart Add NLP parsing, Calendar Sync, and Analytics Dashboards.
- **Navigation Guard**: Restricts entry to main app dashboard for first-time users until onboarding is completed, storing status inside Hive.

---

## 💰 Subscription Gating (PRO)

_Implementation: `lib/features/premium` and `lib/core/services/subscription_service.dart`_

- **RevenueCat Paywalls**: Integrates App Store and Play Store purchase flows via `purchases_flutter` and `purchases_ui_flutter`.
- **Gated Features**:
  - Gated widgets (limit 1 for free tier).
  - Gated categories (limit 5 for free tier).
  - Subtask checklists and attachments (Pro only).
- **Birthday Promo Waiver**: Unlocks full Pro entitlement for all users during the promo month of June 16 - July 16 automatically.

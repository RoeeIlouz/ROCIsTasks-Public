# ROCIs Tasks - Product Backlog & AI Execution Guides

## Architectural Overview & Constraints

This project strictly adheres to a **Feature-First Clean Architecture** layout strategy. Each feature must isolate its UI components (`presentation`), data providers/data sources/repositories (`data`), and business logic layers (`domain`/`providers`).

### Critical Safeguards across all tasks:

1. **No Leaky Paywalls:** Premium operations must check `subscriptionService.isPremium` before revealing views, handling premium logic paths, or parsing structural values.
2. **Persistence Integrity:** Do not alter local/cloud schemas, global Hive box definitions, or initialization routines during refactoring.
3. **Data Protection:** Maintain local encryption boundaries for locked identifiers; state maps must remain secure from global queries until validation success.

---

## Task 1: Biometric Authentication Integration (Fingerprint/FaceID)

- **Status:** New Feature (Premium-gated)
- **Target Files:** - `core/services/subscription_service.dart` (Gating checks)
  - `features/auth/presentation/screens/security_settings_screen.dart` (Configuration UI switch)
  - `features/tasks/presentation/widgets/task_unlock_dialog.dart` (New validation overlay modal)

### Implementation Requirements:

1. Integrate the `local_auth` library into your device verification layer.
2. Under the security configurations UI panel, introduce a biometric unlock switch. Ensure this option is fully disabled or presents the system `PaywallView` if `subscriptionService.isPremium` evaluates to false.
3. When activated, call local platform channels to request fingerprint/FaceID validation data. Gracefully fallback to the pre-existing fallback PIN unlock screen if biometrics fail or lack hardware compatibility.

### 🤖 AI Agent Execution Prompt:

> Review the guidelines inside `# Task 1: Biometric Authentication Integration` from the attached backlog. Implement the biometric activation switch and authentication validation overlay following our feature-first architectural patterns. Verify that the premium entitlement gating explicitly checks `subscriptionService.isPremium` before enabling the biometric settings toggle or processing hardware channels, and provide a clean fallback to the existing PIN validation screen if validation fails or hardware is missing. Do not touch any existing Hive box initialization logic.

---

## Task 2: Google Calendar Synchronization Visual Indicator

- **Status:** UI Polish (All Users)
- **Target Files:** - `features/tasks/presentation/widgets/task_tile.dart` (Primary task list item row view)
  - `features/tasks/domain/models/task_model.dart` (Verify existing parameters)

### Implementation Requirements:

1. Review the data model structure for items to locate the attribute or key string pointing to an upstream cloud item sync state (e.g., checking for a non-null `googleEventId`).
2. Modify the task card render widget layout to position a small, pixel-aligned Google icon badge asset alongside the main title string container or near existing metadata tags.
3. Keep layout impacts minimized; support standard dark/light visibility adaptation modes automatically without overriding theme constraints.

### 🤖 AI Agent Execution Prompt:

> Review the guidelines inside `# Task 2: Google Calendar Synchronization Visual Indicator` from the attached backlog. Update the task item card list row UI following our feature-first presentation architectural layout. Locate the data model parameter that specifies whether a task is linked to Google Calendar, and dynamically append a clean Google brand icon badge near the task title. Ensure the design seamlessly matches light/dark application layout themes and introduces zero changes to structural model fields or background syncing channels.

---

## Task 3: Interactive Google Calendar Upstream Sync Hook

- **Status:** New Logic Engine (Premium-gated)
- **Target Files:** - `features/calendar/data/services/google_calendar_sync_service.dart` (Or your active calendar synchronization service)
  - `features/tasks/domain/repositories/task_repository.dart`

### Implementation Requirements:

1. Inject an evaluation filter deep within the background synchronization handler that processes upstream events originating from the Google Calendar API.
2. **Trigger Constraint:** This hook logic must exit immediately without parsing text bounds unless `subscriptionService.isPremium` is evaluated as true.
3. If an upstream incoming event contains the text substring matches `(ROCIsTasks)` or `(RT)` inside its primary title label string:
   - Call the Google Calendar API to delete that particular event from the user's remote cloud calendar.
   - Instantly initialize and map a new standard local app task inside your repository layer, assigning its due date, completion deadline, and time attributes to copy the deleted calendar item boundaries exactly.

### 🤖 AI Agent Execution Prompt:

> Review the guidelines inside `# Task 3: Interactive Google Calendar Upstream Sync Hook` from the attached backlog. Implement the string intercept and automated upstream event substitution layer following our feature-first clean architecture data rules. Ensure that the text intercept loop (`(ROCIsTasks)` or `(RT)`) is completely wrapped within a premium entitlement constraint checking `subscriptionService.isPremium`. If verified, execute the deletion API request upstream and insert a corresponding task record into the local Hive store with exact matching deadline parameters.

---

## Task 4: Private/Locked Tasks Visibility Filters

- **Status:** Core Visibility Restriction Upgrade (Premium-gated)
- **Target Files:** - `features/tasks/presentation/screens/my_tasks_tab.dart` (Task list rendering)
  - `features/tasks/presentation/widgets/task_detail_view.dart` (Detail presentation layer)

### Implementation Requirements:

1. Modify the compilation adapter engine in the "My Tasks" view panel so that private or password-locked task cards populate the layout sequence normally rather than being skipped or filtered out.
2. For items flagged as locked/private:
   - Limit display fields exclusively to the main top-level string header property (`title`).
   - Hardcode visibility conditional structural masks that hide or strip down all description strings and subtask child nodes from memory initialization until authorization succeeds.
3. Bind an item gesture pointer onto the card row. Tapping a masked item must pop up an interactive authorization challenge dialog requiring biometric confirmation or PIN strings before exposing detail pages or underlying parameters.

### 🤖 AI Agent Execution Prompt:

> Review the guidelines inside `# Task 4: Private/Locked Tasks Visibility Filters` from the attached backlog. Implement the visibility mask updates following our feature-first architectural presentation patterns. Verify that the premium entitlement gating blocks task descriptions and subtask collections from rendering in the list row layout for locked tasks until a biometric or PIN verification resolves successfully. Ensure metadata properties are entirely protected from standard list rendering iterations before the user passes the challenge screen.

---

## Task 5: Document & Multimedia Attachments Base Feature

- **Status:** Subsystems Expansion (Premium-gated)
- **Target Files:** - `features/tasks/domain/models/task_model.dart` (Extend database serialization attributes)
  - `features/tasks/presentation/screens/task_edit_screen.dart` (UI interaction panel updates)

### Implementation Requirements:

1. Integrate file management picker APIs into the file edit and task entry view layers to manage paths for localized document attachments, pictures, or voice files.
2. Anchor the entry-point execution buttons cleanly in the presentation layout. Any interaction with the attachment option must run an entitlement sweep; if `subscriptionService.isPremium` reads false, halt workflow execution and push the `PaywallView` overlay.
3. Store path reference strings safely as an item extension attribute sequence inside the Hive database adapter without modifying previous fields or corrupting existing active document records.

### 🤖 AI Agent Execution Prompt:

> Review the guidelines inside `# Task 5: Document & Multimedia Attachments Base Feature` from the attached backlog. Introduce attachment pickup channels and model parameters following our feature-first clean data and serialization patterns. Secure the attachment interactive picker controls behind an active subscription check against `subscriptionService.isPremium`. Ensure file references append safely inside the target task models without introducing breaking changes to older local model adapters or cloud document structures.

---

## Task 6: Deprecate Task Recurrence System

- **Status:** Feature Removal
- **Target Files:** - `features/tasks/domain/models/task_model.dart` (Maintain data fallback integrity)
  - `features/tasks/presentation/screens/task_edit_screen.dart` (UI removal path)

### Implementation Requirements:

1. Locate and strip away any input selectors, repetition setting switches, period choices, or frequency option pickers from the task configuration and detail view views.
2. Wipe out matching interval calculation background logic engines, reminder notification triggers, or calendar tracking services built around repeating schedules.
3. **Preserve Constraints:** Keep model parameters and baseline type variables safe inside the active schema configuration to protect against broken references or casting errors when the engine opens older data rows. Simply block inputs or initialize them to pass `null` values on creation.

### 🤖 AI Agent Execution Prompt:

> Review the guidelines inside `# Task 6: Deprecate Task Recurrence System` from the attached backlog. Safe-remove recurrence selectors, dropdown items, and matching scheduling calculators from our presentation layer. Ensure that underlying data parameters are left intact inside the domain models as nullable definitions to completely isolate old serialization properties from breaking during database casting updates. Comment out or disable repeating background loops cleanly without mutating core operational entities.

---

## Task 7: Complete Elimination of the Insights Layout Layer

- **Status:** Feature & Tab Cleanup
- **Target Files:** - `features/home/presentation/screens/home_navigation_hub.dart` (Main application landing container)
  - Delete entire subdirectory: `features/analytics/` (Or equivalent chart/insight resource targets)

### Implementation Requirements:

1. Locate the master page frame scaffolding widget that holds global tab state configurations, navigation menu parameters, or active navigation panels.
2. Purge the specific row element corresponding to the "Insights" tab view from the icon arrangement collections.
3. Decrement indices appropriately across internal active view states, page list arrays, and route controllers. Safely erase the unneeded analytics presentation views and charting files to eliminate dead code footprints.

### 🤖 AI Agent Execution Prompt:

> Review the guidelines inside `# Task 7: Complete Elimination of the Insights Layout Layer` from the attached backlog. Cleanly remove the "Insights" navigation icon, target view routing, and corresponding page index entries from the central bottom bar navigation controller structure. Once layout references are cleanly eliminated, safely delete the unneeded dashboard views and components under the analytics feature module folder, ensuring no lingering or broken path statements remain anywhere in our application build tree.

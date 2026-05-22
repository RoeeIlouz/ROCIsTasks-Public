# **ROCIs Tasks \- Closed Beta Feedback Implementation Plan**

## **Overview**

This document contains highly targeted prompts and technical specifications designed for an AI developer assistant (such as Antigravity IDE) to implement the feedback from the Closed Beta. The instructions are structured strictly according to the project's **Feature-First Clean Architecture**, protecting the existing Hive cache synchronization, Firestore backend layers, and background isolate logic.

## **Task 1: System Theme Integration (System Default Theme Mode)**

| Architectural Dimension | Specification Details |
| :---- | :---- |
| **Feature Module** | Core UI & Theming Module |
| **Architecture Layer** | Presentation Layer / Theme Service Providers |
| **Files to Modify** | lib/core/theme/theme\_service.dart (or current application theme provider) lib/features/settings/presentation/screens/settings\_screen.dart lib/main.dart |

### **AI Prompt Instructions for IDE**

Task Description:  
Extend the theme management layer to support "System Default" alongside the manually selected Dark Mode and Light Mode options.

Technical Requirements:  
1\. Update ThemeProvider/ThemeService to handle full ThemeMode enums (ThemeMode.system, ThemeMode.light, ThemeMode.dark).  
2\. Persist the chosen configuration locally inside the application settings Hive box using an enum string value or an integer index representation.  
3\. In \`main.dart\`, ensure the root \`MaterialApp\` widget sets its \`themeMode\` dynamically based on the current reactive state exposed by the theme provider.  
4\. Modify the Settings Screen UI to replace the binary toggle with a unified dropdown menu or list-selection dialogue presenting three clear options: "System Default", "Light Mode", and "Dark Mode".  
5\. Ensure strict compatibility with the existing Material You \`dynamic\_color\` setup. When "System Default" is enabled, the color scheme must seamlessly transition between dark and light variants natively when the operating system theme alters.

CRITICAL PRESERVATION CONSTRAINT:  
\- DO NOT alter, overwrite, or remove any initialization code for Hive box configurations, custom adapter bindings, or encryption configurations.  
\- DO NOT break the existing wallpaper-derived dynamic coloring implementation; only govern the high-level application theme mode.

## **Task 2: Email & Password Authentication Integration**

| Architectural Dimension | Specification Details |
| :---- | :---- |
| **Feature Module** | lib/features/auth |
| **Architecture Layer** | Data Layer (Data Sources), Domain Layer (Repositories), Presentation Layer (Providers & UI) |
| **Files to Modify / Create** | lib/features/auth/data/repositories/auth\_repository\_impl.dart lib/features/auth/presentation/providers/auth\_provider.dart lib/features/auth/presentation/screens/login\_screen.dart Create: lib/features/auth/presentation/screens/register\_screen.dart |

### **AI Prompt Instructions for IDE**

Task Description:  
Incorporate secondary credential-based login capabilities (Email and Password Registration, Authentication, and Password Reset flows) utilizing Firebase Authentication, functioning cleanly side-by-side with the current primary Google Sign-In feature.

Technical Requirements:  
1\. Augment the Auth Repository Interface and Implementation with three mandatory asynchronous calls: \`signUpWithEmailAndPassword(String email, String password)\`, \`signInWithEmailAndPassword(String email, String password)\`, and \`sendPasswordResetEmail(String email)\`.  
2\. Funnel these authentication events cleanly into the active \`AuthService\` state stream so the overarching \`StreamBuilder\` within \`MyApp\` natively detects valid authentication session updates.  
3\. Enhance the \`LoginScreen\` UI layout to display dedicated text input fields for Email and Password. Incorporate full client-side form validation (standard regex for email structure, length thresholds for password inputs). Add an accessible "Forgot Password?" trigger text.  
4\. Build a brand-aligned \`RegisterScreen\` allowing full account sign-up.  
5\. Capture Firebase Auth exceptional statuses cleanly (e.g., email-already-in-use, wrong-password, user-not-found) and map them to standard UI Snackbars or inline notices. Ensure localization files support error notifications in English, Hebrew, and Spanish.

CRITICAL PRESERVATION CONSTRAINT:  
\- DO NOT interfere with or break any logic pertaining to the current Google Sign-In plugin setup.  
\- User objects produced via email validation must construct the exact same backend model schema and hook into the exact same user-profile syncing mechanism in Firestore used by Google authenticated users.

## **Task 3: Dynamic User Onboarding / Interactive Walkthrough**

| Architectural Dimension | Specification Details |
| :---- | :---- |
| **Feature Module** | lib/features/onboarding (New feature directory) |
| **Architecture Layer** | Presentation Layer (UI Screens & Local Navigation Guards) |
| **Files to Modify / Create** | lib/main.dart (Routing / Routing guard modifications) Create: lib/features/onboarding/presentation/screens/onboarding\_screen.dart |

### **AI Prompt Instructions for IDE**

Task Description:  
Establish a crisp, sliding informational carousel onboarding view to orient newly registered users, detailing premium features (Smart Add NLP parsing, Calendar Sync, and Analytics Dashboards).

Technical Requirements:  
1\. Build a swipeable onboarding component utilizing Flutter's \`PageView\` widget.  
2\. Structure a three-pane slideshow emphasizing distinct feature capabilities:  
   \- Panel 1: Smart Task Adding (Natural Language Processing for parsing timelines automatically).  
   \- Panel 2: Continuous Calendar synchronization and Google Calendar matching.  
   \- Panel 3: Productivity Graph trends, distributions, and insights charts.  
3\. Implement persistent indicators and a clear "Skip" / "Get Started" execution path.  
4\. Store a boolean flag entry (\`hasCompletedOnboarding\`) inside a localized persistent Hive preferences box upon workflow completion.  
5\. Update application entry guards in \`main.dart\` or the home routing container to intercept users. If a authenticated user profile is detected but \`hasCompletedOnboarding\` returns false, redirect context immediately to the new onboarding component.

CRITICAL PRESERVATION CONSTRAINT:  
\- Execute all routing guard evaluations safely without initiating rendering race conditions, black frames, or altering active user state models in \`AuthService\`.  

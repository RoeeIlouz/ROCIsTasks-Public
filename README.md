<<<<<<< HEAD
# ROCI's Tasks

A comprehensive Flutter-based task management application with calendar integration, multi-platform support, and cloud synchronization.

## 🚀 Features

### Core Functionality
- **Task Management**: Create, edit, delete, and organize tasks with priorities (High, Medium, Low)
- **Calendar Integration**: View tasks in calendar format with native device calendar sync
- **Categories**: Organize tasks with custom categories, colors, and icons
- **Due Dates & Reminders**: Set due dates and receive notifications
- **Task Prioritization**: Pin important tasks and set priority levels
- **Offline Support**: Full offline functionality with automatic sync when online

### User Experience
- **Multi-language Support**: English and Hebrew localization
- **Dynamic Theming**: Material You design with system color integration
- **Dark Mode**: Standard and AMOLED dark themes
- **Home Widgets**: Quick task access from device home screen
- **Responsive Design**: Optimized for phones, tablets, and desktop

### Data & Sync
- **Cloud Sync**: Firebase Firestore integration for cross-device synchronization
- **Local Storage**: Hive database for fast offline access
- **Authentication**: Google Sign-In integration
- **Data Security**: Encrypted local storage with secure preferences
- **Backup & Restore**: Automatic cloud backup with manual sync options

## 🏗️ Architecture

The app follows a clean architecture pattern with feature-based organization:

```
lib/
├── core/                    # Core services and utilities
│   ├── services/           # App initialization, auth, calendar, notifications
│   ├── theme/              # Theme management and styling
│   └── utils/              # Utility functions and helpers
├── features/               # Feature modules
│   ├── auth/               # Authentication (Google Sign-In)
│   ├── calendar/           # Calendar view and integration
│   ├── categories/         # Task categorization
│   ├── home/               # Main navigation and home widgets
│   └── tasks/              # Task management (CRUD operations)
└── l10n/                   # Internationalization (English/Hebrew)
```

### Key Technologies
- **Flutter**: Cross-platform UI framework
- **Firebase**: Authentication and cloud storage (Firestore)
- **Hive**: Local NoSQL database for offline storage
- **Provider**: State management
- **Material Design 3**: UI components with dynamic theming

## 📱 Supported Platforms

- **Android**: Full feature support with home widgets
- **iOS**: Complete functionality with native calendar integration
- **Web**: Progressive web app capabilities
- **Windows**: Desktop application support
- **macOS**: Native macOS application
- **Linux**: Linux desktop support

## 🛠️ Installation & Setup

### Prerequisites
- Flutter SDK (3.10.0 or higher)
- Dart SDK
- Firebase project setup
- Android Studio / Xcode (for mobile development)

### Getting Started

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd rocis_tasks
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Firebase Configuration**
   - Create a Firebase project at [Firebase Console](https://console.firebase.google.com)
   - Enable Authentication (Google Sign-In)
   - Enable Firestore Database
   - Download configuration files:
     - `google-services.json` for Android
     - `GoogleService-Info.plist` for iOS
   - Place files in respective platform directories

4. **Generate required files**
   ```bash
   flutter packages pub run build_runner build
   ```

5. **Run the application**
   ```bash
   flutter run
   ```

### Platform-Specific Setup

#### Android
- Minimum SDK: API 21 (Android 5.0)
- Target SDK: Latest stable
- Home widget support requires Android 8.0+

#### iOS
- Minimum iOS version: 12.0
- Calendar permissions required for integration
- Sign in with Apple capability (optional)

## 🔧 Configuration

### Firebase Setup
1. Create a new Firebase project
2. Enable the following services:
   - Authentication (Google provider)
   - Firestore Database
   - (Optional) Firebase Analytics

### Environment Variables
Create a `.env` file in the root directory:
```
FIREBASE_PROJECT_ID=your-project-id
GOOGLE_SIGN_IN_CLIENT_ID=your-client-id
```

### Permissions
The app requires the following permissions:
- **Calendar**: Read/write access for task integration
- **Notifications**: Local notifications for reminders
- **Internet**: Cloud synchronization
- **Storage**: Local data persistence

## 📊 Data Models

### Task
```dart
class Task {
  String id;              // Unique identifier
  String title;           // Task title
  String description;     // Optional description
  bool isCompleted;       // Completion status
  DateTime? dueDate;      // Optional due date
  TaskPriority priority;  // High, Medium, Low
  String? categoryId;     // Associated category
  bool isPinned;          // Pin to top
  bool isDeleted;         // Soft delete flag
}
```

### Category
```dart
class Category {
  String id;          // Unique identifier
  String name;        // Category name
  int colorValue;     // Color representation
  int iconCode;       // Icon code point
}
```

## 🎨 Theming

The app supports multiple theme options:
- **Light Theme**: Standard Material Design light theme
- **Dark Theme**: Material Design dark theme
- **AMOLED Theme**: Pure black background for OLED displays
- **Material You**: Dynamic colors based on system wallpaper (Android 12+)

Theme settings are persisted locally and sync across devices.

## 🌐 Localization

Currently supported languages:
- **English** (en)
- **Hebrew** (he) - RTL support included

To add new languages:
1. Create new `.arb` file in `lib/l10n/`
2. Add translations for all keys
3. Update `supportedLocales` in `main.dart`
4. Run `flutter gen-l10n`

## 🔔 Notifications

The app includes a comprehensive notification system:
- **Task Reminders**: Notifications for due tasks
- **Daily Summary**: Overview of pending tasks
- **Completion Celebrations**: Positive reinforcement
- **Background Sync**: Sync status notifications

## 🏠 Home Widgets

Android and iOS home widgets provide:
- **Quick Add**: Add tasks directly from home screen
- **Today's Tasks**: View today's pending tasks
- **Task Counter**: Visual indicator of remaining tasks
- **Quick Actions**: Mark tasks complete without opening app

## 🧪 Testing

Run tests with:
```bash
# Unit tests
flutter test

# Integration tests
flutter test integration_test/

# Widget tests
flutter test test/widget_test/
```

## 📦 Building for Production

### Android
```bash
flutter build apk --release
# or for app bundle
flutter build appbundle --release
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Code Style
- Follow Dart/Flutter conventions
- Use meaningful variable and function names
- Add comments for complex logic
- Ensure all tests pass before submitting

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

For support and questions:
- Create an issue in the GitHub repository
- Check existing documentation
- Review the troubleshooting section below

## 🐛 Troubleshooting

### Common Issues

**Build Errors**
- Run `flutter clean && flutter pub get`
- Ensure all dependencies are up to date
- Check Flutter and Dart SDK versions

**Firebase Connection Issues**
- Verify configuration files are in correct locations
- Check Firebase project settings
- Ensure internet connectivity for initial setup

**Sync Problems**
- Check user authentication status
- Verify Firestore rules allow read/write access
- Try manual sync from settings

**Performance Issues**
- Clear app cache and data
- Restart the application
- Check available device storage

## 🔮 Roadmap

Planned features for future releases:
- [ ] Subtasks and task dependencies
- [ ] Team collaboration features
- [ ] Advanced recurring task patterns
- [ ] Time tracking integration
- [ ] Export/import functionality
- [ ] Voice commands and dictation
- [ ] AI-powered task suggestions
- [ ] Integration with popular productivity tools

---

**ROCI's Tasks** - Simplifying task management across all your devices.
=======
# ROCIs-tasks-Android-

A brief description of what this project does and who it's for.
>>>>>>> 49f59a2274400143427ecfeb4b1f397d9f6bfece

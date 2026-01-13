import 'package:flutter/widgets.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:rocis_tasks/firebase_options.dart' as default_options;
import 'package:rocis_tasks/features/tasks/domain/models/task.dart';
import 'package:rocis_tasks/features/categories/domain/models/category.dart';
import 'package:rocis_tasks/core/services/notification_service.dart';
import 'package:rocis_tasks/core/services/error_service.dart';
import 'package:rocis_tasks/core/config/app_config.dart';

class AppInitializer {
  static bool _isInitialized = false;

  /// Main initialization entry point
  /// Handles both foreground and background initialization needs
  static Future<void> initialize({bool isBackground = false}) async {
    if (_isInitialized) return;

    final stopwatch = Stopwatch()..start();

    try {
      // 1. Core Binding (Required first)
      WidgetsFlutterBinding.ensureInitialized();

      // 2. Initialize error handling
      ErrorService.initialize();

      // 3. Parallel initialization of independent heavy services with timeout
      await Future.wait([
        _initHive(),
        _initEnvironment(),
        _initFirebase(),
      ]).timeout(
        Duration(seconds: AppConfig.syncTimeoutSeconds),
        onTimeout: () {
          debugPrint(
            'AppInitializer: Initialization timeout, continuing with partial setup',
          );
          return [];
        },
      );

      // 4. Dependent services (NotificationService might need Context or other things, but usually safe here)
      // In background, we might need explicitly notification channels
      if (isBackground) {
        // Reduced init for background
        await NotificationService().init();
      }
    } catch (e, stack) {
      debugPrint('AppInitializer: Critical error during initialization: $e');
      debugPrint('Stack: $stack');
      // Don't rethrow - allow app to continue with degraded functionality
    }

    _isInitialized = true;
    if (AppConfig.enableDebugLogging) {
      debugPrint(
        'AppInitializer: Initialization took ${stopwatch.elapsedMilliseconds}ms (isBackground: $isBackground)',
      );
    }
    stopwatch.stop();
  }

  static Future<void> _initEnvironment() async {
    try {
      debugPrint('AppInitializer: Attempting to load environment variables...');
      await dotenv.load(fileName: ".env");
      debugPrint('AppInitializer: Environment variables loaded successfully');
    } catch (e) {
      debugPrint('AppInitializer: Could not load .env file (this is OK): $e');
      debugPrint('AppInitializer: App will use default configuration');
      // This is not critical - continue without .env file
    }
  }

  static Future<void> _initHive() async {
    await Hive.initFlutter();
    _registerHiveAdapters();
  }

  static void _registerHiveAdapters() {
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(TaskPriorityAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(TaskAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(CategoryAdapter());
  }

  static Future<void> _initFirebase() async {
    try {
      // Check if already initialized (common in hot restart or mixed environments)
      if (Firebase.apps.isNotEmpty) {
        debugPrint('AppInitializer: Firebase already initialized');
        return;
      }

      debugPrint(
        'AppInitializer: Initializing Firebase with default configuration...',
      );

      // Use default Firebase configuration directly to avoid any environment variable issues
      await Firebase.initializeApp(
        options: default_options.DefaultFirebaseOptions.currentPlatform,
      );

      debugPrint('AppInitializer: Firebase initialized successfully');

      // Enable Firestore offline persistence for offline support
      try {
        FirebaseFirestore.instance.settings = const Settings(
          persistenceEnabled: true,
        );
        debugPrint('AppInitializer: Firestore offline persistence enabled');
      } catch (e) {
        debugPrint(
          'AppInitializer: Firestore persistence setup failed (non-critical): $e',
        );
      }
    } catch (e, stack) {
      debugPrint(
        'AppInitializer: CRITICAL - Firebase initialization failed: $e',
      );
      debugPrint('AppInitializer: Stack trace: $stack');

      // This is a critical error - rethrow to show error screen
      throw Exception('Firebase initialization failed: $e');
    }
  }
}

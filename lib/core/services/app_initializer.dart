import 'package:flutter/widgets.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:rocis_tasks/firebase_options.dart' as default_options;
import 'package:rocis_tasks/firebase_schedule_options.dart';
import 'package:rocis_tasks/features/tasks/domain/models/task.dart';
import 'package:rocis_tasks/features/categories/domain/models/category.dart';
import 'package:rocis_tasks/core/services/notification_service.dart';
import 'package:rocis_tasks/core/services/error_service.dart';
import 'package:rocis_tasks/core/config/app_config.dart';
import 'package:rocis_tasks/core/services/logger_service.dart';

import 'package:rocis_tasks/core/services/encryption_service.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as t;
import 'package:flutter_timezone/flutter_timezone.dart';

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
        _initEncryption(),
        _initTimezone(),
      ]).timeout(
        Duration(seconds: AppConfig.syncTimeoutSeconds),
        onTimeout: () {
          AppLogger.critical('SECURITY ALERT: Initialization timeout. Potential compromised environment.');
          throw Exception('Security initialization timeout');
        },
      );

      // 4. Dependent services (NotificationService might need Context or other things, but usually safe here)
      // In background, we might need explicitly notification channels
      if (isBackground) {
        // Reduced init for background
        await NotificationService().init();
      }
    } catch (e, stack) {
      AppLogger.critical('Critical error during initialization', error: e, stack: stack);
      // Don't rethrow - allow app to continue with degraded functionality
    }

    _isInitialized = true;
    if (AppConfig.enableDebugLogging) {
      AppLogger.info('Initialization took ${stopwatch.elapsedMilliseconds}ms (isBackground: $isBackground)');
    }
    stopwatch.stop();
  }

  static Future<void> _initEnvironment() async {
    try {
      AppLogger.info('Attempting to load environment variables...');
      await dotenv.load(fileName: ".env");
      AppLogger.info('Environment variables loaded successfully');
    } catch (e) {
      AppLogger.warning('Could not load .env file (this is OK)', error: e);
      AppLogger.info('App will use default configuration');
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
        AppLogger.info('Firebase already initialized');
        // Still try to initialize secondary app if not present
        await _initSecondaryFirebase();
        return;
      }

      AppLogger.info('Initializing Firebase with default configuration...');

      // Use default Firebase configuration directly to avoid any environment variable issues
      await Firebase.initializeApp(
        options: default_options.DefaultFirebaseOptions.currentPlatform,
      );

      AppLogger.info('Firebase initialized successfully');

      // Enable Firestore offline persistence for offline support
      try {
        FirebaseFirestore.instance.settings = const Settings(
          persistenceEnabled: true,
        );
        AppLogger.info('Firestore offline persistence enabled');
      } catch (e) {
        AppLogger.warning('Firestore persistence setup failed (non-critical)', error: e);
      }

      // Initialize secondary Firebase app for ROCIs-Schedule data
      await _initSecondaryFirebase();
    } catch (e, stack) {
      AppLogger.critical('CRITICAL - Firebase initialization failed', error: e, stack: stack);

      // This is a critical error - rethrow to show error screen
      throw Exception('Firebase initialization failed: $e');
    }
  }

  /// Initialize secondary Firebase app for accessing ROCIs-Schedule Firestore
  static Future<void> _initSecondaryFirebase() async {
    try {
      // Check if secondary app already exists
      try {
        Firebase.app('rocis-schedule');
        AppLogger.info('Secondary Firebase app already initialized');
        return;
      } catch (_) {
        // App doesn't exist, continue to initialize
      }

      AppLogger.info('Initializing secondary Firebase app (rocis-schedule)...');

      await Firebase.initializeApp(
        name: 'rocis-schedule',
        options: ScheduleFirebaseOptions.currentPlatform,
      );

      AppLogger.info('Secondary Firebase app initialized successfully');
    } catch (e) {
      AppLogger.warning('Secondary Firebase initialization failed (non-critical)', error: e);
      AppLogger.info('ROCIs-Schedule integration will be unavailable');
    }
  }

  static Future<void> _initEncryption() async {
    try {
      await EncryptionService.init();
      AppLogger.info('Encryption initialized successfully');
    } catch (e) {
      AppLogger.critical('CRITICAL SECURITY FAILURE: Encryption initialization failed', error: e);
      throw Exception('Critical security initialization failed. Please restart the app.');
    }
  }

  static Future<void> _initTimezone() async {
    try {
      tz.initializeTimeZones();
      final String timeZoneName = await FlutterTimezone.getLocalTimezone();
      t.setLocalLocation(t.getLocation(timeZoneName));
      AppLogger.info('Timezone initialized: $timeZoneName');
    } catch (e) {
      AppLogger.error('Timezone initialization failed', error: e);
    }
  }
}

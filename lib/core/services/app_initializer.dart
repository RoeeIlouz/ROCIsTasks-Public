import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:rocis_tasks/core/config/firebase_config.dart';
import 'package:rocis_tasks/firebase_schedule_options.dart';
import 'package:rocis_tasks/features/tasks/domain/models/task.dart';
import 'package:rocis_tasks/features/tasks/domain/models/sub_task.dart';
import 'package:rocis_tasks/features/tasks/domain/models/custom_field.dart';
import 'package:rocis_tasks/features/categories/domain/models/category.dart';
import 'package:rocis_tasks/core/services/notification_service.dart';
import 'package:rocis_tasks/core/services/error_service.dart';
import 'package:rocis_tasks/core/config/app_config.dart';
import 'package:rocis_tasks/core/services/logger_service.dart';
import 'package:rocis_tasks/core/services/analytics_service.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';

import 'package:rocis_tasks/core/services/encryption_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
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

      // Enforce local asset-based font loading for 100% offline instant rendering
      GoogleFonts.config.allowRuntimeFetching = false;

      // 2. Load Environment Variables First
      await _initEnvironment();

      // 3. Initialize DEFAULT Firebase
      await _initFirebase();

      // Start custom cold start trace for performance monitoring (disabled on Web for adblockers)
      Trace? coldStartTrace;
      if (!isBackground && !kIsWeb && AppConfig.enablePerformanceMonitoring) {
        try {
          coldStartTrace = FirebasePerformance.instance.newTrace(
            'app_cold_start',
          );
          await coldStartTrace.start();
        } catch (_) {}
      }

      // 4. Parallel initialization of independent heavy services
      try {
        await Future.wait([
          _initHive().then(
            (_) => _initEncryption(),
          ), // Encryption needs Hive for key gen fallback
          _initTimezone(isBackground: isBackground),
          if (!isBackground) ...[
            _initSecondaryFirebase(),
            _initPerformance(),
            _initRemoteConfig(),
          ]
        ]).timeout(
          Duration(seconds: AppConfig.syncTimeoutSeconds),
          onTimeout: () {
            AppLogger.warning('Initialization services timed out, continuing startup.');
            return [];
          },
        );

        // Services that depend on Firebase but can run after it's ready
        ErrorService.initialize();
        if (!kIsWeb) {
          AnalyticsService();
        }
      } catch (e, stack) {
        AppLogger.warning('Non-critical service initialization warning: $e', error: e, stack: stack);
      }

      // 4. Dependent services (NotificationService might need Context or other things, but usually safe here)
      if (isBackground) {
        try {
          await NotificationService().init();
        } catch (_) {}
      }

      if (coldStartTrace != null) {
        try {
          await coldStartTrace.stop();
        } catch (_) {}
      }
    } catch (e, stack) {
      AppLogger.critical(
        'Critical error during initialization',
        error: e,
        stack: stack,
      );
      // Rethrow critical errors to prevent the app from starting in a broken state
      rethrow;
    }

    _isInitialized = true;
    if (AppConfig.enableDebugLogging) {
      AppLogger.info(
        'Initialization took ${stopwatch.elapsedMilliseconds}ms (isBackground: $isBackground)',
      );
    }
    stopwatch.stop();
  }

  static Future<void> _initEnvironment() async {
    try {
      AppLogger.info('Attempting to load environment variables...');
      await dotenv.load(fileName: '.env');
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
    await Hive.openBox('settings');
  }

  static void _registerHiveAdapters() {
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(TaskPriorityAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(TaskAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(CategoryAdapter());
    if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(SubTaskAdapter());
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(CustomFieldTypeAdapter());
    }
    if (!Hive.isAdapterRegistered(5)) {
      Hive.registerAdapter(TaskCustomFieldAdapter());
    }
  }

  static Future<void> _initFirebase() async {
    try {
      // Check if already initialized (common in hot restart or mixed environments)
      if (Firebase.apps.isNotEmpty) {
        AppLogger.info('Firebase already initialized');
        return;
      }

      AppLogger.info('Initializing Firebase with configuration...');

      // Use FirebaseConfig (reads from .env if present, fallback to default_options)
      await Firebase.initializeApp(
        options: FirebaseConfig.currentPlatform,
      );

      AppLogger.info('Firebase initialized successfully');

      // Enable Firestore offline persistence for offline support
      try {
        FirebaseFirestore.instance.settings = const Settings(
          persistenceEnabled: true,
        );
        AppLogger.info('Firestore offline persistence enabled');
      } catch (e) {
        AppLogger.warning(
          'Firestore persistence setup failed (non-critical)',
          error: e,
        );
      }
    } catch (e, stack) {
      AppLogger.critical(
        'CRITICAL - Firebase initialization failed',
        error: e,
        stack: stack,
      );

      // This is a critical error - rethrow to show error screen
      throw Exception('Firebase initialization failed: $e');
    }
  }

  /// Initialize secondary Firebase app for accessing ROCIs-Schedule Firestore
  static Future<void> _initSecondaryFirebase() async {
    if (kIsWeb) {
      AppLogger.info('ROCIs-Schedule integration skipped on web');
      return;
    }
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
      AppLogger.warning(
        'Secondary Firebase initialization failed (non-critical)',
        error: e,
      );
      AppLogger.info('ROCIs-Schedule integration will be unavailable');
    }
  }

  static Future<void> _initEncryption() async {
    try {
      await EncryptionService.init();
      AppLogger.info('Encryption initialized successfully');
    } catch (e) {
      AppLogger.critical(
        'CRITICAL SECURITY FAILURE: Encryption initialization failed',
        error: e,
      );
      throw Exception(
        'Critical security initialization failed. Please restart the app.',
      );
    }
  }

  static Future<void> _initTimezone({bool isBackground = false}) async {
    try {
      tz_data.initializeTimeZones();
      String timeZoneName = 'UTC';
      try {
        final prefs = await SharedPreferences.getInstance();
        final saved = prefs.getString('app_selected_timezone');
        if (saved != null &&
            saved.isNotEmpty &&
            saved != 'auto' &&
            tz.timeZoneDatabase.locations.containsKey(saved)) {
          timeZoneName = saved;
        } else if (!isBackground) {
          final timezoneInfo = await FlutterTimezone.getLocalTimezone()
              .timeout(const Duration(seconds: 2));
          if (tz.timeZoneDatabase.locations.containsKey(timezoneInfo.identifier)) {
            timeZoneName = timezoneInfo.identifier;
          }
        }
      } catch (e) {
        AppLogger.warning('Failed to get local timezone: $e');
      }
      tz.setLocalLocation(tz.getLocation(timeZoneName));
      AppLogger.info('Timezone initialized: $timeZoneName');
    } catch (e) {
      AppLogger.error('Timezone initialization failed', error: e);
    }
  }

  static Future<void> _initPerformance() async {
    if (kIsWeb) return; // Disable Firebase Performance entirely on Web to prevent adblocker-induced crashes
    if (!AppConfig.enablePerformanceMonitoring) return;
    try {
      FirebasePerformance.instance.setPerformanceCollectionEnabled(true);
      AppLogger.info('Firebase Performance Monitoring initialized');
    } catch (e) {
      AppLogger.warning(
        'Performance Monitoring initialization failed',
        error: e,
      );
    }
  }

  static Future<void> _initRemoteConfig() async {
    if (!AppConfig.enableRemoteConfig) return;
    try {
      final remoteConfig = FirebaseRemoteConfig.instance;
      await remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(minutes: 1),
          minimumFetchInterval: const Duration(hours: 1),
        ),
      );
      await remoteConfig.setDefaults({
        'free_category_limit': AppConfig.freeCategoryLimit,
        'enable_premium_ui': true,
      });
      // Fetch in the background non-blockingly to keep startup instant
      unawaited(
        remoteConfig.fetchAndActivate().then((_) {
          AppLogger.info('Firebase Remote Config fetched and activated');
        }).catchError((e) {
          AppLogger.warning('Remote Config fetch failed (non-critical)', error: e);
        }),
      );
      AppLogger.info('Firebase Remote Config initialized with local defaults');
    } catch (e) {
      AppLogger.warning('Remote Config initialization failed', error: e);
    }
  }
}

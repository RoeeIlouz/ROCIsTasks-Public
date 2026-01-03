import 'package:flutter/widgets.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:rocis_tasks/firebase_options.dart';
import 'package:rocis_tasks/features/tasks/domain/models/task.dart';
import 'package:rocis_tasks/features/categories/domain/models/category.dart';
import 'package:rocis_tasks/core/services/notification_service.dart';

class AppInitializer {
  static bool _isInitialized = false;

  /// Main initialization entry point
  /// Handles both foreground and background initialization needs
  static Future<void> initialize({bool isBackground = false}) async {
    if (_isInitialized) return;

    final stopwatch = Stopwatch()..start();

    // 1. Core Binding (Required first)
    WidgetsFlutterBinding.ensureInitialized();

    // 2. Parallel initialization of independent heavy services
    await Future.wait([_initHive(), _initFirebase()]);

    // 3. Dependent services (NotificationService might need Context or other things, but usually safe here)
    // In background, we might need explicitly notification channels
    try {
      if (isBackground) {
        // Reduced init for background
        await NotificationService().init();
      }
    } catch (e) {
      debugPrint('Notification init warning: $e');
    }

    _isInitialized = true;
    debugPrint(
      'AppInitializer: Initialization took ${stopwatch.elapsedMilliseconds}ms (isBackground: $isBackground)',
    );
    stopwatch.stop();
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
    // Check if already initialized (common in hot restart or mixed environments)
    if (Firebase.apps.isNotEmpty) return;

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e) {
      debugPrint(
        'Firebase initialization failed (non-critical if offline): $e',
      );
    }
  }
}

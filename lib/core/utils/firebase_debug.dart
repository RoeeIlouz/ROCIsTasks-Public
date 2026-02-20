import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:rocis_tasks/core/config/firebase_config.dart';

/// Debug utility for Firebase configuration issues
class FirebaseDebug {
  /// Print comprehensive Firebase configuration debug information
  static void printDebugInfo() {
    if (!kDebugMode) return;

    debugPrint('=== FIREBASE DEBUG INFO ===');

    // Check if Firebase is already initialized
    debugPrint('Firebase apps count: ${Firebase.apps.length}');
    if (Firebase.apps.isNotEmpty) {
      for (final app in Firebase.apps) {
        debugPrint('Firebase app: ${app.name} (${app.options.projectId})');
      }
    }

    // Check environment variables
    debugPrint('Environment variables loaded: ${dotenv.env.isNotEmpty}');
    debugPrint(
      'FIREBASE_PROJECT_ID: ${dotenv.env['FIREBASE_PROJECT_ID'] ?? 'NOT SET'}',
    );
    debugPrint(
      'FIREBASE_ANDROID_API_KEY: ${_maskKey(dotenv.env['FIREBASE_ANDROID_API_KEY'])}',
    );
    debugPrint(
      'FIREBASE_ANDROID_APP_ID: ${dotenv.env['FIREBASE_ANDROID_APP_ID'] ?? 'NOT SET'}',
    );

    // Check Firebase configuration
    try {
      final options = FirebaseConfig.currentPlatform;
      debugPrint('Firebase config project ID: ${options.projectId}');
      debugPrint('Firebase config API key: ${_maskKey(options.apiKey)}');
      debugPrint('Firebase config app ID: ${options.appId}');
      debugPrint(
        'Firebase config validation: ${FirebaseConfig.validateConfig()}',
      );
    } catch (e) {
      debugPrint('Firebase config error: $e');
    }

    debugPrint('=== END FIREBASE DEBUG ===');
  }

  /// Mask sensitive keys for logging
  static String _maskKey(String? key) {
    if (key == null || key.isEmpty) return 'NOT SET';
    if (key.length <= 8) return '***';
    return '${key.substring(0, 4)}***${key.substring(key.length - 4)}';
  }

  /// Test Firebase initialization without actually initializing
  /// Only runs in debug mode.
  static Future<bool> testFirebaseConfig() async {
    if (!kDebugMode) return true;
    try {
      final options = FirebaseConfig.currentPlatform;

      // Basic validation
      if (options.projectId.isEmpty) {
        debugPrint('Firebase test failed: Empty project ID');
        return false;
      }

      if (options.apiKey.isEmpty) {
        debugPrint('Firebase test failed: Empty API key');
        return false;
      }

      if (options.appId.isEmpty) {
        debugPrint('Firebase test failed: Empty app ID');
        return false;
      }

      debugPrint('Firebase configuration test passed');
      return true;
    } catch (e) {
      debugPrint('Firebase configuration test failed: $e');
      return false;
    }
  }
}

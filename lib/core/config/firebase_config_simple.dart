import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:rocis_tasks/firebase_options.dart' as default_options;

/// Simplified Firebase configuration that always uses default options
/// This ensures Firebase initialization always works
class SimpleFirebaseConfig {
  /// Always return the default Firebase configuration
  /// This eliminates any potential issues with environment variables
  static FirebaseOptions get currentPlatform {
    debugPrint('SimpleFirebaseConfig: Using default Firebase configuration');
    return default_options.DefaultFirebaseOptions.currentPlatform;
  }

  /// Test if the default configuration is valid
  static bool validateDefaultConfig() {
    try {
      final options = default_options.DefaultFirebaseOptions.currentPlatform;

      if (options.projectId.isEmpty) {
        debugPrint('SimpleFirebaseConfig: Invalid - Empty project ID');
        return false;
      }

      if (options.apiKey.isEmpty) {
        debugPrint('SimpleFirebaseConfig: Invalid - Empty API key');
        return false;
      }

      if (options.appId.isEmpty) {
        debugPrint('SimpleFirebaseConfig: Invalid - Empty app ID');
        return false;
      }

      debugPrint('SimpleFirebaseConfig: Default configuration is valid');
      debugPrint('  - Project ID: ${options.projectId}');
      debugPrint('  - API Key: ${_maskKey(options.apiKey)}');
      debugPrint('  - App ID: ${options.appId}');

      return true;
    } catch (e) {
      debugPrint('SimpleFirebaseConfig: Error validating default config: $e');
      return false;
    }
  }

  /// Mask sensitive keys for logging
  static String _maskKey(String key) {
    if (key.length <= 8) return '***';
    return '${key.substring(0, 4)}***${key.substring(key.length - 4)}';
  }
}

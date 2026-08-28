import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:rocis_tasks/firebase_options.dart' as default_options;

/// Secure Firebase configuration using environment variables with fallback
class FirebaseConfig {
  static FirebaseOptions get currentPlatform {
    // Always try default configuration first to ensure Firebase works
    // Environment variables are optional for security but not required for functionality
    try {
      // Only use environment config if explicitly validated and complete
      if (_isEnvironmentConfigComplete() && _hasValidEnvironmentConfig()) {
        debugPrint('FirebaseConfig: Using environment configuration');
        return _getEnvironmentConfig();
      }
    } catch (e) {
      debugPrint(
        'FirebaseConfig: Environment config failed, using default: $e',
      );
    }

    // Always fallback to default Firebase options (this should always work)
    debugPrint('FirebaseConfig: Using default Firebase configuration');
    return default_options.DefaultFirebaseOptions.currentPlatform;
  }

  /// Check if environment is loaded and has basic structure
  static bool _isEnvironmentConfigComplete() {
    try {
      // Check if dotenv is loaded at all
      if (!dotenv.isInitialized || dotenv.env.isEmpty) {
        debugPrint('FirebaseConfig: Environment variables not loaded');
        return false;
      }

      // Check if we have the minimum required variables
      final projectId = dotenv.env['FIREBASE_PROJECT_ID'];
      final androidApiKey = dotenv.env['FIREBASE_ANDROID_API_KEY'];
      final androidAppId = dotenv.env['FIREBASE_ANDROID_APP_ID'];

      final hasRequired =
          projectId != null &&
          projectId.isNotEmpty &&
          androidApiKey != null &&
          androidApiKey.isNotEmpty &&
          androidAppId != null &&
          androidAppId.isNotEmpty;

      if (!hasRequired) {
        debugPrint('FirebaseConfig: Missing required environment variables');
        debugPrint('  - FIREBASE_PROJECT_ID: ${projectId ?? "MISSING"}');
        debugPrint(
          '  - FIREBASE_ANDROID_API_KEY: ${androidApiKey != null ? "SET" : "MISSING"}',
        );
        debugPrint(
          '  - FIREBASE_ANDROID_APP_ID: ${androidAppId != null ? "SET" : "MISSING"}',
        );
      }

      return hasRequired;
    } catch (e) {
      debugPrint('FirebaseConfig: Error checking environment completeness: $e');
      return false;
    }
  }

  static bool _hasValidEnvironmentConfig() {
    try {
      // Additional validation for environment config
      final projectId = dotenv.env['FIREBASE_PROJECT_ID'];
      final androidApiKey = dotenv.env['FIREBASE_ANDROID_API_KEY'];
      final androidAppId = dotenv.env['FIREBASE_ANDROID_APP_ID'];

      // Validate format and content
      if (projectId == null || !projectId.contains('-')) {
        debugPrint('FirebaseConfig: Invalid project ID format');
        return false;
      }

      if (androidApiKey == null || !androidApiKey.startsWith('AIza')) {
        debugPrint('FirebaseConfig: Invalid Android API key format');
        return false;
      }

      if (androidAppId == null || !androidAppId.contains(':')) {
        debugPrint('FirebaseConfig: Invalid Android app ID format');
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('FirebaseConfig: Error validating environment config: $e');
      return false;
    }
  }

  static FirebaseOptions _getEnvironmentConfig() {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'FirebaseConfig has not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'FirebaseConfig is not supported for this platform.',
        );
    }
  }

  static FirebaseOptions get web => FirebaseOptions(
    apiKey: dotenv.env['FIREBASE_WEB_API_KEY']!,
    appId: dotenv.env['FIREBASE_WEB_APP_ID']!,
    messagingSenderId: dotenv.env['FIREBASE_WEB_MESSAGING_SENDER_ID']!,
    projectId: dotenv.env['FIREBASE_PROJECT_ID']!,
    authDomain: dotenv.env['FIREBASE_WEB_AUTH_DOMAIN']!,
    storageBucket: dotenv.env['FIREBASE_WEB_STORAGE_BUCKET']!,
    measurementId: dotenv.env['FIREBASE_WEB_MEASUREMENT_ID'],
  );

  static FirebaseOptions get android => FirebaseOptions(
    apiKey: dotenv.env['FIREBASE_ANDROID_API_KEY']!,
    appId: dotenv.env['FIREBASE_ANDROID_APP_ID']!,
    messagingSenderId: dotenv.env['FIREBASE_WEB_MESSAGING_SENDER_ID']!,
    projectId: dotenv.env['FIREBASE_PROJECT_ID']!,
    storageBucket: dotenv.env['FIREBASE_WEB_STORAGE_BUCKET']!,
  );

  static FirebaseOptions get ios => FirebaseOptions(
    apiKey: dotenv.env['FIREBASE_IOS_API_KEY']!,
    appId: dotenv.env['FIREBASE_IOS_APP_ID']!,
    messagingSenderId: dotenv.env['FIREBASE_WEB_MESSAGING_SENDER_ID']!,
    projectId: dotenv.env['FIREBASE_PROJECT_ID']!,
    storageBucket: dotenv.env['FIREBASE_WEB_STORAGE_BUCKET']!,
    iosClientId: dotenv.env['FIREBASE_IOS_CLIENT_ID'],
    iosBundleId: dotenv.env['FIREBASE_IOS_BUNDLE_ID']!,
  );

  static FirebaseOptions get macos => FirebaseOptions(
    apiKey: dotenv.env['FIREBASE_IOS_API_KEY']!,
    appId: dotenv.env['FIREBASE_IOS_APP_ID']!,
    messagingSenderId: dotenv.env['FIREBASE_WEB_MESSAGING_SENDER_ID']!,
    projectId: dotenv.env['FIREBASE_PROJECT_ID']!,
    storageBucket: dotenv.env['FIREBASE_WEB_STORAGE_BUCKET']!,
    iosClientId: dotenv.env['FIREBASE_IOS_CLIENT_ID'],
    iosBundleId: dotenv.env['FIREBASE_IOS_BUNDLE_ID']!,
  );

  static FirebaseOptions get windows => FirebaseOptions(
    apiKey: dotenv.env['FIREBASE_WINDOWS_API_KEY']!,
    appId: dotenv.env['FIREBASE_WINDOWS_APP_ID']!,
    messagingSenderId: dotenv.env['FIREBASE_WEB_MESSAGING_SENDER_ID']!,
    projectId: dotenv.env['FIREBASE_PROJECT_ID']!,
    authDomain: dotenv.env['FIREBASE_WEB_AUTH_DOMAIN']!,
    storageBucket: dotenv.env['FIREBASE_WEB_STORAGE_BUCKET']!,
    measurementId: dotenv.env['FIREBASE_WINDOWS_MEASUREMENT_ID'],
  );

  /// Validate that all required environment variables are present
  static bool validateConfig() {
    return _isEnvironmentConfigComplete() && _hasValidEnvironmentConfig();
  }
}

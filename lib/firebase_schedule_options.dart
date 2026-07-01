// Firebase configuration for accessing ROCIs-Schedule Firestore database
// This allows ROCIs-tasks to read schedule data from the rocis-schedule project

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Firebase options for the rocis-schedule project (secondary Firebase app)
/// Used to fetch schedule data (courses, events, assignments) for widget display
class ScheduleFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'ScheduleFirebaseOptions have not been configured for web - '
        'you can reconfigure this by running the FlutterFire CLI again.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'ScheduleFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'ScheduleFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'ScheduleFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'ScheduleFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // --- Default hardcoded values (fallback) ---
  static const String _defaultApiKey =
      'REDACTED_SCHEDULE_API_KEY';
  static const String _defaultAndroidAppId =
      'REDACTED_SCHEDULE_ANDROID_APP_ID';
  static const String _defaultMessagingSenderId = 'REDACTED_SCHEDULE_SENDER_ID';
  static const String _defaultProjectId = 'rocis-schedule';
  static const String _defaultStorageBucket =
      'rocis-schedule.firebasestorage.app';
  static const String _defaultDatabaseURL =
      'https://rocis-schedule-default-rtdb.europe-west1.firebasedatabase.app';

  /// Firebase options for Android platform - rocis-schedule project
  static FirebaseOptions get android => FirebaseOptions(
    apiKey: dotenv.env['FIREBASE_SCHEDULE_API_KEY'] ?? _defaultApiKey,
    appId:
        dotenv.env['FIREBASE_SCHEDULE_ANDROID_APP_ID'] ?? _defaultAndroidAppId,
    messagingSenderId:
        dotenv.env['FIREBASE_SCHEDULE_MESSAGING_SENDER_ID'] ??
        _defaultMessagingSenderId,
    projectId: dotenv.env['FIREBASE_SCHEDULE_PROJECT_ID'] ?? _defaultProjectId,
    storageBucket:
        dotenv.env['FIREBASE_SCHEDULE_STORAGE_BUCKET'] ?? _defaultStorageBucket,
    databaseURL:
        dotenv.env['FIREBASE_SCHEDULE_DATABASE_URL'] ?? _defaultDatabaseURL,
  );

  /// Firebase options for iOS platform - rocis-schedule project
  /// Note: You may need to update these values from the ROCIs-Schedule iOS config
  static FirebaseOptions get ios => FirebaseOptions(
    apiKey: dotenv.env['FIREBASE_SCHEDULE_API_KEY'] ?? _defaultApiKey,
    appId:
        dotenv.env['FIREBASE_SCHEDULE_IOS_APP_ID'] ??
        '1:REDACTED_SCHEDULE_SENDER_ID:ios:PLACEHOLDER',
    messagingSenderId:
        dotenv.env['FIREBASE_SCHEDULE_MESSAGING_SENDER_ID'] ??
        _defaultMessagingSenderId,
    projectId: dotenv.env['FIREBASE_SCHEDULE_PROJECT_ID'] ?? _defaultProjectId,
    storageBucket:
        dotenv.env['FIREBASE_SCHEDULE_STORAGE_BUCKET'] ?? _defaultStorageBucket,
    databaseURL:
        dotenv.env['FIREBASE_SCHEDULE_DATABASE_URL'] ?? _defaultDatabaseURL,
    iosBundleId: 'com.rocis.schedule.rocisSchedule',
  );
}

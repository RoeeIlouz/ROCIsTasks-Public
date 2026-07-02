import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:rocis_tasks/core/config/firebase_config.dart';

void main() {
  group('FirebaseConfig', () {
    setUp(() {
      // Clear any existing environment
      dotenv.clean();
    });

    test('should use default Firebase options when no .env file', () {
      // When no environment variables are loaded
      final options = FirebaseConfig.currentPlatform;

      // Should use default configuration
      expect(options.projectId, 'rocis-todo');
    });

    test('should use environment config when valid .env is loaded', () {
      // Load test environment variables
      dotenv.loadFromString(
        envString: '''
FIREBASE_PROJECT_ID=test-project
FIREBASE_ANDROID_API_KEY=AIzatestandroidkey
FIREBASE_ANDROID_APP_ID=1:12345:android:test
FIREBASE_WEB_MESSAGING_SENDER_ID=test-sender-id
FIREBASE_WEB_STORAGE_BUCKET=test-bucket
''',
      );

      final options = FirebaseConfig.currentPlatform;

      // Should use environment configuration
      expect(options.projectId, 'test-project');
    });

    test('should validate config correctly', () {
      // Test with missing required variables
      dotenv.loadFromString(envString: 'FIREBASE_PROJECT_ID=test-project');
      expect(FirebaseConfig.validateConfig(), false);

      // Test with all required variables
      dotenv.loadFromString(
        envString: '''
FIREBASE_PROJECT_ID=test-project
FIREBASE_ANDROID_API_KEY=AIzatestkey
FIREBASE_ANDROID_APP_ID=1:12345:android:test
''',
      );
      expect(FirebaseConfig.validateConfig(), true);
    });
  });
}

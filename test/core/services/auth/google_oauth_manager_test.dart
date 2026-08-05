import 'package:flutter_test/flutter_test.dart';
import 'package:rocis_tasks/core/services/auth/google_oauth_manager.dart';
import 'package:rocis_tasks/core/services/error_handling_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GoogleOAuthManager Tests', () {
    late GoogleOAuthManager oauthManager;
    late ErrorHandlingService errorHandlingService;

    setUp(() {
      errorHandlingService = ErrorHandlingService();
      oauthManager = GoogleOAuthManager(errorHandlingService);
    });

    test('isGoogleTasksTokenExpired initial state is false', () {
      expect(oauthManager.isGoogleTasksTokenExpired, isFalse);
    });

    test('setGoogleTasksTokenExpired updates state and fires callback', () {
      bool callbackFired = false;
      oauthManager.setGoogleTasksTokenExpired(true, onStateChanged: () {
        callbackFired = true;
      });

      expect(oauthManager.isGoogleTasksTokenExpired, isTrue);
      expect(callbackFired, isTrue);
    });

    test('googleTasksScopes includes tasks and calendar scopes', () {
      expect(GoogleOAuthManager.googleTasksScopes, contains('https://www.googleapis.com/auth/tasks'));
      expect(GoogleOAuthManager.googleTasksScopes, contains('https://www.googleapis.com/auth/calendar.events'));
    });
  });
}

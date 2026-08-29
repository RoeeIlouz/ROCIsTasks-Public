import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rocis_tasks/core/services/auth/google_oauth_manager.dart';
import 'package:rocis_tasks/core/services/error_handling_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GoogleOAuthManager Tests', () {
    late GoogleOAuthManager oauthManager;
    late ErrorHandlingService errorHandlingService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      errorHandlingService = ErrorHandlingService();
      oauthManager = GoogleOAuthManager(errorHandlingService);
    });

    test('isGoogleTasksTokenExpired initial state is false', () {
      expect(oauthManager.isGoogleTasksTokenExpired, isFalse);
    });

    test('setGoogleTasksTokenExpired updates state and fires callback', () {
      bool callbackFired = false;
      oauthManager.setGoogleTasksTokenExpired(
        true,
        onStateChanged: () {
          callbackFired = true;
        },
      );

      expect(oauthManager.isGoogleTasksTokenExpired, isTrue);
      expect(callbackFired, isTrue);
    });

    test(
      'googleTasksScopes includes email, tasks, and granular calendar scopes',
      () {
        expect(GoogleOAuthManager.googleTasksScopes, contains('email'));
        expect(
          GoogleOAuthManager.googleTasksScopes,
          contains('https://www.googleapis.com/auth/tasks'),
        );
        expect(
          GoogleOAuthManager.googleTasksScopes,
          contains('https://www.googleapis.com/auth/calendar.readonly'),
        );
        expect(
          GoogleOAuthManager.googleTasksScopes,
          contains('https://www.googleapis.com/auth/calendar.events'),
        );
        expect(
          GoogleOAuthManager.googleTasksScopes,
          isNot(contains('https://www.googleapis.com/auth/calendar')),
        );
      },
    );

    test(
      'getGoogleAccessToken returns null and marks expired on mobile when no token or user exists',
      () async {
        expect(oauthManager.isGoogleTasksTokenExpired, isFalse);
        final token = await oauthManager.getGoogleAccessToken();
        expect(token, isNull);
        expect(oauthManager.isGoogleTasksTokenExpired, isTrue);
      },
    );
  });
}

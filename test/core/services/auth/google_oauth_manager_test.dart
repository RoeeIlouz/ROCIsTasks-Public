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

    test(
      'cacheGoogleAccessToken saves token and resets expired flag with 50-minute expiry',
      () async {
        oauthManager.setGoogleTasksTokenExpired(true);
        expect(oauthManager.isGoogleTasksTokenExpired, isTrue);

        await oauthManager.cacheGoogleAccessToken('mock_token_123');

        expect(oauthManager.isGoogleTasksTokenExpired, isFalse);
        final retrieved = await oauthManager.getGoogleAccessToken();
        expect(retrieved, 'mock_token_123');

        final prefs = await SharedPreferences.getInstance();
        final expiresAtStr = prefs.getString(
          GoogleOAuthManager.keyAccessTokenExpiresAt,
        );
        expect(expiresAtStr, isNotNull);
        final expiresAt = DateTime.parse(expiresAtStr!);
        // Expiry should be ~50 minutes from now (between 48 and 51 minutes)
        final diff = expiresAt.difference(DateTime.now()).inMinutes;
        expect(diff, inInclusiveRange(48, 51));
      },
    );

    test(
      'saveGoogleUserIdentity persists email and id and clears on signOut',
      () async {
        await oauthManager.saveGoogleUserIdentity(
          email: 'test@rocisapps.com',
          id: 'google-user-12345',
        );

        expect(
          await oauthManager.getSavedGoogleUserEmail(),
          'test@rocisapps.com',
        );
        expect(await oauthManager.getSavedGoogleUserId(), 'google-user-12345');

        await oauthManager.cacheGoogleAccessToken('token_to_clear');
        expect(await oauthManager.getGoogleAccessToken(), 'token_to_clear');

        await oauthManager.signOut();

        expect(await oauthManager.getSavedGoogleUserEmail(), isNull);
        expect(await oauthManager.getSavedGoogleUserId(), isNull);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString(GoogleOAuthManager.keyAccessToken), isNull);
        expect(
          prefs.getString(GoogleOAuthManager.keyAccessTokenExpiresAt),
          isNull,
        );
      },
    );
  });
}

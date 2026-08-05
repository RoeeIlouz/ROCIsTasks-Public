import 'dart:async';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rocis_tasks/core/services/error_handling_service.dart';
import 'package:rocis_tasks/core/services/logger_service.dart';

class GoogleTokenExpiredException implements Exception {
  final String message;

  /// Whether this exception was caused by a real HTTP 401 from Google's
  /// servers (permanent rejection), vs the token simply being unavailable
  /// or null (transient, e.g. startup race).
  final bool isServerRejection;

  GoogleTokenExpiredException([
    this.message = 'Google Calendar access token expired or invalid.',
    this.isServerRejection = false,
  ]);

  @override
  String toString() => message;
}

class GoogleOAuthManager {
  static const List<String> googleTasksScopes = [
    'email',
    'https://www.googleapis.com/auth/tasks',
    'https://www.googleapis.com/auth/calendar.readonly',
    'https://www.googleapis.com/auth/calendar.events',
  ];

  final ErrorHandlingService _errorHandlingService;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  bool _googleSignInInitialized = false;
  GoogleSignInAccount? _googleUser;
  Completer<String?>? _tokenRefreshCompleter;
  bool _isGoogleTasksTokenExpired = false;

  GoogleOAuthManager(this._errorHandlingService);

  bool get isGoogleTasksTokenExpired => _isGoogleTasksTokenExpired;
  GoogleSignInAccount? get googleUser => _googleUser;
  GoogleSignIn get googleSignIn => _googleSignIn;

  void setGoogleTasksTokenExpired(bool expired, {void Function()? onStateChanged}) {
    if (_isGoogleTasksTokenExpired != expired) {
      _isGoogleTasksTokenExpired = expired;
      onStateChanged?.call();
    }
  }

  Future<void> ensureGoogleSignInInitialized() async {
    if (!_googleSignInInitialized) {
      try {
        await _googleSignIn.initialize();
        _googleSignInInitialized = true;
      } catch (e) {
        AppLogger.error('Failed to initialize GoogleSignIn', error: e, tag: 'Auth');
      }
    }
  }

  void setGoogleUser(GoogleSignInAccount? user) {
    _googleUser = user;
  }

  Future<void> cacheGoogleAccessToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('google_access_token', token);
      final expiresAt = DateTime.now().add(const Duration(minutes: 55));
      await prefs.setString('google_access_token_expires_at', expiresAt.toIso8601String());
      _isGoogleTasksTokenExpired = false;
      AppLogger.info('Google Tasks access token cached successfully.', tag: 'Auth');
    } catch (e) {
      AppLogger.error('Failed to cache Google access token', error: e, tag: 'Auth');
    }
  }

  Future<String?> getGoogleAccessToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('google_access_token');
      final expiresAtStr = prefs.getString('google_access_token_expires_at');

      if (token != null && expiresAtStr != null) {
        final expiresAt = DateTime.tryParse(expiresAtStr);
        if (expiresAt != null && DateTime.now().isBefore(expiresAt)) {
          return token;
        }
      }

      // Token is expired or missing — attempt silent refresh
      if (_tokenRefreshCompleter != null) {
        return await _tokenRefreshCompleter!.future;
      }

      _tokenRefreshCompleter = Completer<String?>();
      try {
        var freshToken = await _performSilentTokenRefresh();

        // If refresh returned null and _googleUser was null (startup race),
        // wait briefly for _restoreGoogleUser() to complete, then retry once.
        if (freshToken == null && _googleUser == null) {
          await Future<void>.delayed(const Duration(milliseconds: 1500));
          freshToken = await _performSilentTokenRefresh();
        }

        _tokenRefreshCompleter!.complete(freshToken);
        return freshToken ?? token;
      } catch (e, s) {
        _tokenRefreshCompleter!.completeError(e, s);
        _errorHandlingService.logError(e, s, reason: 'getGoogleAccessToken refresh');
        return token;
      } finally {
        _tokenRefreshCompleter = null;
      }
    } catch (e, s) {
      _errorHandlingService.logError(e, s, reason: 'getGoogleAccessToken');
      return null;
    }
  }

  Future<String?> _performSilentTokenRefresh() async {
    try {
      await ensureGoogleSignInInitialized();

      if (_googleUser == null) {
        final restoredUser = await _googleSignIn.attemptLightweightAuthentication();
        _googleUser ??= restoredUser;
      }

      if (_googleUser == null) {
        AppLogger.info('Silent refresh: no Google user available.', tag: 'Auth');
        return null;
      }

      final clientAuth = await _googleUser!.authorizationClient.authorizationForScopes(googleTasksScopes);

      if (clientAuth != null && clientAuth.accessToken.isNotEmpty) {
        await cacheGoogleAccessToken(clientAuth.accessToken);
        return clientAuth.accessToken;
      }
      AppLogger.info('Silent refresh: authorizationForScopes returned null.', tag: 'Auth');
      return null;
    } catch (e) {
      AppLogger.warning('Silent Google token refresh failed: $e', tag: 'Auth');
      return null;
    }
  }

  Future<void> signOut() async {
    try {
      await ensureGoogleSignInInitialized();
      if (_googleSignIn.supportsAuthenticate()) {
        await _googleSignIn.signOut();
      }
    } catch (e) {
      AppLogger.warning('Google sign out non-critical error: $e', tag: 'Auth');
    }
    _googleUser = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('google_access_token');
    await prefs.remove('google_access_token_expires_at');
  }
}

import 'dart:async';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rocis_tasks/core/services/error_handling_service.dart';
import 'package:rocis_tasks/core/services/logger_service.dart';

import 'package:flutter/foundation.dart' show kIsWeb;

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
  static List<String> get googleTasksScopes => const [
    'email',
    'https://www.googleapis.com/auth/tasks',
    'https://www.googleapis.com/auth/calendar.readonly',
    'https://www.googleapis.com/auth/calendar.events',
  ];

  static const String keyAccessToken = 'google_access_token';
  static const String keyAccessTokenExpiresAt =
      'google_access_token_expires_at';
  static const String keyUserEmail = 'google_user_email';
  static const String keyUserId = 'google_user_id';

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

  void setGoogleTasksTokenExpired(
    bool expired, {
    void Function()? onStateChanged,
  }) {
    if (_isGoogleTasksTokenExpired != expired) {
      _isGoogleTasksTokenExpired = expired;
      onStateChanged?.call();
    }
  }

  static const String webClientId =
      '867477199658-df3ptf7v5fi66ijc5jeunfmrpf5eghou.apps.googleusercontent.com';

  Future<void> ensureGoogleSignInInitialized() async {
    if (!_googleSignInInitialized) {
      try {
        if (kIsWeb) {
          await _googleSignIn.initialize(clientId: webClientId);
        } else {
          await _googleSignIn.initialize();
        }
        _googleSignInInitialized = true;
      } catch (e) {
        AppLogger.error(
          'Failed to initialize GoogleSignIn',
          error: e,
          tag: 'Auth',
        );
      }
    }
  }

  void setGoogleUser(GoogleSignInAccount? user) {
    _googleUser = user;
    if (user != null) {
      unawaited(saveGoogleUserIdentity(email: user.email, id: user.id));
    }
  }

  Future<void> saveGoogleUserIdentity({
    required String email,
    String? id,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(keyUserEmail, email);
      if (id != null && id.isNotEmpty) {
        await prefs.setString(keyUserId, id);
      }
      AppLogger.info(
        'Saved Google user identity for background auth: $email',
        tag: 'Auth',
      );
    } catch (e) {
      AppLogger.warning('Failed to save Google user identity: $e', tag: 'Auth');
    }
  }

  Future<String?> getSavedGoogleUserEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(keyUserEmail);
    } catch (_) {
      return null;
    }
  }

  Future<String?> getSavedGoogleUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(keyUserId);
    } catch (_) {
      return null;
    }
  }

  Future<void> cacheGoogleAccessToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(keyAccessToken, token);
      // Proactive refresh window: refresh after 50 minutes (5 minutes ahead of 55m Google token expiry)
      final expiresAt = DateTime.now().add(const Duration(minutes: 50));
      await prefs.setString(
        keyAccessTokenExpiresAt,
        expiresAt.toIso8601String(),
      );
      _isGoogleTasksTokenExpired = false;
      AppLogger.info(
        'Google access token cached successfully (proactive refresh in 50m).',
        tag: 'Auth',
      );
    } catch (e) {
      AppLogger.error(
        'Failed to cache Google access token',
        error: e,
        tag: 'Auth',
      );
    }
  }

  Future<String?> getGoogleAccessToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(keyAccessToken);
      final expiresAtStr = prefs.getString(keyAccessTokenExpiresAt);

      if (token != null && expiresAtStr != null) {
        final expiresAt = DateTime.tryParse(expiresAtStr);
        if (expiresAt != null && DateTime.now().isBefore(expiresAt)) {
          return token;
        }
      }

      // Token is expired, missing, or within the 50-minute proactive refresh window
      if (_tokenRefreshCompleter != null) {
        return await _tokenRefreshCompleter!.future;
      }

      _tokenRefreshCompleter = Completer<String?>();
      try {
        final freshToken = await _performSilentTokenRefresh();

        _tokenRefreshCompleter!.complete(freshToken);
        return freshToken;
      } catch (e, s) {
        _tokenRefreshCompleter!.completeError(e, s);
        _errorHandlingService.logError(
          e,
          s,
          reason: 'getGoogleAccessToken refresh',
        );
        _isGoogleTasksTokenExpired = true;
        return null;
      } finally {
        _tokenRefreshCompleter = null;
      }
    } catch (e, s) {
      _errorHandlingService.logError(e, s, reason: 'getGoogleAccessToken');
      _isGoogleTasksTokenExpired = true;
      return null;
    }
  }

  Future<String?> _performSilentTokenRefresh() async {
    try {
      await ensureGoogleSignInInitialized();

      final prefs = await SharedPreferences.getInstance();
      final savedEmail = prefs.getString(keyUserEmail) ?? _googleUser?.email;
      final savedUserId = prefs.getString(keyUserId) ?? _googleUser?.id;

      // 1. If in-memory Google user is active, attempt silent authorization without user prompt
      if (_googleUser != null) {
        try {
          final clientAuth = await _googleUser!.authorizationClient
              .authorizationForScopes(googleTasksScopes);
          if (clientAuth != null && clientAuth.accessToken.isNotEmpty) {
            await cacheGoogleAccessToken(clientAuth.accessToken);
            _isGoogleTasksTokenExpired = false;
            return clientAuth.accessToken;
          }
        } catch (e) {
          AppLogger.info(
            'Silent refresh with in-memory user returned null or failed: $e',
            tag: 'Auth',
          );
        }
      }

      // 2. On Web, attempt non-intrusive lightweight authentication via browser cookies
      if (kIsWeb && _googleUser == null) {
        try {
          _googleUser = await _googleSignIn.attemptLightweightAuthentication();
          if (_googleUser != null) {
            final clientAuth = await _googleUser!.authorizationClient
                .authorizationForScopes(googleTasksScopes);
            if (clientAuth != null && clientAuth.accessToken.isNotEmpty) {
              await cacheGoogleAccessToken(clientAuth.accessToken);
              await saveGoogleUserIdentity(
                email: _googleUser!.email,
                id: _googleUser!.id,
              );
              _isGoogleTasksTokenExpired = false;
              return clientAuth.accessToken;
            }
          }
        } catch (e) {
          AppLogger.info('Web silent auth check failed: $e', tag: 'Auth');
        }
      }

      // 3. On Mobile (or if in-memory user was null), attempt platform authorization directly using saved email
      if (savedEmail != null && savedEmail.isNotEmpty) {
        try {
          final tokens = await GoogleSignInPlatform.instance
              .clientAuthorizationTokensForScopes(
                ClientAuthorizationTokensForScopesParameters(
                  request: AuthorizationRequestDetails(
                    scopes: googleTasksScopes,
                    userId: savedUserId,
                    email: savedEmail,
                    promptIfUnauthorized: false,
                  ),
                ),
              );

          if (tokens != null && tokens.accessToken.isNotEmpty) {
            await cacheGoogleAccessToken(tokens.accessToken);
            _isGoogleTasksTokenExpired = false;
            AppLogger.info(
              'Silent refresh: successfully acquired fresh token via platform authorization.',
              tag: 'Auth',
            );
            return tokens.accessToken;
          }
        } catch (e) {
          AppLogger.info(
            'Silent refresh via platform authorization failed: $e',
            tag: 'Auth',
          );
        }
      }

      // 4. Background refresh failed (e.g. offline, connection lost, or permission revoked).
      // Mark disconnected and never trigger interactive dialogs during background operations.
      AppLogger.info(
        'Silent refresh could not acquire token. Marking disconnected without interactive prompts.',
        tag: 'Auth',
      );
      _isGoogleTasksTokenExpired = true;
      return null;
    } catch (e) {
      AppLogger.warning('Silent Google token refresh failed: $e', tag: 'Auth');
      _isGoogleTasksTokenExpired = true;
      return null;
    }
  }

  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    final currentToken = prefs.getString(keyAccessToken);

    if (currentToken != null && currentToken.isNotEmpty) {
      try {
        await GoogleSignInPlatform.instance.clearAuthorizationToken(
          ClearAuthorizationTokenParams(accessToken: currentToken),
        );
        AppLogger.info(
          'Cleared Google authorization token to prevent stale token reuse.',
          tag: 'Auth',
        );
      } catch (e) {
        AppLogger.warning(
          'Google clearAuthorizationToken non-critical error: $e',
          tag: 'Auth',
        );
      }
    }

    try {
      await ensureGoogleSignInInitialized();
      if (_googleSignIn.supportsAuthenticate()) {
        await _googleSignIn.signOut();
      }
    } catch (e) {
      AppLogger.warning('Google sign out non-critical error: $e', tag: 'Auth');
    }

    _googleUser = null;
    _isGoogleTasksTokenExpired = false;

    await prefs.remove(keyAccessToken);
    await prefs.remove(keyAccessTokenExpiresAt);
    await prefs.remove(keyUserEmail);
    await prefs.remove(keyUserId);
  }
}

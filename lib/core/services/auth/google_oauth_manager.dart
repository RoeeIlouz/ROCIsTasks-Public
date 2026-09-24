import 'dart:async';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rocis_tasks/core/services/error_handling_service.dart';
import 'package:rocis_tasks/core/services/logger_service.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:rocis_tasks/core/services/web/cookie_service.dart';

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
          // Provide serverClientId on mobile so Google Play Services / Credential Manager
          // associates authorization with the OAuth backend client and permits silent background refreshes.
          await _googleSignIn.initialize(serverClientId: webClientId);
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
      } else {
        await prefs.remove(keyUserId);
      }
      if (kIsWeb) {
        CookieService.instance.setCookie(
          keyUserEmail,
          email,
          maxAge: const Duration(days: 365),
        );
        if (id != null && id.isNotEmpty) {
          CookieService.instance.setCookie(
            keyUserId,
            id,
            maxAge: const Duration(days: 365),
          );
        } else {
          CookieService.instance.deleteCookie(keyUserId);
        }
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
      final email = prefs.getString(keyUserEmail);
      if (email != null && email.isNotEmpty) return email;
      if (kIsWeb) {
        return CookieService.instance.getCookie(keyUserEmail);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<String?> getSavedGoogleUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getString(keyUserId);
      if (id != null && id.isNotEmpty) return id;
      if (kIsWeb) {
        return CookieService.instance.getCookie(keyUserId);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Checks if any Google credentials (cached token or saved user email) exist in persistent storage.
  Future<bool> hasCachedGoogleCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasCachedToken = prefs.containsKey(keyAccessToken);
      final hasSavedEmail = prefs.containsKey(keyUserEmail);
      if (hasCachedToken || hasSavedEmail) return true;
      if (kIsWeb) {
        return CookieService.instance.getCookie(keyAccessToken) != null ||
            CookieService.instance.getCookie(keyUserEmail) != null;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Checks if the currently cached Google access token is present and not expired.
  Future<bool> isTokenValid() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var token = prefs.getString(keyAccessToken);
      var expiresAtStr = prefs.getString(keyAccessTokenExpiresAt);

      if (token == null && kIsWeb) {
        token = CookieService.instance.getCookie(keyAccessToken);
        expiresAtStr = CookieService.instance.getCookie(
          keyAccessTokenExpiresAt,
        );
        if (token != null && expiresAtStr != null) {
          await prefs.setString(keyAccessToken, token);
          await prefs.setString(keyAccessTokenExpiresAt, expiresAtStr);
        }
      }

      if (token == null || expiresAtStr == null) return false;
      final expiresAt = DateTime.tryParse(expiresAtStr);
      return expiresAt != null && DateTime.now().isBefore(expiresAt);
    } catch (_) {
      return false;
    }
  }

  Future<void> cacheGoogleAccessToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(keyAccessToken, token);
      // Proactive refresh window: refresh after 50 minutes (5 minutes ahead of 55m Google token expiry)
      final expiresAt = DateTime.now().add(const Duration(minutes: 50));
      final expiresAtStr = expiresAt.toIso8601String();
      await prefs.setString(keyAccessTokenExpiresAt, expiresAtStr);

      if (kIsWeb) {
        CookieService.instance.setCookie(
          keyAccessToken,
          token,
          maxAge: const Duration(days: 30),
        );
        CookieService.instance.setCookie(
          keyAccessTokenExpiresAt,
          expiresAtStr,
          maxAge: const Duration(days: 30),
        );
      }

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

  Future<void> invalidateToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(keyAccessToken);
      await prefs.remove(keyAccessTokenExpiresAt);
      if (kIsWeb) {
        CookieService.instance.deleteCookie(keyAccessToken);
        CookieService.instance.deleteCookie(keyAccessTokenExpiresAt);
      }
      _isGoogleTasksTokenExpired = true;
      AppLogger.info('Cached Google access token invalidated.', tag: 'Auth');
    } catch (e) {
      AppLogger.warning(
        'Failed to invalidate Google access token: $e',
        tag: 'Auth',
      );
    }
  }

  Future<String?> getGoogleAccessToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var token = prefs.getString(keyAccessToken);
      var expiresAtStr = prefs.getString(keyAccessTokenExpiresAt);

      // Web cookie backup restoration
      if (kIsWeb) {
        final cookieToken = CookieService.instance.getCookie(keyAccessToken);
        final cookieExpires = CookieService.instance.getCookie(
          keyAccessTokenExpiresAt,
        );
        if (cookieToken != null && cookieToken.isNotEmpty) {
          token ??= cookieToken;
          expiresAtStr ??= cookieExpires;
          await prefs.setString(keyAccessToken, cookieToken);
          if (cookieExpires != null) {
            await prefs.setString(keyAccessTokenExpiresAt, cookieExpires);
          }
        }
      }

      if (token != null && token.isNotEmpty) {
        if (expiresAtStr != null) {
          final expiresAt = DateTime.tryParse(expiresAtStr);
          if (expiresAt != null && DateTime.now().isBefore(expiresAt)) {
            return token;
          }
        }

        // Token may be near or past 50m expiry — attempt silent background refresh
        if (_tokenRefreshCompleter != null) {
          return await _tokenRefreshCompleter!.future;
        }

        _tokenRefreshCompleter = Completer<String?>();
        try {
          final freshToken = await _performSilentTokenRefresh();
          if (freshToken != null && freshToken.isNotEmpty) {
            _isGoogleTasksTokenExpired = false;
            _tokenRefreshCompleter!.complete(freshToken);
            return freshToken;
          }

          // On Web & Mobile: Preserve cached token from cookie/storage under grace.
          // NEVER mark as expired or show reconnect prompt while a cached token exists.
          _isGoogleTasksTokenExpired = false;
          _tokenRefreshCompleter!.complete(token);
          return token;
        } catch (e, s) {
          _errorHandlingService.logError(
            e,
            s,
            reason: 'getGoogleAccessToken refresh',
          );
          _isGoogleTasksTokenExpired = false;
          _tokenRefreshCompleter?.complete(token);
          return token;
        } finally {
          _tokenRefreshCompleter = null;
        }
      }

      // No token in prefs or cookies — attempt silent refresh using saved identity
      if (_tokenRefreshCompleter != null) {
        return await _tokenRefreshCompleter!.future;
      }

      _tokenRefreshCompleter = Completer<String?>();
      try {
        final freshToken = await _performSilentTokenRefresh();
        if (freshToken != null && freshToken.isNotEmpty) {
          _isGoogleTasksTokenExpired = false;
          _tokenRefreshCompleter!.complete(freshToken);
          return freshToken;
        }

        _isGoogleTasksTokenExpired = !kIsWeb;
        _tokenRefreshCompleter!.complete(null);
        return null;
      } catch (e, s) {
        _errorHandlingService.logError(
          e,
          s,
          reason: 'getGoogleAccessToken no-token refresh',
        );
        _isGoogleTasksTokenExpired = !kIsWeb;
        _tokenRefreshCompleter?.complete(null);
        return null;
      } finally {
        _tokenRefreshCompleter = null;
      }
    } catch (e, s) {
      _errorHandlingService.logError(e, s, reason: 'getGoogleAccessToken');
      _isGoogleTasksTokenExpired = !kIsWeb;
      return null;
    }
  }

  Future<String?> _performSilentTokenRefresh() async {
    try {
      await ensureGoogleSignInInitialized();

      final savedEmail = await getSavedGoogleUserEmail() ?? _googleUser?.email;
      final savedUserId = await getSavedGoogleUserId() ?? _googleUser?.id;

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

      // 3. Attempt platform authorization directly using saved identity (supported across Mobile & Web in google_sign_in 7.x)
      if (savedEmail != null && savedEmail.isNotEmpty) {
        try {
          final tokens = await GoogleSignInPlatform.instance
              .clientAuthorizationTokensForScopes(
                ClientAuthorizationTokensForScopesParameters(
                  request: AuthorizationRequestDetails(
                    scopes: googleTasksScopes,
                    userId:
                        (kIsWeb &&
                            savedUserId != null &&
                            !RegExp(r'^\d+$').hasMatch(savedUserId))
                        ? null
                        : savedUserId,
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

      // 4. Background refresh failed (offline, timeout, etc.)
      // Return null so caller can decide on offline grace fallback.
      AppLogger.info(
        'Silent refresh could not acquire fresh token without prompt.',
        tag: 'Auth',
      );
      return null;
    } catch (e) {
      AppLogger.warning('Silent Google token refresh failed: $e', tag: 'Auth');
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

    if (kIsWeb) {
      CookieService.instance.deleteCookie(keyAccessToken);
      CookieService.instance.deleteCookie(keyAccessTokenExpiresAt);
      CookieService.instance.deleteCookie(keyUserEmail);
      CookieService.instance.deleteCookie(keyUserId);
    }
  }
}

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:rocis_tasks/core/services/auth/google_oauth_manager.dart';
import 'package:rocis_tasks/core/services/encryption_service.dart';
import 'package:rocis_tasks/core/services/error_handling_service.dart';
import 'package:rocis_tasks/core/services/logger_service.dart';

export 'package:rocis_tasks/core/services/auth/google_oauth_manager.dart'
    show GoogleTokenExpiredException;

class AuthService extends ChangeNotifier {
  final ErrorHandlingService _errorHandlingService;
  late final GoogleOAuthManager _oauthManager;

  GoogleOAuthManager get oauthManager => _oauthManager;

  FirebaseAuth get _auth => FirebaseAuth.instance;
  final Completer<void> _initCompleter = Completer<void>();

  bool get isGoogleTasksTokenExpired {
    final isGoogleUser =
        currentUser?.providerData.any((p) => p.providerId == 'google.com') ??
        false;
    return isGoogleUser && _oauthManager.isGoogleTasksTokenExpired;
  }

  void setGoogleTasksTokenExpired(bool expired) {
    _oauthManager.setGoogleTasksTokenExpired(
      expired,
      onStateChanged: notifyListeners,
    );
  }

  Future<void> handleTokenRevokedOrExpired() async {
    await _oauthManager.invalidateToken();
    setGoogleTasksTokenExpired(true);
  }

  Future<void> get initialized => _initCompleter.future;

  FirebaseAuth? _scheduleAuth;
  final ValueNotifier<String?> scheduleAuthError = ValueNotifier<String?>(null);
  StreamSubscription<User?>? _authStateSubscription;

  AuthService(this._errorHandlingService) {
    _oauthManager = GoogleOAuthManager(_errorHandlingService);
    _initAuth();
  }

  Future<void> _initAuth() async {
    _authStateSubscription = _auth.authStateChanges().listen((User? user) {
      if (user != null) {
        unawaited(_syncEncryptionKey(user.uid));
        unawaited(ensureSecondaryAuth());
        unawaited(_restoreGoogleUser());
      }

      if (!_initCompleter.isCompleted) {
        _initCompleter.complete();
      }

      notifyListeners();
    });
  }

  /// Proactively restores Google auth state on startup so that
  /// [_performSilentTokenRefresh] can refresh tokens in the background without
  /// requiring user intervention.
  Future<void> _restoreGoogleUser() async {
    if (_oauthManager.googleUser != null) return;
    try {
      final user = currentUser;
      if (user == null) return;

      final isGoogleUser = user.providerData.any(
        (p) => p.providerId == 'google.com',
      );
      final hasCredentials = await _oauthManager.hasCachedGoogleCredentials();
      final isTokenValid = await _oauthManager.isTokenValid();

      // Only attempt startup restoration if user signed in via Google
      // or has linked Google Tasks/Calendar, avoiding unwanted attempts for Email/Password users.
      if (!isGoogleUser && !hasCredentials) {
        return;
      }

      // If email is not yet saved but Firebase user is a Google user, persist it
      final savedEmail = await _oauthManager.getSavedGoogleUserEmail();
      if (savedEmail == null && isGoogleUser && user.email != null) {
        await _oauthManager.saveGoogleUserIdentity(
          email: user.email!,
          id: user.uid,
        );
      }

      await _oauthManager.ensureGoogleSignInInitialized();

      if (kIsWeb) {
        // On Web: first check if we have a valid cached token (localStorage)
        if (isTokenValid) {
          setGoogleTasksTokenExpired(false);
          AppLogger.info(
            'Web startup: Valid cached Google token found.',
            tag: 'Auth',
          );
          // Still try to restore GIS user for future silent refreshes
          try {
            final restored = await _oauthManager.googleSignIn
                .attemptLightweightAuthentication();
            if (restored != null) {
              _oauthManager.setGoogleUser(restored);
            }
          } catch (_) {}
          return;
        }

        // Cached token is missing or expired — try GIS silent restoration
        try {
          final restored = await _oauthManager.googleSignIn
              .attemptLightweightAuthentication();
          if (restored != null) {
            _oauthManager.setGoogleUser(restored);
            await _oauthManager.saveGoogleUserIdentity(
              email: restored.email,
              id: restored.id,
            );
            AppLogger.info(
              'Web startup: GIS user restored: ${restored.email}',
              tag: 'Auth',
            );

            // Try non-interactive scope authorization (succeeds if user previously granted)
            final clientAuth = await restored.authorizationClient
                .authorizationForScopes(GoogleOAuthManager.googleTasksScopes);
            if (clientAuth != null && clientAuth.accessToken.isNotEmpty) {
              await _oauthManager.cacheGoogleAccessToken(
                clientAuth.accessToken,
              );
              setGoogleTasksTokenExpired(false);
              AppLogger.info(
                'Web startup: Token silently refreshed via GIS.',
                tag: 'Auth',
              );
              return;
            }
          }
        } catch (e) {
          AppLogger.info(
            'Web startup: GIS silent auth/authorization failed: $e',
            tag: 'Auth',
          );
        }

        // All silent methods failed — mark as expired so banner shows
        setGoogleTasksTokenExpired(true);
        AppLogger.info(
          'Web startup: No valid token available. Reconnect banner will show.',
          tag: 'Auth',
        );
      } else {
        // On Mobile, NEVER call attemptLightweightAuthentication() on cold start,
        // because Credential Manager pops up an interactive account-selection bottom sheet.
        // If the token is already valid, mark unexpired and proceed silently.
        if (isTokenValid) {
          setGoogleTasksTokenExpired(false);
          AppLogger.info(
            'Valid cached Google token present on startup.',
            tag: 'Auth',
          );
        } else {
          // If token is missing or expired, quietly refresh in background via getGoogleAccessToken()
          final freshToken = await _oauthManager.getGoogleAccessToken();
          if (freshToken != null && freshToken.isNotEmpty) {
            setGoogleTasksTokenExpired(false);
            AppLogger.info(
              'Silently restored and refreshed Google token on startup.',
              tag: 'Auth',
            );
          } else {
            setGoogleTasksTokenExpired(true);
            AppLogger.info(
              'Google token expired on startup; reconnect banner active.',
              tag: 'Auth',
            );
          }
        }
      }
    } catch (e) {
      AppLogger.warning(
        'Could not restore Google user on startup: $e',
        tag: 'Auth',
      );
    }
  }

  Future<String?> _resolveWebGoogleAccessToken({String? popupToken}) async {
    if (!kIsWeb) return popupToken;

    // Step 1: If Firebase popup gave us a usable token, use it directly
    if (popupToken != null && popupToken.isNotEmpty) {
      AppLogger.info(
        'Web: Using access token from Firebase popup.',
        tag: 'Auth',
      );
      return popupToken;
    }

    // Step 2: Try to establish GIS user session via lightweight auth (One Tap)
    if (_oauthManager.googleUser == null) {
      try {
        await _oauthManager.ensureGoogleSignInInitialized();
        final restored = await _oauthManager.googleSignIn
            .attemptLightweightAuthentication();
        if (restored != null) {
          _oauthManager.setGoogleUser(restored);
          AppLogger.info(
            'Web: GIS lightweight auth restored user: ${restored.email}',
            tag: 'Auth',
          );
        } else {
          AppLogger.info(
            'Web: GIS lightweight auth returned null (no prior GIS session).',
            tag: 'Auth',
          );
        }
      } catch (e) {
        AppLogger.warning('Web: GIS lightweight auth failed: $e', tag: 'Auth');
      }
    }

    // Step 3: If we have a GIS user, try non-interactive then interactive authorization
    if (_oauthManager.googleUser != null) {
      // 3a: Try non-interactive (silent) — succeeds if user previously granted scopes
      try {
        final clientAuth = await _oauthManager.googleUser!.authorizationClient
            .authorizationForScopes(GoogleOAuthManager.googleTasksScopes);
        if (clientAuth != null && clientAuth.accessToken.isNotEmpty) {
          AppLogger.info(
            'Web: Got token via GIS silent authorizationForScopes.',
            tag: 'Auth',
          );
          return clientAuth.accessToken;
        }
      } catch (e) {
        AppLogger.info(
          'Web: GIS silent authorizationForScopes failed: $e',
          tag: 'Auth',
        );
      }

      // 3b: Interactive authorization (GIS consent popup)
      try {
        AppLogger.info(
          'Web: Requesting interactive GIS authorizeScopes...',
          tag: 'Auth',
        );
        final clientAuth = await _oauthManager.googleUser!.authorizationClient
            .authorizeScopes(GoogleOAuthManager.googleTasksScopes);
        if (clientAuth.accessToken.isNotEmpty) {
          AppLogger.info(
            'Web: Got token via GIS interactive authorizeScopes.',
            tag: 'Auth',
          );
          return clientAuth.accessToken;
        }
      } catch (e) {
        AppLogger.warning(
          'Web: GIS interactive authorizeScopes failed: $e',
          tag: 'Auth',
        );
      }
    }

    // Step 4: Last resort — check SharedPreferences cache
    AppLogger.warning(
      'Web: All token resolution attempts failed.',
      tag: 'Auth',
    );
    return null;
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    scheduleAuthError.dispose();
    super.dispose();
  }

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  FirebaseAuth? get scheduleAuth => _scheduleAuth;

  bool get isAuthenticatedInSchedule => _scheduleAuth?.currentUser != null;

  Future<UserCredential?> signInWithGoogle() async {
    if (kIsWeb) {
      try {
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        for (final scope in GoogleOAuthManager.googleTasksScopes) {
          if (scope != 'email' && scope != 'profile') {
            googleProvider.addScope(scope);
          }
        }
        // Force consent so Google issues access tokens with all required scopes.
        googleProvider.setCustomParameters({'prompt': 'consent'});

        final UserCredential userCredential = await _auth.signInWithPopup(
          googleProvider,
        );
        final OAuthCredential? oAuthCred =
            userCredential.credential as OAuthCredential?;
        final resolvedToken = await _resolveWebGoogleAccessToken(
          popupToken: oAuthCred?.accessToken,
        );

        if (resolvedToken != null && resolvedToken.isNotEmpty) {
          await _oauthManager.cacheGoogleAccessToken(resolvedToken);
          setGoogleTasksTokenExpired(false);
          AppLogger.info(
            'Web sign-in: Google API access token acquired and cached.',
            tag: 'Auth',
          );
        } else {
          AppLogger.warning(
            'Web sign-in: Could not acquire Google API access token. Calendar/Tasks will show disconnected.',
            tag: 'Auth',
          );
          setGoogleTasksTokenExpired(true);
        }

        // Save identity for GIS restoration on future page loads
        if (userCredential.user?.email != null) {
          await _oauthManager.saveGoogleUserIdentity(
            email: userCredential.user!.email!,
            id: userCredential.user!.uid,
          );
        }

        if (userCredential.user != null) {
          await _syncEncryptionKey(userCredential.user!.uid);
        }

        notifyListeners();
        return userCredential;
      } catch (webErr, webStack) {
        _errorHandlingService.logError(
          webErr,
          webStack,
          reason: 'Sign in with Google Web Popup',
        );
        return null;
      }
    }

    try {
      await _oauthManager.ensureGoogleSignInInitialized();

      GoogleSignInAccount? googleUser = _oauthManager.googleUser;
      if (googleUser == null) {
        googleUser = await _oauthManager.googleSignIn.authenticate(
          scopeHint: GoogleOAuthManager.googleTasksScopes,
        );
        _oauthManager.setGoogleUser(googleUser);
      }
      await _oauthManager.saveGoogleUserIdentity(
        email: googleUser.email,
        id: googleUser.id,
      );

      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      var clientAuth = await googleUser.authorizationClient
          .authorizationForScopes(GoogleOAuthManager.googleTasksScopes);
      clientAuth ??= await googleUser.authorizationClient.authorizeScopes(
        GoogleOAuthManager.googleTasksScopes,
      );

      final String accessToken = clientAuth.accessToken;
      if (accessToken.isNotEmpty) {
        await _oauthManager.cacheGoogleAccessToken(accessToken);
      }

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: accessToken.isNotEmpty ? accessToken : null,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );

      if (userCredential.user != null) {
        AppLogger.info(
          'Sign in with Google successful. Starting critical key sync...',
          tag: 'Auth',
        );
        await _syncEncryptionKey(userCredential.user!.uid);
        AppLogger.info('Key sync complete.', tag: 'Auth');
      }

      await _signInToSecondaryFirebase(credential);

      notifyListeners();
      return userCredential;
    } catch (e, s) {
      _errorHandlingService.logError(e, s, reason: 'Sign in with Google');
      return null;
    }
  }

  Future<UserCredential?> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      final UserCredential userCredential = await _auth
          .signInWithEmailAndPassword(email: email, password: password);

      if (userCredential.user != null) {
        AppLogger.info(
          'Email sign in successful. Starting critical key sync...',
          tag: 'Auth',
        );
        await _syncEncryptionKey(userCredential.user!.uid);
        AppLogger.info('Key sync complete.', tag: 'Auth');
      }

      await _signInToSecondaryFirebaseWithEmail(email, password);

      notifyListeners();
      return userCredential;
    } catch (e, s) {
      _errorHandlingService.logError(e, s, reason: 'Sign in with Email');
      rethrow;
    }
  }

  Future<UserCredential?> signUpWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      final UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);

      if (userCredential.user != null) {
        AppLogger.info(
          'Email sign up successful. Starting critical key sync...',
          tag: 'Auth',
        );
        await _syncEncryptionKey(userCredential.user!.uid);
        AppLogger.info('Key sync complete.', tag: 'Auth');
      }

      await _signUpToSecondaryFirebaseWithEmail(email, password);

      notifyListeners();
      return userCredential;
    } catch (e, s) {
      _errorHandlingService.logError(e, s, reason: 'Sign up with Email');
      rethrow;
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e, s) {
      _errorHandlingService.logError(e, s, reason: 'Send password reset email');
      rethrow;
    }
  }

  Future<void> _syncEncryptionKey(String userId) async {
    try {
      final userSettingsRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('settings')
          .doc('security');

      final doc = await userSettingsRef.get();
      final localKey = await EncryptionService.getKey();

      if (doc.exists &&
          doc.data() != null &&
          doc.data()!.containsKey('encryptionKey')) {
        final cloudKey = doc.data()!['encryptionKey'] as String;

        if (localKey != cloudKey) {
          AppLogger.info(
            'Restoring encryption key from cloud backup',
            tag: 'Auth',
          );
          await EncryptionService.setKey(cloudKey);
        }
      } else {
        if (localKey != null) {
          AppLogger.info('Backing up encryption key to cloud', tag: 'Auth');
          await userSettingsRef.set({
            'encryptionKey': localKey,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      }
    } catch (e) {
      AppLogger.error('Key sync failed', error: e, tag: 'Auth');
    }
  }

  Future<void> _signInToSecondaryFirebase(AuthCredential credential) async {
    if (kIsWeb) return;
    try {
      final scheduleApp = Firebase.app('rocis-schedule');
      _scheduleAuth = FirebaseAuth.instanceFor(app: scheduleApp);

      await _scheduleAuth!.signInWithCredential(credential);
      AppLogger.info(
        'Signed in to secondary Firebase (rocis-schedule) successfully',
        tag: 'Auth',
      );
    } catch (e) {
      AppLogger.warning(
        'Failed to sign in to secondary Firebase',
        error: e,
        tag: 'Auth',
      );
      _scheduleAuth = null;
      scheduleAuthError.value =
          'Schedule sync unavailable. Some features may be limited.';
    }
  }

  Future<void> _signInToSecondaryFirebaseWithEmail(
    String email,
    String password,
  ) async {
    if (kIsWeb) return;
    try {
      final scheduleApp = Firebase.app('rocis-schedule');
      _scheduleAuth = FirebaseAuth.instanceFor(app: scheduleApp);
      await _scheduleAuth!.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      AppLogger.info('Signed in to secondary Firebase with Email', tag: 'Auth');
    } catch (e) {
      AppLogger.warning(
        'Failed to sign in to secondary Firebase with Email',
        error: e,
        tag: 'Auth',
      );
      _scheduleAuth = null;
      scheduleAuthError.value =
          'Schedule sync unavailable. Some features may be limited.';
    }
  }

  Future<void> _signUpToSecondaryFirebaseWithEmail(
    String email,
    String password,
  ) async {
    if (kIsWeb) return;
    try {
      final scheduleApp = Firebase.app('rocis-schedule');
      _scheduleAuth = FirebaseAuth.instanceFor(app: scheduleApp);
      await _scheduleAuth!.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      AppLogger.info('Signed up to secondary Firebase with Email', tag: 'Auth');
    } catch (e) {
      AppLogger.warning(
        'Failed to sign up to secondary Firebase with Email',
        error: e,
        tag: 'Auth',
      );
    }
  }

  Future<void> ensureSecondaryAuth() async {
    if (kIsWeb) return;
    try {
      final scheduleApp = Firebase.app('rocis-schedule');
      _scheduleAuth ??= FirebaseAuth.instanceFor(app: scheduleApp);
    } catch (_) {
      _scheduleAuth = null;
    }

    if (_scheduleAuth?.currentUser != null) {
      scheduleAuthError.value = null;
      return;
    }

    if (_auth.currentUser != null && _oauthManager.googleUser != null) {
      try {
        final googleUser = _oauthManager.googleUser!;
        final googleAuth = googleUser.authentication;
        final clientAuth = await googleUser.authorizationClient
            .authorizationForScopes(['email', 'profile']);
        final credential = GoogleAuthProvider.credential(
          accessToken: clientAuth?.accessToken,
          idToken: googleAuth.idToken,
        );
        await _signInToSecondaryFirebase(credential);
        if (_scheduleAuth?.currentUser != null) {
          scheduleAuthError.value = null;
        }
      } catch (e) {
        AppLogger.warning(
          'Failed to re-authenticate to secondary Firebase',
          error: e,
          tag: 'Auth',
        );
        scheduleAuthError.value =
            'Schedule sync unavailable. Some features may be limited.';
      }
    }
  }

  Future<bool> linkGoogleTasks() async {
    if (kIsWeb) {
      try {
        final user = currentUser;
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        for (final scope in GoogleOAuthManager.googleTasksScopes) {
          if (scope != 'email' && scope != 'profile') {
            googleProvider.addScope(scope);
          }
        }
        // Force consent so reconnect flow can recover missing calendar/task scopes.
        googleProvider.setCustomParameters({'prompt': 'consent'});

        AppLogger.info(
          'Opening Google popup to refresh access token on Web...',
          tag: 'Auth',
        );
        UserCredential userCredential;
        if (user != null) {
          try {
            userCredential = await user.reauthenticateWithPopup(googleProvider);
          } catch (_) {
            try {
              userCredential = await user.linkWithPopup(googleProvider);
            } catch (_) {
              userCredential = await _auth.signInWithPopup(googleProvider);
            }
          }
        } else {
          userCredential = await _auth.signInWithPopup(googleProvider);
        }

        final OAuthCredential? oAuthCred =
            userCredential.credential as OAuthCredential?;
        final resolvedToken = await _resolveWebGoogleAccessToken(
          popupToken: oAuthCred?.accessToken,
        );

        if (resolvedToken != null && resolvedToken.isNotEmpty) {
          await _oauthManager.cacheGoogleAccessToken(resolvedToken);
          setGoogleTasksTokenExpired(false);
          notifyListeners();
          return true;
        }
      } catch (e, s) {
        AppLogger.error(
          'Error refreshing Google Tasks access token on Web',
          error: e,
          stack: s,
          tag: 'Auth',
        );
      }
      return false;
    } else {
      try {
        await _oauthManager.ensureGoogleSignInInitialized();

        GoogleSignInAccount? googleUser = _oauthManager.googleUser;
        googleUser ??= await _oauthManager.googleSignIn.authenticate(
          scopeHint: GoogleOAuthManager.googleTasksScopes,
        );
        _oauthManager.setGoogleUser(googleUser);

        var clientAuth = await googleUser.authorizationClient
            .authorizationForScopes(GoogleOAuthManager.googleTasksScopes);
        if (clientAuth == null || clientAuth.accessToken.isEmpty) {
          clientAuth = await googleUser.authorizationClient.authorizeScopes(
            GoogleOAuthManager.googleTasksScopes,
          );
        }

        if (clientAuth.accessToken.isNotEmpty) {
          await _oauthManager.cacheGoogleAccessToken(clientAuth.accessToken);
          await _oauthManager.saveGoogleUserIdentity(
            email: googleUser.email,
            id: googleUser.id,
          );

          AppLogger.info(
            'Mobile Google Tasks & Calendar authorized. Token cached.',
            tag: 'Auth',
          );
          setGoogleTasksTokenExpired(false);
          notifyListeners();
          return true;
        }
      } catch (e, s) {
        AppLogger.error(
          'Error authorizing Google Tasks access token on Mobile',
          error: e,
          stack: s,
          tag: 'Auth',
        );
      }
      return false;
    }
  }

  @Deprecated('Use linkGoogleTasks() instead')
  Future<bool> linkGoogleTasksOnWeb() => linkGoogleTasks();

  Future<void> signOut() async {
    try {
      await _scheduleAuth?.signOut();
      _scheduleAuth = null;

      await _oauthManager.signOut();

      await _auth.signOut();
      notifyListeners();
    } catch (e, s) {
      _errorHandlingService.logError(e, s, reason: 'Sign out');
    }
  }

  Future<bool> deleteAccount({String? password}) async {
    final user = currentUser;
    if (user == null) return false;

    try {
      final userId = user.uid;
      final firestore = FirebaseFirestore.instance;

      final recentLoginOk = await _ensureRecentLoginForDestructiveAction(
        user,
        password: password,
      );
      if (!recentLoginOk) {
        return false;
      }

      final tasks = await firestore
          .collection('users')
          .doc(userId)
          .collection('tasks')
          .get();
      for (final doc in tasks.docs) {
        await doc.reference.delete();
      }

      final categories = await firestore
          .collection('users')
          .doc(userId)
          .collection('categories')
          .get();
      for (final doc in categories.docs) {
        await doc.reference.delete();
      }

      final settings = await firestore
          .collection('users')
          .doc(userId)
          .collection('settings')
          .get();
      for (final doc in settings.docs) {
        await doc.reference.delete();
      }

      await firestore.collection('users').doc(userId).delete();

      try {
        await user.delete();
      } on FirebaseAuthException catch (e) {
        if (_isRecentLoginRequired(e)) {
          final reauthed = await _ensureRecentLoginForDestructiveAction(
            user,
            password: password,
          );
          if (!reauthed) return false;
          await user.delete();
        } else {
          rethrow;
        }
      }

      await signOut();
      AppLogger.info('Account and data deleted successfully', tag: 'Auth');
      return true;
    } catch (e, s) {
      _errorHandlingService.logError(e, s, reason: 'Delete account');
      return false;
    }
  }

  bool _isRecentLoginRequired(FirebaseAuthException e) {
    final code = e.code.toLowerCase();
    return code == 'requires-recent-login' || code == 'recent-login-required';
  }

  Future<bool> _ensureRecentLoginForDestructiveAction(
    User user, {
    String? password,
  }) async {
    final providerIds = user.providerData.map((p) => p.providerId).toSet();
    if (providerIds.contains('google.com')) {
      try {
        if (kIsWeb) {
          final GoogleAuthProvider googleProvider = GoogleAuthProvider();
          await user.reauthenticateWithPopup(googleProvider);
          return true;
        }

        final GoogleSignInAccount? googleUser = await _oauthManager.googleSignIn
            .attemptLightweightAuthentication();
        if (googleUser == null) return false;
        final GoogleSignInAuthentication googleAuth = googleUser.authentication;
        final clientAuth = await googleUser.authorizationClient
            .authorizationForScopes(['email', 'profile']);
        final credential = GoogleAuthProvider.credential(
          accessToken: clientAuth?.accessToken,
          idToken: googleAuth.idToken,
        );
        await user.reauthenticateWithCredential(credential);
        return true;
      } catch (e) {
        AppLogger.warning(
          'Google re-authentication failed for destructive action',
          error: e,
          tag: 'Auth',
        );
        return false;
      }
    }

    if (providerIds.contains('password')) {
      final email = user.email;
      final normalizedPassword = password?.trim();
      if (email == null || email.isEmpty) return false;
      if (normalizedPassword == null || normalizedPassword.isEmpty) {
        return false;
      }
      try {
        final credential = EmailAuthProvider.credential(
          email: email,
          password: normalizedPassword,
        );
        await user.reauthenticateWithCredential(credential);
        return true;
      } catch (e) {
        AppLogger.warning(
          'Password re-authentication failed for destructive action',
          error: e,
          tag: 'Auth',
        );
        return false;
      }
    }

    return false;
  }

  Future<String?> getGoogleAccessToken() async {
    return _oauthManager.getGoogleAccessToken();
  }
}

import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:rocis_tasks/core/services/error_handling_service.dart';
import 'package:rocis_tasks/core/services/logger_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rocis_tasks/core/services/encryption_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GoogleTokenExpiredException implements Exception {
  final String message;
  GoogleTokenExpiredException([this.message = 'Google Calendar access token expired or invalid.']);
  
  @override
  String toString() => message;
}

class AuthService extends ChangeNotifier {
  final ErrorHandlingService _errorHandlingService;
  FirebaseAuth get _auth => FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  bool _googleSignInInitialized = false;
  GoogleSignInAccount? _googleUser;
  final Completer<void> _initCompleter = Completer<void>();
  bool _isGoogleTasksTokenExpired = false;

  bool get isGoogleTasksTokenExpired => _isGoogleTasksTokenExpired;

  void setGoogleTasksTokenExpired(bool expired) {
    if (_isGoogleTasksTokenExpired != expired) {
      _isGoogleTasksTokenExpired = expired;
      notifyListeners();
    }
  }

  /// Future that completes when the first auth state has been determined
  Future<void> get initialized => _initCompleter.future;

  // Secondary Firebase Auth for ROCIs-Schedule
  FirebaseAuth? _scheduleAuth;

  /// Exposes secondary auth errors so UI can show a non-blocking banner.
  /// null means no error.
  final ValueNotifier<String?> scheduleAuthError = ValueNotifier<String?>(null);

  StreamSubscription<User?>? _authStateSubscription;

  AuthService(this._errorHandlingService) {
    _initAuth();
  }

  Future<void> _initAuth() async {
    // On Web, explicitly set persistence so the session survives page refresh.
    // Android/iOS handle persistence natively — no extra config needed.
    if (kIsWeb) {
      // No need to set persistence explicitly — Firebase Auth uses local
      // persistence (indexedDB) by default on web, and native persistence
      // on mobile. The old setPersistence() method was removed from the SDK.
    }

    _authStateSubscription = _auth.authStateChanges().listen((User? user) {
      if (user != null) {
        unawaited(_syncEncryptionKey(user.uid));
        unawaited(ensureSecondaryAuth());
        if (!kIsWeb) {
          unawaited(_restoreGoogleSignInSession(user));
        }
      }

      // Complete init on the FIRST auth state event.
      // On Android/iOS, the first event from authStateChanges() IS the
      // persisted auth state — either the restored user or truly null.
      // Using a timer here caused a race: the timer could fire before
      // Firebase emitted the restored session, flashing the login screen.
      if (!_initCompleter.isCompleted) {
        _initCompleter.complete();
      }

      notifyListeners();
    });
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    scheduleAuthError.dispose();
    super.dispose();
  }

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Get the secondary Firebase Auth instance for ROCIs-Schedule
  FirebaseAuth? get scheduleAuth => _scheduleAuth;

  /// Check if user is authenticated in the secondary Firebase app
  bool get isAuthenticatedInSchedule => _scheduleAuth?.currentUser != null;

  Future<UserCredential?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.addScope('profile');
        googleProvider.addScope('https://www.googleapis.com/auth/tasks');
        
        final UserCredential userCredential = await _auth.signInWithPopup(googleProvider);
        
        // Extract Google OAuth Access Token on Web
        final OAuthCredential? oAuthCred = userCredential.credential as OAuthCredential?;
        final String? accessToken = oAuthCred?.accessToken;
        
        if (accessToken != null) {
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('google_access_token', accessToken);
            // Google OAuth token lasts 1 hour. Store it with a 55 minutes expiration.
            final expiresAt = DateTime.now().add(const Duration(minutes: 55));
            await prefs.setString('google_access_token_expires_at', expiresAt.toIso8601String());
            AppLogger.info('Web Google Calendar access token saved.', tag: 'Auth');
          } catch (e) {
            AppLogger.error('Failed to save Web Google access token', error: e, tag: 'Auth');
          }
        }
        
        // Sync encryption key immediately after sign in and WAIT for it
        if (userCredential.user != null) {
          AppLogger.info(
            'Web Google Sign in successful. Starting critical key sync...',
            tag: 'Auth',
          );
          await _syncEncryptionKey(userCredential.user!.uid);
          AppLogger.info('Key sync complete.', tag: 'Auth');
        }
        
        notifyListeners();
        return userCredential;
      }

      await _ensureGoogleSignInInitialized();

      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate(
        scopeHint: _googleTasksScopes,
      );
      _googleUser = googleUser;

      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      // Obtain access token via authorization client
      final clientAuth = await googleUser.authorizationClient
          .authorizationForScopes(_googleTasksScopes)
          ?? await googleUser.authorizationClient.authorizeScopes(_googleTasksScopes);

      // Cache the access token for later use by GoogleTasksService
      await _cacheGoogleAccessToken(clientAuth.accessToken);

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: clientAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );

      // Sync encryption key immediately after sign in and WAIT for it
      if (userCredential.user != null) {
        AppLogger.info(
          'Sign in successful. Starting critical key sync...',
          tag: 'Auth',
        );
        await _syncEncryptionKey(userCredential.user!.uid);
        AppLogger.info('Key sync complete.', tag: 'Auth');
      }

      // Also sign in to the secondary Firebase app (ROCIs-Schedule)
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

  /// Sync encryption key with Cloud Firestore to prevent data loss on reinstall
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

        // If cloud has a key, and it differs from local, RESTORE it
        // This fixes the "DECRYPTION_ERROR" after reinstall
        if (localKey != cloudKey) {
          AppLogger.info(
            'Restoring encryption key from cloud backup',
            tag: 'Auth',
          );
          await EncryptionService.setKey(cloudKey);
        }
      } else {
        // If cloud has no key, backup the current local key
        if (localKey != null) {
          AppLogger.info('Backing up encryption key to cloud', tag: 'Auth');
          await userSettingsRef.set({
            'encryptionKey': localKey,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      }
    } catch (e) {
      // Don't block auth if this fails, but log it
      AppLogger.error('Key sync failed', error: e, tag: 'Auth');
    }
  }

  /// Sign in to the secondary Firebase app (ROCIs-Schedule) using the same credentials
  Future<void> _signInToSecondaryFirebase(AuthCredential credential) async {
    if (kIsWeb) return;
    try {
      // Get the secondary Firebase app
      final scheduleApp = Firebase.app('rocis-schedule');
      _scheduleAuth = FirebaseAuth.instanceFor(app: scheduleApp);

      // Sign in with the same Google credential
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

  /// Re-authenticate to secondary Firebase if needed (e.g., after app restart)
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

    // If user is signed in to primary but not secondary, try to sign in
    if (_auth.currentUser != null) {
      try {
        // Try to get fresh Google credentials using in-memory user first
        final googleUser = _googleUser ?? await _googleSignIn.attemptLightweightAuthentication();
        if (googleUser != null) {
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

  /// Opens Google sign-in/authorization to request Tasks scope and retrieve a new Access Token.
  /// Works on both Mobile and Web.
  Future<bool> linkGoogleTasks() async {
    if (kIsWeb) {
      try {
        final user = currentUser;
        if (user == null) return false;

        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        for (final scope in _googleTasksScopes) {
          googleProvider.addScope(scope);
        }

        AppLogger.info('Opening Google popup to refresh Tasks access token...', tag: 'Auth');
        final UserCredential userCredential = await user.reauthenticateWithPopup(googleProvider);
        
        final OAuthCredential? oAuthCred = userCredential.credential as OAuthCredential?;
        final String? accessToken = oAuthCred?.accessToken;

        if (accessToken != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('google_access_token', accessToken);
          final expiresAt = DateTime.now().add(const Duration(minutes: 55));
          await prefs.setString('google_access_token_expires_at', expiresAt.toIso8601String());
          AppLogger.info('Web Google Tasks access token refreshed successfully.', tag: 'Auth');
          setGoogleTasksTokenExpired(false);
          notifyListeners();
          return true;
        }
      } catch (e, s) {
        AppLogger.error('Error refreshing Google Tasks access token on Web', error: e, stack: s, tag: 'Auth');
      }
      return false;
    } else {
      try {
        await _ensureGoogleSignInInitialized();

        GoogleSignInAccount? googleUser = _googleUser ??
            await _googleSignIn.attemptLightweightAuthentication();
        googleUser ??= await _googleSignIn.authenticate(
          scopeHint: _googleTasksScopes,
        );
        _googleUser = googleUser;
        
        // Request authorization for Tasks scopes
        final clientAuth = await googleUser.authorizationClient
            .authorizationForScopes(_googleTasksScopes)
            ?? await googleUser.authorizationClient.authorizeScopes(_googleTasksScopes);

        // Cache the token so getGoogleAccessToken() can retrieve it without prompts
        await _cacheGoogleAccessToken(clientAuth.accessToken);

        AppLogger.info(
          'Mobile Google Tasks & Calendar authorized. Token cached.',
          tag: 'Auth',
        );
        setGoogleTasksTokenExpired(false);
        notifyListeners();
        return true;
      } catch (e, s) {
        AppLogger.error('Error authorizing Google Tasks access token on Mobile', error: e, stack: s, tag: 'Auth');
      }
      return false;
    }
  }

  /// Opens a Google popup to refresh tasks scopes and retrieve a new Access Token on Web.
  @Deprecated('Use linkGoogleTasks() instead')
  Future<bool> linkGoogleTasksOnWeb() => linkGoogleTasks();

  Future<void> signOut() async {
    try {
      // Sign out from secondary Firebase first
      await _scheduleAuth?.signOut();
      _scheduleAuth = null;

      if (!kIsWeb) {
        await _googleSignIn.signOut();
        _googleUser = null;
      }
      
      // Clear stored Google access token on all platforms
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('google_access_token');
        await prefs.remove('google_access_token_expires_at');
        AppLogger.info('Cleared Google access token from SharedPreferences.', tag: 'Auth');
      } catch (e) {
        AppLogger.error('Failed to clear Google access token on sign out', error: e, tag: 'Auth');
      }
      
      await _auth.signOut();
      notifyListeners();
    } catch (e, s) {
      _errorHandlingService.logError(e, s, reason: 'Sign out');
    }
  }

  /// Delete account and all associated data (GDPR requirement)
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

      // 1. Delete Firestore data
      AppLogger.info(
        'Starting GDPR data deletion for user: $userId',
        tag: 'Auth',
      );

      // Delete tasks subcollection
      final tasks = await firestore
          .collection('users')
          .doc(userId)
          .collection('tasks')
          .get();
      for (final doc in tasks.docs) {
        await doc.reference.delete();
      }

      // Delete categories subcollection
      final categories = await firestore
          .collection('users')
          .doc(userId)
          .collection('categories')
          .get();
      for (final doc in categories.docs) {
        await doc.reference.delete();
      }

      // Delete settings subcollection
      final settings = await firestore
          .collection('users')
          .doc(userId)
          .collection('settings')
          .get();
      for (final doc in settings.docs) {
        await doc.reference.delete();
      }

      // Delete the main user document
      await firestore.collection('users').doc(userId).delete();

      // 2. Delete Auth Account
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
      // If it's a "recent-login-required" error, we should ideally handle it
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

        final GoogleSignInAccount? googleUser =
            await _googleSignIn.attemptLightweightAuthentication();
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
      if (normalizedPassword == null || normalizedPassword.isEmpty) return false;
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

  /// Scopes needed for Google Tasks integration on Mobile (no calendar needed).
  static const List<String> _googleTasksScopesMobile = [
    'email',
    'profile',
    'https://www.googleapis.com/auth/tasks',
  ];

  /// Scopes needed for Google Tasks and Calendar integration on Web.
  static const List<String> _googleTasksScopesWeb = [
    'email',
    'profile',
    'https://www.googleapis.com/auth/tasks',
    'https://www.googleapis.com/auth/calendar',
  ];

  List<String> get _googleTasksScopes => kIsWeb ? _googleTasksScopesWeb : _googleTasksScopesMobile;

  /// Restores Google Sign-In session silently on startup if applicable.
  Future<void> _restoreGoogleSignInSession(User user) async {
    final isGoogleUser = user.providerData.any((p) => p.providerId == 'google.com');
    final prefs = await SharedPreferences.getInstance();
    final hasGoogleTasks = prefs.containsKey('google_access_token');

    // Only restore if user logged in with Google or previously linked tasks
    if (!isGoogleUser && !hasGoogleTasks) return;
    if (_googleUser != null) return;

    try {
      await _ensureGoogleSignInInitialized();
      
      // Start listening to authentication stream events
      _googleSignIn.authenticationEvents.listen((event) {
        if (event is GoogleSignInAuthenticationEventSignIn) {
          _googleUser = event.user;
          unawaited(_cacheTokenFromUser(event.user));
        } else if (event is GoogleSignInAuthenticationEventSignOut) {
          _googleUser = null;
        }
      });

      final googleUser = await _googleSignIn.attemptLightweightAuthentication();
      if (googleUser != null) {
        _googleUser = googleUser;
        await _cacheTokenFromUser(googleUser);
      }
    } catch (e, s) {
      AppLogger.warning('Failed to restore Google Sign-In session silently', error: e, stack: s, tag: 'Auth');
    }
  }

  /// Silent token fetch and caching helper.
  Future<void> _cacheTokenFromUser(GoogleSignInAccount googleUser) async {
    try {
      final clientAuth = await googleUser.authorizationClient
          .authorizationForScopes(_googleTasksScopes);
      if (clientAuth != null) {
        await _cacheGoogleAccessToken(clientAuth.accessToken);
      }
    } catch (e, s) {
      AppLogger.warning('Failed to silently cache token from user', error: e, stack: s, tag: 'Auth');
    }
  }

  /// Ensures GoogleSignIn.initialize() has been called exactly once.
  Future<void> _ensureGoogleSignInInitialized() async {
    if (!_googleSignInInitialized) {
      await _googleSignIn.initialize();
      _googleSignInInitialized = true;
    }
  }

  /// Caches a Google access token in SharedPreferences with a 55-minute expiry.
  Future<void> _cacheGoogleAccessToken(String accessToken) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('google_access_token', accessToken);
      final expiresAt = DateTime.now().add(const Duration(minutes: 55));
      await prefs.setString('google_access_token_expires_at', expiresAt.toIso8601String());
      AppLogger.info('Google access token cached (expires in 55 min).', tag: 'Auth');
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
        final expiresAt = DateTime.parse(expiresAtStr);
        if (DateTime.now().isBefore(expiresAt)) {
          setGoogleTasksTokenExpired(false);
          return token;
        }
        AppLogger.info('Cached Google access token expired, attempting silent refresh...', tag: 'Auth');
      }
    } catch (e) {
      AppLogger.error('Error reading cached access token', error: e, tag: 'Auth');
    }

    try {
      await _ensureGoogleSignInInitialized();

      GoogleSignInAccount? googleUser = _googleUser;
      if (googleUser == null && !kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        final hasGoogleTasks = prefs.containsKey('google_access_token');
        if (hasGoogleTasks) {
          googleUser = await _googleSignIn.attemptLightweightAuthentication();
          _googleUser = googleUser;
        }
      }

      if (googleUser != null) {
        final authClient = googleUser.authorizationClient;
        // Try to get authorization SILENTLY ONLY (never call interactive authorizeScopes in background getter)
        final clientAuth = await authClient.authorizationForScopes(_googleTasksScopes);
        if (clientAuth != null) {
          await _cacheGoogleAccessToken(clientAuth.accessToken);
          setGoogleTasksTokenExpired(false);
          return clientAuth.accessToken;
        }
      }
      AppLogger.warning('Google access token not available silently', tag: 'Auth');
      
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey('google_access_token')) {
        setGoogleTasksTokenExpired(true);
      }
    } catch (e) {
      AppLogger.warning('Failed to silently refresh Google access token', error: e, tag: 'Auth');
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey('google_access_token')) {
        setGoogleTasksTokenExpired(true);
      }
    }

    return null;
  }
}

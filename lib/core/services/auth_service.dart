import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:rocis_tasks/core/services/error_handling_service.dart';
import 'package:rocis_tasks/core/services/logger_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rocis_tasks/core/services/encryption_service.dart';

class AuthService extends ChangeNotifier {
  final ErrorHandlingService _errorHandlingService;
  FirebaseAuth get _auth => FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final Completer<void> _initCompleter = Completer<void>();

  /// Future that completes when the first auth state has been determined
  Future<void> get initialized => _initCompleter.future;

  // Secondary Firebase Auth for ROCIs-Schedule
  FirebaseAuth? _scheduleAuth;

  /// Exposes secondary auth errors so UI can show a non-blocking banner.
  /// null means no error.
  final ValueNotifier<String?> scheduleAuthError = ValueNotifier<String?>(null);

  StreamSubscription<User?>? _authStateSubscription;

  AuthService(this._errorHandlingService) {
    _authStateSubscription = _auth.authStateChanges().listen((User? user) {
      if (user != null) {
        _syncEncryptionKey(user.uid);
        ensureSecondaryAuth();
      }

      // Complete init on first event
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
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // User canceled

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
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

  /// Re-authenticate to secondary Firebase if needed (e.g., after app restart)
  Future<void> ensureSecondaryAuth() async {
    if (_scheduleAuth?.currentUser != null) return;

    // If user is signed in to primary but not secondary, try to sign in
    if (_auth.currentUser != null) {
      try {
        // Try to get fresh Google credentials
        final googleUser = await _googleSignIn.signInSilently();
        if (googleUser != null) {
          final googleAuth = await googleUser.authentication;
          final credential = GoogleAuthProvider.credential(
            accessToken: googleAuth.accessToken,
            idToken: googleAuth.idToken,
          );
          await _signInToSecondaryFirebase(credential);
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

  Future<void> signOut() async {
    try {
      // Sign out from secondary Firebase first
      await _scheduleAuth?.signOut();
      _scheduleAuth = null;

      await _googleSignIn.signOut();
      await _auth.signOut();
      notifyListeners();
    } catch (e, s) {
      _errorHandlingService.logError(e, s, reason: 'Sign out');
    }
  }

  /// Delete account and all associated data (GDPR requirement)
  Future<bool> deleteAccount() async {
    final user = currentUser;
    if (user == null) return false;

    try {
      final userId = user.uid;
      final firestore = FirebaseFirestore.instance;

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
      for (var doc in tasks.docs) {
        await doc.reference.delete();
      }

      // Delete categories subcollection
      final categories = await firestore
          .collection('users')
          .doc(userId)
          .collection('categories')
          .get();
      for (var doc in categories.docs) {
        await doc.reference.delete();
      }

      // Delete settings subcollection
      final settings = await firestore
          .collection('users')
          .doc(userId)
          .collection('settings')
          .get();
      for (var doc in settings.docs) {
        await doc.reference.delete();
      }

      // Delete the main user document
      await firestore.collection('users').doc(userId).delete();

      // 2. Delete Auth Account
      // Note: This may fail if the user hasn't signed in recently.
      // In production, you'd trigger a re-auth flow here.
      await user.delete();

      await signOut();
      AppLogger.info('Account and data deleted successfully', tag: 'Auth');
      return true;
    } catch (e, s) {
      _errorHandlingService.logError(e, s, reason: 'Delete account');
      // If it's a "recent-login-required" error, we should ideally handle it
      return false;
    }
  }
}

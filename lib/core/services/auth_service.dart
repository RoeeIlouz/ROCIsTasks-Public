import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:rocis_tasks/core/services/error_handling_service.dart';
import 'package:rocis_tasks/core/services/logger_service.dart';

class AuthService extends ChangeNotifier {
  final ErrorHandlingService _errorHandlingService;
  FirebaseAuth get _auth => FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  
  // Secondary Firebase Auth for ROCIs-Schedule
  FirebaseAuth? _scheduleAuth;

  AuthService(this._errorHandlingService);

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
      
      // Also sign in to the secondary Firebase app (ROCIs-Schedule)
      await _signInToSecondaryFirebase(credential);
      
      notifyListeners();
      return userCredential;
    } catch (e, s) {
      _errorHandlingService.logError(e, s, reason: 'Sign in with Google');
      return null;
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
      AppLogger.info('Signed in to secondary Firebase (rocis-schedule) successfully', tag: 'Auth');
    } catch (e) {
      AppLogger.warning('Failed to sign in to secondary Firebase', error: e, tag: 'Auth');
      // Non-critical - schedule integration will just be unavailable
      _scheduleAuth = null;
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
        AppLogger.warning('Failed to re-authenticate to secondary Firebase', error: e, tag: 'Auth');
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
}

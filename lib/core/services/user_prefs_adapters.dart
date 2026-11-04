import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:rocis_tasks/core/services/user_prefs_sync.dart';

/// `users/{uid}/settings/preferences`. The `settings` sub-collection is
/// owner-only in firestore.rules.
class FirestorePrefsRemote implements PrefsRemote {
  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('settings')
          .doc('preferences');

  @override
  Future<Map<String, dynamic>?> read(String uid) async {
    final snap = await _doc(uid).get();
    return snap.exists ? snap.data() : null;
  }

  @override
  Future<void> write(String uid, Map<String, dynamic> data) =>
      _doc(uid).set(data);
}

class FlutterSecureSecretStore implements SecretStore {
  static const _storage = FlutterSecureStorage();

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:rocis_tasks/core/services/logger_service.dart';

class EncryptionService {
  // Use EncryptedSharedPreferences for better persistence on Android
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // Legacy storage for migration
  static const _legacyStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: false),
  );

  static const _keyName = 'hive_encryption_key_v1';

  static enc.Encrypter? _encrypter;
  static enc.Key? _key;

  /// Initialize encryption service
  static Future<void> init() async {
    await getOrGenerateKey();
  }

  /// Retrieves the existing encryption key or generates a new one.
  static Future<List<int>> getOrGenerateKey() async {
    try {
      AppLogger.info(
        'Attempting to retrieve encryption key...',
        tag: 'EncryptionService',
      );

      // 1. Try reading from robust storage
      String? keyString = await _secureStorage.read(key: _keyName);
      if (keyString != null) {
        AppLogger.info(
          'Key found in secure storage.',
          tag: 'EncryptionService',
        );
      }

      // 2. If not found, try migrating from legacy storage
      if (keyString == null) {
        AppLogger.info(
          'Key not found in secure storage. Checking legacy...',
          tag: 'EncryptionService',
        );
        keyString = await _legacyStorage.read(key: _keyName);
        if (keyString != null) {
          AppLogger.info(
            'Key found in legacy storage. Migrating...',
            tag: 'EncryptionService',
          );
          await _secureStorage.write(key: _keyName, value: keyString);
        }
      }

      List<int> keyBytes;
      if (keyString == null) {
        // 3. Generate new key if absolutely no key found
        AppLogger.warning(
          'No existing encryption key found anywhere. Generating NEW key.',
          tag: 'EncryptionService',
        );
        keyBytes = Hive.generateSecureKey();
        await _secureStorage.write(
          key: _keyName,
          value: base64UrlEncode(keyBytes),
        );
      } else {
        keyBytes = base64Url.decode(keyString);
      }

      _initEncrypter(keyBytes);
      return keyBytes;
    } catch (e) {
      AppLogger.error(
        'EncryptionService Error',
        error: e,
        tag: 'EncryptionService',
      );
      rethrow;
    }
  }

  /// Wipe all keys from storage (Subsequent app runs will act as fresh install)
  static Future<void> nukeKey() async {
    try {
      AppLogger.critical(
        'NUKING ALL ENCRYPTION KEYS',
        tag: 'EncryptionService',
      );
      await _secureStorage.delete(key: _keyName);
      await _legacyStorage.delete(key: _keyName);
      _encrypter = null;
      _key = null;
    } catch (e) {
      AppLogger.error(
        'Failed to nuke keys',
        error: e,
        tag: 'EncryptionService',
      );
    }
  }

  /// Explicitly set the encryption key (e.g. from Cloud Backup)
  static Future<void> setKey(String base64Key) async {
    try {
      final keyBytes = base64Url.decode(base64Key);
      await _secureStorage.write(key: _keyName, value: base64Key);
      _initEncrypter(keyBytes);
      AppLogger.info('Encryption key explicitly set', tag: 'Security');
    } catch (e) {
      AppLogger.error(
        'Failed to set encryption key',
        error: e,
        tag: 'Security',
      );
      throw Exception('Invalid key format');
    }
  }

  /// Get the current key as base64 string (for Cloud Backup)
  static Future<String?> getKey() async {
    if (_key != null) {
      return base64UrlEncode(_key!.bytes);
    }
    return await _secureStorage.read(key: _keyName);
  }

  /// Checks if a key exists without generating one.
  static Future<bool> hasKey() async {
    final keyString =
        await _secureStorage.read(key: _keyName) ??
        await _legacyStorage.read(key: _keyName);
    if (keyString != null) {
      _initEncrypter(base64Url.decode(keyString));
      return true;
    }
    return false;
  }

  static void _initEncrypter(List<int> keyBytes) {
    _key ??= enc.Key(Uint8List.fromList(keyBytes));
    _encrypter ??= enc.Encrypter(enc.AES(_key!));
    AppLogger.info('Encrypter initialized.', tag: 'EncryptionService');
  }

  static String encrypt(String plainText) {
    if (plainText.isEmpty) return plainText;
    if (_encrypter == null) {
      AppLogger.critical(
        'SECURITY ALERT: Encrypter not initialized. Blocking operation.',
        tag: 'Security',
      );
      throw StateError('Encryption service not initialized');
    }
    try {
      final iv = enc.IV.fromLength(16);
      final encrypted = _encrypter!.encrypt(plainText, iv: iv);
      return '${iv.base64}:${encrypted.base64}'; // Format: IV:CipherText
    } catch (e) {
      AppLogger.critical(
        'SECURITY ALERT: Encryption failed',
        error: e,
        tag: 'Security',
      );
      throw Exception('Failed to secure data: $e');
    }
  }

  static String decrypt(String cipherText) {
    if (cipherText.isEmpty) return cipherText;
    if (_encrypter == null) {
      AppLogger.critical(
        'SECURITY ALERT: Decrypter not initialized. Blocking operation.',
        tag: 'Security',
      );
      return '[SECURE_DATA_LOCKED]';
    }

    if (!cipherText.contains(':')) {
      // Assume Legacy (Unencrypted) - In a hardened environment, you might want to block this
      AppLogger.warning('Accessing legacy unencrypted data', tag: 'Security');
      return cipherText;
    }

    try {
      final parts = cipherText.split(':');
      if (parts.length != 2)
        throw const FormatException('Invalid secure data format');

      final iv = enc.IV.fromBase64(parts[0]);
      final encrypted = enc.Encrypted.fromBase64(parts[1]);

      return _encrypter!.decrypt(encrypted, iv: iv);
    } catch (e) {
      AppLogger.error('Decryption failed', error: e, tag: 'Security');
      return '[DECRYPTION_ERROR]';
    }
  }
}

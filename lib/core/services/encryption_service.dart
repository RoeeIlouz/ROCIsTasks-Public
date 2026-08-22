import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:rocis_tasks/core/services/logger_service.dart';

class EncryptionService {
  // Use AndroidOptions with resetOnError for robust persistence on Android
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      resetOnError: true,
    ),
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

      String? keyString;
      try {
        keyString = await _secureStorage.read(key: _keyName);
      } catch (e) {
        AppLogger.warning('Keystore read failed, resetting corrupted secure storage: $e');
        try {
          await _secureStorage.deleteAll();
        } catch (_) {}
      }

      if (keyString != null) {
        AppLogger.info(
          'Key found in secure storage.',
          tag: 'EncryptionService',
        );
      }

      List<int> keyBytes;
      if (keyString == null) {
        AppLogger.warning(
          'No existing encryption key found. Generating NEW key.',
          tag: 'EncryptionService',
        );
        keyBytes = Hive.generateSecureKey();
        try {
          await _secureStorage.write(
            key: _keyName,
            value: base64UrlEncode(keyBytes),
          );
        } catch (e) {
          AppLogger.error('Failed to write key to secure storage', error: e);
        }
      } else {
        try {
          keyBytes = base64Url.decode(keyString);
        } catch (_) {
          keyBytes = Hive.generateSecureKey();
          try {
            await _secureStorage.write(
              key: _keyName,
              value: base64UrlEncode(keyBytes),
            );
          } catch (_) {}
        }
      }

      _initEncrypter(keyBytes);
      return keyBytes;
    } catch (e) {
      AppLogger.error(
        'EncryptionService fallback to generated memory key due to error',
        error: e,
        tag: 'EncryptionService',
      );
      final fallbackKey = Hive.generateSecureKey();
      _initEncrypter(fallbackKey);
      return fallbackKey;
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
    final keyString = await _secureStorage.read(key: _keyName);
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
      AppLogger.warning(
        'Attempted to encrypt data but encrypter is not initialized',
        tag: 'Security',
      );
      return plainText;
    }

    try {
      final iv = enc.IV.fromSecureRandom(16);
      final encrypted = _encrypter!.encrypt(plainText, iv: iv);
      return '${iv.base64}:${encrypted.base64}';
    } catch (e) {
      AppLogger.error(
        'Encryption failed, returning raw text',
        error: e,
        tag: 'Security',
      );
      return plainText;
    }
  }

  static String decrypt(String cipherText) {
    if (cipherText.isEmpty) return cipherText;

    if (!cipherText.contains(':')) {
      // Data is not in IV:CipherText format, assume it's already plain text
      return cipherText;
    }

    if (_encrypter == null) {
      AppLogger.warning(
        'Attempted to decrypt data but encrypter is not initialized',
        tag: 'Security',
      );
      return cipherText;
    }

    try {
      final parts = cipherText.split(':');
      if (parts.length != 2) return cipherText;

      final iv = enc.IV.fromBase64(parts[0]);
      final encrypted = enc.Encrypted.fromBase64(parts[1]);

      return _encrypter!.decrypt(encrypted, iv: iv);
    } catch (e) {
      AppLogger.error(
        'Decryption failed, returning raw text',
        error: e,
        tag: 'Security',
      );
      return cipherText;
    }
  }
}

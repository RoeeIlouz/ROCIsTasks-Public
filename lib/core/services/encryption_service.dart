import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:encrypt/encrypt.dart' as enc;

class EncryptionService {
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _keyName = 'hive_encryption_key_v1';

  static enc.Encrypter? _encrypter;
  static enc.Key? _key;

  /// Retrieves the existing encryption key or generates a new one.
  static Future<List<int>> getOrGenerateKey() async {
    try {
      final keyString = await _secureStorage.read(key: _keyName);
      List<int> keyBytes;
      if (keyString == null) {
        // Generate new key
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
      debugPrint('EncryptionService Error: $e');
      rethrow;
    }
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
  }

  static String encrypt(String plainText) {
    if (plainText.isEmpty) return plainText;
    if (_encrypter == null) {
      debugPrint('Warning: Encrypter not initialized. Returning plain text.');
      return plainText;
    }
    try {
      final iv = enc.IV.fromLength(16);
      final encrypted = _encrypter!.encrypt(plainText, iv: iv);
      return '${iv.base64}:${encrypted.base64}'; // Format: IV:CipherText
    } catch (e) {
      debugPrint('Encryption failed: $e');
      return plainText;
    }
  }

  static String decrypt(String cipherText) {
    if (cipherText.isEmpty) return cipherText;
    if (_encrypter == null) return cipherText;

    if (!cipherText.contains(':')) {
      // Assume Legacy (Unencrypted)
      return cipherText;
    }

    try {
      final parts = cipherText.split(':');
      if (parts.length != 2) return cipherText; // Not our format

      final iv = enc.IV.fromBase64(parts[0]);
      final encrypted = enc.Encrypted.fromBase64(parts[1]);

      return _encrypter!.decrypt(encrypted, iv: iv);
    } catch (e) {
      // Fallback for any errors (malformed, different key, or plain text containing :)
      // We assume it might be plain text if decryption fails.
      return cipherText;
    }
  }
}

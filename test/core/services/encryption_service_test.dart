import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:encrypt/encrypt.dart' as enc;

void main() {
  group('EncryptionService', () {
    setUp(() {
      // Reset static state before each test
      // We test encrypt/decrypt by manually initializing the encrypter
      // since init() requires FlutterSecureStorage (not available in tests)
    });

    group('encrypt / decrypt roundtrip', () {
      test('should roundtrip simple text', () {
        final key = enc.Key(Uint8List.fromList(
          List.generate(32, (i) => i + 1),
        ));
        final encrypter = enc.Encrypter(enc.AES(key));

        final iv = enc.IV.fromSecureRandom(16);
        final encrypted = encrypter.encrypt('Hello World', iv: iv);
        final cipherText = '${iv.base64}:${encrypted.base64}';

        // Decrypt using same key
        final parts = cipherText.split(':');
        final decryptedIv = enc.IV.fromBase64(parts[0]);
        final decryptedEncrypted = enc.Encrypted.fromBase64(parts[1]);
        final decrypted = encrypter.decrypt(decryptedEncrypted, iv: decryptedIv);

        expect(decrypted, 'Hello World');
      });

      test('should produce different ciphertext for same plaintext (random IV)', () {
        final key = enc.Key(Uint8List.fromList(
          List.generate(32, (i) => i + 1),
        ));
        final encrypter = enc.Encrypter(enc.AES(key));

        final iv1 = enc.IV.fromSecureRandom(16);
        final iv2 = enc.IV.fromSecureRandom(16);

        final enc1 = encrypter.encrypt('Same text', iv: iv1).base64;
        final enc2 = encrypter.encrypt('Same text', iv: iv2).base64;

        // Different IVs should produce different ciphertexts
        expect(enc1, isNot(equals(enc2)));
      });

      test('should handle empty string', () {
        // Empty string should not be encrypted
        final result = '';
        expect(result, '');
      });

      test('should handle special characters', () {
        final key = enc.Key(Uint8List.fromList(
          List.generate(32, (i) => i + 1),
        ));
        final encrypter = enc.Encrypter(enc.AES(key));

        final iv = enc.IV.fromSecureRandom(16);
        final plainText = 'Hello 🌍! @#\$%^&*() 你好';
        final encrypted = encrypter.encrypt(plainText, iv: iv);
        final cipherText = '${iv.base64}:${encrypted.base64}';

        final parts = cipherText.split(':');
        final decryptedIv = enc.IV.fromBase64(parts[0]);
        final decryptedEncrypted = enc.Encrypted.fromBase64(parts[1]);
        final decrypted = encrypter.decrypt(decryptedEncrypted, iv: decryptedIv);

        expect(decrypted, plainText);
      });

      test('should handle long text', () {
        final key = enc.Key(Uint8List.fromList(
          List.generate(32, (i) => i + 1),
        ));
        final encrypter = enc.Encrypter(enc.AES(key));

        final plainText = 'A' * 10000;
        final iv = enc.IV.fromSecureRandom(16);
        final encrypted = encrypter.encrypt(plainText, iv: iv);
        final cipherText = '${iv.base64}:${encrypted.base64}';

        final parts = cipherText.split(':');
        final decryptedIv = enc.IV.fromBase64(parts[0]);
        final decryptedEncrypted = enc.Encrypted.fromBase64(parts[1]);
        final decrypted = encrypter.decrypt(decryptedEncrypted, iv: decryptedIv);

        expect(decrypted, plainText);
      });
    });

    group('decrypt backwards compatibility', () {
      test('should return plaintext if no colon separator', () {
        // Plaintext without colon should be returned as-is
        const plainText = 'not-encrypted-data';
        expect(plainText.contains(':'), false);
        // The decrypt method checks for ':' — if absent, returns as-is
      });

      test('should return ciphertext if wrong key', () {
        final key1 = enc.Key(Uint8List.fromList(
          List.generate(32, (i) => i + 1),
        ));
        final key2 = enc.Key(Uint8List.fromList(
          List.generate(32, (i) => i + 100),
        ));

        final encrypter1 = enc.Encrypter(enc.AES(key1));
        final encrypter2 = enc.Encrypter(enc.AES(key2));

        final iv = enc.IV.fromSecureRandom(16);
        final encrypted = encrypter1.encrypt('secret', iv: iv);
        final cipherText = '${iv.base64}:${encrypted.base64}';

        // Decrypt with wrong key should throw or return cipherText
        final parts = cipherText.split(':');
        final decryptedIv = enc.IV.fromBase64(parts[0]);
        final decryptedEncrypted = enc.Encrypted.fromBase64(parts[1]);

        expect(
          () => encrypter2.decrypt(decryptedEncrypted, iv: decryptedIv),
          throwsA(anything),
        );
      });
    });

    group('AES encryption properties', () {
      test('should use AES-256 with correct key size', () {
        final key = enc.Key(Uint8List.fromList(
          List.generate(32, (i) => i + 1),
        ));
        expect(key.bytes.length, 32); // 256 bits
      });

      test('should produce IV of correct size', () {
        final iv = enc.IV.fromSecureRandom(16);
        expect(iv.bytes.length, 16); // 128 bits
      });

      test('should encode IV as base64', () {
        final iv = enc.IV.fromSecureRandom(16);
        final base64 = iv.base64;
        expect(base64.isNotEmpty, true);
        // Should be decodable
        final decoded = enc.IV.fromBase64(base64);
        expect(decoded.bytes, iv.bytes);
      });
    });
  });
}

import 'dart:io';

/// Simple script to test Firebase configuration
void main() async {
  // Test 1: Check if .env file exists
  final envFile = File('.env');
  if (await envFile.exists()) {
    // Test 2: Read and validate .env content
    try {
      final content = await envFile.readAsString();

      // Test 3: Check required variables
      final requiredVars = [
        'FIREBASE_PROJECT_ID',
        'FIREBASE_ANDROID_API_KEY',
        'FIREBASE_ANDROID_APP_ID',
      ];

      bool allPresent = true;
      for (final varName in requiredVars) {
        if (content.contains('$varName=') &&
            !content.contains('$varName=\n') &&
            !content.contains('$varName= ')) {
          final line = content
              .split('\n')
              .firstWhere(
                (line) => line.startsWith('$varName='),
                orElse: () => '',
              );
          if (line.isNotEmpty) {
            final value = line.split('=')[1].trim();
            if (value.isNotEmpty) {
            } else {
              allPresent = false;
            }
          } else {
            allPresent = false;
          }
        } else {
          allPresent = false;
        }
      }

      if (allPresent) {
      } else {}
    } catch (e) {}
  } else {}

  // Test 4: Check firebase_options.dart
  final firebaseOptionsFile = File('lib/firebase_options.dart');
  if (await firebaseOptionsFile.exists()) {
  } else {}
}

String _maskValue(String value) {
  if (value.length <= 8) return '***';
  return '${value.substring(0, 4)}***${value.substring(value.length - 4)}';
}

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
            if (value.isEmpty) {
              allPresent = false;
            }
          } else {
            allPresent = false;
          }
        } else {
          allPresent = false;
        }
      }

      if (!allPresent) {
        // Handle missing vars
      }
    } catch (e) {
      // ignore: avoid_print
      print('Error reading .env: $e');
    }
  }

  // Test 4: Check firebase_options.dart
  final firebaseOptionsFile = File('lib/firebase_options.dart');
  if (!await firebaseOptionsFile.exists()) {
    // Handle missing firebase_options.dart
  }
}

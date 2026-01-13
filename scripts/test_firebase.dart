import 'dart:io';

/// Simple script to test Firebase configuration
void main() async {
  print('=== Firebase Configuration Test ===');
  
  // Test 1: Check if .env file exists
  final envFile = File('.env');
  if (await envFile.exists()) {
    print('✅ .env file exists');
    
    // Test 2: Read and validate .env content
    try {
      final content = await envFile.readAsString();
      print('✅ .env file readable');
      
      // Test 3: Check required variables
      final requiredVars = [
        'FIREBASE_PROJECT_ID',
        'FIREBASE_ANDROID_API_KEY',
        'FIREBASE_ANDROID_APP_ID',
      ];
      
      bool allPresent = true;
      for (final varName in requiredVars) {
        if (content.contains('$varName=') && !content.contains('$varName=\n') && !content.contains('$varName= ')) {
          final line = content.split('\n').firstWhere(
            (line) => line.startsWith('$varName='),
            orElse: () => '',
          );
          if (line.isNotEmpty) {
            final value = line.split('=')[1].trim();
            if (value.isNotEmpty) {
              print('✅ $varName: ${_maskValue(value)}');
            } else {
              print('❌ Empty value: $varName');
              allPresent = false;
            }
          } else {
            print('❌ Missing: $varName');
            allPresent = false;
          }
        } else {
          print('❌ Missing or empty: $varName');
          allPresent = false;
        }
      }
      
      if (allPresent) {
        print('✅ All required Firebase variables are present');
      } else {
        print('❌ Some required Firebase variables are missing');
      }
      
    } catch (e) {
      print('❌ Failed to read .env file: $e');
    }
  } else {
    print('❌ .env file not found');
    print('ℹ️  The app will use default Firebase configuration');
  }
  
  // Test 4: Check firebase_options.dart
  final firebaseOptionsFile = File('lib/firebase_options.dart');
  if (await firebaseOptionsFile.exists()) {
    print('✅ firebase_options.dart exists');
  } else {
    print('❌ firebase_options.dart not found');
  }
  
  print('\n=== Test Complete ===');
  print('If all tests pass, Firebase should initialize correctly.');
  print('If tests fail, check your .env file configuration.');
}

String _maskValue(String value) {
  if (value.length <= 8) return '***';
  return '${value.substring(0, 4)}***${value.substring(value.length - 4)}';
}
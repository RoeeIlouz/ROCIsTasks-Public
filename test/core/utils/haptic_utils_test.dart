import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rocis_tasks/core/utils/haptic_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final List<String?> hapticCalls = [];

  setUp(() {
    hapticCalls.clear();
    HapticUtils.resetThrottle();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (
          MethodCall methodCall,
        ) async {
          if (methodCall.method == 'HapticFeedback.vibrate') {
            hapticCalls.add(methodCall.arguments as String?);
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  test(
    'throttledLightImpact throttles subsequent calls within duration',
    () async {
      HapticUtils.throttledLightImpact(const Duration(milliseconds: 100));
      HapticUtils.throttledLightImpact(const Duration(milliseconds: 100));
      HapticUtils.throttledLightImpact(const Duration(milliseconds: 100));

      expect(hapticCalls.length, equals(1));
      expect(hapticCalls.first, equals('HapticFeedbackType.lightImpact'));

      // Wait past throttle duration
      await Future.delayed(const Duration(milliseconds: 110));

      HapticUtils.throttledLightImpact(const Duration(milliseconds: 100));
      expect(hapticCalls.length, equals(2));
    },
  );

  test('throttledSelectionClick throttles rapid clicks', () async {
    HapticUtils.throttledSelectionClick(const Duration(milliseconds: 80));
    HapticUtils.throttledSelectionClick(const Duration(milliseconds: 80));

    expect(hapticCalls.length, equals(1));
    expect(hapticCalls.first, equals('HapticFeedbackType.selectionClick'));

    await Future.delayed(const Duration(milliseconds: 90));
    HapticUtils.throttledSelectionClick(const Duration(milliseconds: 80));
    expect(hapticCalls.length, equals(2));
  });

  test('throttledMediumImpact throttles rapid impacts', () async {
    HapticUtils.throttledMediumImpact(const Duration(milliseconds: 80));
    HapticUtils.throttledMediumImpact(const Duration(milliseconds: 80));

    expect(hapticCalls.length, equals(1));
    expect(hapticCalls.first, equals('HapticFeedbackType.mediumImpact'));

    await Future.delayed(const Duration(milliseconds: 90));
    HapticUtils.throttledMediumImpact(const Duration(milliseconds: 80));
    expect(hapticCalls.length, equals(2));
  });
}

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rocis_tasks/core/services/security_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('stores the PIN hashed and unlocks with it', () async {
    final service = PrivateModeService();
    expect(await service.setPin('4821'), isTrue);

    final stored = await const FlutterSecureStorage().read(
      key: 'private_mode_pin_v1',
    );
    expect(stored, startsWith('v2:'));
    expect(stored, isNot(contains('4821')));

    expect(await service.unlockWithPin('4821'), PinUnlockResult.unlocked);
    expect(service.isUnlocked, isTrue);
  });

  test(
    'a plain-text PIN from before hashing still works and is rehashed',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'private_mode_pin_v1': '1234',
      });
      final service = PrivateModeService();

      expect(await service.unlockWithPin('1234'), PinUnlockResult.unlocked);
      final stored = await const FlutterSecureStorage().read(
        key: 'private_mode_pin_v1',
      );
      expect(stored, startsWith('v2:'));
      expect(await service.verifyPin('1234'), isTrue);
    },
  );

  test('locks entry after 5 wrong PINs, even across restarts', () async {
    await PrivateModeService().setPin('4821');

    for (var i = 0; i < 4; i++) {
      expect(
        await PrivateModeService().unlockWithPin('0000'),
        PinUnlockResult.wrong,
      );
    }
    expect(
      await PrivateModeService().unlockWithPin('0000'),
      PinUnlockResult.lockedOut,
    );

    // A fresh instance (app restart) is still locked, even with the right PIN.
    final restarted = PrivateModeService();
    expect(await restarted.unlockWithPin('4821'), PinUnlockResult.lockedOut);
    final left = await restarted.pinLockoutRemaining();
    expect(left, isNotNull);
    expect(left!.inSeconds, inInclusiveRange(1, 30));
  });

  test('lockout ends and a correct PIN clears the failure count', () async {
    await PrivateModeService().setPin('4821');
    SharedPreferences.setMockInitialValues({
      'private_mode_failed_attempts_v1': 7,
      'private_mode_locked_until_v1': DateTime.now()
          .subtract(const Duration(seconds: 1))
          .millisecondsSinceEpoch,
    });

    final service = PrivateModeService();
    expect(await service.pinLockoutRemaining(), isNull);
    expect(await service.unlockWithPin('4821'), PinUnlockResult.unlocked);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('private_mode_failed_attempts_v1'), isNull);
  });

  test('the lockout grows with each extra failure but stays capped', () async {
    await PrivateModeService().setPin('4821');
    SharedPreferences.setMockInitialValues({
      'private_mode_failed_attempts_v1': 100,
    });

    expect(
      await PrivateModeService().unlockWithPin('0000'),
      PinUnlockResult.lockedOut,
    );
    final left = await PrivateModeService().pinLockoutRemaining();
    expect(left!.inMinutes, inInclusiveRange(14, 15));
  });
}

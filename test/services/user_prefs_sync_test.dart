import 'package:flutter_test/flutter_test.dart';
import 'package:rocis_tasks/core/services/user_prefs_sync.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeRemote implements PrefsRemote {
  Map<String, dynamic>? doc;
  int writes = 0;
  @override
  Future<Map<String, dynamic>?> read(String uid) async => doc;
  @override
  Future<void> write(String uid, Map<String, dynamic> data) async {
    writes++;
    doc = data;
  }
}

class FakeSecret implements SecretStore {
  final map = <String, String>{};
  @override
  Future<String?> read(String key) async => map[key];
  @override
  Future<void> write(String key, String value) async => map[key] = value;
  @override
  Future<void> delete(String key) async => map.remove(key);
}

const hash = 'v2:salt:hashvalue';

Future<(UserPrefsSync, SharedPreferences, FakeRemote, FakeSecret)> make(
  Map<String, Object> initial, {
  DateTime? now,
}) async {
  SharedPreferences.setMockInitialValues(initial);
  final prefs = await SharedPreferences.getInstance();
  final remote = FakeRemote();
  final secret = FakeSecret();
  final sync = UserPrefsSync(
    prefs: prefs,
    secret: secret,
    remote: remote,
    now: () => now ?? DateTime.utc(2026, 11, 5, 12),
  );
  return (sync, prefs, remote, secret);
}

void main() {
  test(
    'first device with no cloud copy pushes its settings and PIN hash',
    () async {
      final (sync, _, remote, secret) = await make({
        'use_24h_format': true,
        'app_selected_timezone': 'Asia/Jerusalem',
        'private_mode_enabled_v1': true,
      });
      secret.map[UserPrefsSync.pinKey] = hash;

      expect(await sync.sync('u'), PrefsSyncOutcome.pushed);

      final values = remote.doc!['values'] as Map;
      expect(values['use_24h_format'], true);
      expect(values['app_selected_timezone'], 'Asia/Jerusalem');
      expect(values['private_mode_enabled_v1'], true);
      expect(remote.doc!['pinHash'], hash);
      expect(remote.doc!['updatedAt'], isNotNull);
    },
  );

  test('a new device with nothing set applies the account settings', () async {
    final (sync, prefs, remote, secret) = await make({});
    remote.doc = {
      'values': {
        'use_24h_format': true,
        'theme_mode': 2,
        'language_code': 'he',
        'app_selected_timezone': 'Asia/Jerusalem',
        'private_mode_enabled_v1': true,
      },
      'pinHash': hash,
      'updatedAt': '2026-11-01T10:00:00.000Z',
    };

    expect(await sync.sync('u'), PrefsSyncOutcome.applied);

    expect(prefs.getBool('use_24h_format'), true);
    expect(prefs.getInt('theme_mode'), 2);
    expect(prefs.getString('language_code'), 'he');
    expect(prefs.getString('app_selected_timezone'), 'Asia/Jerusalem');
    expect(prefs.getBool('private_mode_enabled_v1'), true);
    expect(secret.map[UserPrefsSync.pinKey], hash);
  });

  test('newer cloud copy wins; newer local copy is pushed', () async {
    final (sync, prefs, remote, _) = await make({
      'use_24h_format': false,
      UserPrefsSync.updatedAtKey: '2026-11-02T10:00:00.000Z',
    });
    remote.doc = {
      'values': {'use_24h_format': true},
      'updatedAt': '2026-11-03T10:00:00.000Z',
    };
    expect(await sync.sync('u'), PrefsSyncOutcome.applied);
    expect(prefs.getBool('use_24h_format'), true);

    await prefs.setBool('use_24h_format', false);
    await prefs.setString(
      UserPrefsSync.updatedAtKey,
      '2026-11-04T10:00:00.000Z',
    );
    expect(await sync.sync('u'), PrefsSyncOutcome.pushed);
    expect((remote.doc!['values'] as Map)['use_24h_format'], false);
  });

  test('same timestamps change nothing', () async {
    final (sync, _, remote, _) = await make({
      UserPrefsSync.updatedAtKey: '2026-11-03T10:00:00.000Z',
    });
    remote.doc = {'values': {}, 'updatedAt': '2026-11-03T10:00:00.000Z'};
    expect(await sync.sync('u'), PrefsSyncOutcome.unchanged);
    expect(remote.writes, 0);
  });

  test('removing the PIN on one device removes it on the others', () async {
    final (sync, _, remote, secret) = await make({});
    secret.map[UserPrefsSync.pinKey] = hash;
    remote.doc = {
      'values': {},
      'pinHash': null,
      'updatedAt': '2026-11-03T10:00:00.000Z',
    };
    await sync.sync('u');
    expect(secret.map.containsKey(UserPrefsSync.pinKey), isFalse);
  });

  test('a malformed PIN value from the cloud is never stored', () async {
    final (sync, _, remote, secret) = await make({});
    remote.doc = {
      'values': {},
      'pinHash': '1234',
      'updatedAt': '2026-11-03T10:00:00.000Z',
    };
    await sync.sync('u');
    expect(secret.map.containsKey(UserPrefsSync.pinKey), isFalse);
  });

  test('settings removed in the cloud are removed locally', () async {
    final (sync, prefs, remote, _) = await make({'language_code': 'de'});
    remote.doc = {
      'values': {'language_code': null},
      'updatedAt': '2026-11-03T10:00:00.000Z',
    };
    await sync.sync('u');
    expect(prefs.containsKey('language_code'), isFalse);
  });

  test('wrongly typed cloud values are ignored, not applied', () async {
    final (sync, prefs, remote, _) = await make({'use_24h_format': true});
    remote.doc = {
      'values': {'use_24h_format': 'yes', 'theme_mode': 'dark'},
      'updatedAt': '2026-11-03T10:00:00.000Z',
    };
    await sync.sync('u');
    expect(prefs.containsKey('theme_mode'), isFalse);
    expect(prefs.getBool('use_24h_format'), isNull);
  });

  test(
    'localChanged stamps the time and pushes once after the delay',
    () async {
      final (sync, prefs, remote, _) = await make({'use_24h_format': true});
      sync.localChanged('u', delay: const Duration(milliseconds: 20));
      sync.localChanged('u', delay: const Duration(milliseconds: 20));
      expect(prefs.getString(UserPrefsSync.updatedAtKey), isNotNull);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(remote.writes, 1);
    },
  );
}

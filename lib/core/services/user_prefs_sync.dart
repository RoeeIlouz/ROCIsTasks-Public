import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

/// Where the cloud copy of the preferences lives.
abstract class PrefsRemote {
  Future<Map<String, dynamic>?> read(String uid);
  Future<void> write(String uid, Map<String, dynamic> data);
}

/// Device secure storage, for the PIN hash.
abstract class SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

enum PrefsSyncOutcome { pushed, applied, unchanged }

/// Keeps a user's preferences (theme, 24-hour clock, timezone, language,
/// app lock and its PIN hash) on their account, so they follow them to every
/// device. The newest write wins. Only the salted PIN hash ever leaves the
/// device, never the PIN. Failed-attempt counters and the biometric switch
/// stay per device: biometrics depend on the hardware.
class UserPrefsSync {
  static const boolKeys = <String>{
    'use_material_theme',
    'use_glassmorphism',
    'use_amoled_theme',
    'use_24h_format',
    'auto_remove_nlp_dates',
    'task_completion_feedback',
    'use_custom_seed_color',
    'beta_features_unlocked',
    'beta_schedule_integration',
    'private_mode_enabled_v1',
  };
  static const intKeys = <String>{'theme_mode', 'custom_seed_color_value'};
  static const stringKeys = <String>{'language_code', 'app_selected_timezone'};
  static const pinKey = 'private_mode_pin_v1';
  static const updatedAtKey = 'prefs_updated_at';

  final SharedPreferences _prefs;
  final SecretStore _secret;
  final PrefsRemote _remote;
  final DateTime Function() _now;
  Timer? _debounce;
  bool _applying = false;

  UserPrefsSync({
    required SharedPreferences prefs,
    required SecretStore secret,
    required PrefsRemote remote,
    DateTime Function()? now,
  }) : _prefs = prefs,
       _secret = secret,
       _remote = remote,
       _now = now ?? DateTime.now;

  /// True while remote values are being written locally, so listeners that
  /// call [localChanged] can ignore their own echo.
  bool get isApplying => _applying;

  DateTime? get _localUpdatedAt =>
      DateTime.tryParse(_prefs.getString(updatedAtKey) ?? '')?.toUtc();

  /// Records a local change and pushes it shortly after (changes in quick
  /// succession are sent once).
  void localChanged(String uid, {Duration delay = const Duration(seconds: 2)}) {
    if (_applying) return;
    _prefs.setString(updatedAtKey, _now().toUtc().toIso8601String());
    _debounce?.cancel();
    _debounce = Timer(delay, () => unawaited(_push(uid)));
  }

  void dispose() => _debounce?.cancel();

  /// Reconciles this device with the account's copy.
  Future<PrefsSyncOutcome> sync(String uid) async {
    final remote = await _remote.read(uid);
    final remoteAt = DateTime.tryParse(
      remote?['updatedAt']?.toString() ?? '',
    )?.toUtc();
    final localAt = _localUpdatedAt;

    if (remote == null || remoteAt == null) {
      if (localAt == null) _stamp();
      await _push(uid);
      return PrefsSyncOutcome.pushed;
    }
    if (localAt == null || remoteAt.isAfter(localAt)) {
      await _apply(remote, remoteAt);
      return PrefsSyncOutcome.applied;
    }
    if (localAt.isAfter(remoteAt)) {
      await _push(uid);
      return PrefsSyncOutcome.pushed;
    }
    return PrefsSyncOutcome.unchanged;
  }

  void _stamp() =>
      _prefs.setString(updatedAtKey, _now().toUtc().toIso8601String());

  Future<void> _push(String uid) async {
    try {
      final values = <String, Object?>{
        for (final k in {...boolKeys, ...intKeys, ...stringKeys})
          k: _prefs.get(k),
      };
      final pin = await _secret.read(pinKey);
      await _remote.write(uid, {
        'values': values,
        'pinHash': (pin != null && pin.isNotEmpty) ? pin : null,
        'updatedAt': (_localUpdatedAt ?? _now().toUtc()).toIso8601String(),
      });
    } catch (_) {
      // Offline or denied: the next sync retries.
    }
  }

  Future<void> _apply(Map<String, dynamic> remote, DateTime at) async {
    _applying = true;
    try {
      final values = (remote['values'] as Map?) ?? const {};
      for (final k in boolKeys) {
        final v = values[k];
        v is bool ? await _prefs.setBool(k, v) : await _prefs.remove(k);
      }
      for (final k in intKeys) {
        final v = values[k];
        v is int ? await _prefs.setInt(k, v) : await _prefs.remove(k);
      }
      for (final k in stringKeys) {
        final v = values[k];
        v is String && v.isNotEmpty
            ? await _prefs.setString(k, v)
            : await _prefs.remove(k);
      }
      if (remote.containsKey('pinHash')) {
        final pin = remote['pinHash'];
        if (pin is String && pin.startsWith('v2:')) {
          await _secret.write(pinKey, pin);
        } else if (pin == null) {
          await _secret.delete(pinKey);
        }
      }
      await _prefs.setString(updatedAtKey, at.toIso8601String());
    } finally {
      _applying = false;
    }
  }
}

import 'package:shorebird_code_push/shorebird_code_push.dart';

import 'package:rocis_tasks/core/config/app_config.dart';

/// The version shown to users: `0.3.2`, or `0.3.2 P4` while Shorebird patch 4
/// is running. The patch number comes from the updater, so it always matches
/// what the device actually runs (a downloaded patch applies on next launch).
class AppVersionService {
  AppVersionService._();

  static Future<String>? _label;

  static Future<String> label() => _label ??= _readLabel();

  static Future<String> _readLabel() async {
    try {
      final updater = ShorebirdUpdater();
      // Unavailable in debug builds, on web and in tests.
      if (!updater.isAvailable) return AppConfig.appVersion;
      final patch = await updater.readCurrentPatch();
      return patch == null
          ? AppConfig.appVersion
          : '${AppConfig.appVersion} P${patch.number}';
    } catch (_) {
      return AppConfig.appVersion;
    }
  }
}

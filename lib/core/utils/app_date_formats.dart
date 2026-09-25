import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:rocis_tasks/features/tasks/domain/models/task.dart';
import 'package:rocis_tasks/l10n/app_localizations.dart';

/// Date/time formats in the app's UI language (not `Intl.defaultLocale`),
/// cached per locale so list items don't rebuild formatters.
class AppDateFormats {
  AppDateFormats._();

  static final _cache = <String, DateFormat>{};

  static DateFormat _get(
    BuildContext context,
    String key,
    DateFormat Function(String locale) create,
  ) {
    final locale = Localizations.localeOf(context).toString();
    return _cache.putIfAbsent('$key|$locale', () => create(locale));
  }

  /// Clock time; 12h/24h follows the app setting, the pattern follows the
  /// language (e.g. Hebrew uses 16:30 even in "12h" mode).
  static DateFormat time(BuildContext context, {required bool use24h}) => use24h
      ? _get(context, 'Hm', DateFormat.Hm)
      : _get(context, 'jm', DateFormat.jm);

  /// Any skeleton/pattern, e.g. `EEEE` or `MMM d`.
  static DateFormat pattern(BuildContext context, String pattern) =>
      _get(context, pattern, (locale) => DateFormat(pattern, locale));

  /// Localized priority name for chips and badges.
  static String priority(AppLocalizations l10n, TaskPriority priority) =>
      switch (priority) {
        TaskPriority.high => l10n.high,
        TaskPriority.medium => l10n.medium,
        TaskPriority.low => l10n.low,
      };
}

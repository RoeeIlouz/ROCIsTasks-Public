import 'app_localizations.dart';
import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_he.dart';
import 'app_localizations_sv.dart';
import 'app_localizations_de.dart';
import 'app_localizations_fr.dart';
import 'package:flutter/material.dart';

/// Safely returns the corresponding [AppLocalizations] instance for the given [Locale].
/// If the language code of the [locale] is not supported, it returns the English instance
/// (`AppLocalizationsEn`) instead of throwing an exception.
AppLocalizations getSafeAppLocalizations(Locale locale) {
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'es':
      return AppLocalizationsEs();
    case 'he':
      return AppLocalizationsHe();
    case 'sv':
      return AppLocalizationsSv();
    case 'de':
      return AppLocalizationsDe();
    case 'fr':
      return AppLocalizationsFr();
    case 'en':
    default:
      return AppLocalizationsEn();
  }
}

/// Helper to get the best supported locale from a system/device locale.
Locale getBestSupportedLocale(Locale deviceLocale) {
  const supportedLanguageCodes = {'ar', 'en', 'es', 'he', 'sv', 'de', 'fr'};
  if (supportedLanguageCodes.contains(deviceLocale.languageCode)) {
    return Locale(deviceLocale.languageCode);
  }
  return const Locale('en');
}

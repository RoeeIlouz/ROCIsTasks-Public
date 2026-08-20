import 'app_localizations.dart';
import 'app_localizations_en.dart'; // Eager import for fallback
import 'package:flutter/material.dart';

AppLocalizations _currentLocalizations = AppLocalizationsEn();

/// The active localized strings instance. Defaults to English until loaded.
AppLocalizations get currentLocalizations => _currentLocalizations;

/// Safely returns the corresponding [AppLocalizations] instance for the given [Locale].
/// Returns the active loaded locale if it matches, otherwise falls back to English.
AppLocalizations getSafeAppLocalizations(Locale locale) {
  if (_currentLocalizations.localeName == locale.languageCode) {
    return _currentLocalizations;
  }
  return AppLocalizationsEn();
}

/// Asynchronously load the localizations for the given locale.
Future<void> ensureLocaleLoaded(Locale locale) async {
  try {
    _currentLocalizations = await lookupAppLocalizations(locale);
  } catch (e) {
    // Fail-safe default
    _currentLocalizations = AppLocalizationsEn();
  }
}

/// Helper to get the best supported locale from a system/device locale.
Locale getBestSupportedLocale(Locale deviceLocale) {
  const supportedLanguageCodes = {'ar', 'en', 'es', 'he', 'sv', 'de', 'fr', 'hi'};
  if (supportedLanguageCodes.contains(deviceLocale.languageCode)) {
    return Locale(deviceLocale.languageCode);
  }
  return const Locale('en');
}

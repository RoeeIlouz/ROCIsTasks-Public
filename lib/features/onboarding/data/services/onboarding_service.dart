import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingService extends ChangeNotifier {
  static const String _onboardingCompleteKey = 'onboarding_complete';
  final SharedPreferences _prefs;

  OnboardingService(this._prefs);

  bool get hasSeenOnboarding => _prefs.getBool(_onboardingCompleteKey) ?? false;

  Future<void> completeOnboarding() async {
    await _prefs.setBool(_onboardingCompleteKey, true);
    notifyListeners();
  }
}

import 'package:shared_preferences/shared_preferences.dart';

abstract interface class OnboardingPreferences {
  Future<bool> isCompleted();

  Future<void> markCompleted();
}

class SharedPreferencesOnboardingPreferences implements OnboardingPreferences {
  SharedPreferencesOnboardingPreferences([this._preferences]);

  static const _completedKey = 'onboarding.completed';

  SharedPreferencesAsync? _preferences;

  SharedPreferencesAsync get _store =>
      _preferences ??= SharedPreferencesAsync();

  @override
  Future<bool> isCompleted() async =>
      await _store.getBool(_completedKey) ?? false;

  @override
  Future<void> markCompleted() => _store.setBool(_completedKey, true);
}

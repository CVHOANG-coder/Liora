import 'package:shared_preferences/shared_preferences.dart';

abstract interface class YearlySalePreferences {
  Future<void> scheduleAfterWeeklyPurchase();

  Future<bool> consumeScheduledOffer();
}

class SharedPreferencesYearlySalePreferences implements YearlySalePreferences {
  SharedPreferencesYearlySalePreferences([this._preferences]);

  static const _scheduledKey = 'yearly_sale.scheduled_after_weekly_purchase';

  SharedPreferencesAsync? _preferences;

  SharedPreferencesAsync get _store =>
      _preferences ??= SharedPreferencesAsync();

  @override
  Future<void> scheduleAfterWeeklyPurchase() =>
      _store.setBool(_scheduledKey, true);

  @override
  Future<bool> consumeScheduledOffer() async {
    final scheduled = await _store.getBool(_scheduledKey) ?? false;
    if (!scheduled) return false;
    await _store.remove(_scheduledKey);
    return true;
  }
}

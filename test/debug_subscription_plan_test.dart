import 'package:flutter_test/flutter_test.dart';
import 'package:video_gen/data/models/user_profile.dart';
import 'package:video_gen/presentation/providers/home_subscription_plan_provider.dart';
import 'package:video_gen/presentation/screens/in_app_purchase/all_plans_screen.dart';

void main() {
  UserProfile profile(Duration duration, {bool subscribed = true}) {
    final start = DateTime.utc(2026, 10, 9, 23, 58);
    return UserProfile.fromJson({
      'isSubscribed': subscribed,
      'sub_time': start.toIso8601String(),
      'sub_end_time': start.add(duration).toIso8601String(),
    });
  }

  test('debug durations classify consistently across Home and All Plans', () {
    for (final duration in [
      const Duration(minutes: 29),
      const Duration(minutes: 30),
      const Duration(days: 7),
    ]) {
      final user = profile(duration);
      expect(
        homeSubscriptionPlanFromProfile(user),
        HomeSubscriptionPlan.yearly,
      );
      expect(resolveProPlanStatus(user), ProPlanStatus.yearly);
    }
    for (final duration in [
      const Duration(seconds: 1),
      const Duration(minutes: 3),
      const Duration(minutes: 5),
    ]) {
      final user = profile(duration);
      expect(
        homeSubscriptionPlanFromProfile(user),
        HomeSubscriptionPlan.weekly,
      );
      expect(resolveProPlanStatus(user), ProPlanStatus.weekly);
    }
  });

  test('unmatched and invalid durations keep existing resolution', () {
    for (final duration in [
      const Duration(minutes: 5, seconds: 1),
      const Duration(minutes: 28, seconds: 59),
      Duration.zero,
      const Duration(minutes: -1),
    ]) {
      expect(profile(duration).debugSubscriptionIsYearly, isNull);
    }
    final inactive = profile(const Duration(minutes: 30), subscribed: false);
    expect(
      homeSubscriptionPlanFromProfile(inactive),
      HomeSubscriptionPlan.none,
    );
    expect(resolveProPlanStatus(inactive), ProPlanStatus.none);
    expect(
      UserProfile.fromJson({'isSubscribed': true}).debugSubscriptionIsYearly,
      isNull,
    );
  });
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../data/models/package_catalog.dart';
import '../../data/models/user_profile.dart';
import 'package_provider.dart';
import 'profile_provider.dart';
import 'purchase_provider.dart';

enum HomeSubscriptionPlan { none, weekly, yearly }

final googlePlayPastPurchasesProvider =
    FutureProvider.autoDispose<List<PurchaseDetails>>((ref) async {
      if (!ref.watch(googlePlayPlatformProvider)) return const [];
      final gateway = ref.watch(purchaseGatewayProvider);
      if (!await gateway.isAvailable()) return const [];
      return gateway.queryPastPurchases();
    });

final homeSubscriptionPlanProvider =
    FutureProvider.autoDispose<HomeSubscriptionPlan>((ref) async {
      final profile = ref.watch(profileProvider);
      final profilePlan = _planFromProfile(profile);
      if (profilePlan != null) return profilePlan;

      final packages = ref
          .watch(packageCatalogProvider)
          ?.forPlatform(profile?.platform);
      if (packages == null) return HomeSubscriptionPlan.weekly;

      try {
        final purchases = await ref.watch(
          googlePlayPastPurchasesProvider.future,
        );
        return planFromGooglePlayPurchases(purchases, packages) ??
            HomeSubscriptionPlan.weekly;
      } catch (_) {
        return HomeSubscriptionPlan.weekly;
      }
    });

HomeSubscriptionPlan homeSubscriptionPlanFromProfile(UserProfile? profile) =>
    _planFromProfile(profile) ?? HomeSubscriptionPlan.weekly;

HomeSubscriptionPlan? _planFromProfile(UserProfile? profile) {
  if (profile == null || !profile.isSubscribed) {
    return HomeSubscriptionPlan.none;
  }

  final startedAt = profile.subscriptionTime;
  final endsAt = profile.subscriptionEndTime;
  if (startedAt == null || endsAt == null) {
    return HomeSubscriptionPlan.weekly;
  }
  if (_isSameUtcDay(startedAt, endsAt)) return null;
  if (!endsAt.isAfter(startedAt)) return HomeSubscriptionPlan.weekly;

  final subscriptionDays = endsAt.difference(startedAt).inHours / 24;
  return subscriptionDays >= 300
      ? HomeSubscriptionPlan.yearly
      : HomeSubscriptionPlan.weekly;
}

HomeSubscriptionPlan? planFromGooglePlayPurchases(
  List<PurchaseDetails> purchases,
  PlatformPackages packages,
) {
  final weeklyIds = packages.subscriptions
      .where((package) => package.durationDays <= 14)
      .map((package) => package.productId)
      .toSet();
  final yearlyIds = <String>{
    ...packages.subscriptions
        .where((package) => package.durationDays >= 300)
        .map((package) => package.productId),
    ...packages.sales
        .where((package) => package.durationDays >= 300)
        .map((package) => package.productId),
  };

  final matching =
      purchases
          .where((purchase) {
            final active =
                purchase.status == PurchaseStatus.purchased ||
                purchase.status == PurchaseStatus.restored;
            return active &&
                (weeklyIds.contains(purchase.productID) ||
                    yearlyIds.contains(purchase.productID));
          })
          .toList(growable: false)
        ..sort(
          (left, right) =>
              _transactionTime(right).compareTo(_transactionTime(left)),
        );

  if (matching.isEmpty) return null;
  return yearlyIds.contains(matching.first.productID)
      ? HomeSubscriptionPlan.yearly
      : HomeSubscriptionPlan.weekly;
}

bool _isSameUtcDay(DateTime left, DateTime right) {
  final leftUtc = left.toUtc();
  final rightUtc = right.toUtc();
  return leftUtc.year == rightUtc.year &&
      leftUtc.month == rightUtc.month &&
      leftUtc.day == rightUtc.day;
}

int _transactionTime(PurchaseDetails purchase) =>
    int.tryParse(purchase.transactionDate ?? '') ?? 0;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:video_gen/core/storage/yearly_sale_preferences.dart';
import 'package:video_gen/data/models/package_catalog.dart';
import 'package:video_gen/data/models/user_profile.dart';
import 'package:video_gen/data/video_categories.dart';
import 'package:video_gen/presentation/providers/home_subscription_plan_provider.dart';
import 'package:video_gen/presentation/providers/package_provider.dart';
import 'package:video_gen/presentation/providers/profile_provider.dart';
import 'package:video_gen/presentation/providers/purchase_provider.dart';
import 'package:video_gen/presentation/providers/theme_provider.dart';
import 'package:video_gen/presentation/screens/home/home_screen.dart';
import 'package:video_gen/presentation/screens/in_app_purchase/all_plans_screen.dart';
import 'package:video_gen/presentation/screens/in_app_purchase/free_trial_screen.dart';
import 'package:video_gen/presentation/screens/in_app_purchase/in_app_purchase_screen.dart';
import 'package:video_gen/presentation/screens/in_app_purchase/yearly_sale_screen.dart';
import 'package:video_gen/presentation/screens/main/main_screen.dart';

void main() {
  testWidgets('non-VIP opens Free Trial from the Home Pro button', (
    tester,
  ) async {
    _configurePhoneSize(tester);
    final container = _profileContainer(isSubscribed: false);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const Key('homeProButton')),
        matching: find.text('Pro'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('homeProButton')));
    await tester.pumpAndSettle();

    expect(find.byType(FreeTrialScreen), findsOneWidget);
    expect(find.byType(AllPlans), findsNothing);
    expect(find.byKey(const Key('trialClaimButton')), findsOneWidget);
  });

  testWidgets('yearly subscriber sees Credit and opens Buy Credits', (
    tester,
  ) async {
    _configurePhoneSize(tester);
    final container = _profileContainer(
      isSubscribed: true,
      subscriptionDays: 365,
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: MainScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('trialClaimButton')), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const Key('homeProButton')),
        matching: find.text('Credit'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('homeProButton')),
        matching: find.byType(Image),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('homeProButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('trialClaimButton')), findsNothing);
    expect(find.byType(BuyCredits), findsOneWidget);
  });

  testWidgets('same-day test subscription uses Google Play yearly plan', (
    tester,
  ) async {
    _configurePhoneSize(tester);
    final container = _profileContainer(
      isSubscribed: true,
      isVIP: true,
      subscriptionDays: 0,
      googlePlayProductId: 'yearly.product',
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Credit'), findsOneWidget);
    expect(find.text('Upgrade'), findsNothing);
  });

  testWidgets('same-day test subscription uses Google Play weekly plan', (
    tester,
  ) async {
    _configurePhoneSize(tester);
    final container = _profileContainer(
      isSubscribed: true,
      isVIP: true,
      subscriptionDays: 0,
      googlePlayProductId: 'weekly.product',
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Upgrade'), findsOneWidget);
    expect(find.text('Credit'), findsNothing);
  });

  testWidgets('weekly subscriber sees Upgrade and opens All Plans', (
    tester,
  ) async {
    _configurePhoneSize(tester);
    final container = _profileContainer(
      isSubscribed: true,
      isVIP: false,
      subscriptionDays: 7,
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const Key('homeProButton')),
        matching: find.text('Upgrade'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('homeProButton')));
    await tester.pumpAndSettle();

    expect(find.byType(AllPlans), findsOneWidget);
    expect(find.byType(YearlySaleScreen), findsNothing);
  });

  testWidgets('VIP without a subscription opens Home without an offer', (
    tester,
  ) async {
    _configurePhoneSize(tester);
    final container = _profileContainer(isSubscribed: false, isVIP: true);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: MainScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('trialClaimButton')), findsNothing);
    expect(find.byType(YearlySaleScreen), findsNothing);
    expect(find.byKey(const Key('homeProButton')), findsOneWidget);
    expect(find.text('Pro'), findsOneWidget);
  });

  testWidgets('weekly subscriber sees the scheduled yearly sale only once', (
    tester,
  ) async {
    _configurePhoneSize(tester);
    final container = _profileContainer(
      isSubscribed: true,
      isVIP: true,
      subscriptionDays: 7,
      yearlySalePending: true,
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: MainScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(YearlySaleScreen), findsOneWidget);
    expect(find.text('Lola '), findsOneWidget);
    expect(find.text('Sale Pro'), findsOneWidget);

    await tester.tap(find.byKey(const Key('yearlySaleCloseButton')));
    await tester.pumpAndSettle();
    expect(find.byType(YearlySaleScreen), findsNothing);

    await tester.tap(find.byKey(const Key('homeProButton')));
    await tester.pumpAndSettle();
    expect(find.byType(AllPlans), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(find.byType(YearlySaleScreen), findsNothing);
    expect(find.byType(AllPlans), findsOneWidget);
  });

  testWidgets('weekly subscriber does not see an unscheduled yearly sale', (
    tester,
  ) async {
    _configurePhoneSize(tester);
    final container = _profileContainer(
      isSubscribed: true,
      isVIP: true,
      subscriptionDays: 7,
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: MainScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(YearlySaleScreen), findsNothing);
    expect(find.byKey(const Key('homeProButton')), findsOneWidget);
    expect(find.text('Upgrade'), findsOneWidget);
  });
}

ProviderContainer _profileContainer({
  required bool isSubscribed,
  bool? isVIP,
  int subscriptionDays = 7,
  bool yearlySalePending = false,
  String? googlePlayProductId,
}) {
  final container = ProviderContainer(
    overrides: [
      themeCategoriesProvider.overrideWith(
        (ref) async => const <VideoCategory>[],
      ),
      yearlySalePreferencesProvider.overrideWithValue(
        _MemoryYearlySalePreferences(yearlySalePending),
      ),
      if (googlePlayProductId != null)
        googlePlayPastPurchasesProvider.overrideWith(
          (ref) async => <PurchaseDetails>[
            PurchaseDetails(
              purchaseID: 'GPA.test',
              productID: googlePlayProductId,
              verificationData: PurchaseVerificationData(
                localVerificationData: '',
                serverVerificationData: 'token',
                source: 'google_play',
              ),
              transactionDate: '1787558400000',
              status: PurchaseStatus.purchased,
            ),
          ],
        ),
    ],
  );
  container
      .read(profileProvider.notifier)
      .setProfile(
        UserProfile.fromJson(<String, dynamic>{
          'id': 2,
          'user_code': 'USER001',
          'platform': 'ANDROID',
          'is_actived': true,
          'isVIP': isVIP ?? isSubscribed,
          'isSubscribed': isSubscribed,
          'sub_time': isSubscribed ? '2026-08-01T00:00:00Z' : null,
          'sub_end_time': isSubscribed
              ? DateTime.utc(
                  2026,
                  8,
                  1,
                ).add(Duration(days: subscriptionDays)).toIso8601String()
              : null,
          'total_credit': 100,
          'i2v_credit_base': 35,
        }),
      );
  if (googlePlayProductId != null) {
    container
        .read(packageCatalogProvider.notifier)
        .setCatalog(
          PackageCatalog.fromJson(<String, dynamic>{
            'ANDROID': <String, dynamic>{
              'SUBSCRIPTION': <Map<String, dynamic>>[
                <String, dynamic>{
                  'product_id': 'weekly.product',
                  'pack_duration_day': 7,
                },
                <String, dynamic>{
                  'product_id': 'yearly.product',
                  'pack_duration_day': 365,
                },
              ],
            },
          }),
        );
  }
  return container;
}

class _MemoryYearlySalePreferences implements YearlySalePreferences {
  _MemoryYearlySalePreferences(this.pending);

  bool pending;

  @override
  Future<bool> consumeScheduledOffer() async {
    final result = pending;
    pending = false;
    return result;
  }

  @override
  Future<void> scheduleAfterWeeklyPurchase() async => pending = true;
}

void _configurePhoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

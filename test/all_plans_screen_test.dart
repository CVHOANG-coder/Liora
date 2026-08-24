import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_gen/data/models/user_profile.dart';
import 'package:video_gen/presentation/providers/profile_provider.dart';
import 'package:video_gen/presentation/screens/in_app_purchase/all_plans_screen.dart';
import 'package:video_gen/presentation/screens/in_app_purchase/in_app_purchase_screen.dart';

void main() {
  test('resolves subscription state from the user profile', () {
    expect(
      resolveProPlanStatus(
        _profile(
          isSubscribed: false,
          startedAt: '2026-08-12T00:00:00Z',
          endsAt: '2027-08-12T00:00:00Z',
        ),
      ),
      ProPlanStatus.none,
    );
    expect(
      resolveProPlanStatus(
        _profile(
          isSubscribed: true,
          startedAt: '2026-08-01T00:00:00Z',
          endsAt: '2026-08-08T00:00:00Z',
        ),
      ),
      ProPlanStatus.weekly,
    );
    expect(
      resolveProPlanStatus(
        _profile(
          isSubscribed: true,
          startedAt: '2026-08-12T00:00:00Z',
          endsAt: '2027-08-12T00:00:00Z',
        ),
      ),
      ProPlanStatus.yearly,
    );
  });

  testWidgets('renders plans and lets the user change the selected plan', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = _profileContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AllPlans()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nostalia '), findsOneWidget);
    expect(find.text('Ready to go PRO?'), findsOneWidget);
    expect(find.text('Yearly Pro'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -420));
    await tester.pumpAndSettle();
    expect(find.text('Weekly Pro'), findsOneWidget);
    await tester.tap(find.text('Weekly Pro'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('opens BuyCredits from the credit button', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = _profileContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AllPlans()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buy Credits'));
    await tester.pumpAndSettle();

    expect(find.byType(BuyCredits), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('does not grant yearly locally before a store purchase', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = _profileContainer(
      isSubscribed: true,
      startedAt: '2026-08-01T00:00:00Z',
      endsAt: '2026-08-08T00:00:00Z',
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AllPlans()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("You're on PRO"), findsOneWidget);
    expect(find.text('CURRENT PLAN'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Upgrade to Yearly'));
    await tester.pumpAndSettle();

    expect(find.text("You're on PRO"), findsOneWidget);
    expect(find.text('Subscription plans are unavailable.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows the yearly plan benefits and balance', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = _profileContainer(
      isSubscribed: true,
      startedAt: '2026-08-12T00:00:00Z',
      endsAt: '2027-08-12T00:00:00Z',
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AllPlans()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("You're PRO! 👑"), findsOneWidget);
    expect(find.text('Active until 12/08/2027'), findsOneWidget);
    expect(find.text('Unlimited AI video generation'), findsOneWidget);
    expect(find.text('Your Balance'), findsOneWidget);
    expect(find.text('Give PRO, Get More'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

ProviderContainer _profileContainer({
  bool isSubscribed = false,
  String? startedAt,
  String? endsAt,
}) {
  final container = ProviderContainer();
  container
      .read(profileProvider.notifier)
      .setProfile(
        _profile(
          isSubscribed: isSubscribed,
          startedAt: startedAt,
          endsAt: endsAt,
        ),
      );
  return container;
}

UserProfile _profile({
  required bool isSubscribed,
  String? startedAt,
  String? endsAt,
}) {
  return UserProfile.fromJson(<String, dynamic>{
    'id': 2,
    'user_code': 'USER001',
    'is_actived': true,
    'isSubscribed': isSubscribed,
    'sub_time': startedAt,
    'sub_end_time': endsAt,
    'total_credit': 2350,
    'i2v_credit_base': 35,
  });
}

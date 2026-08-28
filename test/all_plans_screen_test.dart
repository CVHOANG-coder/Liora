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

    expect(find.text('Liora '), findsOneWidget);
    expect(find.byKey(const Key('allPlansHeadline')), findsOneWidget);
    expect(find.text('Yearly Pro'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -420));
    await tester.pumpAndSettle();
    expect(find.text('Weekly Pro'), findsOneWidget);
    expect(find.text('3 days free trailer'), findsNothing);
    await tester.tap(find.text('Weekly Pro'));
    await tester.pumpAndSettle();

    expect(find.text('Weekly Pro'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 393.0]) {
    testWidgets('weekly plan follows isVIP at width $width', (tester) async {
      tester.view.physicalSize = Size(width, 852);
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
      await tester.scrollUntilVisible(
        find.text('Weekly Pro'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('Weekly Pro'), findsOneWidget);
      expect(tester.takeException(), isNull);

      container
          .read(profileProvider.notifier)
          .setProfile(
            UserProfile.fromJson({'isSubscribed': false, 'isVIP': true}),
          );
      await tester.pumpAndSettle();

      expect(find.text('3 days free trailer'), findsNothing);
      expect(find.text('Weekly Pro'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

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
    expect(find.text('CURRENT PLAN'), findsNothing);
    expect(find.byKey(const Key('weeklyCurrentPlanCard')), findsNothing);
    expect(find.text('Weekly Pro'), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const Key('yearlyUpgradePlanCard')),
        matching: find.byIcon(Icons.check_rounded),
      ),
      findsOneWidget,
    );
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

  testWidgets('yearly active state stays readable on compact screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
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
        child: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: const MaterialApp(home: AllPlans()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('YOUR LOLA PRO PLAN'), findsOneWidget);
    expect(find.text('Active until 12/08/2027'), findsOneWidget);
    expect(find.text('Explore PRO Tools'), findsOneWidget);
    for (final flex in tester.allRenderObjects.whereType<RenderFlex>()) {
      final children = <String>[];
      var child = flex.firstChild;
      while (child != null) {
        final data = child.parentData as FlexParentData;
        children.add('${child.runtimeType}:${child.size}:${data.offset}');
        child = data.nextSibling;
      }
      // ignore: avoid_print
      print('FLEX ${flex.size} ${flex.debugCreator} children=$children');
    }
    final layoutException = tester.takeException();
    if (layoutException != null) {
      // Keep the widget test diagnostic visible while tuning compact layouts.
      // ignore: avoid_print
      print(layoutException.toString());
    }
    expect(layoutException, isNull);
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

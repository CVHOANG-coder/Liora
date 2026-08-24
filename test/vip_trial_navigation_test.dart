import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_gen/data/models/user_profile.dart';
import 'package:video_gen/data/video_categories.dart';
import 'package:video_gen/presentation/providers/profile_provider.dart';
import 'package:video_gen/presentation/providers/theme_provider.dart';
import 'package:video_gen/presentation/screens/home/home_screen.dart';
import 'package:video_gen/presentation/screens/main/main_screen.dart';

void main() {
  testWidgets('non-subscriber opens free trial from the Home Pro button', (
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

    await tester.tap(find.byKey(const Key('homeProButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('trialClaimButton')), findsOneWidget);
    expect(find.text('free trial works'), findsOneWidget);
  });

  testWidgets('subscriber skips free trial and opens All Plans from Pro', (
    tester,
  ) async {
    _configurePhoneSize(tester);
    final container = _profileContainer(isSubscribed: true);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: MainScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('trialClaimButton')), findsNothing);

    await tester.tap(find.byKey(const Key('homeProButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('trialClaimButton')), findsNothing);
    expect(find.text("You're on PRO"), findsOneWidget);
    expect(find.text('CURRENT PLAN'), findsOneWidget);
  });
}

ProviderContainer _profileContainer({required bool isSubscribed}) {
  final container = ProviderContainer(
    overrides: [
      themeCategoriesProvider.overrideWith(
        (ref) async => const <VideoCategory>[],
      ),
    ],
  );
  container
      .read(profileProvider.notifier)
      .setProfile(
        UserProfile.fromJson(<String, dynamic>{
          'id': 2,
          'user_code': 'USER001',
          'is_actived': true,
          'isVIP': isSubscribed,
          'isSubscribed': isSubscribed,
          'sub_time': isSubscribed ? '2026-08-01T00:00:00Z' : null,
          'sub_end_time': isSubscribed ? '2026-08-08T00:00:00Z' : null,
          'total_credit': 100,
          'i2v_credit_base': 35,
        }),
      );
  return container;
}

void _configurePhoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

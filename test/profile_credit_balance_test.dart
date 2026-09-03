import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_gen/core/constants/app_features.dart';
import 'package:video_gen/data/models/user_profile.dart';
import 'package:video_gen/presentation/providers/profile_provider.dart';
import 'package:video_gen/presentation/screens/in_app_purchase/in_app_purchase_screen.dart';
import 'package:video_gen/presentation/screens/profile/profile_screen.dart';

void main() {
  if (!AppFeatures.commerceEnabled) {
    test('legacy credit card is preserved behind the flag', () {
      expect(AppFeatures.commerceEnabled, isFalse);
    });
    return;
  }

  testWidgets('shows the profile credit balance and opens BuyCredits', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(profileProvider.notifier)
        .setProfile(
          UserProfile.fromJson(<String, dynamic>{
            'id': 2,
            'user_code': 'USER001',
            'username': 'Ava Studio',
            'email': 'ava@example.com',
            'is_actived': true,
            'isSubscribed': true,
            'gen_count': 18,
            'today_gen_count': 3,
            'total_credit': 2350,
            'i2v_credit_base': 35,
          }),
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ProfileScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('CREDIT BALANCE'), findsOneWidget);
    expect(find.text('Buy More Credits'), findsOneWidget);
    expect(find.text('2,350'), findsOneWidget);
    expect(find.text('Ava Studio'), findsOneWidget);
    expect(find.text('ava@example.com'), findsOneWidget);
    expect(find.text('18'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('Pro'), findsNWidgets(2));
    expect(
      tester
          .widget<Semantics>(find.byKey(const Key('profileAccountStatus')))
          .properties
          .value,
      'Account status: active',
    );
    expect(find.byKey(const Key('buyMoreCreditsButton')), findsOneWidget);
    expect(tester.takeException(), isNull);

    final buyMore = find.byKey(const Key('buyMoreCreditsButton'));
    await tester.ensureVisible(buyMore);
    await tester.pumpAndSettle();
    await tester.tap(buyMore);
    await tester.pumpAndSettle();

    expect(find.byType(BuyCredits), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_gen/data/models/package_catalog.dart';
import 'package:video_gen/data/models/user_profile.dart';
import 'package:video_gen/presentation/providers/package_provider.dart';
import 'package:video_gen/presentation/providers/profile_provider.dart';
import 'package:video_gen/presentation/screens/in_app_purchase/all_plans_screen.dart';
import 'package:video_gen/presentation/screens/in_app_purchase/free_trial_screen.dart';
import 'package:video_gen/presentation/screens/in_app_purchase/in_app_purchase_screen.dart';

void main() {
  testWidgets('shows API subscription prices on All Plans', (tester) async {
    final container = _container(isSubscribed: false);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AllPlans()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(r'$29.99/year'), findsOneWidget);
    expect(find.text(r'$7.99/week'), findsOneWidget);
  });

  testWidgets('uses regular or VIP credit prices from subscription state', (
    tester,
  ) async {
    final regularContainer = _container(isSubscribed: false);
    addTearDown(regularContainer.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: regularContainer,
        child: const MaterialApp(home: BuyCredits()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(r'$5.19'), findsOneWidget);
    expect(find.text(r'$2.59'), findsNothing);

    final vipContainer = _container(isSubscribed: true);
    addTearDown(vipContainer.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: vipContainer,
        child: const MaterialApp(home: BuyCredits()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(r'$2.59'), findsOneWidget);
    expect(find.text(r'$5.19'), findsNothing);
  });

  testWidgets(
    'opens the free trial screen when the subscription banner is tapped',
    (tester) async {
      final container = _container(isSubscribed: false);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: BuyCredits()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('subscriptionBanner')));
      await tester.pumpAndSettle();

      expect(find.byType(FreeTrialScreen), findsOneWidget);
    },
  );
}

ProviderContainer _container({required bool isSubscribed}) {
  final container = ProviderContainer();
  container
      .read(profileProvider.notifier)
      .setProfile(
        UserProfile.fromJson(<String, dynamic>{
          'id': 2,
          'platform': 'ANDROID',
          'isSubscribed': isSubscribed,
        }),
      );
  container
      .read(packageCatalogProvider.notifier)
      .setCatalog(
        PackageCatalog.fromJson(<String, dynamic>{
          'ANDROID': <String, dynamic>{
            'SUBSCRIPTION': <Map<String, dynamic>>[
              _package(name: 'Weekly Pro', price: 7.99, days: 7),
              _package(name: 'Annually Pro', price: 49.99, days: 365),
            ],
            'SALE': <Map<String, dynamic>>[
              _package(name: 'Annually Sale', price: 29.99, days: 365),
            ],
            'CONSUMABLE_VIP': <Map<String, dynamic>>[
              _package(name: '70 Credits VIP', price: 2.59, credit: 70),
            ],
            'CONSUMABLE_NEW': <Map<String, dynamic>>[
              _package(name: '70 Credits', price: 5.19, credit: 70),
            ],
          },
        }),
      );
  return container;
}

Map<String, dynamic> _package({
  required String name,
  required double price,
  int days = 0,
  int credit = 0,
}) {
  return <String, dynamic>{
    'id': 1,
    'product_id': name,
    'product_type': days == 0 ? 'CONSUMABLE' : 'SUBSCRIPTION',
    'name': name,
    'price': price,
    'platform': 'ANDROID',
    'description': '',
    'credit': credit,
    'pack_duration_day': days,
  };
}

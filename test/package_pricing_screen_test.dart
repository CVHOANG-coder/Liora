import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_gen/data/models/package_catalog.dart';
import 'package:video_gen/data/models/user_profile.dart';
import 'package:video_gen/presentation/providers/package_provider.dart';
import 'package:video_gen/presentation/providers/profile_provider.dart';
import 'package:video_gen/presentation/providers/purchase_provider.dart';
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

    expect(find.text(r'$49.99/year'), findsOneWidget);
    expect(find.text(r'$7.99/week'), findsOneWidget);
  });

  testWidgets('purchases the regular yearly product from All Plans', (
    tester,
  ) async {
    _configurePhoneSize(tester);
    final container = _container(isSubscribed: false, recordPurchases: true);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AllPlans()),
      ),
    );
    await tester.pumpAndSettle();

    final button = find.text('Start My Subscription');
    await tester.scrollUntilVisible(
      button,
      350,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(button.hitTestable(), findsOneWidget);
    await tester.tap(button);
    await tester.pump();

    final controller =
        container.read(purchaseControllerProvider.notifier)
            as _RecordingPurchaseController;
    expect(controller.productId, 'com.nostalia.ai.videogenerator.annually');
    expect(
      controller.productId,
      isNot('com.nostalia.videogenerator.annuallysale'),
    );
    expect(controller.replaceExistingSubscription, isFalse);
  });

  testWidgets('upgrades a weekly plan to the regular yearly product', (
    tester,
  ) async {
    _configurePhoneSize(tester);
    final container = _container(
      isSubscribed: true,
      recordPurchases: true,
      subscriptionStart: '2026-08-01T00:00:00Z',
      subscriptionEnd: '2026-08-08T00:00:00Z',
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AllPlans()),
      ),
    );
    await tester.pumpAndSettle();

    final button = find.text('Upgrade to Yearly');
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -650));
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pump();

    final controller =
        container.read(purchaseControllerProvider.notifier)
            as _RecordingPurchaseController;
    expect(controller.productId, 'com.nostalia.ai.videogenerator.annually');
    expect(controller.replaceExistingSubscription, isTrue);
  });

  testWidgets('returns Home after a successful yearly purchase', (
    tester,
  ) async {
    _configurePhoneSize(tester);
    final container = _container(isSubscribed: false, recordPurchases: true);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                key: const Key('openAllPlans'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const AllPlans()),
                ),
                child: const Text('Home'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('openAllPlans')));
    await tester.pumpAndSettle();

    final subscribeButton = find.text('Start My Subscription');
    await tester.scrollUntilVisible(
      subscribeButton,
      350,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(subscribeButton.hitTestable(), findsOneWidget);
    await tester.tap(subscribeButton);
    await tester.pump();

    final controller =
        container.read(purchaseControllerProvider.notifier)
            as _RecordingPurchaseController;
    controller.completeSuccessfully();
    await tester.pumpAndSettle();

    expect(controller.productId, 'com.nostalia.ai.videogenerator.annually');
    expect(find.byType(AllPlans), findsNothing);
    expect(find.byKey(const Key('openAllPlans')), findsOneWidget);
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

  testWidgets('returns success after buying credits for a pending request', (
    tester,
  ) async {
    _configurePhoneSize(tester);
    final container = _container(isSubscribed: true, recordPurchases: true);
    addTearDown(container.dispose);
    bool? purchaseResult;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                purchaseResult = await Navigator.of(context).push<bool>(
                  MaterialPageRoute<bool>(
                    builder: (_) =>
                        const BuyCredits(returnPurchaseResult: true),
                  ),
                );
              },
              child: const Text('Open credits'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open credits'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Buy Now'));
    await tester.tap(find.text('Buy Now'));
    await tester.pump();

    final controller =
        container.read(purchaseControllerProvider.notifier)
            as _RecordingPurchaseController;
    controller.completeSuccessfully();
    await tester.pumpAndSettle();

    expect(purchaseResult, isTrue);
    expect(find.byType(BuyCredits), findsNothing);
    expect(find.text('Open credits'), findsOneWidget);
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

  testWidgets('hides the subscription banner for a subscribed user', (
    tester,
  ) async {
    final container = _container(isSubscribed: true);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: BuyCredits()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('subscriptionBanner')), findsNothing);
  });

  testWidgets('opens All Plans for a VIP when the banner is tapped', (
    tester,
  ) async {
    final container = _container(isSubscribed: false, isVIP: true);
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

    expect(find.byType(AllPlans), findsOneWidget);
    expect(find.byType(FreeTrialScreen), findsNothing);
    expect(find.text('Yearly Pro'), findsOneWidget);
    expect(find.text('Weekly Pro'), findsNothing);
  });
}

ProviderContainer _container({
  required bool isSubscribed,
  bool isVIP = false,
  bool recordPurchases = false,
  String? subscriptionStart,
  String? subscriptionEnd,
}) {
  final container = ProviderContainer(
    overrides: recordPurchases
        ? [
            purchaseControllerProvider.overrideWith(
              _RecordingPurchaseController.new,
            ),
          ]
        : const [],
  );
  container
      .read(profileProvider.notifier)
      .setProfile(
        UserProfile.fromJson(<String, dynamic>{
          'id': 2,
          'platform': 'ANDROID',
          'isVIP': isVIP,
          'isSubscribed': isSubscribed,
          'sub_time': subscriptionStart,
          'sub_end_time': subscriptionEnd,
        }),
      );
  container
      .read(packageCatalogProvider.notifier)
      .setCatalog(
        PackageCatalog.fromJson(<String, dynamic>{
          'ANDROID': <String, dynamic>{
            'SUBSCRIPTION': <Map<String, dynamic>>[
              _package(
                productId: 'com.nostalia.ai.videogenerator.weekly',
                name: 'Weekly Pro',
                price: 7.99,
                days: 7,
              ),
              _package(
                productId: 'com.nostalia.ai.videogenerator.annually',
                name: 'Annually Pro',
                price: 49.99,
                days: 365,
              ),
            ],
            'SALE': <Map<String, dynamic>>[
              _package(
                productId: 'com.nostalia.videogenerator.annuallysale',
                name: 'Annually Sale',
                price: 29.99,
                days: 365,
              ),
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
  String? productId,
  required String name,
  required double price,
  int days = 0,
  int credit = 0,
}) {
  return <String, dynamic>{
    'id': 1,
    'product_id': productId ?? name,
    'product_type': days == 0 ? 'CONSUMABLE' : 'SUBSCRIPTION',
    'name': name,
    'price': price,
    'platform': 'ANDROID',
    'description': '',
    'credit': credit,
    'pack_duration_day': days,
  };
}

class _RecordingPurchaseController extends PurchaseController {
  String? productId;
  bool? replaceExistingSubscription;

  @override
  PurchaseState build() =>
      const PurchaseState(status: PurchaseFlowStatus.ready);

  @override
  Future<void> buy({
    required String productId,
    required bool consumable,
    bool replaceExistingSubscription = false,
  }) async {
    this.productId = productId;
    this.replaceExistingSubscription = replaceExistingSubscription;
    state = state.copyWith(
      status: PurchaseFlowStatus.launching,
      productId: productId,
      clearMessage: true,
    );
  }

  void completeSuccessfully() {
    state = state.copyWith(
      status: PurchaseFlowStatus.success,
      message: 'Yearly purchase successful.',
      productId: productId,
    );
  }
}

void _configurePhoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

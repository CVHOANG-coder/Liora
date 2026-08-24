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
  testWidgets('shows the free-trial timeline and opens all plans', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => FreeTrialScreen.open(context),
              child: const Text('Open trial'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open trial'));
    await tester.pumpAndSettle();

    expect(find.byType(FreeTrialScreen), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
    expect(find.text('How your'), findsOneWidget);
    expect(find.text('free trial works'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('In 2 days'), findsOneWidget);
    expect(find.text('In 3 days'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final viewPlans = find.byKey(const Key('viewAllPlansButton'));
    await tester.ensureVisible(viewPlans);
    await tester.pumpAndSettle();
    await tester.tap(viewPlans);
    await tester.pumpAndSettle();

    expect(find.byType(AllPlans), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('returns to FreeTrialScreen after closing BuyCredits', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => FreeTrialScreen.open(context),
              child: const Text('Open trial'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open trial'));
    await tester.pumpAndSettle();

    final priceOffer = find.byKey(const Key('trialPriceOffer'));
    await tester.ensureVisible(priceOffer);
    await tester.tap(priceOffer);
    await tester.pumpAndSettle();

    expect(find.byType(BuyCredits), findsOneWidget);
    expect(find.byType(FreeTrialScreen), findsNothing);

    await tester.tap(find.byKey(const Key('buyCreditsCloseButton')));
    await tester.pumpAndSettle();

    expect(find.byType(BuyCredits), findsNothing);
    expect(find.byType(FreeTrialScreen), findsOneWidget);
    expect(find.text('free trial works'), findsOneWidget);
  });

  testWidgets('starts the weekly IAP and closes after purchase success', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer(
      overrides: [
        purchaseControllerProvider.overrideWith(
          _RecordingPurchaseController.new,
        ),
      ],
    );
    addTearDown(container.dispose);
    container
        .read(profileProvider.notifier)
        .setProfile(
          UserProfile.fromJson(<String, dynamic>{
            'id': 2,
            'platform': 'ANDROID',
          }),
        );
    container
        .read(packageCatalogProvider.notifier)
        .setCatalog(
          PackageCatalog.fromJson(<String, dynamic>{
            'ANDROID': <String, dynamic>{
              'SUBSCRIPTION': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 7,
                  'product_id': 'weekly.pro.trial',
                  'product_type': 'SUBSCRIPTION',
                  'name': 'Weekly Pro',
                  'price': 7.99,
                  'platform': 'ANDROID',
                  'description': 'Three-day trial',
                  'credit': 0,
                  'pack_duration_day': 7,
                },
              ],
            },
          }),
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => FreeTrialScreen.open(context),
                child: const Text('Open trial'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open trial'));
    await tester.pumpAndSettle();

    final claimButton = find.byKey(const Key('trialClaimButton'));
    await tester.ensureVisible(claimButton);
    await tester.tap(claimButton);
    await tester.pump();

    final controller =
        container.read(purchaseControllerProvider.notifier)
            as _RecordingPurchaseController;
    expect(controller.productId, 'weekly.pro.trial');
    expect(controller.consumable, isFalse);
    expect(find.text('Processing...'), findsOneWidget);

    controller.completeSuccessfully();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(FreeTrialScreen), findsNothing);
    expect(find.text('Open trial'), findsOneWidget);
    expect(find.text('Weekly trial started.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _RecordingPurchaseController extends PurchaseController {
  String? productId;
  bool? consumable;

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
    this.consumable = consumable;
    state = state.copyWith(
      status: PurchaseFlowStatus.launching,
      productId: productId,
      clearMessage: true,
    );
  }

  void completeSuccessfully() {
    state = state.copyWith(
      status: PurchaseFlowStatus.success,
      message: 'Weekly trial started.',
    );
  }
}

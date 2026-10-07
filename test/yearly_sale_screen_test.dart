import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_gen/data/models/package_catalog.dart';
import 'package:video_gen/data/models/user_profile.dart';
import 'package:video_gen/presentation/providers/package_provider.dart';
import 'package:video_gen/presentation/providers/profile_provider.dart';
import 'package:video_gen/presentation/providers/purchase_provider.dart';
import 'package:video_gen/presentation/screens/in_app_purchase/yearly_sale_screen.dart';

void main() {
  testWidgets('renders the annual offer using sale package pricing', (
    tester,
  ) async {
    _configurePhoneSize(tester);
    final container = _container();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: YearlySaleScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Lola '), findsNothing);
    expect(find.text('Annually'), findsOneWidget);
    expect(find.text('Sale Pro'), findsOneWidget);
    expect(find.byKey(const Key('yearlySaleProBannerVideo')), findsOneWidget);
    expect(find.text(r'$29.99'), findsOneWidget);
    expect(find.text(r'$99.99/year'), findsOneWidget);
    expect(find.text('SAVE 70%'), findsOneWidget);
    expect(find.textContaining('/week'), findsNothing);
    expect(find.textContaining('Billed annually'), findsNothing);
    expect(find.text('7-day free trial'), findsNothing);
    expect(find.text('Upgrade to Annual'), findsOneWidget);
    expect(find.text('Buy more credits'), findsOneWidget);
    final close = tester.getRect(
      find.byKey(const Key('yearlySaleCloseButton')),
    );
    final content = tester.getRect(
      find.byKey(const Key('yearlySaleBottomContent')),
    );
    expect(content.top - close.bottom, greaterThan(40));
    expect(content.bottom, closeTo(tester.view.physicalSize.height, 1));
    expect(
      tester
          .getBottomRight(find.byKey(const Key('yearlySaleBuyCreditsButton')))
          .dy,
      lessThanOrEqualTo(tester.view.physicalSize.height),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps the bottom actions reachable on a compact screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 44, bottom: 34);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    final container = _container();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: YearlySaleScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(
      find.text('Restore Purchase'),
      250,
      scrollable: find.descendant(
        of: find.byKey(const Key('yearlySaleScrollView')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Restore Purchase'), findsOneWidget);
    expect(
      tester.getRect(find.text('Restore Purchase')).bottom,
      lessThanOrEqualTo(568 - 34),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('purchases the SALE product as a weekly plan replacement', (
    tester,
  ) async {
    _configurePhoneSize(tester);
    final container = _container();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: YearlySaleScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final button = find.byKey(const Key('yearlySalePurchaseButton'));
    await tester.scrollUntilVisible(
      button,
      350,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.takeException(), isNull);
    await tester.tap(button);
    await tester.pump();

    final controller =
        container.read(purchaseControllerProvider.notifier)
            as _RecordingPurchaseController;
    expect(controller.productId, 'com.lioraai.videogenerator.annuallysale');
    expect(controller.consumable, isFalse);
    expect(controller.replaceExistingSubscription, isTrue);
    expect(find.text('Processing...'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

ProviderContainer _container() {
  final container = ProviderContainer(
    overrides: [
      purchaseControllerProvider.overrideWith(_RecordingPurchaseController.new),
    ],
  );
  container
      .read(profileProvider.notifier)
      .setProfile(
        UserProfile.fromJson(<String, dynamic>{
          'id': 2,
          'platform': 'ANDROID',
          'isVIP': true,
          'isSubscribed': true,
          'sub_time': '2026-08-01T00:00:00Z',
          'sub_end_time': '2026-08-08T00:00:00Z',
        }),
      );
  container
      .read(packageCatalogProvider.notifier)
      .setCatalog(
        PackageCatalog.fromJson(<String, dynamic>{
          'ANDROID': <String, dynamic>{
            'SUBSCRIPTION': <Map<String, dynamic>>[
              _package(
                'com.lioraai.videogenerator.weekly',
                'Weekly Pro',
                7.99,
                7,
              ),
              _package(
                'com.lioraai.videogenerator.annually',
                'Yearly Pro',
                99.99,
                365,
              ),
            ],
            'SALE': <Map<String, dynamic>>[
              _package(
                'com.lioraai.videogenerator.annuallysale',
                'Yearly Sale Pro',
                29.99,
                365,
              ),
            ],
          },
        }),
      );
  return container;
}

Map<String, dynamic> _package(
  String productId,
  String name,
  double price,
  int days,
) {
  return <String, dynamic>{
    'id': days,
    'product_id': productId,
    'product_type': 'SUBSCRIPTION',
    'name': name,
    'price': price,
    'platform': 'ANDROID',
    'description': '',
    'credit': 0,
    'pack_duration_day': days,
  };
}

class _RecordingPurchaseController extends PurchaseController {
  String? productId;
  bool? consumable;
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
    this.consumable = consumable;
    this.replaceExistingSubscription = replaceExistingSubscription;
    state = state.copyWith(
      status: PurchaseFlowStatus.launching,
      productId: productId,
      clearMessage: true,
    );
  }
}

void _configurePhoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

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
  testWidgets('renders the Nostalia yearly offer using sale package pricing', (
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

    expect(find.text('Nostalia '), findsOneWidget);
    expect(find.text('Sale Pro'), findsOneWidget);
    expect(find.text(r'$29.99'), findsOneWidget);
    expect(find.text(r'$99.99/year'), findsOneWidget);
    expect(find.text('Save 70%'), findsOneWidget);
    expect(find.text('SAVE 70%'), findsOneWidget);
    expect(find.text('7-day free trial'), findsOneWidget);
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
    expect(controller.productId, 'nostalia.yearly.sale');
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
              _package('nostalia.weekly', 'Weekly Pro', 7.99, 7),
              _package('nostalia.yearly', 'Yearly Pro', 99.99, 365),
            ],
            'SALE': <Map<String, dynamic>>[
              _package('nostalia.yearly.sale', 'Yearly Sale Pro', 29.99, 365),
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

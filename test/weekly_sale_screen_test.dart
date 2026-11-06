import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_gen/core/constants/iap_product_ids.dart';
import 'package:video_gen/data/models/package_catalog.dart';
import 'package:video_gen/presentation/providers/package_provider.dart';
import 'package:video_gen/presentation/providers/purchase_provider.dart';
import 'package:video_gen/presentation/screens/in_app_purchase/weekly_sale_screen.dart';

void main() {
  testWidgets(
    'uses weeklybonus from SUBSCRIPTION and keeps actions reachable',
    (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final container = ProviderContainer(
        overrides: [
          purchaseControllerProvider.overrideWith(_Purchases.new),
          iapCatalogPlatformProvider.overrideWithValue('IOS'),
        ],
      );
      addTearDown(container.dispose);
      container
          .read(packageCatalogProvider.notifier)
          .setCatalog(
            PackageCatalog.fromJson({
              'IOS': {
                'SUBSCRIPTION': [
                  {
                    'product_id': IapProductIds.weekly,
                    'pack_duration_day': 7,
                    'price': 7.99,
                  },
                  {
                    'product_id': IapProductIds.weeklyBonus,
                    'pack_duration_day': 7,
                    'price': 0.99,
                  },
                ],
                'SALE': [
                  {
                    'product_id': 'annual.sale',
                    'pack_duration_day': 365,
                    'price': 29.99,
                  },
                  {
                    'product_id': 'weekly.sale',
                    'pack_duration_day': 7,
                    'price': 0.19,
                  },
                ],
              },
            }),
          );
      const preview = String.fromEnvironment('WEEKLY_SALE_PREVIEW');
      if (preview.isNotEmpty) {
        await (FontLoader(
          'Nunito',
        )..addFont(rootBundle.load('assets/fonts/Nunito-VF.ttf'))).load();
        await (FontLoader(
          'MaterialIcons',
        )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      }
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: ThemeData(fontFamily: 'Nunito'),
            home: RepaintBoundary(
              key: Key('preview'),
              child: WeeklySaleScreen(),
            ),
          ),
        ),
      );
      Animation<double> pulse() => tester
          .widget<ScaleTransition>(find.byKey(const Key('weeklySalePulse')))
          .scale;
      expect(pulse().status, AnimationStatus.dismissed);
      await tester.pump(const Duration(milliseconds: 2000));
      expect(pulse().status, AnimationStatus.dismissed);
      await tester.pump(const Duration(milliseconds: 2300));
      expect(pulse().status, AnimationStatus.forward);
      expect(find.text(r'$0.99'), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (preview.isNotEmpty) {
        await tester.runAsync(() async {
          final context = tester.element(find.byType(WeeklySaleScreen));
          for (final asset in [
            'free_trailer_icon_banner',
            'today_free_trailer',
            'day3_free_trailer',
            'discount_free_trailer',
          ]) {
            await precacheImage(
              AssetImage('assets/images/in_app_purchase/$asset.png'),
              context,
            );
          }
        });
        await tester.pump(const Duration(milliseconds: 4300));
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const Key('preview')),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(preview).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.scrollUntilVisible(
        find.byKey(const Key('weeklySalePurchaseButton')),
        150,
      );
      await tester.tap(find.byKey(const Key('weeklySalePurchaseButton')));
      await tester.pump();
      expect(
        (container.read(purchaseControllerProvider.notifier) as _Purchases)
            .purchased,
        IapProductIds.weeklyBonus,
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('does not purchase a regular weekly plan when sale is missing', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        purchaseControllerProvider.overrideWith(_Purchases.new),
        iapCatalogPlatformProvider.overrideWithValue('ANDROID'),
      ],
    );
    addTearDown(container.dispose);
    container
        .read(packageCatalogProvider.notifier)
        .setCatalog(
          PackageCatalog.fromJson({
            'ANDROID': {
              'SUBSCRIPTION': [
                {
                  'product_id': IapProductIds.weekly,
                  'pack_duration_day': 7,
                  'price': 7.99,
                },
              ],
              'SALE': [
                {
                  'product_id': 'weekly.sale',
                  'pack_duration_day': 7,
                  'price': 0.19,
                },
              ],
            },
          }),
        );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: ThemeData(fontFamily: 'Nunito'),
          home: WeeklySaleScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 4300));
    await tester.scrollUntilVisible(
      find.byKey(const Key('weeklySalePurchaseButton')),
      150,
    );
    await tester.tap(find.byKey(const Key('weeklySalePurchaseButton')));
    await tester.pump();
    expect(
      (container.read(purchaseControllerProvider.notifier) as _Purchases)
          .purchased,
      isNull,
    );
    expect(
      find.text('The weekly sale is currently unavailable.'),
      findsOneWidget,
    );
  });

  testWidgets('compact screen and large text can scroll to restore', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [purchaseControllerProvider.overrideWith(_Purchases.new)],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(1.5)),
            child: child!,
          ),
          home: const WeeklySaleScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 4300));
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.byKey(const Key('weeklySaleRestoreButton')),
      200,
    );
    await tester.pump(const Duration(milliseconds: 4300));
    expect(
      find.byKey(const Key('weeklySaleRestoreButton')).hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

class _Purchases extends PurchaseController {
  String? purchased;
  @override
  PurchaseState build() =>
      const PurchaseState(status: PurchaseFlowStatus.ready);
  @override
  Future<void> buy({
    required String productId,
    required bool consumable,
    bool replaceExistingSubscription = false,
  }) async {
    purchased = productId;
    state = PurchaseState(
      status: PurchaseFlowStatus.launching,
      productId: productId,
    );
  }
}

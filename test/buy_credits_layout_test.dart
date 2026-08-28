import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:video_gen/presentation/providers/purchase_provider.dart';
import 'package:video_gen/presentation/screens/in_app_purchase/in_app_purchase_screen.dart';
import 'package:video_gen/shared/themes/app_theme.dart';

const _productPrefix = 'com.nostalia.ai.videogenerator.';

void main() {
  const previewPath = String.fromEnvironment('CREDITS_PREVIEW_PATH');
  const sansPath = String.fromEnvironment('CREDITS_PREVIEW_SANS');
  const serifPath = String.fromEnvironment('CREDITS_PREVIEW_SERIF');

  setUpAll(() async {
    if (previewPath.isEmpty) return;
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    if (sansPath.isNotEmpty) {
      for (final family in ['Roboto', '.SF Pro Text', '.SF Pro Display']) {
        final loader = FontLoader(family)
          ..addFont(File(sansPath).readAsBytes().then(ByteData.sublistView));
        await loader.load();
      }
    }
    if (serifPath.isNotEmpty) {
      final loader = FontLoader('Times New Roman')
        ..addFont(File(serifPath).readAsBytes().then(ByteData.sublistView));
      await loader.load();
    }
  });

  for (final size in [
    const Size(320, 568),
    const Size(393, 698),
    const Size(393, 852),
    const Size(430, 932),
  ]) {
    for (final textScale in [1.0, 1.5]) {
      testWidgets('Credit layout at $size, text $textScale', (tester) async {
        _configureView(tester, size);
        final container = _container();
        addTearDown(container.dispose);
        await _pumpScreen(
          tester,
          container,
          textScale: textScale,
          previewFonts: previewPath.isNotEmpty,
        );
        expect(tester.takeException(), isNull);
        expect(
          tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
          const Color(0xFF02050C),
        );
        expect(
          tester.widget<Text>(find.text('Buy Credit')).style!.fontFamily,
          'Times New Roman',
        );
        final header = tester.getRect(
          find.byKey(const Key('buyCreditsHeader')),
        );
        final close = tester.getRect(
          find.byKey(const Key('buyCreditsCloseButton')),
        );
        expect(close.width, closeTo(44, 0.001));
        expect(close.height, closeTo(44, 0.001));
        expect(_selection(tester, 70), isFalse);

        if (previewPath.isNotEmpty &&
            size == const Size(393, 852) &&
            textScale == 1) {
          await tester.runAsync(() async {
            final context = tester.element(find.byType(BuyCredits));
            for (final asset in ['credit', 'gift']) {
              await precacheImage(
                AssetImage('assets/images/in_app_purchase/$asset.png'),
                context,
              );
            }
          });
          await tester.pumpAndSettle();
          final previousShadows = debugDisableShadows;
          try {
            debugDisableShadows = false;
            await tester.pumpWidget(const SizedBox.shrink());
            await _pumpScreen(tester, container, previewFonts: true);
            final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(const Key('creditsPreview')),
            );
            await tester.runAsync(() async {
              final image = await boundary.toImage(pixelRatio: 2);
              try {
                final bytes = await image.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                await File(
                  previewPath,
                ).writeAsBytes(bytes!.buffer.asUint8List());
              } finally {
                image.dispose();
              }
            });
          } finally {
            debugDisableShadows = previousShadows;
          }
        }

        for (final credits in [70, 150, 500, 1000, 5000]) {
          final tile = _tile(credits);
          await tester.scrollUntilVisible(tile, 100, scrollable: _scrollable());
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(
            tester
                .widget<Text>(find.text('$credits Credits'))
                .style!
                .fontFamily,
            'Times New Roman',
          );
          expect(
            find.descendant(
              of: tile,
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is Image &&
                    widget.image is AssetImage &&
                    (widget.image as AssetImage).assetName ==
                        'assets/images/in_app_purchase/credit.png',
              ),
            ),
            findsOneWidget,
          );
        }
        expect(_selection(tester, 5000), isTrue);
        final decoration =
            tester
                    .widget<AnimatedContainer>(
                      find.byKey(const Key('creditPackageSurface-5000')),
                    )
                    .decoration!
                as BoxDecoration;
        expect((decoration.gradient! as LinearGradient).colors, const [
          Color(0xFFEC5FB6),
          Color(0xFFA850CF),
          Color(0xFF4561DF),
        ]);

        final disclaimer = find.byKey(const Key('buyCreditsDisclaimer'));
        await tester.scrollUntilVisible(
          disclaimer,
          100,
          scrollable: _scrollable(),
        );
        await tester.pumpAndSettle();
        expect(disclaimer.hitTestable(), findsOneWidget);
        expect(find.text('Buy Now').hitTestable(), findsOneWidget);
        expect(find.text('Restore Purchase').hitTestable(), findsOneWidget);
        expect(
          tester.getRect(find.byKey(const Key('buyCreditsHeader'))),
          header,
        );
        expect(
          tester.getRect(find.byKey(const Key('buyCreditsCloseButton'))),
          close,
        );
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
    'uses store prices, selects a package, and prevents duplicate purchases',
    (tester) async {
      _configureView(tester, const Size(393, 852));
      final container = _container();
      addTearDown(container.dispose);
      final controller =
          container.read(purchaseControllerProvider.notifier)
              as _RecordingPurchases;
      controller.showStorePrice();
      await _pumpScreen(tester, container);
      expect(find.text('139.000 ₫'), findsOneWidget);
      expect(find.text('VND 136,000'), findsNothing);
      await tester.tap(_tile(70));
      await tester.pumpAndSettle();
      expect(_selection(tester, 70), isTrue);
      expect(_selection(tester, 5000), isFalse);

      final button = find.byKey(const Key('buyCreditsButton'));
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pump();
      expect(controller.purchases, ['${_productPrefix}70_credits']);
      expect(controller.consumable, isTrue);
      expect(find.text('Waiting for payment...'), findsOneWidget);
      final purchaseTap = tester.widget<InkWell>(
        find.descendant(of: button, matching: find.byType(InkWell)),
      );
      expect(purchaseTap.onTap, isNull);
      await tester.tap(button);
      await tester.pump();
      expect(controller.purchases.length, 1);

      await tester.scrollUntilVisible(
        _tile(70),
        -100,
        scrollable: _scrollable(),
      );
      await tester.pump();
      expect(tester.widget<Semantics>(_tile(70)).properties.enabled, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('restore action retains its progress state', (tester) async {
    _configureView(tester, const Size(393, 852));
    final container = _container();
    addTearDown(container.dispose);
    await _pumpScreen(tester, container);
    await tester.ensureVisible(find.text('Restore Purchase'));
    await tester.tap(find.text('Restore Purchase'));
    await tester.pump();
    final controller =
        container.read(purchaseControllerProvider.notifier)
            as _RecordingPurchases;
    expect(controller.restoreCalls, 1);
    expect(find.text('Restoring...'), findsOneWidget);
    expect(find.text('Restoring purchases...'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Finder _tile(int credits) =>
    find.byKey(ValueKey('creditPackage-$_productPrefix${credits}_credits'));

Finder _scrollable() => find.descendant(
  of: find.byKey(const PageStorageKey('buyCreditsScroll')),
  matching: find.byType(Scrollable),
);

bool? _selection(WidgetTester tester, int credits) =>
    tester.widget<Semantics>(_tile(credits)).properties.selected;

ProviderContainer _container() => ProviderContainer(
  overrides: [purchaseControllerProvider.overrideWith(_RecordingPurchases.new)],
);

void _configureView(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 44, bottom: 34);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPadding);
}

Future<void> _pumpScreen(
  WidgetTester tester,
  ProviderContainer container, {
  double textScale = 1,
  bool previewFonts = false,
}) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: RepaintBoundary(
        key: const Key('creditsPreview'),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: previewFonts
              ? AppTheme.dark.copyWith(
                  textTheme: AppTheme.dark.textTheme.apply(
                    fontFamily: 'Roboto',
                  ),
                )
              : AppTheme.dark,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: const BuyCredits(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _RecordingPurchases extends PurchaseController {
  final purchases = <String>[];
  bool? consumable;
  int restoreCalls = 0;

  @override
  PurchaseState build() =>
      const PurchaseState(status: PurchaseFlowStatus.ready);

  void showStorePrice() {
    const id = '${_productPrefix}70_credits';
    state = PurchaseState(
      status: PurchaseFlowStatus.ready,
      products: {
        id: ProductDetails(
          id: id,
          title: '70 Credits',
          description: '',
          price: '139.000 ₫',
          rawPrice: 139000,
          currencyCode: 'VND',
        ),
      },
    );
  }

  @override
  Future<void> buy({
    required String productId,
    required bool consumable,
    bool replaceExistingSubscription = false,
  }) async {
    purchases.add(productId);
    this.consumable = consumable;
    state = state.copyWith(
      status: PurchaseFlowStatus.pending,
      productId: productId,
    );
  }

  @override
  Future<void> restore() async {
    restoreCalls++;
    state = state.copyWith(status: PurchaseFlowStatus.restoring);
  }
}

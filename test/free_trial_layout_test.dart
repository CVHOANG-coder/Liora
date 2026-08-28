import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:video_gen/data/models/package_catalog.dart';
import 'package:video_gen/data/models/user_profile.dart';
import 'package:video_gen/presentation/providers/package_provider.dart';
import 'package:video_gen/presentation/providers/profile_provider.dart';
import 'package:video_gen/presentation/providers/purchase_provider.dart';
import 'package:video_gen/presentation/screens/in_app_purchase/free_trial_screen.dart';
import 'package:video_gen/shared/themes/app_theme.dart';

const _previewPath = String.fromEnvironment('TRIAL_PREVIEW_PATH');
const _sansPath = String.fromEnvironment('TRIAL_PREVIEW_SANS');
const _serifPath = String.fromEnvironment('TRIAL_PREVIEW_SERIF');

void main() {
  setUpAll(() async {
    if (_previewPath.isEmpty) return;
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    if (_sansPath.isNotEmpty) {
      for (final family in ['Roboto', '.SF Pro Text', '.SF Pro Display']) {
        final loader = FontLoader(family)
          ..addFont(File(_sansPath).readAsBytes().then(ByteData.sublistView));
        await loader.load();
      }
    }
    if (_serifPath.isNotEmpty) {
      final loader = FontLoader('Times New Roman')
        ..addFont(File(_serifPath).readAsBytes().then(ByteData.sublistView));
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
      testWidgets('Free trial layout at $size, text $textScale', (
        tester,
      ) async {
        _configureView(tester, size);
        final container = _container();
        addTearDown(container.dispose);
        final previousShadows = debugDisableShadows;
        try {
          if (_previewPath.isNotEmpty) debugDisableShadows = false;
          await _pumpScreen(tester, container, textScale: textScale);
          expect(tester.takeException(), isNull);
          expect(
            tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
            const Color(0xFF02050E),
          );
          final close = tester.getRect(
            find.byKey(const Key('trialLaterButton')),
          );
          expect(close.width, closeTo(44, 0.001));
          expect(close.height, closeTo(44, 0.001));
          for (final title in ['How your', 'free trial works']) {
            expect(
              tester.widget<Text>(find.text(title)).style!.fontFamily,
              'Times New Roman',
            );
            expect(
              tester.widget<Text>(find.text(title)).style!.fontWeight,
              FontWeight.w400,
            );
          }
          expect(_asset('free_trailer_icon_banner'), findsOneWidget);

          if (_previewPath.isNotEmpty &&
              size == const Size(393, 852) &&
              textScale == 1) {
            await tester.runAsync(() async {
              final context = tester.element(find.byType(FreeTrialScreen));
              for (final asset in [
                'free_trailer_icon_banner',
                'today_free_trailer',
                'day2_free_trailer',
                'day3_free_trailer',
                'discount_free_trailer',
                'credit',
              ]) {
                await precacheImage(
                  AssetImage('assets/images/in_app_purchase/$asset.png'),
                  context,
                );
              }
            });
            await tester.pumpAndSettle();
            final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(const Key('trialPreview')),
            );
            await tester.runAsync(() async {
              final image = await boundary.toImage(pixelRatio: 2);
              try {
                final bytes = await image.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                await File(
                  _previewPath,
                ).writeAsBytes(bytes!.buffer.asUint8List());
              } finally {
                image.dispose();
              }
            });
          }

          for (var step = 1; step <= 3; step++) {
            final card = find.byKey(ValueKey('trialStepCard-$step'));
            await tester.scrollUntilVisible(
              card,
              100,
              scrollable: _scrollable(),
            );
            await tester.pumpAndSettle();
            final decoration =
                tester.widget<Container>(card).decoration! as BoxDecoration;
            expect((decoration.gradient! as LinearGradient).colors, const [
              Color(0xFF101321),
              Color(0xFF080D19),
            ]);
            expect(
              (decoration.border! as Border).top.color,
              const Color(0xFF3C3D4E),
            );
            expect(decoration.boxShadow, isNull);
            final number = tester.getRect(
              find.byKey(ValueKey('trialStepNumber-$step')),
            );
            expect(number.center.dx, lessThan(tester.getRect(card).left));
            expect(number.top, greaterThanOrEqualTo(tester.getRect(card).top));
            expect(tester.takeException(), isNull);
          }

          await tester.scrollUntilVisible(
            find.byKey(const Key('trialLegalFooter')),
            100,
            scrollable: _scrollable(),
          );
          await tester.pumpAndSettle();
          expect(find.text('Restore Purchase').hitTestable(), findsOneWidget);
          expect(
            find.byKey(const Key('trialClaimButton')).hitTestable(),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('viewAllPlansButton')).hitTestable(),
            findsOneWidget,
          );
          final primary =
              tester
                      .widget<Container>(
                        find.byKey(const Key('trialClaimSurface')),
                      )
                      .decoration!
                  as BoxDecoration;
          expect((primary.gradient! as LinearGradient).colors, const [
            Color(0xFFDF458D),
            Color(0xFF9044AD),
            Color(0xFF3553D2),
          ]);
          expect(
            tester.getRect(find.byKey(const Key('trialLaterButton'))),
            close,
          );
          expect(
            find.byKey(const Key('trialLaterButton')).hitTestable(),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        } finally {
          debugDisableShadows = previousShadows;
        }
      });
    }
  }

  testWidgets(
    'trial shows the localized store price and blocks duplicate checkout',
    (tester) async {
      _configureView(tester, const Size(393, 852));
      final container = _container();
      addTearDown(container.dispose);
      container
          .read(profileProvider.notifier)
          .setProfile(UserProfile.fromJson({'id': 2, 'platform': 'ANDROID'}));
      container
          .read(packageCatalogProvider.notifier)
          .setCatalog(
            PackageCatalog.fromJson({
              'ANDROID': {
                'SUBSCRIPTION': [
                  {
                    'id': 7,
                    'product_id': 'weekly.trial',
                    'product_type': 'SUBSCRIPTION',
                    'name': 'Weekly Pro',
                    'price': 7.99,
                    'platform': 'ANDROID',
                    'description': '',
                    'credit': 0,
                    'pack_duration_day': 7,
                  },
                ],
              },
            }),
          );
      final controller =
          container.read(purchaseControllerProvider.notifier)
              as _TrialPurchases;
      controller.showPrice();
      await _pumpScreen(tester, container);
      final offer = find.byKey(const Key('trialPriceOffer'));
      await tester.scrollUntilVisible(offer, 150, scrollable: _scrollable());
      expect(
        tester
            .widget<Text>(find.byKey(const Key('trialWeeklyPrice')))
            .textSpan!
            .toPlainText(),
        '199.000 ₫ /week',
      );
      final button = find.byKey(const Key('trialClaimButton'));
      await tester.scrollUntilVisible(button, 100, scrollable: _scrollable());
      await tester.tap(button);
      await tester.pump();
      expect(controller.purchases, ['weekly.trial']);
      expect(controller.consumable, isFalse);
      expect(find.text('Processing...'), findsOneWidget);
      expect(
        tester
            .widget<InkWell>(
              find.descendant(of: button, matching: find.byType(InkWell)),
            )
            .onTap,
        isNull,
      );
      await tester.tap(button);
      await tester.pump();
      expect(controller.purchases.length, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('restores purchases with busy state and completion feedback', (
    tester,
  ) async {
    _configureView(tester, const Size(393, 852));
    final container = _container();
    addTearDown(container.dispose);
    await _pumpScreen(tester, container);
    final restore = find.byKey(const Key('trialRestoreButton'));
    await tester.scrollUntilVisible(restore, 150, scrollable: _scrollable());
    await tester.tap(restore);
    await tester.pump();
    final controller =
        container.read(purchaseControllerProvider.notifier) as _TrialPurchases;
    expect(controller.restoreCalls, 1);
    expect(find.text('Restoring...'), findsOneWidget);
    expect(tester.widget<TextButton>(restore).onPressed, isNull);
    controller.restored.complete();
    await tester.pumpAndSettle();
    expect(find.text('Previous purchases have been checked.'), findsOneWidget);
    expect(find.text('Restore Purchase'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Finder _scrollable() => find.descendant(
  of: find.byKey(const PageStorageKey('freeTrialScroll')),
  matching: find.byType(Scrollable),
);

Finder _asset(String name) => find.byWidgetPredicate(
  (widget) =>
      widget is Image &&
      widget.image is AssetImage &&
      (widget.image as AssetImage).assetName ==
          'assets/images/in_app_purchase/$name.png',
);

ProviderContainer _container() => ProviderContainer(
  overrides: [purchaseControllerProvider.overrideWith(_TrialPurchases.new)],
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
}) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: RepaintBoundary(
        key: const Key('trialPreview'),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: _previewPath.isEmpty
              ? AppTheme.dark
              : AppTheme.dark.copyWith(
                  textTheme: AppTheme.dark.textTheme.apply(
                    fontFamily: 'Roboto',
                  ),
                ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: const FreeTrialScreen(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _TrialPurchases extends PurchaseController {
  final purchases = <String>[];
  bool? consumable;
  int restoreCalls = 0;
  final restored = Completer<void>();

  @override
  PurchaseState build() =>
      const PurchaseState(status: PurchaseFlowStatus.ready);

  void showPrice() {
    state = PurchaseState(
      status: PurchaseFlowStatus.ready,
      products: {
        'weekly.trial': ProductDetails(
          id: 'weekly.trial',
          title: 'Weekly Pro',
          description: '',
          price: '199.000 ₫',
          rawPrice: 199000,
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
    await restored.future;
    state = state.copyWith(
      status: PurchaseFlowStatus.ready,
      message: 'Previous purchases have been checked.',
    );
  }
}

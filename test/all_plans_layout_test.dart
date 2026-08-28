import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_gen/presentation/screens/in_app_purchase/all_plans_screen.dart';
import 'package:video_gen/shared/themes/app_theme.dart';

const _previewPath = String.fromEnvironment('ALL_PLANS_PREVIEW_PATH');
const _fontPath = String.fromEnvironment('ALL_PLANS_PREVIEW_FONT');
const _sansPath = String.fromEnvironment('ALL_PLANS_PREVIEW_SANS');

void main() {
  setUpAll(() async {
    if (_previewPath.isEmpty) return;
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    if (_fontPath.isNotEmpty) {
      final loader = FontLoader('Times New Roman')
        ..addFont(File(_fontPath).readAsBytes().then(ByteData.sublistView));
      await loader.load();
    }
    if (_sansPath.isNotEmpty) {
      final loader = FontLoader('Roboto')
        ..addFont(File(_sansPath).readAsBytes().then(ByteData.sublistView));
      await loader.load();
    }
  });

  for (final size in [
    const Size(320, 568),
    const Size(393, 698),
    const Size(393, 852),
    const Size(430, 932),
  ]) {
    for (final textScale in [1.0, 1.6]) {
      testWidgets(
        'All Plans layout ${size.width}x${size.height} text $textScale',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          tester.view.padding = const FakeViewPadding(top: 44, bottom: 20);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPadding);
          var theme = AppTheme.dark;
          if (_sansPath.isNotEmpty) {
            theme = theme.copyWith(
              textTheme: theme.textTheme.apply(fontFamily: 'Roboto'),
            );
          }
          await tester.pumpWidget(
            RepaintBoundary(
              key: const Key('allPlansPreview'),
              child: ProviderScope(
                child: MaterialApp(
                  debugShowCheckedModeBanner: false,
                  theme: theme,
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(textScale)),
                    child: child!,
                  ),
                  home: const AllPlans(),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('allPlansCloseButton')), findsOneWidget);
          expect(find.byKey(const Key('allPlansHeadline')), findsOneWidget);
          expect(find.text('Unlimited AI video generation'), findsOneWidget);
          expect(find.text('Start My Subscription'), findsOneWidget);
          expect(tester.takeException(), isNull);
          if (_previewPath.isNotEmpty && size.width >= 393 && textScale == 1) {
            await _capturePreview(tester, size);
          }

          final yearly = find.byKey(const Key('allPlansYearlyCard'));
          final weekly = find.byKey(const Key('allPlansWeeklyCard'));
          final yearlySize = tester.getSize(yearly);
          final weeklySize = tester.getSize(weekly);
          expect(
            find.descendant(
              of: yearly,
              matching: find.byIcon(Icons.check_rounded),
            ),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: weekly,
              matching: find.byIcon(Icons.check_rounded),
            ),
            findsNothing,
          );
          final yearlyRect = tester.getRect(yearly);
          final badgeRect = tester.getRect(
            find.byKey(const Key('allPlansPopularBadge')),
          );
          expect(yearlyRect.contains(badgeRect.topLeft), isTrue);
          expect(yearlyRect.contains(badgeRect.bottomRight), isTrue);

          await tester.ensureVisible(weekly);
          await tester.pumpAndSettle();
          await tester.tap(find.text('Weekly Pro'));
          await tester.pumpAndSettle();
          expect(tester.getSize(yearly), yearlySize);
          expect(tester.getSize(weekly), weeklySize);
          expect(
            find.descendant(
              of: weekly,
              matching: find.byIcon(Icons.check_rounded),
            ),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: yearly,
              matching: find.byIcon(Icons.check_rounded),
            ),
            findsNothing,
          );
          expect(find.text('3 days free trailer'), findsNothing);
          expect(tester.takeException(), isNull);
          await tester.ensureVisible(
            find.byKey(const Key('allPlansSubscribeButton')),
          );
          await tester.pumpAndSettle();
          expect(
            find.text('Start My Subscription').hitTestable(),
            findsOneWidget,
          );
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}

Future<void> _capturePreview(WidgetTester tester, Size size) async {
  final context = tester.element(find.byType(AllPlans));
  await tester.runAsync(() async {
    for (final asset in [
      'assets/images/in_app_purchase/all_plans_hero_v2.png',
      'assets/images/in_app_purchase/credit.png',
    ]) {
      await precacheImage(AssetImage(asset), context);
    }
  });
  await tester.pumpAndSettle();
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('allPlansPreview')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final destination = _previewPath.replaceFirst(
        '.png',
        '-${size.width.toInt()}x${size.height.toInt()}.png',
      );
      await File(destination).writeAsBytes(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

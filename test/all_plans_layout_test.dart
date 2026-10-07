import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_gen/core/constants/app_colors.dart';
import 'package:video_gen/data/models/user_profile.dart';
import 'package:video_gen/presentation/providers/profile_provider.dart';
import 'package:video_gen/presentation/screens/in_app_purchase/all_plans_screen.dart';
import 'package:video_gen/shared/themes/app_theme.dart';

const _previewPath = String.fromEnvironment('ALL_PLANS_PREVIEW_PATH');
const _sansPath = String.fromEnvironment('ALL_PLANS_PREVIEW_SANS');

void main() {
  setUpAll(() async {
    if (_previewPath.isEmpty) return;
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    await (FontLoader(
      'Nunito',
    )..addFont(rootBundle.load('assets/fonts/Nunito-VF.ttf'))).load();
    await (FontLoader(
      'Nunito Sans',
    )..addFont(rootBundle.load('assets/fonts/NunitoSans-VF.ttf'))).load();
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
              textTheme: theme.textTheme.apply(fontFamily: 'Nunito Sans'),
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
          expect(
            tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
            const Color(0xFF02050C),
          );
          final subscribeSurface = tester.widget<Container>(
            find.byKey(const Key('allPlansSubscribeButton')),
          );
          final subscribeDecoration =
              subscribeSurface.decoration! as BoxDecoration;
          expect(subscribeDecoration.gradient, isNull);
          expect(subscribeDecoration.color, const Color(0xFF8246B8));
          expect(find.byKey(const Key('allPlansCloseButton')), findsOneWidget);
          expect(find.byKey(const Key('allPlansHeadline')), findsOneWidget);
          expect(
            find.byKey(const Key('allPlansProBannerVideo')),
            findsOneWidget,
          );
          expect(find.text('Unlimited AI video generation'), findsNothing);
          final creditsRect = tester.getRect(
            find.byKey(const Key('allPlansBuyCredits')),
          );
          final creditsButton = tester.widget<Container>(
            find.byKey(const Key('allPlansBuyCredits')),
          );
          final creditsDecoration = creditsButton.decoration! as BoxDecoration;
          expect(creditsDecoration.color, isNull);
          expect(
            creditsDecoration.gradient,
            const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color(0xFFC184EE), Color(0xFF9294E9)],
            ),
          );
          expect(creditsDecoration.border!.top.width, 1.2);
          expect(
            tester.widget<Text>(find.text('Buy Credits')).style!.color,
            const Color(0xFF1D102D),
          );
          final headline = find.byKey(const Key('allPlansHeadline'));
          expect(
            tester.widget<Text>(headline).style!.fontWeight,
            FontWeight.w800,
          );
          expect(
            tester.widget<Text>(find.text('PRO?')).style!.fontWeight,
            FontWeight.w800,
          );
          final headlineRect = tester.getRect(headline);
          final heroRect = tester.getRect(
            find.byKey(const Key('allPlansHeroBanner')),
          );
          final heroAreaRect = tester.getRect(
            find.byKey(const Key('allPlansHeroArea')),
          );
          expect(headlineRect.top, greaterThan(heroRect.top));
          expect(headlineRect.top, greaterThan(heroAreaRect.top));
          expect(creditsRect.left, closeTo(headlineRect.left, .1));
          expect(creditsRect.top, greaterThan(headlineRect.bottom));
          expect(creditsRect.bottom, lessThan(heroAreaRect.bottom));
          expect(
            find.ancestor(
              of: headline,
              matching: find.byKey(const Key('allPlansHeaderActions')),
            ),
            findsOneWidget,
          );
          expect(find.text('Start My Subscription'), findsOneWidget);
          expect(tester.takeException(), isNull);
          if (_previewPath.isNotEmpty && size.width >= 393 && textScale == 1) {
            await _capturePreview(tester, size);
          }

          final yearly = find.byKey(const Key('allPlansYearlyCard'));
          final weekly = find.byKey(const Key('allPlansWeeklyCard'));
          final tooltip = find.byKey(const Key('allPlansCreatorTooltip'));
          final tooltipRect = tester.getRect(tooltip);
          expect(tooltipRect.bottom, closeTo(tester.getRect(yearly).top, .1));
          expect(tooltipRect.width, lessThan(tester.getRect(yearly).width));
          expect(
            find.descendant(
              of: tooltip,
              matching: find.text('12,541 creators chose Annually Pro'),
            ),
            findsOneWidget,
          );
          final tooltipSurface = tester.widget<Container>(
            find
                .descendant(of: tooltip, matching: find.byType(Container))
                .first,
          );
          expect(
            (tooltipSurface.decoration! as BoxDecoration).gradient,
            isA<LinearGradient>(),
          );
          expect((tooltipSurface.decoration! as BoxDecoration).border, isNull);
          expect(
            (tooltipSurface.decoration! as BoxDecoration).borderRadius,
            BorderRadius.circular(20),
          );
          expect(
            tester.getSize(find.byKey(const Key('allPlansTooltipPointer'))),
            const Size(14, 12),
          );
          expect(
            find.descendant(
              of: yearly,
              matching: find.text('VND 1,300,000/year'),
            ),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: yearly,
              matching: find.text('only VND 25,000/week'),
            ),
            findsOneWidget,
          );
          expect(
            find.descendant(of: yearly, matching: find.byType(SvgPicture)),
            findsNothing,
          );
          expect(
            find.descendant(of: weekly, matching: find.byType(SvgPicture)),
            findsNothing,
          );
          final yearlySize = tester.getSize(yearly);
          final weeklySize = tester.getSize(weekly);
          final yearlyRect = tester.getRect(yearly);
          final yearlyTitleRect = tester.getRect(
            find.descendant(of: yearly, matching: find.text('Annually')),
          );
          final yearlyWeeklyPriceRect = tester.getRect(
            find.byKey(const Key('allPlansYearlyWeeklyPrice')),
          );
          final yearlyAnnualPriceRect = tester.getRect(
            find.byKey(const Key('allPlansYearlyAnnualPrice')),
          );
          final contentTop = math.min(
            yearlyTitleRect.top,
            yearlyAnnualPriceRect.top,
          );
          final contentBottom = math.max(
            yearlyWeeklyPriceRect.bottom,
            yearlyAnnualPriceRect.bottom,
          );
          expect(
            contentTop - yearlyRect.top,
            closeTo(yearlyRect.bottom - contentBottom, 2),
          );
          expect(
            find.descendant(
              of: yearly,
              matching: find.byKey(const Key('allPlansSelectedDot')),
            ),
            findsOneWidget,
          );
          final selectedDot = tester.widget<DecoratedBox>(
            find.byKey(const Key('allPlansSelectedDot')),
          );
          expect(
            (selectedDot.decoration as BoxDecoration).color,
            AppColors.primary,
          );
          expect(
            find.descendant(
              of: weekly,
              matching: find.byKey(const Key('allPlansSelectedDot')),
            ),
            findsNothing,
          );
          final badgeRect = tester.getRect(
            find.byKey(const Key('allPlansPopularBadge')),
          );
          final badge = tester.widget<Container>(
            find.byKey(const Key('allPlansPopularBadge')),
          );
          expect(
            (badge.decoration! as BoxDecoration).color,
            const Color(0xFFFFC857),
          );
          expect(badgeRect.top, lessThan(yearlyRect.top));
          expect(badgeRect.bottom, greaterThan(yearlyRect.top));
          expect(badgeRect.right, closeTo(yearlyRect.right + 4.5, 0.1));

          await tester.ensureVisible(weekly);
          await tester.pumpAndSettle();
          await tester.tap(find.text('Weekly'));
          await tester.pumpAndSettle();
          expect(tester.getSize(yearly), yearlySize);
          expect(tester.getSize(weekly), weeklySize);
          expect(
            tester.getRect(find.byKey(const Key('allPlansPopularBadge'))).top,
            lessThan(tester.getRect(yearly).top),
          );
          expect(
            find.descendant(
              of: weekly,
              matching: find.byKey(const Key('allPlansSelectedDot')),
            ),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: yearly,
              matching: find.byKey(const Key('allPlansSelectedDot')),
            ),
            findsNothing,
          );
          expect(find.text('3 days free trailer'), findsNothing);
          expect(find.text('Start My Subscription'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }

  testWidgets('weekly plan keeps a compact header without benefits', (
    tester,
  ) async {
    const size = Size(393, 852);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 44, bottom: 20);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(profileProvider.notifier)
        .setProfile(
          UserProfile.fromJson(<String, dynamic>{
            'isSubscribed': true,
            'sub_time': '2026-08-01T00:00:00Z',
            'sub_end_time': '2026-08-08T00:00:00Z',
          }),
        );
    var theme = AppTheme.dark;
    if (_sansPath.isNotEmpty) {
      theme = theme.copyWith(
        textTheme: theme.textTheme.apply(fontFamily: 'Nunito Sans'),
      );
    }
    await tester.pumpWidget(
      RepaintBoundary(
        key: const Key('allPlansPreview'),
        child: UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: theme,
            home: const AllPlans(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Weekly PRO'), findsOneWidget);
    expect(find.text('Active until 08/08/2026'), findsOneWidget);
    expect(find.text('Your PRO benefits'), findsNothing);
    expect(find.byKey(const Key('allPlansBuyCredits')), findsOneWidget);
    final banner = tester.getRect(find.byKey(const Key('allPlansHeroBanner')));
    final summary = tester.getRect(find.byKey(const Key('weeklyProSummary')));
    final title = tester.getRect(find.text('Weekly PRO'));
    final credits = tester.getRect(find.byKey(const Key('allPlansBuyCredits')));
    expect(summary.bottom, closeTo(banner.bottom, 3));
    expect(credits.left, closeTo(title.left, 1));
    expect(credits.top, greaterThan(title.bottom));
    expect(
      find.ancestor(
        of: find.byKey(const Key('weeklyProSummary')),
        matching: find.byKey(const Key('allPlansWeeklyHeroArea')),
      ),
      findsOneWidget,
    );
    final tooltip = find.byKey(const Key('allPlansCreatorTooltip'));
    expect(tooltip, findsOneWidget);
    expect(
      find.descendant(
        of: tooltip,
        matching: find.text("You're among 12,541 creators using PRO!"),
      ),
      findsOneWidget,
    );
    expect(
      tester.getRect(tooltip).bottom,
      closeTo(
        tester.getRect(find.byKey(const Key('yearlyUpgradePlanCard'))).top,
        .1,
      ),
    );
    expect(find.text('Upgrade to Annually Pro'), findsOneWidget);
    expect(tester.takeException(), isNull);
    if (_previewPath.isNotEmpty) {
      await _capturePreview(tester, size, suffix: '-weekly');
    }
  });
}

Future<void> _capturePreview(
  WidgetTester tester,
  Size size, {
  String suffix = '',
}) async {
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
        '$suffix-${size.width.toInt()}x${size.height.toInt()}.png',
      );
      await File(destination).writeAsBytes(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

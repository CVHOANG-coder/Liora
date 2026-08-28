import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_gen/core/firebase/firebase_service.dart';
import 'package:video_gen/data/video_categories.dart';
import 'package:video_gen/presentation/providers/theme_provider.dart';
import 'package:video_gen/presentation/screens/home/home_screen.dart';
import 'package:video_gen/presentation/screens/main/main_screen.dart';
import 'package:video_gen/presentation/widgets/cached_video_thumbnail.dart';

void main() {
  testWidgets('Home only mounts previews near the viewport, not all rows', (
    tester,
  ) async {
    await _pumpHome(tester);

    expect(
      find.byType(CachedVideoThumbnail).evaluate().length,
      lessThanOrEqualTo(9),
    );
    expect(find.byKey(const Key('videoThumbnail_8-0')), findsNothing);
    expect(find.byKey(const Key('videoThumbnail_0-5')), findsNothing);

    final scroll = _verticalScroll(tester);
    scroll.position.jumpTo(1050);
    await tester.pumpAndSettle();
    expect(
      find.byType(CachedVideoThumbnail).evaluate().length,
      lessThanOrEqualTo(15),
    );
    expect(find.byKey(const Key('videoThumbnail_0-0')), findsNothing);
    expect(find.byKey(const Key('videoThumbnail_4-0')), findsOneWidget);

    scroll.position.jumpTo(0);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('videoThumbnail_0-0')), findsOneWidget);
    expect(
      find.byType(CachedVideoThumbnail).evaluate().length,
      lessThanOrEqualTo(9),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('horizontal scrolling releases old previews and saves offset', (
    tester,
  ) async {
    await _pumpHome(tester);
    final row = find.byType(ListView).first;
    final horizontal = tester.state<ScrollableState>(
      find.descendant(of: row, matching: find.byType(Scrollable)),
    );
    horizontal.position.jumpTo(horizontal.position.maxScrollExtent);
    await tester.pumpAndSettle();
    final offset = horizontal.position.pixels;
    expect(find.byKey(const Key('videoThumbnail_0-0')), findsNothing);
    expect(find.byKey(const Key('videoThumbnail_0-9')), findsOneWidget);

    final vertical = _verticalScroll(tester);
    vertical.position.jumpTo(1050);
    await tester.pumpAndSettle();
    vertical.position.jumpTo(0);
    await tester.pumpAndSettle();
    final restored = tester.state<ScrollableState>(
      find.descendant(
        of: find.byType(ListView).first,
        matching: find.byType(Scrollable),
      ),
    );
    expect(restored.position.pixels, offset);
    expect(find.byKey(const Key('videoThumbnail_0-9')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final dpr in [1.0, 3.0]) {
    testWidgets('Home decodes previews at card pixel width for DPR $dpr', (
      tester,
    ) async {
      await _pumpHome(tester, dpr: dpr);
      final finder = find.byType(CachedVideoThumbnail).first;
      final image = tester.widget<CachedVideoThumbnail>(finder);
      final expectedWidth = (tester.getSize(finder).width * dpr).ceil();
      expect(image.maxDecodeWidth, expectedWidth);
      expect(image.filterQuality, FilterQuality.low);
      expect(image.fadeInDuration, Duration.zero);
      expect(image.fadeOutDuration, Duration.zero);
      expect(
        find.ancestor(of: finder, matching: find.byType(RepaintBoundary)),
        findsWidgets,
      );
    });
  }

  testWidgets('Home pauses image animation on another tab and resumes', (
    tester,
  ) async {
    await _pumpHome(tester, mainScreen: true);
    final home = tester.element(find.byType(HomeScreen));
    expect(TickerMode.valuesOf(home).enabled, isTrue);

    await tester.tap(find.byKey(const Key('profileTab')));
    await tester.pumpAndSettle();
    expect(TickerMode.valuesOf(home).enabled, isFalse);

    await tester.tap(find.byKey(const Key('homeTab')));
    await tester.pumpAndSettle();
    expect(TickerMode.valuesOf(home).enabled, isTrue);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpHome(
  WidgetTester tester, {
  double dpr = 1,
  bool mainScreen = false,
}) async {
  tester.view.devicePixelRatio = dpr;
  tester.view.physicalSize = const Size(393, 852) * dpr;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        themeCategoriesProvider.overrideWith(
          (_) async => List.generate(
            9,
            (category) => VideoCategory(
              id: 'category-$category',
              title: 'Category $category',
              posts: List.generate(
                10,
                (post) => VideoPost(
                  id: '$category-$post',
                  description: 'Preview $category-$post',
                  // No live network/plugin calls in layout/lifecycle tests.
                  thumbnailUrl: null,
                  videoUrl: null,
                ),
              ),
            ),
          ),
        ),
      ],
      child: MaterialApp(
        home: mainScreen
            ? MainScreen(
                showTrialOffer: false,
                notificationPermissionRequester: () async =>
                    NotificationPermissionFlowResult.granted,
              )
            : const HomeScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

ScrollableState _verticalScroll(WidgetTester tester) =>
    tester.state<ScrollableState>(
      find
          .descendant(
            of: find.byKey(const PageStorageKey('homeScroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );

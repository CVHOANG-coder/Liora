import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_gen/core/network/api_exception.dart';
import 'package:video_gen/presentation/screens/splash/splash_screen.dart';
import 'package:video_gen/shared/themes/app_theme.dart';

void main() {
  const previewPath = String.fromEnvironment('SPLASH_PREVIEW_PATH');
  const sansPath = String.fromEnvironment('SPLASH_PREVIEW_SANS');
  const serifPath = String.fromEnvironment('SPLASH_PREVIEW_SERIF');

  // The optional preview uses host fonts, without adding a dependency for CI.
  setUpAll(() async {
    if (previewPath.isEmpty) return;
    for (final family in ['Roboto', '.SF Pro Text', '.SF Pro Display']) {
      if (sansPath.isEmpty) continue;
      final loader = FontLoader(family)
        ..addFont(File(sansPath).readAsBytes().then(ByteData.sublistView));
      await loader.load();
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
    testWidgets('Liora splash fits $size and waits for bootstrap', (
      tester,
    ) async {
      _configurePhone(tester, size);
      final previousShadows = debugDisableShadows;
      if (previewPath.isNotEmpty) debugDisableShadows = false;
      try {
        final bootstrap = Completer<void>();
        await tester.pumpWidget(
          ProviderScope(
            child: RepaintBoundary(
              key: const Key('splashPreview'),
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: AppTheme.dark,
                home: SplashScreen(
                  duration: const Duration(seconds: 2),
                  bootstrap: () => bootstrap.future,
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(tester.takeException(), isNull);
        expect(find.text('Liora'), findsOneWidget);
        expect(find.text('Create cinematic AI videos'), findsOneWidget);
        final artwork = tester.widget<Image>(
          find.byKey(const Key('splashArtwork')),
        );
        expect(
          (artwork.image as AssetImage).assetName,
          'assets/images/splash_icon.png',
        );
        final artRect = tester.getRect(find.byKey(const Key('splashArtwork')));
        final titleRect = tester.getRect(find.byKey(const Key('splashTitle')));
        final progressRect = tester.getRect(
          find.byKey(const Key('splashProgress')),
        );
        final loadingRect = tester.getRect(
          find.byKey(const Key('splashLoadingLabel')),
        );
        expect(artRect.bottom, lessThan(titleRect.top));
        expect(titleRect.bottom, lessThan(progressRect.top));
        expect(loadingRect.bottom, lessThan(size.height - 20));
        expect(progressRect.width, closeTo(size.width * 0.68, 0.5));
        expect(
          tester.getSize(find.byKey(const Key('splashProgressFill'))).width,
          closeTo(progressRect.width * 0.7175, 0.1),
        );
        expect(
          tester
              .getRect(find.byKey(const Key('splashProgressHighlight')))
              .center
              .dx,
          closeTo(
            tester.getRect(find.byKey(const Key('splashProgressFill'))).right,
            0.1,
          ),
        );
        final track = tester.widget<Container>(
          find.byKey(const Key('splashProgressTrack')),
        );
        expect(
          (track.decoration! as BoxDecoration).color,
          const Color(0xFF252432),
        );

        if (previewPath.isNotEmpty && size == const Size(393, 698)) {
          await tester.runAsync(() async {
            await precacheImage(
              artwork.image,
              tester.element(find.byType(SplashScreen)),
            );
          });
          await tester.pump();
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const Key('splashPreview')),
          );
          await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 2);
            try {
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await File(previewPath).writeAsBytes(bytes!.buffer.asUint8List());
            } finally {
              image.dispose();
            }
          });
        }

        await tester.pump(const Duration(seconds: 3));
        expect(find.text('Loading...'), findsOneWidget);
        expect(find.text('Get Started'), findsNothing);
        expect(
          tester.getSize(find.byKey(const Key('splashProgressFill'))).width,
          closeTo(progressRect.width * 0.82, 0.1),
        );
        expect(
          tester
              .getRect(find.byKey(const Key('splashProgressHighlight')))
              .center
              .dx,
          closeTo(progressRect.left + progressRect.width * 0.82, 0.1),
        );
        // Dispose while waiting, then release the mocked request. No real request
        // or app navigation is left running after this layout test.
        await tester.pumpWidget(const SizedBox.shrink());
        bootstrap.complete();
        await tester.pump();
        expect(tester.takeException(), isNull);
      } finally {
        debugDisableShadows = previousShadows;
      }
    });
  }

  testWidgets('error actions remain reachable on a small phone', (
    tester,
  ) async {
    _configurePhone(tester, const Size(320, 568));
    var attempts = 0;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.dark,
          home: SplashScreen(
            duration: const Duration(milliseconds: 50),
            bootstrap: () async {
              attempts++;
              throw const ApiException(
                message:
                    'The service is temporarily unavailable. Please try again.',
                errorCode: ApiErrorCode.internalError,
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (var retry = 0; retry < 2; retry++) {
      final button = find.byKey(const Key('splashRetryButton'));
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
    }
    expect(attempts, 3);
    expect(find.text('Contact Support'), findsOneWidget);
    await tester.ensureVisible(find.text('Contact Support'));
    await tester.pumpAndSettle();
    expect(find.text('Contact Support').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

void _configurePhone(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 44, bottom: 34);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPadding);
}

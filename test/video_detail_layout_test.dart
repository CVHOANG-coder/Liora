import 'dart:io';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_gen/data/video_categories.dart';
import 'package:video_gen/presentation/screens/video_detail/video_detail_screen.dart';
import 'package:video_gen/shared/themes/app_theme.dart';

const _thumbnailUrl = 'https://preview.invalid/detail-layout.jpg';

void main() {
  const previewPath = String.fromEnvironment('DETAIL_PREVIEW_PATH');
  const sansPath = String.fromEnvironment('DETAIL_PREVIEW_SANS');
  const serifPath = String.fromEnvironment('DETAIL_PREVIEW_SERIF');

  setUpAll(() async {
    if (previewPath.isEmpty) return;
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
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
    for (final textScale in [1.0, 1.5]) {
      testWidgets('Template detail layout at $size, text $textScale', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPadding);
        await _cacheFixture(tester);
        final previousShadows = debugDisableShadows;
        if (previewPath.isNotEmpty) debugDisableShadows = false;
        try {
          await tester.pumpWidget(
            RepaintBoundary(
              key: const Key('detailPreview'),
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: AppTheme.dark,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(textScale)),
                  child: child!,
                ),
                home: VideoDetailScreen(
                  post: VideoPost(
                    id: 'detail-layout',
                    thumbnailUrl: _thumbnailUrl,
                    videoUrl: null,
                    description: textScale == 1
                        ? 'Mad dance'
                        : 'A very long cinematic template name for the selected video',
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final scale = size.width / 393;
          final header = tester.getRect(
            find.byKey(const Key('videoDetailHeader')),
          );
          final frame = tester.getRect(
            find.byKey(const Key('videoDetailFrame')),
          );
          final media = tester.getRect(
            find.byKey(const Key('videoDetailMedia')),
          );
          final metadata = tester.getRect(
            find.byKey(const Key('videoDetailMetadata')),
          );
          final cta = tester.getRect(find.byKey(const Key('videoDetailCta')));
          expect(frame.left, closeTo(24 * scale, 0.01));
          expect(frame.top - header.bottom, closeTo(12 * scale, 0.01));
          expect(media.left - frame.left, closeTo(8 * scale, 0.01));
          expect(metadata.top, greaterThan(media.top));
          expect(metadata.bottom, lessThan(media.bottom));
          expect(cta.top - frame.bottom, closeTo(11 * scale, 0.01));
          expect(cta.width, closeTo(frame.width, 0.01));
          expect(cta.height, closeTo(56 * scale, 0.01));
          expect(cta.bottom, lessThanOrEqualTo(size.height - 24));
          expect(
            find.byKey(const Key('useVideoTemplateButton')).hitTestable(),
            findsOneWidget,
          );
          expect(
            find.bySemanticsLabel('Turn sound on').hitTestable(),
            findsOneWidget,
          );
          expect(
            tester.getSize(find.byKey(const Key('videoMuteButton'))).width,
            greaterThanOrEqualTo(44),
          );

          if (previewPath.isNotEmpty &&
              size == const Size(393, 698) &&
              textScale == 1) {
            await tester.runAsync(() async {
              final context = tester.element(find.byType(VideoDetailScreen));
              await precacheImage(
                const AssetImage('assets/images/home/lola_logo.png'),
                context,
              );
            });
            await tester.pumpAndSettle();
            final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(const Key('detailPreview')),
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
          }

          await tester.tap(find.byKey(const Key('videoMuteButton')));
          await tester.pump();
          expect(find.bySemanticsLabel('Mute'), findsOneWidget);
          expect(
            tester.getRect(find.byKey(const Key('videoDetailFrame'))),
            frame,
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        } finally {
          debugDisableShadows = previousShadows;
        }
      });
    }
  }
}

// Seed only this test URL with an existing asset. The production screen still
// renders the selected template's thumbnail/video, and tests make no HTTP call.
Future<void> _cacheFixture(WidgetTester tester) async {
  await tester.runAsync(() async {
    const provider = ResizeImage(
      CachedNetworkImageProvider(_thumbnailUrl),
      width: 1080,
    );
    final key = await provider.obtainKey(ImageConfiguration.empty);
    final data = await rootBundle.load(
      'assets/images/templates/moody-light.jpg',
    );
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    codec.dispose();
    PaintingBinding.instance.imageCache.putIfAbsent(
      key,
      () => OneFrameImageStreamCompleter(
        Future.value(ImageInfo(image: frame.image)),
      ),
    );
    addTearDown(() => PaintingBinding.instance.imageCache.evict(key));
  });
}

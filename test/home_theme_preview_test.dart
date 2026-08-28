import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_gen/data/video_categories.dart';
import 'package:video_gen/presentation/providers/theme_provider.dart';
import 'package:video_gen/presentation/screens/home/home_screen.dart';
import 'package:video_gen/presentation/widgets/cached_video_thumbnail.dart';

const _preview = 'https://example.test/preview.webp';
const _thumbnail = 'https://example.test/thumbnail.jpg';

void main() {
  for (final sample in [
    (_preview, _thumbnail, _preview),
    (null, _thumbnail, _thumbnail),
    ('  ', _thumbnail, _thumbnail),
    (_preview, null, _preview),
  ]) {
    testWidgets(
      'Home chooses ${sample.$3} with WebP ${sample.$1} and JPG ${sample.$2}',
      (tester) async {
        final post = VideoPost.fromJson({
          'theme_key': 'preview-test',
          'name': 'Preview test',
          'preview_webp_url': sample.$1,
          'thumbnail_url': sample.$2,
        });
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              themeCategoriesProvider.overrideWith(
                (_) async => [
                  VideoCategory(id: 'test', title: 'Test', posts: [post]),
                ],
              ),
            ],
            child: const MaterialApp(home: HomeScreen()),
          ),
        );
        await tester.pumpAndSettle();
        final tile = find.byKey(const Key('videoThumbnail_preview-test'));
        await tester.ensureVisible(tile);
        await tester.pumpAndSettle();
        final image = tester.widget<CachedVideoThumbnail>(
          find.descendant(
            of: tile,
            matching: find.byType(CachedVideoThumbnail),
          ),
        );
        expect(image.imageUrl, sample.$3);
        expect(image.fallbackImageUrl, sample.$2 ?? '');
        expect(image.cacheKey, 'template:preview-test');
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'WebP load/decode failure tries the thumbnail before the error UI',
    (tester) async {
      final context = await _buildContext(tester);
      const error = SizedBox(key: Key('failedPreview'));
      const placeholder = SizedBox(key: Key('loadingPreview'));
      const widget = CachedVideoThumbnail(
        cacheKey: 'preview',
        imageUrl: _preview,
        fallbackImageUrl: _thumbnail,
        maxDecodeWidth: 320,
        fadeInDuration: Duration.zero,
        fadeOutDuration: Duration.zero,
        placeholder: placeholder,
        errorWidget: error,
      );
      // Exercise the image provider's error callbacks directly, without network
      // timing or native thumbnail plugins in this fallback-order test.
      final primary = widget.build(context) as CachedNetworkImage;
      expect(primary.imageUrl, _preview);
      expect(primary.memCacheWidth, 320);
      expect(primary.fadeInDuration, Duration.zero);
      expect(primary.fadeOutDuration, Duration.zero);
      expect(primary.placeholder!(context, _preview), same(placeholder));
      final fallback =
          primary.errorWidget!(context, _preview, StateError('decode'))
              as CachedNetworkImage;
      expect(fallback.imageUrl, _thumbnail);
      expect(fallback.memCacheWidth, 320);
      expect(fallback.fadeInDuration, Duration.zero);
      expect(fallback.fadeOutDuration, Duration.zero);
      expect(
        fallback.errorWidget!(context, _thumbnail, StateError('404')),
        same(error),
      );
    },
  );

  testWidgets('identical fallback URL is not retried recursively', (
    tester,
  ) async {
    final context = await _buildContext(tester);
    const error = SizedBox(key: Key('failedPreview'));
    const widget = CachedVideoThumbnail(
      cacheKey: 'same',
      imageUrl: _thumbnail,
      fallbackImageUrl: ' $_thumbnail ',
      errorWidget: error,
    );
    final image = widget.build(context) as CachedNetworkImage;
    expect(
      image.errorWidget!(context, _thumbnail, StateError('404')),
      same(error),
    );
  });

  testWidgets('empty primary URL uses the fallback immediately', (
    tester,
  ) async {
    final context = await _buildContext(tester);
    const widget = CachedVideoThumbnail(
      cacheKey: 'empty',
      imageUrl: ' ',
      fallbackImageUrl: ' $_thumbnail ',
    );
    final image = widget.build(context) as CachedNetworkImage;
    expect(image.imageUrl, _thumbnail);
  });
}

Future<BuildContext> _buildContext(WidgetTester tester) async {
  final key = GlobalKey();
  await tester.pumpWidget(SizedBox(key: key));
  return key.currentContext!;
}

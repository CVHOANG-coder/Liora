import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_gen/data/video_categories.dart';
import 'package:video_gen/presentation/providers/theme_provider.dart';
import 'package:video_gen/presentation/screens/home/home_screen.dart';
import 'package:video_gen/presentation/widgets/cached_video_thumbnail.dart';

const _preview = 'https://example.test/preview.webp';
const _thumbnail = 'https://example.test/thumbnail.jpg';

void main() {
  for (final size in [const Size(320, 568), const Size(393, 852)]) {
    for (final textScale in [1.0, 1.6, 2.0]) {
      testWidgets('Home creation labels fit at $size, text $textScale', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              themeCategoriesProvider.overrideWith(
                (_) async => const <VideoCategory>[],
              ),
            ],
            child: MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(textScale)),
                child: child!,
              ),
              home: const HomeScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        for (final (key, title) in [
          ('homeImageToVideoCard', 'Image to Video'),
          ('homeTextToVideoCard', 'Text to Video'),
        ]) {
          final card = find.byKey(Key(key));
          final text = find.descendant(
            of: card,
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Text && widget.data?.replaceAll('\n', ' ') == title,
            ),
          );
          final cardRect = tester.getRect(card);
          final textRect = tester.getRect(text);
          final paragraph = tester.renderObject<RenderParagraph>(text);
          if (textScale == 1.0) {
            expect(cardRect.height, inInclusiveRange(143.9, 160.1));
          }
          expect(
            paragraph.didExceedMaxLines,
            isFalse,
            reason:
                '$title at $size x$textScale: '
                '${tester.widget<Text>(text).data}, card=$cardRect, text=$textRect',
          );
          expect(textRect.left, greaterThan(cardRect.left));
          expect(textRect.right, lessThan(cardRect.right));
          expect(textRect.bottom, lessThan(cardRect.bottom));
          expect(textRect.top, greaterThan(cardRect.top + 65));
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('Home shows the brand and See all opens the category', (
    tester,
  ) async {
    final post = VideoPost.fromJson({
      'theme_key': 'theme-1',
      'name': 'Theme one',
      'thumbnail_url': _thumbnail,
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          themeCategoriesProvider.overrideWith(
            (_) async => [
              VideoCategory(id: 'featured', title: 'Featured', posts: [post]),
            ],
          ),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('homeAvatar')), findsNothing);
    expect(find.byKey(const Key('homeBrand')), findsOneWidget);
    expect(find.byKey(const Key('homeVideoBanner')), findsOneWidget);
    expect(find.byKey(const Key('homeBannerCreateButton')), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                'assets/images/home/home_banner_poster.jpg',
      ),
      findsOneWidget,
    );
    final brandImage = tester.widget<Image>(
      find.descendant(
        of: find.byKey(const Key('homeBrand')),
        matching: find.byType(Image),
      ),
    );
    expect(
      (brandImage.image as AssetImage).assetName,
      'assets/images/home/liora_header_title.png',
    );

    expect(
      tester.getCenter(find.byKey(const Key('homeImageToVideoCard'))).dx,
      lessThan(
        tester.getCenter(find.byKey(const Key('homeTextToVideoCard'))).dx,
      ),
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('videoThumbnail_theme-1')),
      180,
      scrollable: find
          .descendant(
            of: find.byKey(const PageStorageKey('homeScroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    final thumbnail = find.byKey(const Key('videoThumbnail_theme-1'));
    final thumbnailSize = tester.getSize(thumbnail);
    expect(thumbnailSize.width, greaterThan(100));
    expect(thumbnailSize.width / thumbnailSize.height, closeTo(2 / 3, 0.01));
    expect(
      find.descendant(
        of: thumbnail,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is ClipRRect &&
              widget.borderRadius == BorderRadius.circular(20),
        ),
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<CachedVideoThumbnail>(
            find.descendant(
              of: thumbnail,
              matching: find.byType(CachedVideoThumbnail),
            ),
          )
          .fit,
      BoxFit.cover,
    );

    await tester.tap(find.byKey(const Key('seeAllThemes_featured')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('categoryThemesScreen')), findsOneWidget);
    expect(find.text('Featured'), findsOneWidget);
  });

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
        await tester.scrollUntilVisible(
          tile,
          180,
          scrollable: find
              .descendant(
                of: find.byKey(const PageStorageKey('homeScroll')),
                matching: find.byType(Scrollable),
              )
              .first,
        );
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

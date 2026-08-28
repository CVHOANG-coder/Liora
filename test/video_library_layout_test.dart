import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:video_gen/data/models/generation_history.dart';
import 'package:video_gen/data/models/i2v_request_status.dart';
import 'package:video_gen/presentation/screens/generation_history/generation_history_screen.dart';
import 'package:video_gen/presentation/screens/image_to_video/generated_video_screen.dart';
import 'package:video_gen/presentation/widgets/video_form_style.dart';
import 'package:video_gen/presentation/widgets/video_library_widgets.dart';
import 'package:video_gen/shared/themes/app_theme.dart';

const _imageUrl = 'https://preview.invalid/lola-library.jpg';
const _fixture = 'assets/images/templates/moody-light.jpg';
const _previewDirectory = String.fromEnvironment('LIBRARY_PREVIEW_DIR');

void main() {
  setUpAll(() async {
    if (_previewDirectory.isEmpty) return;
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    for (final family in ['Roboto', '.SF Pro Text', '.SF Pro Display']) {
      await (FontLoader(family)..addFont(
            File(
              '/System/Library/Fonts/Supplemental/Arial.ttf',
            ).readAsBytes().then(ByteData.sublistView),
          ))
          .load();
    }
    await (FontLoader('Times New Roman')..addFont(
          File(
            '/System/Library/Fonts/Supplemental/Times New Roman.ttf',
          ).readAsBytes().then(ByteData.sublistView),
        ))
        .load();
  });

  setUp(() {
    final previous = VideoPlayerPlatform.instance;
    VideoPlayerPlatform.instance = _FixtureVideoPlatform();
    addTearDown(() => VideoPlayerPlatform.instance = previous);
  });

  for (final size in [
    const Size(320, 568),
    const Size(393, 852),
    const Size(568, 320),
  ]) {
    for (final textScale in [1.0, 2.0]) {
      testWidgets('History layout and cancel deletion at $size / $textScale', (
        tester,
      ) async {
        _setView(tester, size);
        await _cacheFixture(tester);
        var deletions = 0;
        await tester.pumpWidget(
          _app(
            GenerationHistoryScreen(
              fetcher: ({required page, required limit}) async => _page([
                _request('one'),
                _request('two', status: 'PENDING'),
                _request('three', status: 'FAILED'),
                _request('four', status: 'COMPLETED'),
              ]),
              deleter: (_) async => deletions++,
            ),
            textScale,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(find.text('My videos'), findsOneWidget);
        expect(tester.takeException(), isNull);
        final grid = tester.widget<SliverGrid>(
          find.byType(SliverGrid, skipOffstage: false),
        );
        expect(
          (grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
              .crossAxisCount,
          textScale == 1 ? 2 : 1,
        );
        if (size == const Size(393, 852) && textScale == 1) {
          await _capture(tester, 'history');
        }
        final delete = find.byKey(const Key('deleteHistoryRequest_one'));
        await tester.scrollUntilVisible(
          delete,
          200,
          scrollable: find.descendant(
            of: find.byKey(
              const PageStorageKey<String>('generationHistoryScroll'),
            ),
            matching: find.byType(Scrollable),
          ),
        );
        await tester.pump();
        await tester.tap(delete);
        await tester.pump(const Duration(milliseconds: 300));
        final cancel = find.byKey(const Key('cancelDeleteHistoryRequest'));
        await tester.ensureVisible(cancel);
        await tester.pump();
        await tester.tap(cancel);
        await tester.pump(const Duration(milliseconds: 300));
        expect(deletions, 0);
        expect(find.byKey(const Key('deleteHistoryVideoDialog')), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets('Player layout and actions at $size / $textScale', (
        tester,
      ) async {
        _setView(tester, size);
        final controller = _FixtureVideoController();
        var shares = 0;
        await tester.pumpWidget(
          _app(
            GeneratedVideoScreen(
              result: _request('one'),
              controllerFactory: (_) async => controller,
              sharer: (_, _) async => shares++,
            ),
            textScale,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(controller.value.isPlaying, isTrue);
        expect(tester.takeException(), isNull);
        final frame = tester.getRect(
          find.byKey(const Key('generatedVideoFrame')),
        );
        expect(frame.left, 16);
        expect(frame.right, size.width - 16);
        expect(
          tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
          VideoFormStyle.background,
        );
        if (size == const Size(393, 852) && textScale == 1) {
          await _capture(tester, 'video');
        }
        final share = find.byKey(const Key('shareGeneratedVideo'));
        await tester.ensureVisible(share);
        await tester.pump();
        await tester.tap(share);
        await tester.pump();
        expect(shares, 1);
        final remove = find.byKey(const Key('deleteGeneratedVideo'));
        await tester.ensureVisible(remove);
        await tester.pump();
        await tester.tap(remove);
        await tester.pump(const Duration(milliseconds: 300));
        final cancel = find.byKey(const Key('cancelDeleteGeneratedVideo'));
        await tester.ensureVisible(cancel);
        await tester.pump();
        await tester.tap(cancel);
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(GeneratedVideoScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets('History empty and error states at $size / $textScale', (
        tester,
      ) async {
        _setView(tester, size);
        var calls = 0;
        await tester.pumpWidget(
          _app(
            GenerationHistoryScreen(
              fetcher: ({required page, required limit}) async {
                if (calls++ == 0) throw Exception('Connection unavailable');
                return _page([]);
              },
            ),
            textScale,
          ),
        );
        await tester.pump();
        expect(find.text('Could not load video history'), findsOneWidget);
        final retry = find.text('Try again');
        await tester.ensureVisible(retry);
        await tester.pump();
        await tester.tap(retry);
        await tester.pump();
        expect(calls, 2);
        expect(find.text('No videos yet'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }

  testWidgets('Play, pause, mute and seek remain interactive', (tester) async {
    _setView(tester, const Size(393, 852));
    final controller = _FixtureVideoController();
    await tester.pumpWidget(
      _app(
        GeneratedVideoScreen(
          result: _request('one'),
          controllerFactory: (_) async => controller,
        ),
      ),
    );
    await tester.pump();
    expect(controller.value.isPlaying, isTrue);
    await tester.tap(find.byKey(const Key('generatedVideoPlayPause')));
    await tester.pump();
    expect(controller.value.isPlaying, isFalse);
    await tester.tap(find.byKey(const Key('generatedVideoCenterPlay')));
    await tester.pump();
    expect(controller.value.isPlaying, isTrue);
    await tester.tap(find.byKey(const Key('generatedVideoMute')));
    await tester.pump();
    expect(controller.value.volume, 0);
    expect(find.byTooltip('Turn sound on'), findsOneWidget);
    await tester.tap(find.byKey(const Key('generatedVideoMute')));
    await tester.pump();
    expect(controller.value.volume, 1);
    await tester.tap(find.byType(VideoProgressIndicator));
    await tester.pump();
    expect(controller.value.position.inSeconds, closeTo(5, 1));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Failed preview retries; saving disables conflicting actions', (
    tester,
  ) async {
    _setView(tester, const Size(393, 852));
    var attempts = 0;
    var shares = 0;
    final saved = Completer<void>();
    final controller = _FixtureVideoController();
    await tester.pumpWidget(
      _app(
        GeneratedVideoScreen(
          result: _request('one'),
          controllerFactory: (_) async {
            if (attempts++ == 0) throw StateError('Test playback failure');
            return controller;
          },
          downloader: (_, _, progress) async {
            progress(50, 100);
            await saved.future;
          },
          sharer: (_, _) async => shares++,
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('generatedVideoPreviewError')), findsOneWidget);
    await tester.tap(find.byKey(const Key('retryGeneratedVideo')));
    await tester.pump();
    expect(attempts, 2);
    expect(controller.value.isPlaying, isTrue);
    expect(find.byKey(const Key('generatedVideoPreviewError')), findsNothing);
    final save = find.byKey(const Key('downloadGeneratedVideo'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pump();
    expect(find.text('Saving 50%'), findsOneWidget);
    for (final key in [
      'downloadGeneratedVideo',
      'shareGeneratedVideo',
      'deleteGeneratedVideo',
    ]) {
      expect(
        tester.widget<VideoLibraryAction>(find.byKey(Key(key))).onTap,
        isNull,
      );
    }
    await tester.tap(find.byKey(const Key('shareGeneratedVideo')));
    expect(shares, 0);
    saved.complete();
    await tester.pump();
    expect(find.text('Video saved to your photo library.'), findsOneWidget);
    expect(tester.widget<VideoLibraryAction>(save).onTap, isNotNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

void _setView(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPadding);
}

Widget _app(Widget home, [double scale = 1]) => RepaintBoundary(
  key: const Key('libraryPreview'),
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.dark,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: home,
  ),
);

I2VRequestStatus _request(String id, {String status = 'COMPLETED'}) =>
    I2VRequestStatus.fromJson({
      'request_id': id,
      'request_status': status,
      'service_type': 'I2V_GENERATOR',
      'prompt': 'A quiet moment in cinematic light',
      'duration': 10,
      'is_hd': true,
      'thumbnail_url': _imageUrl,
      'result_data': 'https://example.test/$id.mp4',
      'create_time': '2026-08-28T08:20:00Z',
    });

GenerationHistoryPage _page(List<I2VRequestStatus> requests) =>
    GenerationHistoryPage(
      requests: requests,
      pagination: GenerationHistoryPagination(
        page: 1,
        limit: 10,
        total: requests.length,
        totalPages: 1,
      ),
    );

// Test-only frames; the production player continues to render the actual video.
class _FixtureVideoPlatform extends VideoPlayerPlatform {
  @override
  Future<void> init() async {}

  @override
  Widget buildViewWithOptions(VideoViewOptions options) =>
      Image.asset(_fixture, fit: BoxFit.cover);
}

class _FixtureVideoController extends VideoPlayerController {
  _FixtureVideoController()
    : super.networkUrl(Uri.parse('https://example.test/fixture.mp4'));

  @override
  int get playerId => 1;

  @override
  Future<void> initialize() async {
    value = const VideoPlayerValue(
      duration: Duration(seconds: 10),
      size: Size(9, 16),
      isInitialized: true,
    );
  }

  @override
  Future<void> play() async => value = value.copyWith(isPlaying: true);
  @override
  Future<void> pause() async => value = value.copyWith(isPlaying: false);
  @override
  Future<void> setVolume(double volume) async =>
      value = value.copyWith(volume: volume);
  @override
  Future<void> setLooping(bool looping) async =>
      value = value.copyWith(isLooping: looping);
  @override
  Future<void> seekTo(Duration position) async =>
      value = value.copyWith(position: position);
}

Future<void> _cacheFixture(WidgetTester tester) async {
  await tester.runAsync(() async {
    final key = await const ResizeImage(
      CachedNetworkImageProvider(_imageUrl),
      width: 512,
    ).obtainKey(ImageConfiguration.empty);
    final data = await rootBundle.load(_fixture);
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

Future<void> _capture(WidgetTester tester, String name) async {
  if (_previewDirectory.isEmpty) return;
  await tester.runAsync(
    () => precacheImage(
      const AssetImage(_fixture),
      tester.element(find.byType(Scaffold)),
    ),
  );
  await tester.pump(const Duration(seconds: 1));
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('libraryPreview')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        '$_previewDirectory/$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_gen/data/video_categories.dart';
import 'package:video_gen/presentation/providers/theme_provider.dart';
import 'package:video_gen/presentation/screens/home/home_screen.dart';
import 'package:video_gen/presentation/screens/image_to_video/image_to_video_screen.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

void main() {
  test(
    'optimized Home videos are present in the Flutter asset bundle',
    () async {
      for (final asset in [
        'assets/videos/home_banner/slide_1.mp4',
        'assets/videos/home_banner/slide_2.mp4',
        'assets/videos/home_banner/slide_3.mp4',
      ]) {
        final data = await rootBundle.load(asset);
        expect(data.lengthInBytes, greaterThan(100000));
      }
    },
  );

  late _BannerVideoPlatform platform;
  late VideoPlayerPlatform previous;

  setUp(() {
    previous = VideoPlayerPlatform.instance;
    platform = _BannerVideoPlatform();
    VideoPlayerPlatform.instance = platform;
  });
  tearDown(() => VideoPlayerPlatform.instance = previous);

  testWidgets('Home banner autoplays each asset, loops, and keeps one player', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          themeCategoriesProvider.overrideWith(
            (_) async => const <VideoCategory>[],
          ),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PageView), findsNothing);
    expect(platform.assets, ['assets/videos/home_banner/slide_1.mp4']);
    expect(platform.played, contains(1));
    expect(platform.looping, everyElement(isFalse));
    expect(platform.maxActive, 1);

    for (final expected in [
      'assets/videos/home_banner/slide_2.mp4',
      'assets/videos/home_banner/slide_3.mp4',
      'assets/videos/home_banner/slide_1.mp4',
    ]) {
      platform.complete(platform.latestId);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      expect(platform.assets.last, expected);
      expect(platform.played, contains(platform.latestId));
      expect(platform.activeCount, 1);
      expect(platform.maxActive, 1);
    }
  });

  testWidgets('Home banner pauses when it scrolls offscreen', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          themeCategoriesProvider.overrideWith(
            (_) async => List.generate(
              6,
              (index) => VideoCategory(
                id: 'category-$index',
                title: 'Category $index',
                posts: const [],
              ),
            ),
          ),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(platform.played, contains(1));

    await tester.drag(
      find.byKey(const PageStorageKey('homeScroll')),
      const Offset(0, -420),
    );
    await tester.pumpAndSettle();
    expect(platform.paused, contains(1));
    expect(platform.activeCount, 1);
  });

  testWidgets('Home banner pauses off tab and resumes when Home returns', (
    tester,
  ) async {
    final homeActive = ValueNotifier<bool>(true);
    addTearDown(homeActive.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          themeCategoriesProvider.overrideWith(
            (_) async => const <VideoCategory>[],
          ),
        ],
        child: MaterialApp(
          home: ValueListenableBuilder<bool>(
            valueListenable: homeActive,
            builder: (context, active, _) =>
                TickerMode(enabled: active, child: const HomeScreen()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(platform.played, contains(1));

    homeActive.value = false;
    await tester.pumpAndSettle();
    expect(platform.paused, contains(1));
    final playsBeforeReturn = platform.played.length;

    homeActive.value = true;
    await tester.pumpAndSettle();
    expect(platform.played.length, greaterThan(playsBeforeReturn));
    expect(platform.activeCount, 1);
  });

  testWidgets('banner retries after a video initialization failure', (
    tester,
  ) async {
    platform.failNextInitialization = true;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          themeCategoriesProvider.overrideWith(
            (_) async => const <VideoCategory>[],
          ),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    expect(platform.activeCount, 0);

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(platform.assets.length, 2);
    expect(platform.played, contains(platform.latestId));
  });

  testWidgets('white banner action opens Image to Video', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
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
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final action = find.byKey(const Key('homeBannerCreateButton'));
    expect(tester.widget<Material>(action).color, Colors.white);
    expect(tester.getSize(action).width, lessThan(220));
    expect(tester.getSize(action).height, lessThan(36));
    expect(find.text('Create Video Now'), findsOneWidget);
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(find.byType(ImageToVideoScreen), findsOneWidget);
  });
}

class _BannerVideoPlatform extends VideoPlayerPlatform {
  final assets = <String>[];
  final played = <int>[];
  final paused = <int>[];
  final looping = <bool>[];
  final _events = <int, StreamController<VideoEvent>>{};
  var _nextId = 0;
  var maxActive = 0;
  var failNextInitialization = false;

  int get latestId => _nextId;
  int get activeCount => _events.length;

  @override
  Future<void> init() async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    final id = ++_nextId;
    assets.add(options.dataSource.asset!);
    _events[id] = StreamController<VideoEvent>.broadcast(sync: true);
    if (activeCount > maxActive) maxActive = activeCount;
    return id;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) {
    final events = _events[playerId]!;
    scheduleMicrotask(() {
      if (failNextInitialization) {
        failNextInitialization = false;
        events.addError(
          PlatformException(code: 'decode', message: 'Unavailable'),
        );
        return;
      }
      events.add(
        VideoEvent(
          eventType: VideoEventType.initialized,
          duration: const Duration(seconds: 10),
          size: const Size(1280, 720),
        ),
      );
    });
    return events.stream;
  }

  void complete(int id) =>
      _events[id]!.add(VideoEvent(eventType: VideoEventType.completed));

  @override
  Future<void> dispose(int playerId) async {
    _events.remove(playerId);
  }

  @override
  Future<void> setLooping(int playerId, bool value) async => looping.add(value);

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> play(int playerId) async => played.add(playerId);

  @override
  Future<void> pause(int playerId) async => paused.add(playerId);

  @override
  Future<void> seekTo(int playerId, Duration position) async {}

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;

  @override
  Widget buildViewWithOptions(VideoViewOptions options) =>
      const ColoredBox(color: Colors.transparent);
}

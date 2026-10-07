import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_gen/presentation/widgets/pro_banner_video.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

void main() {
  test('Pro banner is bundled as a video asset', () async {
    final data = await rootBundle.load(ProBannerVideo.asset);
    expect(data.lengthInBytes, greaterThan(100000));
  });

  late _TestVideoPlatform platform;
  late VideoPlayerPlatform previous;

  setUp(() {
    previous = VideoPlayerPlatform.instance;
    platform = _TestVideoPlatform();
    VideoPlayerPlatform.instance = platform;
  });

  tearDown(() => VideoPlayerPlatform.instance = previous);

  testWidgets('Pro banner autoplays, loops and releases its player', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ProBannerVideo())),
    );
    await tester.pumpAndSettle();

    expect(platform.asset, ProBannerVideo.asset);
    expect(platform.looping, isTrue);
    expect(platform.volume, 0);
    expect(platform.played, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    expect(platform.disposed, isTrue);
  });
}

class _TestVideoPlatform extends VideoPlayerPlatform {
  final _events = StreamController<VideoEvent>.broadcast(sync: true);
  String? asset;
  bool? looping;
  double? volume;
  bool played = false;
  bool disposed = false;

  @override
  Future<void> init() async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    asset = options.dataSource.asset;
    return 1;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) {
    scheduleMicrotask(
      () => _events.add(
        VideoEvent(
          eventType: VideoEventType.initialized,
          duration: const Duration(seconds: 8),
          size: const Size(1108, 832),
        ),
      ),
    );
    return _events.stream;
  }

  @override
  Future<void> setLooping(int playerId, bool value) async => looping = value;

  @override
  Future<void> setVolume(int playerId, double value) async => volume = value;

  @override
  Future<void> play(int playerId) async => played = true;

  @override
  Future<void> pause(int playerId) async => played = false;

  @override
  Future<void> dispose(int playerId) async {
    disposed = true;
    await _events.close();
  }

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

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:video_gen/core/media/video_thumbnail_cache.dart';

void main() {
  test('generates a thumbnail once and reuses the cached file', () async {
    final temporary = await Directory.systemTemp.createTemp(
      'video_thumbnail_cache_test_',
    );
    addTearDown(() async {
      if (await temporary.exists()) await temporary.delete(recursive: true);
    });
    var generationCalls = 0;
    final cache = VideoThumbnailCache(
      temporaryDirectory: () async => temporary,
      generator:
          ({
            required video,
            required thumbnailPath,
            required maxWidth,
            required timeMs,
            required quality,
          }) async {
            generationCalls += 1;
            expect(video, 'https://example.test/video.mp4');
            expect(maxWidth, 320);
            expect(timeMs, 300);
            expect(quality, 78);
            await File(thumbnailPath).writeAsBytes(<int>[1, 2, 3]);
            return thumbnailPath;
          },
    );

    final first = await cache.getOrCreate(
      videoUrl: 'https://example.test/video.mp4',
      cacheKey: 'request-1',
      maxWidth: 320,
    );
    final second = await cache.getOrCreate(
      videoUrl: 'https://example.test/video.mp4?new-signature=true',
      cacheKey: 'request-1',
      maxWidth: 320,
    );

    expect(first, isNotNull);
    expect(second?.path, first?.path);
    expect(generationCalls, 1);
  });

  test('deduplicates simultaneous generation for the same video', () async {
    final temporary = await Directory.systemTemp.createTemp(
      'video_thumbnail_dedup_test_',
    );
    addTearDown(() async {
      if (await temporary.exists()) await temporary.delete(recursive: true);
    });
    var generationCalls = 0;
    final cache = VideoThumbnailCache(
      temporaryDirectory: () async => temporary,
      generator:
          ({
            required video,
            required thumbnailPath,
            required maxWidth,
            required timeMs,
            required quality,
          }) async {
            generationCalls += 1;
            await Future<void>.delayed(const Duration(milliseconds: 10));
            await File(thumbnailPath).writeAsBytes(<int>[1]);
            return thumbnailPath;
          },
    );

    final results = await Future.wait([
      cache.getOrCreate(
        videoUrl: 'https://example.test/video.mp4',
        cacheKey: 'same',
      ),
      cache.getOrCreate(
        videoUrl: 'https://example.test/video.mp4',
        cacheKey: 'same',
      ),
    ]);

    expect(results.whereType<File>(), hasLength(2));
    expect(generationCalls, 1);
  });
}

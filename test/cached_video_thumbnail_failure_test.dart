import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_gen/presentation/widgets/cached_video_thumbnail.dart';

void main() {
  testWidgets('interrupted WebP and fallback downloads show the error UI', (
    tester,
  ) async {
    final originalCacheManager = CachedNetworkImageProvider.defaultCacheManager;
    final cacheManager = _InterruptedDownloadCache();
    CachedNetworkImageProvider.defaultCacheManager = cacheManager;
    addTearDown(() {
      CachedNetworkImageProvider.defaultCacheManager = originalCacheManager;
      PaintingBinding.instance.imageCache.clear();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: CachedVideoThumbnail(
          cacheKey: 'interrupted-preview',
          imageUrl: 'https://example.test/interrupted.webp',
          fallbackImageUrl: 'https://example.test/fallback.jpg',
          fadeInDuration: Duration.zero,
          fadeOutDuration: Duration.zero,
          errorWidget: SizedBox(key: Key('thumbnailUnavailable')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(cacheManager.requests, [
      'https://example.test/interrupted.webp',
      'https://example.test/fallback.jpg',
    ]);
    expect(find.byKey(const Key('thumbnailUnavailable')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _InterruptedDownloadCache implements BaseCacheManager {
  final requests = <String>[];

  @override
  Stream<FileResponse> getFileStream(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool withProgress = false,
  }) {
    requests.add(url);
    return Stream<FileResponse>.error(
      HttpException(
        'Connection closed while receiving data',
        uri: Uri.parse(url),
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

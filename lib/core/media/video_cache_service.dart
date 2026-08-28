import 'dart:async';
import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:video_player/video_player.dart';

/// Keeps a small, short-lived disk cache for replayable app videos.
///
/// A cached file is preferred immediately. On the first view the network URL
/// is played without waiting for the whole download, while one deduplicated
/// background download prepares subsequent views and offline replay.
class VideoCacheService {
  VideoCacheService._({CacheManager? cacheManager})
    : _cacheManager =
          cacheManager ??
          CacheManager(
            Config(
              _cacheName,
              stalePeriod: const Duration(days: 7),
              maxNrOfCacheObjects: 15,
            ),
          );

  static const _cacheName = 'nostaliaVideoCacheV1';
  static final VideoCacheService instance = VideoCacheService._();

  final CacheManager _cacheManager;
  final Map<String, Future<void>> _downloads = <String, Future<void>>{};
  int _cacheGeneration = 0;

  Future<VideoPlayerController> createController(
    Uri videoUri, {
    required String cacheKey,
  }) async {
    final key = _normalizedKey(videoUri, cacheKey);
    try {
      final cached = await _cacheManager.getFileFromCache(key);
      final file = cached?.file;
      if (file != null && await file.exists()) {
        return VideoPlayerController.file(file);
      }
    } catch (_) {
      // Cache access must never prevent normal network playback.
    }

    unawaited(_cacheInBackground(videoUri, key));
    return VideoPlayerController.networkUrl(videoUri);
  }

  Future<File?> cachedFile(Uri videoUri, {required String cacheKey}) async {
    try {
      final cached = await _cacheManager.getFileFromCache(
        _normalizedKey(videoUri, cacheKey),
      );
      if (cached != null && await cached.file.exists()) return cached.file;
    } catch (_) {
      // Callers can fall back to the network source.
    }
    return null;
  }

  Future<void> clear() async {
    _cacheGeneration += 1;
    _downloads.clear();
    await _cacheManager.emptyCache();
  }

  Future<void> _cacheInBackground(Uri videoUri, String key) {
    final active = _downloads[key];
    if (active != null) return active;

    final download = _download(videoUri, key, _cacheGeneration);
    _downloads[key] = download;
    download.whenComplete(() {
      if (identical(_downloads[key], download)) _downloads.remove(key);
    });
    return download;
  }

  Future<void> _download(Uri videoUri, String key, int generation) async {
    try {
      await _cacheManager.downloadFile(videoUri.toString(), key: key);
      if (generation != _cacheGeneration) {
        await _cacheManager.removeFile(key);
      }
    } catch (_) {
      // Playback continues from the network when a background cache fails.
    }
  }

  String _normalizedKey(Uri videoUri, String cacheKey) {
    final value = cacheKey.trim();
    return value.isEmpty ? videoUri.toString() : 'video:$value';
  }
}

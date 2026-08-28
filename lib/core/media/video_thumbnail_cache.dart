import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_video_thumbnail_plus/flutter_video_thumbnail_plus.dart';
import 'package:path_provider/path_provider.dart';

typedef VideoThumbnailGenerator =
    Future<String?> Function({
      required String video,
      required String thumbnailPath,
      required int maxWidth,
      required int timeMs,
      required int quality,
    });

/// Generates one still frame per video and reuses it from the temporary disk
/// cache. Generation is throttled so a scrolling grid cannot start a large
/// number of native decoders at once.
class VideoThumbnailCache {
  VideoThumbnailCache({
    Future<Directory> Function()? temporaryDirectory,
    VideoThumbnailGenerator? generator,
    int maxConcurrentGenerations = 2,
  }) : _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory,
       _generator = generator ?? _generateThumbnail,
       _limiter = _AsyncLimiter(maxConcurrentGenerations);

  static final VideoThumbnailCache instance = VideoThumbnailCache();

  final Future<Directory> Function() _temporaryDirectory;
  final VideoThumbnailGenerator _generator;
  final _AsyncLimiter _limiter;
  final Map<String, Future<File?>> _inFlight = <String, Future<File?>>{};
  Future<Directory>? _cacheDirectory;

  Future<File?> getOrCreate({
    required String videoUrl,
    required String cacheKey,
    int maxWidth = 512,
  }) {
    final url = videoUrl.trim();
    if (url.isEmpty) return Future<File?>.value();
    final fileKey = sha256
        .convert(utf8.encode(cacheKey.trim().isEmpty ? url : cacheKey.trim()))
        .toString();

    return _inFlight.putIfAbsent(fileKey, () async {
      try {
        return await _limiter.run(
          () => _create(url: url, fileKey: fileKey, maxWidth: maxWidth),
        );
      } finally {
        _inFlight.remove(fileKey);
      }
    });
  }

  Future<void> clear() async {
    _inFlight.clear();
    try {
      final directory = await _directory();
      if (await directory.exists()) await directory.delete(recursive: true);
    } catch (_) {
      // The OS may have already removed temporary files.
    } finally {
      _cacheDirectory = null;
    }
  }

  Future<File?> _create({
    required String url,
    required String fileKey,
    required int maxWidth,
  }) async {
    try {
      final directory = await _directory();
      final target = File('${directory.path}/$fileKey.jpg');
      if (await target.exists() && await target.length() > 0) return target;

      final generatedPath = await _generator(
        video: url,
        thumbnailPath: target.path,
        maxWidth: maxWidth,
        timeMs: 300,
        quality: 78,
      );
      if (generatedPath == null || generatedPath.isEmpty) return null;
      final generated = File(generatedPath);
      return await generated.exists() ? generated : null;
    } catch (_) {
      return null;
    }
  }

  Future<Directory> _directory() {
    return _cacheDirectory ??= () async {
      final temporary = await _temporaryDirectory();
      final directory = Directory('${temporary.path}/video_thumbnails_v1');
      await directory.create(recursive: true);
      return directory;
    }();
  }

  static Future<String?> _generateThumbnail({
    required String video,
    required String thumbnailPath,
    required int maxWidth,
    required int timeMs,
    required int quality,
  }) {
    return FlutterVideoThumbnailPlus.thumbnailFile(
      video: video,
      thumbnailPath: thumbnailPath,
      imageFormat: ImageFormat.jpeg,
      maxWidth: maxWidth,
      timeMs: timeMs,
      quality: quality,
    );
  }
}

class _AsyncLimiter {
  _AsyncLimiter(this.limit) : assert(limit > 0);

  final int limit;
  final Queue<Completer<void>> _waiters = Queue<Completer<void>>();
  int _active = 0;

  Future<T> run<T>(Future<T> Function() action) async {
    await _acquire();
    try {
      return await action();
    } finally {
      _release();
    }
  }

  Future<void> _acquire() {
    if (_active < limit) {
      _active += 1;
      return Future<void>.value();
    }
    final waiter = Completer<void>();
    _waiters.add(waiter);
    return waiter.future;
  }

  void _release() {
    if (_waiters.isNotEmpty) {
      _waiters.removeFirst().complete();
    } else {
      _active -= 1;
    }
  }
}

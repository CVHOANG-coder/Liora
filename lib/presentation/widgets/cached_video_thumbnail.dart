import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/media/video_cache_service.dart';
import '../../core/media/video_thumbnail_cache.dart';

/// Displays a disk-cached image (including animated WebP), tries a fallback
/// image on failure, then generates a still frame if a video URL is available.
class CachedVideoThumbnail extends StatelessWidget {
  const CachedVideoThumbnail({
    super.key,
    required this.cacheKey,
    this.imageUrl = '',
    this.fallbackImageUrl = '',
    this.videoUrl = '',
    this.fit = BoxFit.cover,
    this.filterQuality = FilterQuality.medium,
    this.placeholder,
    this.errorWidget,
    this.thumbnailCache,
    this.maxDecodeWidth = 512,
    this.fadeInDuration = const Duration(milliseconds: 500),
    this.fadeOutDuration = const Duration(milliseconds: 1000),
  });

  final String cacheKey;
  final String imageUrl;
  final String fallbackImageUrl;
  final String videoUrl;
  final BoxFit fit;
  final FilterQuality filterQuality;
  final Widget? placeholder;
  final Widget? errorWidget;
  final VideoThumbnailCache? thumbnailCache;
  final int maxDecodeWidth;
  final Duration fadeInDuration;
  final Duration fadeOutDuration;

  @override
  Widget build(BuildContext context) {
    final networkThumbnail = imageUrl.trim();
    final fallback = fallbackImageUrl.trim();
    if (networkThumbnail.isNotEmpty) {
      return _networkImage(
        networkThumbnail,
        fallback: fallback.isNotEmpty && fallback != networkThumbnail
            ? fallback
            : null,
      );
    }

    if (fallback.isNotEmpty) return _networkImage(fallback);
    return _videoFallback;
  }

  Widget _networkImage(String url, {String? fallback}) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      filterQuality: filterQuality,
      memCacheWidth: maxDecodeWidth,
      fadeInDuration: fadeInDuration,
      fadeOutDuration: fadeOutDuration,
      placeholder: (_, _) => _placeholder,
      errorWidget: (_, _, _) =>
          fallback == null ? _videoFallback : _networkImage(fallback),
    );
  }

  Widget get _videoFallback {
    if (videoUrl.trim().isEmpty) return _error;
    return _GeneratedVideoThumbnail(
      cacheKey: cacheKey,
      videoUrl: videoUrl,
      fit: fit,
      filterQuality: filterQuality,
      placeholder: _placeholder,
      errorWidget: _error,
      thumbnailCache: thumbnailCache,
      maxDecodeWidth: maxDecodeWidth,
    );
  }

  Widget get _placeholder =>
      placeholder ?? const ColoredBox(color: Color(0xFF171016));

  Widget get _error =>
      errorWidget ??
      const ColoredBox(
        color: Color(0xFF171016),
        child: Center(
          child: Icon(
            Icons.movie_creation_outlined,
            color: Color(0xFF837680),
            size: 38,
          ),
        ),
      );
}

class _GeneratedVideoThumbnail extends StatefulWidget {
  const _GeneratedVideoThumbnail({
    required this.cacheKey,
    required this.videoUrl,
    required this.fit,
    required this.filterQuality,
    required this.placeholder,
    required this.errorWidget,
    required this.thumbnailCache,
    required this.maxDecodeWidth,
  });

  final String cacheKey;
  final String videoUrl;
  final BoxFit fit;
  final FilterQuality filterQuality;
  final Widget placeholder;
  final Widget errorWidget;
  final VideoThumbnailCache? thumbnailCache;
  final int maxDecodeWidth;

  @override
  State<_GeneratedVideoThumbnail> createState() =>
      _GeneratedVideoThumbnailState();
}

class _GeneratedVideoThumbnailState extends State<_GeneratedVideoThumbnail> {
  late Future<File?> _thumbnail;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _GeneratedVideoThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cacheKey != widget.cacheKey ||
        oldWidget.videoUrl != widget.videoUrl ||
        oldWidget.maxDecodeWidth != widget.maxDecodeWidth) {
      _load();
    }
  }

  void _load() {
    _thumbnail = _resolveThumbnail();
  }

  Future<File?> _resolveThumbnail() async {
    var source = widget.videoUrl;
    final uri = Uri.tryParse(source);
    if (uri != null && uri.hasScheme) {
      final cachedVideo = await VideoCacheService.instance.cachedFile(
        uri,
        cacheKey: widget.cacheKey,
      );
      if (cachedVideo != null) source = cachedVideo.path;
    }
    return (widget.thumbnailCache ?? VideoThumbnailCache.instance).getOrCreate(
      videoUrl: source,
      cacheKey: widget.cacheKey,
      maxWidth: widget.maxDecodeWidth,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<File?>(
      future: _thumbnail,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return widget.placeholder;
        }
        final file = snapshot.data;
        if (file == null) return widget.errorWidget;
        return Image.file(
          file,
          fit: widget.fit,
          filterQuality: widget.filterQuality,
          cacheWidth: widget.maxDecodeWidth,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => widget.errorWidget,
        );
      },
    );
  }
}

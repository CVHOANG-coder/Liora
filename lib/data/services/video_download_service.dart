import 'dart:io';

import 'package:dio/dio.dart';
import 'package:gal/gal.dart';

class VideoDownloadService {
  VideoDownloadService({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  Future<void> saveToGallery({
    required String videoUrl,
    required String requestId,
    void Function(int received, int total)? onProgress,
  }) async {
    var hasAccess = await Gal.hasAccess();
    if (!hasAccess) hasAccess = await Gal.requestAccess();
    if (!hasAccess) {
      throw const FileSystemException(
        'Photo library permission was not granted.',
      );
    }

    final safeId = requestId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final output = File(
      '${Directory.systemTemp.path}/lola_${safeId}_${DateTime.now().millisecondsSinceEpoch}.mp4',
    );

    try {
      await _dio.download(videoUrl, output.path, onReceiveProgress: onProgress);
      await Gal.putVideo(output.path);
    } finally {
      if (await output.exists()) await output.delete();
    }
  }
}

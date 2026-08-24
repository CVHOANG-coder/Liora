import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/firebase/firebase_service.dart';
import '../../../core/network/api_client.dart';
import '../../../data/models/i2v_generation.dart';
import '../../../data/models/i2v_request_status.dart';
import '../image_to_video/creating_video_screen.dart';
import '../image_to_video/generated_video_screen.dart';

class VideoNotificationRequestScreen extends StatefulWidget {
  const VideoNotificationRequestScreen({
    super.key,
    required this.notification,
    this.statusFetcher,
  });

  final VideoNotificationOpen notification;
  final I2VStatusFetcher? statusFetcher;

  @override
  State<VideoNotificationRequestScreen> createState() =>
      _VideoNotificationRequestScreenState();
}

class _VideoNotificationRequestScreenState
    extends State<VideoNotificationRequestScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_resolveRequest());
    });
  }

  Future<void> _resolveRequest() async {
    final fetcher =
        widget.statusFetcher ?? ApiClient.instance.fetchImageToVideoStatus;
    I2VRequestStatus status;
    try {
      status = await fetcher(widget.notification.requestId);
      if (status.resultUrl.isEmpty &&
          widget.notification.resultUrl.isNotEmpty) {
        status = status.copyWith(resultUrl: widget.notification.resultUrl);
      }
    } catch (_) {
      status = _fallbackStatus(widget.notification);
    }
    if (!mounted) return;

    final Widget destination;
    if (status.isCompleted && status.resultUrl.isNotEmpty) {
      destination = GeneratedVideoScreen(
        result: status,
        returnToPreviousOnBack: true,
      );
    } else {
      destination = CreatingVideoScreen(
        generation: I2VGeneration.fromRequestStatus(status),
        statusFetcher: fetcher,
        initialRequestStatus: status,
        initialPollDelay: Duration.zero,
        returnToPreviousOnBack: true,
        creatorLabel: _creatorLabel(status.serviceType),
      );
    }

    await Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute<void>(builder: (_) => destination));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('videoNotificationRequestScreen'),
      backgroundColor: const Color(0xFF030208),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Video status'),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Color(0xFFFF3CAE)),
            const SizedBox(height: 18),
            const Text(
              'Opening your video…',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Text(
                'Request ${widget.notification.requestId}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFF8D8592), fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

I2VRequestStatus _fallbackStatus(VideoNotificationOpen notification) {
  return I2VRequestStatus.fromJson(<String, dynamic>{
    'request_id': notification.requestId,
    'request_status': notification.status,
    'result_data': notification.resultUrl,
    'error_message': notification.type == 'video_failed'
        ? 'The video could not be generated.'
        : '',
    'credit_refunded': notification.type == 'video_failed',
  });
}

String _creatorLabel(String serviceType) {
  return switch (serviceType.trim().toUpperCase()) {
    'T2V_GENERATOR' => 'Text to Video',
    'THEME_GENERATOR' => 'Theme to Video',
    _ => 'Image to Video',
  };
}

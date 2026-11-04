import 'dart:async';

import 'package:video_onboarding_activity/video_onboarding_activity.dart';

class VideoGenerationEvents {
  VideoGenerationEvents._();

  static final StreamController<String> _successController =
      StreamController<String>.broadcast(sync: true);

  static Stream<String> get successes => _successController.stream;

  static void notifySuccess(String requestId) {
    final normalizedRequestId = requestId.trim();
    if (normalizedRequestId.isEmpty) return;
    unawaited(VideoOnboardingActivity.recordCompleted([normalizedRequestId]));
    _successController.add(normalizedRequestId);
  }
}

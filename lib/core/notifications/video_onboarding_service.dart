import 'package:flutter/foundation.dart';
import 'package:video_onboarding_activity/video_onboarding_activity.dart';

import '../../data/services/generation_history_service.dart';

/// Restores progress for videos completed while the app was not running, and
/// includes existing history when upgrading an older installation.
abstract final class VideoOnboardingService {
  static Future<void>? _refreshInFlight;

  static Future<void> refresh(GenerationHistoryService Function() history) {
    if (!VideoOnboardingActivity.isSupported) return Future.value();
    return _refreshInFlight ??= _refresh(
      history,
    ).whenComplete(() => _refreshInFlight = null);
  }

  static Future<void> _refresh(
    GenerationHistoryService Function() history,
  ) async {
    final count = await VideoOnboardingActivity.completedCount();
    if (count == null) return;
    if (count >= 3) {
      await VideoOnboardingActivity.refresh();
      return;
    }
    try {
      var page = 1;
      final completed = <String>{};
      while (completed.length < 3) {
        final result = await history().fetch(page: page, limit: 50);
        completed.addAll(
          result.requests
              .where((request) => request.isCompleted)
              .map((request) => request.requestId.trim())
              .where((id) => id.isNotEmpty),
        );
        if (!result.pagination.hasMore) break;
        page++;
      }
      await VideoOnboardingActivity.recordCompleted(completed);
    } catch (error) {
      debugPrint('Could not restore video onboarding progress: $error');
    }
    await VideoOnboardingActivity.refresh();
  }
}

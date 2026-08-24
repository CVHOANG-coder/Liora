class GenerationProgress {
  const GenerationProgress({
    required this.requestId,
    required this.startedAt,
    required this.videoDurationSeconds,
    required this.isHd,
    required this.fakeDurationSeconds,
    required this.savedStepIndex,
  });

  factory GenerationProgress.create({
    required String requestId,
    required DateTime startedAt,
    required int videoDurationSeconds,
    required bool isHd,
  }) {
    final normalizedDuration = videoDurationSeconds > 5 ? 10 : 5;
    return GenerationProgress(
      requestId: requestId,
      startedAt: startedAt,
      videoDurationSeconds: normalizedDuration,
      isHd: isHd,
      fakeDurationSeconds: _estimateSeconds(
        requestId: requestId,
        videoDurationSeconds: normalizedDuration,
        isHd: isHd,
      ),
      savedStepIndex: 0,
    );
  }

  factory GenerationProgress.fromJson(Map<String, dynamic> json) {
    return GenerationProgress(
      requestId: json['request_id']?.toString() ?? '',
      startedAt:
          DateTime.tryParse(json['started_at']?.toString() ?? '') ??
          DateTime.now(),
      videoDurationSeconds:
          (json['video_duration_seconds'] as num?)?.toInt() ?? 5,
      isHd: json['is_hd'] == true,
      fakeDurationSeconds:
          (json['fake_duration_seconds'] as num?)?.toInt() ?? 150,
      savedStepIndex: (json['saved_step_index'] as num?)?.toInt() ?? 0,
    );
  }

  final String requestId;
  final DateTime startedAt;
  final int videoDurationSeconds;
  final bool isHd;
  final int fakeDurationSeconds;
  final int savedStepIndex;

  int get totalSteps => (fakeDurationSeconds / 15).ceil();

  int stepIndexAt(DateTime now) {
    final elapsedSeconds = now
        .difference(startedAt)
        .inSeconds
        .clamp(0, fakeDurationSeconds);
    return (elapsedSeconds ~/ 15).clamp(0, totalSteps - 1);
  }

  double progressAt(DateTime now) {
    final elapsedMilliseconds = now
        .difference(startedAt)
        .inMilliseconds
        .clamp(0, fakeDurationSeconds * 1000);
    final raw = elapsedMilliseconds / (fakeDurationSeconds * 1000);
    return raw.clamp(0.02, 0.95);
  }

  GenerationProgress copyWith({int? savedStepIndex}) {
    return GenerationProgress(
      requestId: requestId,
      startedAt: startedAt,
      videoDurationSeconds: videoDurationSeconds,
      isHd: isHd,
      fakeDurationSeconds: fakeDurationSeconds,
      savedStepIndex: savedStepIndex ?? this.savedStepIndex,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'request_id': requestId,
    'started_at': startedAt.toUtc().toIso8601String(),
    'video_duration_seconds': videoDurationSeconds,
    'is_hd': isHd,
    'fake_duration_seconds': fakeDurationSeconds,
    'saved_step_index': savedStepIndex,
  };
}

int _estimateSeconds({
  required String requestId,
  required int videoDurationSeconds,
  required bool isHd,
}) {
  if (videoDurationSeconds <= 5 && !isHd) return 150;

  final hash = requestId.codeUnits.fold<int>(
    0,
    (value, codeUnit) => (value * 31 + codeUnit) & 0x7fffffff,
  );
  if (videoDurationSeconds <= 5 && isHd) return 180 + hash % 61;
  if (!isHd) return 180 + hash % 61;
  return 300 + hash % 121;
}

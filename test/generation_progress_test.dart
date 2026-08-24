import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_gen/data/models/generation_progress.dart';
import 'package:video_gen/data/models/i2v_generation.dart';
import 'package:video_gen/data/models/i2v_request_status.dart';
import 'package:video_gen/data/services/generation_progress_repository.dart';
import 'package:video_gen/presentation/screens/image_to_video/creating_video_screen.dart';

void main() {
  test('uses generation estimates for every duration and quality case', () {
    final startedAt = DateTime.utc(2026, 8, 24, 10);

    final fiveSecondNonHd = GenerationProgress.create(
      requestId: 'five-non-hd',
      startedAt: startedAt,
      videoDurationSeconds: 5,
      isHd: false,
    );
    final fiveSecondHd = GenerationProgress.create(
      requestId: 'five-hd',
      startedAt: startedAt,
      videoDurationSeconds: 5,
      isHd: true,
    );
    final tenSecondNonHd = GenerationProgress.create(
      requestId: 'ten-non-hd',
      startedAt: startedAt,
      videoDurationSeconds: 10,
      isHd: false,
    );
    final tenSecondHd = GenerationProgress.create(
      requestId: 'ten-hd',
      startedAt: startedAt,
      videoDurationSeconds: 10,
      isHd: true,
    );

    expect(fiveSecondNonHd.fakeDurationSeconds, 150);
    expect(fiveSecondHd.fakeDurationSeconds, inInclusiveRange(180, 240));
    expect(tenSecondNonHd.fakeDurationSeconds, inInclusiveRange(180, 240));
    expect(tenSecondHd.fakeDurationSeconds, inInclusiveRange(300, 420));
  });

  test('advances one fake step every fifteen seconds and caps at 95%', () {
    final startedAt = DateTime.utc(2026, 8, 24, 10);
    final progress = GenerationProgress.create(
      requestId: 'request-001',
      startedAt: startedAt,
      videoDurationSeconds: 5,
      isHd: false,
    );

    expect(progress.stepIndexAt(startedAt.add(const Duration(seconds: 14))), 0);
    expect(progress.stepIndexAt(startedAt.add(const Duration(seconds: 15))), 1);
    expect(progress.stepIndexAt(startedAt.add(const Duration(seconds: 45))), 3);
    expect(
      progress.progressAt(startedAt.add(const Duration(minutes: 4))),
      0.95,
    );
  });

  test('persists request id, start time, fake duration and step', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    const repository = SharedPreferencesGenerationProgressRepository();
    final progress = GenerationProgress.create(
      requestId: 'persisted-request',
      startedAt: DateTime.utc(2026, 8, 24, 10),
      videoDurationSeconds: 10,
      isHd: true,
    );

    await repository.save(progress);
    await repository.updateStep(progress.requestId, 7);
    final restored = await repository.load(progress.requestId);

    expect(restored, isNotNull);
    expect(restored!.requestId, progress.requestId);
    expect(restored.startedAt, progress.startedAt);
    expect(restored.fakeDurationSeconds, progress.fakeDurationSeconds);
    expect(restored.savedStepIndex, 7);
    expect(restored.isHd, isTrue);

    await repository.remove(progress.requestId);
    expect(await repository.load(progress.requestId), isNull);
  });

  testWidgets('restores the current fake step when loading screen reopens', (
    tester,
  ) async {
    final repository = _MemoryProgressRepository();
    final progress = GenerationProgress.create(
      requestId: 'request-001',
      startedAt: DateTime.now().subtract(const Duration(seconds: 46)),
      videoDurationSeconds: 5,
      isHd: false,
    );
    await repository.save(progress);

    await tester.pumpWidget(
      MaterialApp(
        home: CreatingVideoScreen(
          generation: _generation(),
          progressRepository: repository,
          initialPollDelay: const Duration(minutes: 10),
          statusFetcher: (_) async => _queuedStatus(),
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('Preparing visual assets'), findsOneWidget);
    expect(find.textContaining('4/10'), findsOneWidget);
    expect(find.text('31%'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _MemoryProgressRepository implements GenerationProgressRepository {
  final Map<String, GenerationProgress> values = <String, GenerationProgress>{};

  @override
  Future<GenerationProgress?> load(String requestId) async => values[requestId];

  @override
  Future<void> save(GenerationProgress progress) async {
    values[progress.requestId] = progress;
  }

  @override
  Future<void> remove(String requestId) async {
    values.remove(requestId);
  }

  @override
  Future<void> updateStep(String requestId, int stepIndex) async {
    final progress = values[requestId];
    if (progress != null) {
      values[requestId] = progress.copyWith(savedStepIndex: stepIndex);
    }
  }
}

I2VGeneration _generation() {
  return I2VGenerationResponse.fromJson(<String, dynamic>{
    'success': true,
    'message': 'success',
    'data': <String, dynamic>{
      'request_id': 'request-001',
      'status': 'IN_QUEUE',
      'credit_info': <String, dynamic>{},
      'params': <String, dynamic>{'duration': 5},
    },
  }).data;
}

I2VRequestStatus _queuedStatus() {
  return I2VRequestStatus.fromJson(<String, dynamic>{
    'request_id': 'request-001',
    'request_status': 'IN_QUEUE',
  });
}

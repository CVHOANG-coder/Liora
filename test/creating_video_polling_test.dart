import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_gen/core/firebase/firebase_service.dart';
import 'package:video_gen/data/models/generation_progress.dart';
import 'package:video_gen/data/models/i2v_generation.dart';
import 'package:video_gen/data/models/i2v_request_status.dart';
import 'package:video_gen/data/services/generation_progress_repository.dart';
import 'package:video_gen/presentation/screens/image_to_video/creating_video_screen.dart';
import 'package:video_gen/presentation/screens/image_to_video/generated_video_screen.dart';
import 'package:video_gen/presentation/screens/main/main_screen.dart';
import 'package:video_gen/presentation/screens/profile/profile_screen.dart';

void main() {
  testWidgets('shows Settings fallback after the second permission attempt', (
    tester,
  ) async {
    var permissionRequests = 0;
    var settingsOpens = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: CreatingVideoScreen(
          generation: _generation(),
          initialProgress: _progress(),
          progressRepository: _MemoryProgressRepository(),
          notificationPermissionRequester: () async {
            permissionRequests += 1;
            return NotificationPermissionFlowResult.settingsRequired;
          },
          notificationSettingsOpener: () async {
            settingsOpens += 1;
            return true;
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(permissionRequests, 1);
    expect(find.text('Never miss your video'), findsOneWidget);

    await tester.tap(find.byKey(const Key('notificationOpenSettingsButton')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(settingsOpens, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('starts polling at two minutes then repeats every ten seconds', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: CreatingVideoScreen(
          generation: _generation(),
          initialProgress: _progress(),
          progressRepository: _MemoryProgressRepository(),
          statusFetcher: (_) async {
            calls += 1;
            return _status('IN_QUEUE');
          },
        ),
      ),
    );

    await tester.pump(const Duration(minutes: 1, seconds: 59));
    expect(calls, 0);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(calls, 1);

    await tester.pump(const Duration(seconds: 9));
    expect(calls, 1);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(calls, 2);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('poll timing is calculated from the persisted start time', (
    tester,
  ) async {
    var calls = 0;
    final progress = GenerationProgress.create(
      requestId: 'request-001',
      startedAt: DateTime.now().subtract(
        const Duration(minutes: 2, seconds: 5),
      ),
      videoDurationSeconds: 10,
      isHd: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CreatingVideoScreen(
          generation: _generation(),
          initialProgress: progress,
          progressRepository: _MemoryProgressRepository(),
          statusFetcher: (_) async {
            calls += 1;
            return _status('IN_QUEUE');
          },
        ),
      ),
    );

    await tester.pump();

    expect(calls, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('opens the generated video when polling returns COMPLETED', (
    tester,
  ) async {
    var historyRefreshCalls = 0;
    final progressRepository = _MemoryProgressRepository();
    await progressRepository.save(_progress());
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: CreatingVideoScreen(
            generation: _generation(),
            initialProgress: _progress(),
            progressRepository: progressRepository,
            initialPollDelay: Duration.zero,
            pollInterval: const Duration(seconds: 10),
            statusFetcher: (_) async => _status(
              'COMPLETED',
              resultUrl: 'https://example.test/result.mp4',
            ),
            historyRefresher: () async => historyRefreshCalls += 1,
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(GeneratedVideoScreen), findsOneWidget);
    expect(find.text('Your Video'), findsOneWidget);
    expect(historyRefreshCalls, 1);
    expect(await progressRepository.load('request-001'), isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows failure and returns to the create route on FAILED', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final progressRepository = _MemoryProgressRepository();
    await progressRepository.save(_progress());
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: Center(child: Text('Create origin'))),
      ),
    );
    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => CreatingVideoScreen(
          generation: _generation(),
          initialProgress: _progress(),
          progressRepository: progressRepository,
          initialPollDelay: Duration.zero,
          pollInterval: const Duration(seconds: 10),
          statusFetcher: (_) async => _status(
            'FAILED',
            errorMessage: 'The provider could not render this video.',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Video Generation Failed'), findsOneWidget);
    expect(
      find.text('The provider could not render this video.'),
      findsOneWidget,
    );
    expect(await progressRepository.load('request-001'), isNull);
    await tester.tap(find.byKey(const Key('backToImageToVideo')));
    await tester.pumpAndSettle();

    expect(find.text('Create origin'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('downloads video and back opens the Profile tab', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var downloadCalled = false;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: GeneratedVideoScreen(
            result: _status(
              'COMPLETED',
              resultUrl: 'https://example.test/result.mp4',
            ),
            downloader: (url, requestId, onProgress) async {
              downloadCalled = true;
              expect(url, endsWith('result.mp4'));
              expect(requestId, 'request-001');
              onProgress(50, 100);
            },
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Generation Complete ✨'), findsNothing);
    expect(find.byKey(const Key('generatedVideoControls')), findsOneWidget);
    expect(find.byKey(const Key('generatedVideoPlayPause')), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    final downloadButton = find.byKey(const Key('downloadGeneratedVideo'));
    expect(tester.getSize(downloadButton).height, 42);
    expect(tester.getSize(downloadButton).width, lessThan(120));

    await tester.tap(downloadButton);
    await tester.pump();
    expect(downloadCalled, isTrue);
    expect(find.text('Video saved to your photo library.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('generatedVideoBack')));
    await tester.pumpAndSettle();

    expect(find.byType(MainScreen), findsOneWidget);
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('recognizes both failure status spellings', () {
    expect(_status('FAILED').isFailed, isTrue);
    expect(_status('FAIL').isFailed, isTrue);
  });
}

I2VGeneration _generation() {
  return I2VGenerationResponse.fromJson(<String, dynamic>{
    'success': true,
    'message': 'success',
    'data': <String, dynamic>{
      'request_id': 'request-001',
      'runpod_job_id': 'pod-001',
      'status': 'IN_QUEUE',
      'remaining_credit': 65,
      'credit_info': <String, dynamic>{},
      'params': <String, dynamic>{},
    },
  }).data;
}

GenerationProgress _progress() {
  return GenerationProgress.create(
    requestId: 'request-001',
    startedAt: DateTime.now(),
    videoDurationSeconds: 5,
    isHd: false,
  );
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

I2VRequestStatus _status(
  String status, {
  String resultUrl = '',
  String errorMessage = '',
}) {
  return I2VRequestStatus.fromJson(<String, dynamic>{
    'id': 2,
    'request_id': 'request-001',
    'runpod_job_id': 'pod-001',
    'user_id': 2,
    'service_type': 'I2V_GENERATOR',
    'request_status': status,
    'prompt': 'A calm seaside at golden hour',
    'image_url': '',
    'thumbnail_url': '',
    'result_data': resultUrl,
    'error_message': errorMessage,
    'credit_charged': 35,
    'credit_refunded': false,
    'duration': 5,
    'is_hd': false,
    'is_long_time': false,
  });
}

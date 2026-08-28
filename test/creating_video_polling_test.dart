import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
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
import 'package:video_gen/shared/themes/app_theme.dart';

const _previewPath = String.fromEnvironment('CREATING_PREVIEW_PATH');
const _sansPath = String.fromEnvironment('CREATING_PREVIEW_SANS');
const _serifPath = String.fromEnvironment('CREATING_PREVIEW_SERIF');

void main() {
  setUpAll(() async {
    if (_previewPath.isEmpty) return;
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    for (final font in [
      ('Roboto', _sansPath),
      ('Times New Roman', _serifPath),
    ]) {
      if (font.$2.isEmpty) continue;
      final loader = FontLoader(font.$1)
        ..addFont(File(font.$2).readAsBytes().then(ByteData.sublistView));
      await loader.load();
    }
  });

  for (final size in [
    const Size(320, 568),
    const Size(393, 852),
    const Size(568, 320),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('waiting layout and leave dialog at $size, text $scale', (
        tester,
      ) async {
        _setWaitingView(tester, size);
        final theme = _previewPath.isEmpty
            ? AppTheme.dark
            : AppTheme.dark.copyWith(
                textTheme: AppTheme.dark.textTheme.apply(fontFamily: 'Roboto'),
              );
        await tester.pumpWidget(
          RepaintBoundary(
            key: const Key('creatingPreview'),
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: theme,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: CreatingVideoScreen(
                generation: _generation(),
                initialProgress: _progress(),
                progressRepository: _MemoryProgressRepository(),
                notificationPermissionRequester: () async =>
                    NotificationPermissionFlowResult.granted,
                historyDestinationBuilder: (_) =>
                    const Scaffold(body: Text('Video history destination')),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);
        if (_previewPath.isNotEmpty &&
            size == const Size(393, 852) &&
            scale == 1) {
          await _captureWaitingPreview(tester);
        }
        final scroll = find
            .descendant(
              of: find.byKey(const PageStorageKey('creatingVideoScroll')),
              matching: find.byType(Scrollable),
            )
            .first;
        await tester.scrollUntilVisible(
          find.byKey(const Key('continueCreatingInBackground')),
          180,
          scrollable: scroll,
        );
        await tester.pump(const Duration(milliseconds: 300));
        expect(
          find.byKey(const Key('continueCreatingInBackground')).hitTestable(),
          findsOneWidget,
        );
        if (_previewPath.isNotEmpty &&
            size == const Size(393, 852) &&
            scale == 1) {
          await _captureWaitingPreview(tester, suffix: '-actions');
        }
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const Key('creatingVideoBack')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(
          find.byKey(const Key('leaveCreatingVideoDialog')),
          findsOneWidget,
        );
        if (_previewPath.isNotEmpty &&
            size == const Size(393, 852) &&
            scale == 1) {
          await _captureWaitingPreview(tester, suffix: '-dialog');
        }
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(
          find.byKey(const Key('keepWaitingForVideo')),
        );
        await tester.tap(find.byKey(const Key('keepWaitingForVideo')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byKey(const Key('leaveCreatingVideoDialog')), findsNothing);
        await tester.tap(find.byKey(const Key('continueCreatingInBackground')));
        await tester.pumpAndSettle();
        expect(find.text('Video history destination'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }

  testWidgets(
    'failure content stays scrollable with large text on a small phone',
    (tester) async {
      _setWaitingView(tester, const Size(320, 568));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: CreatingVideoScreen(
            generation: _generation(),
            initialProgress: _progress(),
            initialRequestStatus: _status(
              'FAILED',
              errorMessage:
                  'The video could not be generated. Please try another image or prompt.',
            ),
            progressRepository: _MemoryProgressRepository(),
            notificationPermissionRequester: () async =>
                NotificationPermissionFlowResult.granted,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Video Generation Failed'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('backToImageToVideo')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('backToImageToVideo')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

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

  testWidgets('confirms back and opens Generation History', (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: Text('Create origin')),
      ),
    );
    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => CreatingVideoScreen(
          generation: _generation(),
          initialProgress: _progress(),
          progressRepository: _MemoryProgressRepository(),
          notificationPermissionRequester: () async =>
              NotificationPermissionFlowResult.granted,
          historyDestinationBuilder: (_) => const Scaffold(
            key: Key('generationHistoryDestination'),
            body: Text('Generation History'),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('leaveCreatingVideoDialog')), findsOneWidget);
    expect(find.text('Leave this screen?'), findsOneWidget);
    expect(find.textContaining('keep generating'), findsOneWidget);

    await tester.tap(find.byKey(const Key('keepWaitingForVideo')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(CreatingVideoScreen), findsOneWidget);

    await tester.tap(find.byKey(const Key('creatingVideoBack')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('leaveForGenerationHistory')));
    await tester.pumpAndSettle();

    expect(find.byType(CreatingVideoScreen), findsNothing);
    expect(
      find.byKey(const Key('generationHistoryDestination')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
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
    var shareCalled = false;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: GeneratedVideoScreen(
            result: _status(
              'COMPLETED',
              resultUrl: 'https://example.test/result.mp4',
            ),
            sharer: (url, requestId) async {
              shareCalled = true;
              expect(url, endsWith('result.mp4'));
              expect(requestId, 'request-001');
            },
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
    await tester.tap(find.byKey(const Key('shareGeneratedVideo')));
    await tester.pump();
    expect(shareCalled, isTrue);
    final downloadButton = find.byKey(const Key('downloadGeneratedVideo'));
    expect(tester.getSize(downloadButton).height, greaterThanOrEqualTo(48));
    expect(tester.getSize(downloadButton).width, greaterThanOrEqualTo(120));

    await tester.tap(downloadButton);
    await tester.pump();
    expect(downloadCalled, isTrue);
    expect(find.text('Video saved to your photo library.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('generatedVideoBack')));
    await tester.pumpAndSettle();

    expect(find.byType(MainScreen), findsOneWidget);
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.text('SETTINGS'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('deletes the generated video and returns to history', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    var deletedRequestId = '';
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: Text('Video history')),
      ),
    );
    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => GeneratedVideoScreen(
          result: _status(
            'COMPLETED',
            resultUrl: 'https://example.test/result.mp4',
          ),
          returnToPreviousOnBack: true,
          deleter: (requestId) async => deletedRequestId = requestId,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.byKey(const Key('deleteGeneratedVideo')));
    await tester.pump();
    expect(find.byKey(const Key('deleteGeneratedVideoDialog')), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirmDeleteGeneratedVideo')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    expect(deletedRequestId, 'request-001');
    expect(find.byType(GeneratedVideoScreen), findsNothing);
    expect(find.text('Video history'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('recognizes the complete request status contract', () {
    expect(_status('IN_QUEUE').isQueued, isTrue);
    expect(_status('IN_QUEUE').isActive, isTrue);
    expect(_status('PENDING').isPending, isTrue);
    expect(_status('PENDING').isActive, isTrue);
    expect(_status('COMPLETED').isCompleted, isTrue);
    expect(_status('FAILED').isFailed, isTrue);
    expect(_status('ERROR').isFailed, isTrue);
    expect(_status('CANCELLED').isCancelled, isTrue);
    expect(_status('DELETED').isDeleted, isTrue);

    expect(_status('FAILED').isTerminal, isTrue);
    expect(_status('ERROR').isTerminal, isTrue);
    expect(_status('CANCELLED').isTerminal, isTrue);
    expect(_status('DELETED').isTerminal, isTrue);
    expect(_status('FAIL').isFailed, isFalse);
  });

  testWidgets('stops polling and reports refunded credits on CANCELLED', (
    tester,
  ) async {
    final progressRepository = _MemoryProgressRepository();
    await progressRepository.save(_progress());
    await tester.pumpWidget(
      MaterialApp(
        home: CreatingVideoScreen(
          generation: _generation(),
          initialProgress: _progress(),
          progressRepository: progressRepository,
          initialPollDelay: Duration.zero,
          statusFetcher: (_) async => _status('CANCELLED'),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Video Generation Cancelled'), findsOneWidget);
    expect(find.textContaining('credits have been refunded'), findsOneWidget);
    expect(await progressRepository.load('request-001'), isNull);
    expect(tester.takeException(), isNull);
  });
}

void _setWaitingView(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 44, bottom: 34);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPadding);
}

Future<void> _captureWaitingPreview(
  WidgetTester tester, {
  String suffix = '',
}) async {
  final context = tester.element(find.byType(CreatingVideoScreen));
  await tester.runAsync(() async {
    await precacheImage(
      const AssetImage('assets/images/create_video.png'),
      context,
    );
    await precacheImage(
      const AssetImage('assets/images/gen_video/clock.png'),
      context,
    );
  });
  await tester.pump(const Duration(milliseconds: 300));
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('creatingPreview')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final path = _previewPath.replaceFirst(RegExp(r'\.png$'), '$suffix.png');
      await File(path).writeAsBytes(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
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

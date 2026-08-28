import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_gen/core/network/api_exception.dart';
import 'package:video_gen/data/models/generation_progress.dart';
import 'package:video_gen/data/models/i2v_generation.dart';
import 'package:video_gen/data/models/user_profile.dart';
import 'package:video_gen/data/services/generation_progress_repository.dart';
import 'package:video_gen/presentation/providers/profile_provider.dart';
import 'package:video_gen/presentation/screens/image_to_video/creating_video_screen.dart';
import 'package:video_gen/presentation/screens/in_app_purchase/free_trial_screen.dart';
import 'package:video_gen/presentation/screens/text_to_video/text_to_video_screen.dart';

void main() {
  testWidgets('submits T2V prompt and opens the shared creating flow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(profileProvider.notifier)
        .setProfile(
          UserProfile.fromJson(<String, dynamic>{'id': 2, 'total_credit': 100}),
        );
    final progressRepository = _MemoryProgressRepository();
    String? submittedPrompt;
    bool? submittedHd;
    bool? submittedLong;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: TextToVideoScreen(
            progressRepository: progressRepository,
            submit:
                ({required prompt, required isHd, required isLongTime}) async {
                  submittedPrompt = prompt;
                  submittedHd = isHd;
                  submittedLong = isLongTime;
                  return _generation();
                },
          ),
        ),
      ),
    );

    expect(find.text('Select image'), findsNothing);
    expect(find.text('10s'), findsOneWidget);
    expect(find.text('Non-HD'), findsOneWidget);
    await tester.tap(find.text('10s'));
    await tester.pumpAndSettle();
    expect(find.text('3s'), findsNothing);
    expect(find.text('8s'), findsNothing);
    expect(find.widgetWithText(ListTile, '5s'), findsOneWidget);
    await tester.tap(find.widgetWithText(ListTile, '10s'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Non-HD'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Non-HD'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('textToVideoPromptField')),
      'A calm seaside at golden hour',
    );
    await tester.ensureVisible(find.byKey(const Key('generateTextToVideo')));
    await tester.tap(find.byKey(const Key('generateTextToVideo')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(CreatingVideoScreen), findsOneWidget);
    expect(find.byKey(const Key('creatingDefaultArtwork')), findsOneWidget);
    final initialBounce = List<double>.of(
      tester
          .widget<Transform>(
            find.byKey(const Key('creatingDefaultArtworkBounce')),
          )
          .transform
          .storage,
    );
    await tester.pump(const Duration(milliseconds: 500));
    final nextBounce = List<double>.of(
      tester
          .widget<Transform>(
            find.byKey(const Key('creatingDefaultArtworkBounce')),
          )
          .transform
          .storage,
    );
    expect(nextBounce, isNot(equals(initialBounce)));
    expect(find.byKey(const Key('creatingSourceImage')), findsNothing);
    expect(find.byKey(const Key('creatingImageLottie')), findsOneWidget);
    expect(submittedPrompt, 'A calm seaside at golden hour');
    expect(submittedHd, isFalse);
    expect(submittedLong, isTrue);
    expect(container.read(profileProvider)!.totalCredit, 65);
    final savedProgress = progressRepository.values['request-t2v-001'];
    expect(savedProgress?.videoDurationSeconds, 10);
    expect(savedProgress?.isHd, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('requires a prompt before submitting T2V', (tester) async {
    var submitCalled = false;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: TextToVideoScreen(
            submit:
                ({required prompt, required isHd, required isLongTime}) async {
                  submitCalled = true;
                  return _generation();
                },
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('generateTextToVideo')));
    await tester.pump();

    expect(submitCalled, isFalse);
    expect(find.text('Enter a video prompt.'), findsOneWidget);
  });

  testWidgets('opens FreeTrial when non-VIP T2V user runs out of credits', (
    tester,
  ) async {
    var submitCount = 0;
    String? originalPrompt;
    bool? originalIsHd;
    bool? originalIsLongTime;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: TextToVideoScreen(
            progressRepository: _MemoryProgressRepository(),
            submit:
                ({required prompt, required isHd, required isLongTime}) async {
                  submitCount += 1;
                  if (submitCount == 1) {
                    originalPrompt = prompt;
                    originalIsHd = isHd;
                    originalIsLongTime = isLongTime;
                    throw const ApiException(
                      message: 'You need 35 credits, current balance is 0.',
                      statusCode: 400,
                    );
                  }
                  expect(prompt, originalPrompt);
                  expect(isHd, originalIsHd);
                  expect(isLongTime, originalIsLongTime);
                  return _generation();
                },
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('textToVideoPromptField')),
      'A cinematic city at night',
    );
    await tester.tap(find.byKey(const Key('generateTextToVideo')));
    await tester.pumpAndSettle();

    expect(find.text('Not Enough Credits'), findsNothing);
    expect(find.byType(FreeTrialScreen), findsOneWidget);
    expect(
      find.widgetWithText(
        SnackBar,
        'You need 35 credits, current balance is 0.',
      ),
      findsOneWidget,
    );

    Navigator.of(tester.element(find.byType(FreeTrialScreen))).pop(true);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(submitCount, 2);
    expect(find.byType(CreatingVideoScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

I2VGeneration _generation() {
  return I2VGenerationResponse.fromJson(<String, dynamic>{
    'success': true,
    'message': 'success',
    'data': <String, dynamic>{
      'request_id': 'request-t2v-001',
      'runpod_job_id': 'pod-t2v-001',
      'user_id': 2,
      'service_type': 'T2V_GENERATOR',
      'prompt': 'A calm seaside at golden hour',
      'image_url': '',
      'status': 'IN_QUEUE',
      'create_time': '2026-08-23T18:34:47.718Z',
      'remaining_credit': 65,
      'credit_info': <String, dynamic>{
        'base_credit': 35,
        'multiplier': 1,
        'total_charged': 35,
      },
      'params': <String, dynamic>{
        'duration': 5,
        'megapixels': 0.5,
        'steps': 8,
        'aspect_ratio': '9:16',
        'seed': '123',
      },
    },
  }).data;
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

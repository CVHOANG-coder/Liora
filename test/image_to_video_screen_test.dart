import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_gen/core/device/image_access_permission.dart';
import 'package:video_gen/core/network/api_exception.dart';
import 'package:video_gen/data/models/generation_progress.dart';
import 'package:video_gen/data/models/i2v_generation.dart';
import 'package:video_gen/data/models/user_profile.dart';
import 'package:video_gen/data/services/generation_progress_repository.dart';
import 'package:video_gen/presentation/providers/profile_provider.dart';
import 'package:video_gen/presentation/screens/image_to_video/creating_video_screen.dart';
import 'package:video_gen/presentation/screens/image_to_video/image_to_video_screen.dart';
import 'package:video_gen/presentation/screens/in_app_purchase/in_app_purchase_screen.dart';
import 'package:video_gen/presentation/widgets/generation_failure_dialog.dart';

void main() {
  test('recognizes insufficient-credit API errors', () {
    expect(
      isInsufficientCreditError(
        const ApiException(message: 'Payment required', statusCode: 402),
      ),
      isTrue,
    );
    expect(
      isInsufficientCreditError(
        const ApiException(message: 'Not enough credits to generate video'),
      ),
      isTrue,
    );
    expect(
      isInsufficientCreditError(
        const ApiException(message: 'Internal server error', statusCode: 500),
      ),
      isFalse,
    );
  });

  testWidgets('submits I2V form and opens the creating screen on success', (
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
    String? submittedPath;
    String? submittedPrompt;
    bool? submittedHd;
    bool? submittedLong;
    final progressRepository = _MemoryProgressRepository();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: ImageToVideoScreen(
            progressRepository: progressRepository,
            requestPermission: (_) async => ImageAccessPermissionResult.granted,
            pickImageFromSource: (_) async =>
                File('assets/images/create_video.png').absolute.path,
            submit:
                ({
                  required imagePath,
                  required prompt,
                  required isHd,
                  required isLongTime,
                }) async {
                  submittedPath = imagePath;
                  submittedPrompt = prompt;
                  submittedHd = isHd;
                  submittedLong = isLongTime;
                  return _generation();
                },
          ),
        ),
      ),
    );

    await _selectFromGallery(tester);
    expect(find.text('Image selected'), findsOneWidget);

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
    expect(find.text('Normal (720p)'), findsNothing);
    expect(find.text('High (1080p)'), findsNothing);
    await tester.tap(find.widgetWithText(ListTile, 'Non-HD'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('imageToVideoPromptField')),
      'Gentle cinematic camera movement',
    );
    await tester.pump();
    await tester.ensureVisible(find.text('Generate'));
    await tester.pump();
    await tester.tap(find.text('Generate'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(CreatingVideoScreen), findsOneWidget);
    expect(find.text('Creating Video'), findsOneWidget);
    expect(submittedPath, endsWith('assets/images/create_video.png'));
    expect(submittedPrompt, 'Gentle cinematic camera movement');
    expect(submittedHd, isFalse);
    expect(submittedLong, isTrue);
    expect(container.read(profileProvider)!.totalCredit, 65);
    final savedProgress = progressRepository.values['request-001'];
    expect(savedProgress?.videoDurationSeconds, 10);
    expect(savedProgress?.isHd, isFalse);
    expect(savedProgress?.fakeDurationSeconds, inInclusiveRange(180, 240));
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows a failure dialog for a regular generation error', (
    tester,
  ) async {
    await _setPhoneSize(tester);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ImageToVideoScreen(
            requestPermission: (_) async => ImageAccessPermissionResult.granted,
            pickImageFromSource: (_) => _testImagePath(),
            submit:
                ({
                  required imagePath,
                  required prompt,
                  required isHd,
                  required isLongTime,
                }) async => throw const ApiException(
                  message: 'The generation service is temporarily unavailable.',
                  statusCode: 500,
                ),
          ),
        ),
      ),
    );

    await _prepareAndGenerate(tester);

    expect(find.text('Video Generation Failed'), findsOneWidget);
    expect(find.text('Try Again'), findsOneWidget);
    expect(find.text('Buy Credits'), findsNothing);
    expect(
      find.text('The generation service is temporarily unavailable.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'opens BuyCredits when generation fails for insufficient credit',
    (tester) async {
      await _setPhoneSize(tester);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: ImageToVideoScreen(
              requestPermission: (_) async =>
                  ImageAccessPermissionResult.granted,
              pickImageFromSource: (_) => _testImagePath(),
              submit:
                  ({
                    required imagePath,
                    required prompt,
                    required isHd,
                    required isLongTime,
                  }) async => throw const ApiException(
                    message: 'Insufficient credit balance',
                    statusCode: 402,
                  ),
            ),
          ),
        ),
      );

      await _prepareAndGenerate(tester);

      expect(find.text('Not Enough Credits'), findsOneWidget);
      expect(find.text('Buy Credits'), findsOneWidget);
      await tester.tap(find.text('Buy Credits'));
      await tester.pumpAndSettle();

      expect(find.byType(BuyCredits), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('requests camera permission before opening the camera', (
    tester,
  ) async {
    await _setPhoneSize(tester);
    final events = <String>[];

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ImageToVideoScreen(
            requestPermission: (source) async {
              events.add('permission:${source.name}');
              return ImageAccessPermissionResult.granted;
            },
            pickImageFromSource: (source) async {
              events.add('picker:${source.name}');
              return File('assets/images/create_video.png').absolute.path;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Select image'));
    await tester.pumpAndSettle();
    expect(find.text('Photo library'), findsOneWidget);
    expect(find.text('Camera'), findsOneWidget);

    await tester.tap(find.byKey(const Key('cameraImageSource')));
    await tester.pumpAndSettle();

    expect(events, ['permission:camera', 'picker:camera']);
    expect(find.text('Image selected'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('does not open gallery when photo permission is denied', (
    tester,
  ) async {
    await _setPhoneSize(tester);
    var pickerCalled = false;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ImageToVideoScreen(
            requestPermission: (_) async => ImageAccessPermissionResult.denied,
            pickImageFromSource: (_) async {
              pickerCalled = true;
              return null;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Select image'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('galleryImageSource')));
    await tester.pumpAndSettle();

    expect(pickerCalled, isFalse);
    expect(
      find.text('Photo access is required to select an image.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

Future<String?> _testImagePath() async =>
    File('assets/images/create_video.png').absolute.path;

Future<void> _prepareAndGenerate(WidgetTester tester) async {
  await _selectFromGallery(tester);
  await tester.enterText(
    find.byKey(const Key('imageToVideoPromptField')),
    'Gentle cinematic camera movement',
  );
  await tester.pump();
  await tester.ensureVisible(find.text('Generate'));
  await tester.pump();
  await tester.tap(find.text('Generate'));
  await tester.pumpAndSettle();
}

Future<void> _selectFromGallery(WidgetTester tester) async {
  await tester.tap(find.text('Select image'));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('galleryImageSource')));
  await tester.pumpAndSettle();
}

Future<void> _setPhoneSize(WidgetTester tester) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

I2VGeneration _generation() {
  return I2VGenerationResponse.fromJson(<String, dynamic>{
    'success': true,
    'message': 'success',
    'data': <String, dynamic>{
      'request_id': 'request-001',
      'runpod_job_id': 'pod-001',
      'user_id': 2,
      'service_type': 'I2V_GENERATOR',
      'prompt': 'cinematic',
      'image_url': 'https://example.test/image.jpg',
      'status': 'IN_QUEUE',
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

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_gen/core/device/image_access_permission.dart';
import 'package:video_gen/core/network/api_exception.dart';
import 'package:video_gen/data/models/generation_progress.dart';
import 'package:video_gen/data/models/i2v_generation.dart';
import 'package:video_gen/data/models/user_profile.dart';
import 'package:video_gen/data/services/generation_progress_repository.dart';
import 'package:video_gen/data/video_categories.dart';
import 'package:video_gen/presentation/providers/profile_provider.dart';
import 'package:video_gen/presentation/screens/image_to_video/creating_video_screen.dart';
import 'package:video_gen/presentation/screens/in_app_purchase/free_trial_screen.dart';
import 'package:video_gen/presentation/screens/theme_to_video/theme_to_video_screen.dart';

void main() {
  const theme = VideoPost(
    id: 'mad_dance',
    themeKey: 'mad_dance',
    thumbnailUrl: 'https://example.test/mad-dance.jpg',
    videoUrl: null,
    description: 'Mad dance',
  );

  testWidgets('submits a theme video with only the first frame', (
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
    final imagePath = File('assets/images/create_video.png').absolute.path;
    var pickerCalls = 0;
    String? submittedTheme;
    String? submittedFirstImage;
    bool? submittedHd;
    bool? submittedLong;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: ThemeToVideoScreen(
            theme: theme,
            progressRepository: progressRepository,
            requestPermission: (_) async => ImageAccessPermissionResult.granted,
            pickImage: (source) async {
              expect(source, ImageSource.gallery);
              pickerCalls += 1;
              return imagePath;
            },
            submit:
                ({
                  required themeId,
                  required firstImagePath,
                  required isHd,
                  required isLongTime,
                }) async {
                  submittedTheme = themeId;
                  submittedFirstImage = firstImagePath;
                  submittedHd = isHd;
                  submittedLong = isLongTime;
                  return _generation();
                },
          ),
        ),
      ),
    );

    expect(find.text('Prompt'), findsNothing);
    expect(find.text('First frame'), findsOneWidget);
    expect(find.text('Last frame'), findsNothing);
    expect(find.byKey(const Key('lastFrameCard')), findsNothing);

    await _selectGalleryFrame(tester, const Key('firstFrameCard'));
    expect(pickerCalls, 1);

    expect(find.text('10s'), findsOneWidget);
    expect(find.text('Non-HD'), findsOneWidget);
    await tester.tap(find.text('10s'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, '5s'), findsOneWidget);
    await tester.tap(find.widgetWithText(ListTile, '10s'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Non-HD'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Non-HD'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('generateThemeVideo')));
    await tester.tap(find.byKey(const Key('generateThemeVideo')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(CreatingVideoScreen), findsOneWidget);
    expect(find.byKey(const Key('creatingSourceImage')), findsOneWidget);
    expect(find.byKey(const Key('creatingImageLottie')), findsOneWidget);
    expect(find.byKey(const Key('creatingImageScanLine')), findsOneWidget);
    expect(submittedTheme, 'mad_dance');
    expect(submittedFirstImage, imagePath);
    expect(submittedHd, isFalse);
    expect(submittedLong, isTrue);
    expect(container.read(profileProvider)!.totalCredit, 65);
    final savedProgress = progressRepository.values['request-theme-001'];
    expect(savedProgress?.videoDurationSeconds, 10);
    expect(savedProgress?.isHd, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('requires only the first frame', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final imagePath = File('assets/images/create_video.png').absolute.path;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ThemeToVideoScreen(
            theme: theme,
            progressRepository: _MemoryProgressRepository(),
            requestPermission: (_) async => ImageAccessPermissionResult.granted,
            pickImage: (_) async => imagePath,
            submit:
                ({
                  required themeId,
                  required firstImagePath,
                  required isHd,
                  required isLongTime,
                }) async {
                  return _generation();
                },
          ),
        ),
      ),
    );

    await _selectGalleryFrame(tester, const Key('firstFrameCard'));
    await tester.ensureVisible(find.byKey(const Key('generateThemeVideo')));
    await tester.tap(find.byKey(const Key('generateThemeVideo')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(CreatingVideoScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'opens FreeTrial when non-VIP theme generation runs out of credits',
    (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final imagePath = File('assets/images/create_video.png').absolute.path;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: ThemeToVideoScreen(
              theme: theme,
              requestPermission: (_) async =>
                  ImageAccessPermissionResult.granted,
              pickImage: (_) async => imagePath,
              submit:
                  ({
                    required themeId,
                    required firstImagePath,
                    required isHd,
                    required isLongTime,
                  }) async => throw const ApiException(
                    message: 'Not enough credits to generate this video.',
                    errorCode: ApiErrorCode.insufficientCredit,
                    statusCode: 400,
                  ),
            ),
          ),
        ),
      );

      await _selectGalleryFrame(tester, const Key('firstFrameCard'));
      await tester.ensureVisible(find.byKey(const Key('generateThemeVideo')));
      await tester.tap(find.byKey(const Key('generateThemeVideo')));
      await tester.pumpAndSettle();

      expect(find.text('Not Enough Credits'), findsOneWidget);
      expect(find.text('Buy Credits'), findsOneWidget);
      await tester.tap(find.text('Buy Credits'));
      await tester.pumpAndSettle();

      expect(find.byType(FreeTrialScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _selectGalleryFrame(WidgetTester tester, Key cardKey) async {
  await tester.tap(find.byKey(cardKey));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('galleryFrameSource')));
  await tester.pumpAndSettle();
}

I2VGeneration _generation() {
  return I2VGenerationResponse.fromJson(<String, dynamic>{
    'success': true,
    'message': 'success',
    'data': <String, dynamic>{
      'request_id': 'request-theme-001',
      'runpod_job_id': 'pod-theme-001',
      'user_id': 2,
      'service_type': 'I2V_GENERATOR',
      'theme': <String, dynamic>{'id': 1, 'name': 'Mad dance'},
      'prompt': 'High-energy dance',
      'image_url': 'https://example.test/first.jpg',
      'image2_url': 'https://example.test/last.jpg',
      'status': 'IN_QUEUE',
      'create_time': '2026-08-23T19:13:17.143Z',
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

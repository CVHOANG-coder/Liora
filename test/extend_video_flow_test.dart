import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_gen/core/network/api_exception.dart';
import 'package:video_gen/core/constants/app_features.dart';
import 'package:video_gen/presentation/screens/in_app_purchase/in_app_purchase_screen.dart';
import 'package:video_gen/presentation/screens/in_app_purchase/free_trial_screen.dart';
import 'package:video_gen/data/models/i2v_generation.dart';
import 'package:video_gen/data/models/i2v_request_status.dart';
import 'package:video_gen/data/models/user_profile.dart';
import 'package:video_gen/data/services/generation_progress_repository.dart';
import 'package:video_gen/presentation/providers/profile_provider.dart';
import 'package:video_gen/presentation/screens/extend_video/extend_video_screen.dart';
import 'package:video_gen/presentation/screens/image_to_video/creating_video_screen.dart';
import 'package:video_gen/presentation/screens/image_to_video/generated_video_screen.dart';
import 'package:video_gen/presentation/widgets/generation_failure_dialog.dart';
import 'package:video_gen/presentation/widgets/video_library_widgets.dart';
import 'package:video_gen/shared/themes/app_theme.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'submits selected settings once, saves progress, updates credits and polls new job to completion',
    (tester) async {
      final response = Completer<I2VGeneration>();
      var submissions = 0;
      var polls = 0;
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container
          .read(profileProvider.notifier)
          .setProfile(
            UserProfile.fromJson({
              'total_credit': 500,
              'duration_options': [
                {'duration': 5, 'i2v_credit': 35, 'i2v_credit_hd': 70},
                {'duration': 10, 'i2v_credit': 70, 'i2v_credit_hd': 140},
                {'duration': 15, 'i2v_credit': 140, 'i2v_credit_hd': 280},
              ],
            }),
          );
      await _open(
        tester,
        ExtendVideoScreen(
          result: _source(),
          submit:
              ({
                requestId,
                videoUrl,
                required prompt,
                isHd = false,
                duration = 5,
                seed,
              }) {
                submissions++;
                expect(requestId, 'source');
                expect(videoUrl, isNull);
                expect(prompt, 'The camera pulls back');
                expect(duration, 15);
                expect(isHd, true);
                expect(seed, isNull);
                return response.future;
              },
          statusFetcher: (id) async {
            expect(id, 'new-extension');
            polls++;
            return I2VRequestStatus.fromJson({
              'request_id': id,
              'request_status': polls == 1 ? 'PENDING' : 'COMPLETED',
              'result_data': 'https://example.test/extended.mp4',
            });
          },
        ),
        container: container,
      );
      expect(find.text('Extend video · 10s'), findsOneWidget);
      expect(find.byKey(const Key('extendVideoCreditCost')), findsNothing);
      expect(
        find.byKey(const PageStorageKey('extendVideoAdvanced')),
        findsNothing,
      );
      await tester.enterText(
        find.byKey(const Key('extendVideoPrompt')),
        ' The camera pulls back ',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await _reveal(tester, find.byKey(const Key('extendDuration15')));
      await tester.tap(find.byKey(const Key('extendDuration15')));
      await _reveal(tester, find.byKey(const ValueKey('videoSetting-Quality')));
      await tester.tap(find.byKey(const ValueKey('videoSetting-Quality')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('HD').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('submitExtendVideo')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('submitExtendVideo')));
      expect(submissions, 1);
      expect(
        tester
            .widget<VideoLibraryAction>(
              find.byKey(const Key('submitExtendVideo')),
            )
            .onTap,
        isNull,
      );
      response.complete(_generation());
      await _transition(tester);
      expect(find.byType(CreatingVideoScreen), findsOneWidget);
      final processing = tester.widget<CreatingVideoScreen>(
        find.byType(CreatingVideoScreen),
      );
      expect(processing.creatorLabel, 'Extend Video');
      expect(processing.isExtension, isTrue);
      expect(find.text('Extending Video'), findsOneWidget);
      expect(find.text('Extending your video...'), findsOneWidget);
      expect(
        tester
            .widget<Image>(find.byKey(const Key('creatingSourceImage')))
            .image,
        const NetworkImage('https://example.test/last-frame.png'),
      );
      expect(find.byKey(const Key('creatingImageLottie')), findsOneWidget);
      expect(processing.initialProgress!.videoDurationSeconds, 15);
      expect(processing.initialProgress!.isHd, isTrue);
      expect(container.read(profileProvider)!.totalCredit, 220);
      final stored = await const SharedPreferencesGenerationProgressRepository()
          .load('new-extension');
      expect(stored!.videoDurationSeconds, 15);
      await tester.pump(const Duration(minutes: 2));
      await tester.pump();
      expect(polls, 1);
      await tester.pump(const Duration(seconds: 10));
      await _transition(tester);
      expect(find.byType(GeneratedVideoScreen), findsOneWidget);
      expect(
        tester
            .widget<GeneratedVideoScreen>(find.byType(GeneratedVideoScreen))
            .result
            .requestId,
        'new-extension',
      );
      expect(
        await const SharedPreferencesGenerationProgressRepository().load(
          'new-extension',
        ),
        isNull,
      );
      expect(submissions, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  if (AppFeatures.commerceEnabled) {
    for (final subscribed in [false, true]) {
      testWidgets(
        'insufficient credits opens purchase and resumes extension, subscribed=$subscribed',
        (tester) async {
          final container = ProviderContainer();
          addTearDown(container.dispose);
          container
              .read(profileProvider.notifier)
              .setProfile(
                UserProfile.fromJson({
                  'isSubscribed': subscribed,
                  'isVIP': false,
                }),
              );
          var calls = 0;
          await _open(
            tester,
            ExtendVideoScreen(
              result: _source(),
              submit:
                  ({
                    requestId,
                    videoUrl,
                    required prompt,
                    isHd = false,
                    duration = 5,
                    seed,
                  }) async {
                    calls++;
                    expect(prompt, 'Continue');
                    if (calls == 1) {
                      throw const ApiException(
                        message: 'Not enough credits',
                        errorCode: ApiErrorCode.insufficientCredit,
                      );
                    }
                    return _generation();
                  },
            ),
            container: container,
          );
          await tester.enterText(
            find.byKey(const Key('extendVideoPrompt')),
            'Continue',
          );
          await tester.tap(find.byKey(const Key('submitExtendVideo')));
          await tester.pumpAndSettle();
          final destination = subscribed
              ? find.byType(BuyCredits)
              : find.byType(FreeTrialScreen);
          expect(destination, findsOneWidget);
          expect(calls, 1);
          Navigator.of(tester.element(destination)).pop(true);
          await _transition(tester);
          expect(calls, 2);
          expect(find.byType(CreatingVideoScreen), findsOneWidget);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }

  for (final leave in [false, true]) {
    testWidgets(
      'pending extend guards back and handles late response, leave=$leave',
      (tester) async {
        final response = Completer<I2VGeneration>();
        await _open(
          tester,
          ExtendVideoScreen(
            result: _source(),
            submit:
                ({
                  requestId,
                  videoUrl,
                  required prompt,
                  isHd = false,
                  duration = 5,
                  seed,
                }) => response.future,
          ),
        );
        await tester.enterText(
          find.byKey(const Key('extendVideoPrompt')),
          'Continue',
        );
        await tester.tap(find.byKey(const Key('submitExtendVideo')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('extendVideoBack')));
        await _transition(tester);
        expect(find.byKey(const Key('generationExitDialog')), findsOneWidget);
        await tester.tap(
          find.byKey(
            Key(leave ? 'leaveGenerationForm' : 'stayOnGenerationForm'),
          ),
        );
        await tester.pump();
        response.complete(_generation());
        await _transition(tester);
        expect(
          find.byType(CreatingVideoScreen),
          leave ? findsNothing : findsOneWidget,
        );
        expect(find.byKey(const Key('generationExitDialog')), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'frame extraction failure retries the same input then opens processing',
    (tester) async {
      var calls = 0;
      await _open(
        tester,
        ExtendVideoScreen(
          result: _source(),
          submit:
              ({
                requestId,
                videoUrl,
                required prompt,
                isHd = false,
                duration = 5,
                seed,
              }) async {
                calls++;
                expect(prompt, 'Continue');
                if (calls == 1) {
                  throw const ApiException(
                    message: 'Extraction failed',
                    errorCode: ApiErrorCode.frameExtractFailed,
                  );
                }
                return _generation();
              },
        ),
      );
      await tester.enterText(
        find.byKey(const Key('extendVideoPrompt')),
        'Continue',
      );
      await tester.tap(find.byKey(const Key('submitExtendVideo')));
      await tester.pumpAndSettle();
      expect(find.byType(GenerationFailureDialog), findsOneWidget);
      await tester.tap(find.text('Try Again'));
      await _transition(tester);
      expect(calls, 2);
      expect(find.byType(CreatingVideoScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

I2VRequestStatus _source() => I2VRequestStatus.fromJson({
  'request_id': 'source',
  'request_status': 'COMPLETED',
  'result_data': 'https://example.test/source.mp4',
});
I2VGeneration _generation() => I2VGeneration.fromJson({
  'request_id': 'new-extension',
  'extend_from': 'source',
  'image_url': 'https://example.test/last-frame.png',
  'status': 'IN_QUEUE',
  'remaining_credit': 220,
  'params': {'duration': 15, 'megapixels': 1},
});

Future<void> _open(
  WidgetTester tester,
  Widget screen, {
  ProviderContainer? container,
}) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final app = MaterialApp(
    theme: AppTheme.dark,
    home: Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          key: const Key('open'),
          onPressed: () => Navigator.of(
            context,
          ).push(MaterialPageRoute<void>(builder: (_) => screen)),
          child: const Text('Open'),
        ),
      ),
    ),
  );
  await tester.pumpWidget(
    container == null
        ? ProviderScope(child: app)
        : UncontrolledProviderScope(container: container, child: app),
  );
  await tester.tap(find.byKey(const Key('open')));
  await tester.pumpAndSettle();
}

Future<void> _transition(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _reveal(WidgetTester tester, Finder finder) async {
  for (var i = 0; finder.evaluate().isEmpty && i < 30; i++) {
    final rect = tester.getRect(find.byType(Scrollable).first);
    await tester.dragFrom(
      Offset(rect.left + 4, rect.center.dy),
      const Offset(0, -150),
    );
    await tester.pumpAndSettle();
  }
  await Scrollable.ensureVisible(tester.element(finder), alignment: .5);
  await tester.pumpAndSettle();
}

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_gen/core/constants/app_features.dart';
import 'package:video_gen/core/device/image_access_permission.dart';
import 'package:video_gen/core/network/api_exception.dart';
import 'package:video_gen/data/models/generation_progress.dart';
import 'package:video_gen/data/models/i2v_generation.dart';
import 'package:video_gen/data/services/generation_progress_repository.dart';
import 'package:video_gen/data/video_categories.dart';
import 'package:video_gen/presentation/screens/image_to_video/creating_video_screen.dart';
import 'package:video_gen/presentation/screens/image_to_video/image_to_video_screen.dart';
import 'package:video_gen/presentation/screens/in_app_purchase/free_trial_screen.dart';
import 'package:video_gen/presentation/screens/text_to_video/text_to_video_screen.dart';
import 'package:video_gen/presentation/screens/theme_to_video/theme_to_video_screen.dart';
import 'package:video_gen/presentation/widgets/generation_failure_dialog.dart';
import 'package:video_gen/shared/themes/app_theme.dart';

enum _Form { image, text, theme }

void main() {
  for (final form in _Form.values) {
    for (final systemBack in [false, true]) {
      testWidgets('${form.name}: exits an idle form, systemBack=$systemBack', (
        tester,
      ) async {
        await _openForm(tester, form, () async => _generation());
        await _goBack(tester, systemBack: systemBack);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('openForm')), findsOneWidget);
        expect(find.byKey(const Key('generationExitDialog')), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets(
        '${form.name}: warns while sending and stays, systemBack=$systemBack',
        (tester) async {
          final response = Completer<I2VGeneration>();
          var calls = 0;
          await _openForm(tester, form, () {
            calls += 1;
            return response.future;
          });
          await _submit(tester, form);
          await _goBack(tester, systemBack: systemBack);

          expect(find.byKey(const Key('generationExitDialog')), findsOneWidget);
          expect(
            find.textContaining(
              AppFeatures.commerceEnabled
                  ? 'may still be processed and use credits'
                  : 'may still be processed',
            ),
            findsOneWidget,
          );
          await tester.tap(find.byKey(const Key('stayOnGenerationForm')));
          await _pumpTransition(tester);
          expect(find.byKey(const Key('generationExitDialog')), findsNothing);
          expect(find.byKey(const Key('openForm')), findsNothing);
          expect(calls, 1);

          response.complete(_generation());
          await _pumpTransition(tester);
          expect(find.byType(CreatingVideoScreen), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }

    for (final succeeds in [false, true]) {
      testWidgets(
        '${form.name}: confirmed exit ignores late response, success=$succeeds',
        (tester) async {
          final response = Completer<I2VGeneration>();
          await _openForm(tester, form, () => response.future);
          await _submit(tester, form);
          await _goBack(tester, systemBack: true);
          await tester.tap(find.byKey(const Key('leaveGenerationForm')));
          // Complete before the route's exit animation disposes the form.
          await tester.pump();
          _complete(response, succeeds: succeeds);
          await tester.pumpAndSettle();

          expect(find.byKey(const Key('openForm')), findsOneWidget);
          expect(find.byKey(const Key('generationExitDialog')), findsNothing);
          expect(find.byType(CreatingVideoScreen), findsNothing);
          expect(find.byType(FreeTrialScreen), findsNothing);
          expect(find.byType(GenerationFailureDialog), findsNothing);
          expect(find.byType(SnackBar), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        '${form.name}: response dismisses pending warning, success=$succeeds',
        (tester) async {
          final response = Completer<I2VGeneration>();
          await _openForm(tester, form, () => response.future);
          await _submit(tester, form);
          await _goBack(tester, systemBack: true);
          expect(find.byKey(const Key('generationExitDialog')), findsOneWidget);

          _complete(response, succeeds: succeeds);
          await _pumpTransition(tester);

          expect(find.byKey(const Key('generationExitDialog')), findsNothing);
          expect(
            find.byType(CreatingVideoScreen),
            succeeds ? findsOneWidget : findsNothing,
          );
          expect(
            find.byType(FreeTrialScreen),
            !succeeds && AppFeatures.commerceEnabled
                ? findsOneWidget
                : findsNothing,
          );
          expect(
            find.byType(GenerationFailureDialog),
            !succeeds && !AppFeatures.commerceEnabled
                ? findsOneWidget
                : findsNothing,
          );
          expect(find.byKey(const Key('openForm')), findsNothing);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }

    testWidgets('${form.name}: repeated back requests do not stack warnings', (
      tester,
    ) async {
      final response = Completer<I2VGeneration>();
      await _openForm(tester, form, () => response.future);
      await _submit(tester, form);
      final formContext = tester.element(
        find.byType(switch (form) {
          _Form.image => ImageToVideoScreen,
          _Form.text => TextToVideoScreen,
          _Form.theme => ThemeToVideoScreen,
        }),
      );
      // Two back requests before the first dialog route has been built.
      final first = Navigator.maybePop(formContext);
      final second = Navigator.maybePop(formContext);
      await Future.wait([first, second]);
      await _pumpTransition(tester);
      expect(find.byKey(const Key('generationExitDialog')), findsOneWidget);

      await tester.binding.handlePopRoute();
      await _pumpTransition(tester);
      expect(find.byKey(const Key('generationExitDialog')), findsNothing);
      expect(find.byKey(const Key('openForm')), findsNothing);

      response.completeError(
        const ApiException(message: 'Server unavailable', statusCode: 500),
      );
      await tester.pumpAndSettle();
      expect(find.byType(GenerationFailureDialog), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      await _goBack(tester, systemBack: true);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('openForm')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

void _complete(Completer<I2VGeneration> response, {required bool succeeds}) {
  if (succeeds) {
    response.complete(_generation());
  } else {
    response.completeError(
      const ApiException(
        message: 'Not enough credits',
        errorCode: ApiErrorCode.insufficientCredit,
        statusCode: 402,
      ),
    );
  }
}

Future<void> _openForm(
  WidgetTester tester,
  _Form form,
  Future<I2VGeneration> Function() submit,
) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final imagePath = File('assets/images/create_video.png').absolute.path;
  final repository = _MemoryProgressRepository();
  final screen = switch (form) {
    _Form.image => ImageToVideoScreen(
      progressRepository: repository,
      requestPermission: (_) async => ImageAccessPermissionResult.granted,
      pickImageFromSource: (_) async => imagePath,
      submit:
          ({
            required imagePath,
            onUploadProgress,
            required prompt,
            required isHd,
            required isLongTime,
          }) => submit(),
    ),
    _Form.text => TextToVideoScreen(
      progressRepository: repository,
      submit: ({required prompt, required isHd, required isLongTime}) =>
          submit(),
    ),
    _Form.theme => ThemeToVideoScreen(
      theme: const VideoPost(
        id: 'mad_dance',
        themeKey: 'mad_dance',
        thumbnailUrl: 'https://example.test/theme.jpg',
        videoUrl: null,
        description: 'Mad dance',
      ),
      progressRepository: repository,
      requestPermission: (_) async => ImageAccessPermissionResult.granted,
      pickImage: (_) async => imagePath,
      submit:
          ({
            required themeId,
            required firstImagePath,
            onUploadProgress,
            required isHd,
            required isLongTime,
          }) => submit(),
    ),
  };
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: AppTheme.dark,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                key: const Key('openForm'),
                onPressed: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute<void>(builder: (_) => screen)),
                child: const Text('Open form'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const Key('openForm')));
  await tester.pumpAndSettle();
}

Future<void> _submit(WidgetTester tester, _Form form) async {
  switch (form) {
    case _Form.image:
      await tester.tap(find.text('Select image'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('galleryImageSource')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('imageToVideoPromptField')),
        'Cinematic motion',
      );
    case _Form.text:
      await tester.enterText(
        find.byKey(const Key('textToVideoPromptField')),
        'Cinematic motion',
      );
    case _Form.theme:
      await tester.tap(find.byKey(const Key('firstFrameCard')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('galleryFrameSource')));
      await tester.pumpAndSettle();
  }
  await tester.ensureVisible(find.text('Generate'));
  await tester.pump();
  await tester.tap(find.text('Generate'));
  await _pumpTransition(tester);
}

Future<void> _goBack(WidgetTester tester, {required bool systemBack}) async {
  if (systemBack) {
    await tester.binding.handlePopRoute();
  } else {
    await tester.scrollUntilVisible(
      find.byIcon(Icons.arrow_back_rounded),
      -250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
  }
  await _pumpTransition(tester);
}

Future<void> _pumpTransition(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump();
}

I2VGeneration _generation() => I2VGeneration.fromJson({
  'request_id': 'exit-test-request',
  'status': 'IN_QUEUE',
  'remaining_credit': 65,
  'create_time': DateTime.now().toIso8601String(),
});

class _MemoryProgressRepository implements GenerationProgressRepository {
  final _values = <String, GenerationProgress>{};
  @override
  Future<GenerationProgress?> load(String requestId) async =>
      _values[requestId];
  @override
  Future<void> save(GenerationProgress progress) async {
    _values[progress.requestId] = progress;
  }

  @override
  Future<void> remove(String requestId) async {
    _values.remove(requestId);
  }

  @override
  Future<void> updateStep(String requestId, int stepIndex) async {}
}

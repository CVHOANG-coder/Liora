import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_gen/core/device/image_access_permission.dart';
import 'package:video_gen/core/network/api_exception.dart';
import 'package:video_gen/data/models/generation_progress.dart';
import 'package:video_gen/data/models/i2v_generation.dart';
import 'package:video_gen/data/services/generation_progress_repository.dart';
import 'package:video_gen/data/video_categories.dart';
import 'package:video_gen/presentation/screens/image_to_video/creating_video_screen.dart';
import 'package:video_gen/presentation/screens/image_to_video/image_to_video_screen.dart';
import 'package:video_gen/presentation/screens/theme_to_video/theme_to_video_screen.dart';
import 'package:video_gen/presentation/widgets/generation_failure_dialog.dart';
import 'package:video_gen/presentation/widgets/image_upload_progress_overlay.dart';
import 'package:video_gen/shared/themes/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    const fontDirectory = String.fromEnvironment('UPLOAD_PREVIEW_FONT_DIR');
    if (fontDirectory.isEmpty) return;
    final loader = FontLoader('Roboto');
    for (final weight in ['Regular', 'Medium', 'Bold']) {
      loader.addFont(
        File(
          '$fontDirectory/Roboto-$weight.ttf',
        ).readAsBytes().then(ByteData.sublistView),
      );
    }
    await loader.load();
    final iconLoader = FontLoader('MaterialIcons')
      ..addFont(
        File(
          '$fontDirectory/MaterialIcons-Regular.otf',
        ).readAsBytes().then(ByteData.sublistView),
      );
    await iconLoader.load();
  });
  for (final useTheme in [false, true]) {
    for (final width in [320.0, 393.0]) {
      testWidgets(
        '${useTheme ? 'Theme' : 'Image'} upload at $width: real progress, wait, failure, retry, success',
        (tester) async {
          _setPhoneSize(tester, width);
          final imagePath = File(
            'assets/images/create_video.png',
          ).absolute.path;
          final responses = [
            Completer<I2VGeneration>(),
            Completer<I2VGeneration>(),
          ];
          final callbacks = <void Function(int, int)>[];
          final repository = _MemoryProgressRepository();
          Future<I2VGeneration> submit(
            void Function(int, int)? onUploadProgress,
          ) {
            expect(onUploadProgress, isNotNull);
            callbacks.add(onUploadProgress!);
            return responses[callbacks.length - 1].future;
          }

          final Widget form = useTheme
              ? ThemeToVideoScreen(
                  theme: const VideoPost(
                    id: 'dance',
                    themeKey: 'dance',
                    thumbnailUrl: 'https://example.test/theme.jpg',
                    videoUrl: null,
                    description: 'Dance',
                  ),
                  requestPermission: (_) async =>
                      ImageAccessPermissionResult.granted,
                  pickImage: (_) async => imagePath,
                  progressRepository: repository,
                  submit:
                      ({
                        required themeId,
                        required firstImagePath,
                        required isHd,
                        required isLongTime,
                        onUploadProgress,
                      }) => submit(onUploadProgress),
                )
              : ImageToVideoScreen(
                  requestPermission: (_) async =>
                      ImageAccessPermissionResult.granted,
                  pickImageFromSource: (_) async => imagePath,
                  progressRepository: repository,
                  submit:
                      ({
                        required imagePath,
                        required prompt,
                        required isHd,
                        required isLongTime,
                        onUploadProgress,
                      }) => submit(onUploadProgress),
                );
          await tester.pumpWidget(
            RepaintBoundary(
              key: const Key('uploadPreviewBoundary'),
              child: ProviderScope(
                child: MaterialApp(
                  debugShowCheckedModeBanner: false,
                  theme: AppTheme.dark,
                  home: form,
                ),
              ),
            ),
          );
          if (const bool.fromEnvironment('CAPTURE_UPLOAD_PREVIEW')) {
            final context = tester.element(find.byType(form.runtimeType));
            await tester.runAsync(() async {
              await precacheImage(FileImage(File(imagePath)), context);
              if (!context.mounted) return;
              await precacheImage(
                ResizeImage(FileImage(File(imagePath)), width: 144),
                context,
              );
            });
          }
          await tester.tap(
            useTheme
                ? find.byKey(const Key('firstFrameCard'))
                : find.text('Select image'),
          );
          await tester.pumpAndSettle();
          await tester.tap(
            find.byKey(
              Key(useTheme ? 'galleryFrameSource' : 'galleryImageSource'),
            ),
          );
          await tester.pumpAndSettle();
          if (!useTheme) {
            await tester.enterText(
              find.byKey(const Key('imageToVideoPromptField')),
              'Gentle cinematic motion',
            );
          }
          await tester.ensureVisible(find.text('Generate'));
          await tester.pump();
          final generateButton = find.byKey(
            Key(useTheme ? 'generateThemeVideo' : 'generateImageVideo'),
          );
          final imageCard = find.byKey(
            Key(useTheme ? 'firstFrameCard' : 'imageToVideoImageCard'),
          );
          final buttonRect = tester.getRect(generateButton);
          final cardSize = tester.getSize(imageCard);
          final scrollRect = tester.getRect(find.byType(CustomScrollView));
          await tester.tap(find.text('Generate'));
          await _pumpFrames(tester);

          expect(find.byType(ImageUploadProgressOverlay), findsOneWidget);
          expect(find.text('Preparing image'), findsOneWidget);
          expect(tester.getRect(generateButton), buttonRect);
          expect(tester.getSize(imageCard), cardSize);
          expect(tester.getRect(find.byType(CustomScrollView)), scrollRect);
          expect(
            tester.widget<Scaffold>(find.byType(Scaffold)).bottomNavigationBar,
            isNull,
          );
          expect(find.text('Generate'), findsOneWidget);
          expect(tester.widget<InkWell>(generateButton).onTap, isNull);
          expect(
            find.descendant(
              of: generateButton,
              matching: find.byKey(const Key('generateVideoLoading')),
            ),
            findsOneWidget,
          );
          await tester.tap(generateButton);
          expect(
            callbacks,
            hasLength(1),
            reason: 'Do not submit twice while loading.',
          );
          expect(_progress(tester), isNull);
          callbacks.first(512 * 1024, 2 * 1024 * 1024);
          await _pumpFrames(tester);
          expect(find.text('25%'), findsOneWidget);
          expect(find.text('512 KB / 2.0 MB'), findsOneWidget);
          expect(_progress(tester), 0.25);
          await tester.pump(const Duration(seconds: 2));
          expect(
            _progress(tester),
            0.25,
            reason: 'Progress must not advance without upload events.',
          );

          await tester.drag(
            find.byType(CustomScrollView),
            const Offset(0, 600),
          );
          await _pumpFrames(tester);
          final overlay = find.byKey(const Key('imageUploadProgressOverlay'));
          final overlayRect = tester.getRect(overlay);
          final cardRect = tester.getRect(imageCard);
          expect(
            find.descendant(of: imageCard, matching: overlay),
            findsOneWidget,
          );
          expect(overlayRect.top, greaterThanOrEqualTo(cardRect.top));
          expect(overlayRect.bottom, lessThanOrEqualTo(cardRect.bottom));
          expect(overlayRect.left, greaterThanOrEqualTo(cardRect.left));
          expect(overlayRect.right, lessThanOrEqualTo(cardRect.right));
          expect(tester.getSize(imageCard), cardSize);
          expect(
            tester
                .widget<InkWell>(
                  find
                      .descendant(of: imageCard, matching: find.byType(InkWell))
                      .first,
                )
                .onTap,
            isNull,
          );
          if (!useTheme) {
            expect(
              tester
                  .widget<TextField>(
                    find.byKey(const Key('imageToVideoPromptField')),
                  )
                  .readOnly,
              isTrue,
            );
            expect(find.byKey(const Key('removeSelectedImage')), findsNothing);
          }
          await _capturePreview(
            tester,
            '${useTheme ? 'theme' : 'image'}-${width.toInt()}-upload',
          );
          callbacks.first(999, 1000);
          await _pumpFrames(tester);
          expect(find.text('99%'), findsOneWidget);
          expect(find.text('Submitting request'), findsNothing);
          callbacks.first(1000, 1000);
          await _pumpFrames(tester);
          expect(find.text('100%'), findsOneWidget);
          expect(find.text('Submitting request'), findsOneWidget);
          expect(find.text('Image uploaded'), findsOneWidget);
          expect(tester.widget<InkWell>(generateButton).onTap, isNull);
          expect(find.byKey(const Key('generateVideoLoading')), findsOneWidget);
          expect(find.byType(CreatingVideoScreen), findsNothing);
          await _capturePreview(
            tester,
            '${useTheme ? 'theme' : 'image'}-${width.toInt()}-submit',
          );

          responses.first.completeError(
            const ApiException(
              message: 'Upload failed. Please try again.',
              statusCode: 500,
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(ImageUploadProgressOverlay), findsNothing);
          expect(find.byKey(const Key('generateVideoLoading')), findsNothing);
          expect(tester.widget<InkWell>(generateButton).onTap, isNotNull);
          expect(find.byType(GenerationFailureDialog), findsOneWidget);
          await tester.tap(find.text('Try Again'));
          await _pumpFrames(tester);
          expect(callbacks, hasLength(2));
          expect(find.text('Preparing image'), findsOneWidget);
          callbacks.first(1000, 1000);
          await _pumpFrames(tester);
          expect(
            _progress(tester),
            isNull,
            reason: 'Ignore callbacks from the previous attempt.',
          );
          callbacks.last(500, 1000);
          await _pumpFrames(tester);
          expect(find.text('50%'), findsOneWidget);
          responses.last.complete(
            I2VGeneration.fromJson({
              'request_id': 'upload-progress-test',
              'status': 'IN_QUEUE',
              'create_time': DateTime.now().toIso8601String(),
              'remaining_credit': 65,
            }),
          );
          await _pumpFrames(tester);
          expect(find.byType(CreatingVideoScreen), findsOneWidget);
          expect(find.byType(ImageUploadProgressOverlay), findsNothing);
          await tester.pumpWidget(const SizedBox.shrink());
          callbacks.last(1000, 1000);
          await tester.pump();
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final sample in [
    (0, 0),
    (512, -1),
    (0, 2048),
    (2000, 1000),
    (-10, 1000),
  ]) {
    testWidgets('inline upload handles byte counts $sample and larger text', (
      tester,
    ) async {
      _setPhoneSize(tester, 320);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(1.4)),
            child: child!,
          ),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(20),
              child: AspectRatio(
                aspectRatio: 1.55,
                child: ImageUploadProgressOverlay(
                  sentBytes: sample.$1,
                  totalBytes: sample.$2,
                ),
              ),
            ),
          ),
        ),
      );
      await _pumpFrames(tester);
      expect(
        _progress(tester),
        sample.$2 <= 0 ? isNull : inInclusiveRange(0.0, 1.0),
      );
      expect(tester.takeException(), isNull);
    });
  }
}

double? _progress(WidgetTester tester) => tester
    .widget<LinearProgressIndicator>(
      find.byKey(const Key('imageUploadProgressBar')),
    )
    .value;

void _setPhoneSize(WidgetTester tester, double width) {
  tester.view.physicalSize = Size(width, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pumpFrames(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump();
}

// Opt-in visual QA; generated previews stay under the ignored build directory.
Future<void> _capturePreview(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('CAPTURE_UPLOAD_PREVIEW')) return;
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const Key('uploadPreviewBoundary')),
    );
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File(
      'build/upload-inline-$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

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

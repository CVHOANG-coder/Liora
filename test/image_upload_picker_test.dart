import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_gen/core/device/image_access_permission.dart';
import 'package:video_gen/core/network/api_exception.dart';
import 'package:video_gen/data/video_categories.dart';
import 'package:video_gen/presentation/screens/image_to_video/image_to_video_screen.dart';
import 'package:video_gen/presentation/screens/theme_to_video/theme_to_video_screen.dart';

void main() {
  const pickerChannel = MethodChannel('plugins.flutter.io/image_picker');
  const theme = VideoPost(
    id: 'mad_dance',
    themeKey: 'mad_dance',
    thumbnailUrl: null,
    videoUrl: null,
    description: 'Mad dance',
  );

  for (final isTheme in [false, true]) {
    for (final source in ImageSource.values) {
      testWidgets(
        '${isTheme ? 'Theme' : 'I2V'} ${source.name} requests q80/1920 and submits picker output',
        (tester) async {
          tester.view.physicalSize = const Size(393, 852);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          // Mock only the native boundary, not the form's picker callback, so
          // the real ImagePicker options and returned upload path are tested.
          final pickedPath = File(
            'assets/images/create_video.png',
          ).absolute.path;
          final calls = <MethodCall>[];
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            pickerChannel,
            (call) async {
              calls.add(call);
              return pickedPath;
            },
          );
          addTearDown(() {
            tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
              pickerChannel,
              null,
            );
          });

          String? submittedPath;
          await tester.pumpWidget(
            ProviderScope(
              child: MaterialApp(
                home: isTheme
                    ? ThemeToVideoScreen(
                        theme: theme,
                        requestPermission: (_) async =>
                            ImageAccessPermissionResult.granted,
                        submit:
                            ({
                              required themeId,
                              required firstImagePath,
                              required isHd,
                              required isLongTime,
                              onUploadProgress,
                            }) async {
                              submittedPath = firstImagePath;
                              throw const ApiException(
                                message: 'Stopped in test',
                              );
                            },
                      )
                    : ImageToVideoScreen(
                        requestPermission: (_) async =>
                            ImageAccessPermissionResult.granted,
                        submit:
                            ({
                              required imagePath,
                              required prompt,
                              required isHd,
                              required isLongTime,
                              onUploadProgress,
                            }) async {
                              submittedPath = imagePath;
                              throw const ApiException(
                                message: 'Stopped in test',
                              );
                            },
                      ),
              ),
            ),
          );

          await tester.tap(
            isTheme
                ? find.byKey(const Key('firstFrameCard'))
                : find.text('Select image'),
          );
          await tester.pumpAndSettle();
          await tester.tap(
            find.byKey(
              Key('${source.name}${isTheme ? 'Frame' : 'Image'}Source'),
            ),
          );
          await tester.pumpAndSettle();

          expect(calls, hasLength(1));
          expect(calls.single.method, 'pickImage');
          expect(calls.single.arguments, {
            'source': source.index,
            'maxWidth': 1920.0,
            'maxHeight': 1920.0,
            'imageQuality': 80,
            'cameraDevice': CameraDevice.rear.index,
            'requestFullMetadata': false,
          });

          if (!isTheme) {
            await tester.enterText(
              find.byKey(const Key('imageToVideoPromptField')),
              'A calm seaside',
            );
          }
          final generate = isTheme
              ? find.byKey(const Key('generateThemeVideo'))
              : find.text('Generate');
          await tester.ensureVisible(generate);
          await tester.tap(generate);
          await tester.pumpAndSettle();
          expect(submittedPath, pickedPath);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_gen/core/constants/app_colors.dart';
import 'package:video_gen/core/device/image_access_permission.dart';
import 'package:video_gen/core/network/api_exception.dart';
import 'package:video_gen/data/models/i2v_generation.dart';
import 'package:video_gen/data/models/user_profile.dart';
import 'package:video_gen/data/video_categories.dart';
import 'package:video_gen/presentation/providers/profile_provider.dart';
import 'package:video_gen/presentation/screens/image_to_video/image_to_video_screen.dart';
import 'package:video_gen/presentation/screens/in_app_purchase/all_plans_screen.dart';
import 'package:video_gen/presentation/screens/in_app_purchase/free_trial_screen.dart';
import 'package:video_gen/presentation/screens/in_app_purchase/in_app_purchase_screen.dart';
import 'package:video_gen/presentation/screens/text_to_video/text_to_video_screen.dart';
import 'package:video_gen/presentation/screens/theme_to_video/theme_to_video_screen.dart';
import 'package:video_gen/presentation/widgets/generation_failure_dialog.dart';
import 'package:video_gen/shared/themes/app_theme.dart';

enum _GenerationForm { image, text, theme }

void main() {
  const scenarios = [
    (isSubscribed: true, isVIP: true, destination: BuyCredits),
    (isSubscribed: true, isVIP: false, destination: BuyCredits),
    (isSubscribed: false, isVIP: true, destination: AllPlans),
    (isSubscribed: false, isVIP: false, destination: FreeTrialScreen),
  ];

  for (final form in _GenerationForm.values) {
    for (final scenario in scenarios) {
      for (final purchased in [false, true]) {
        testWidgets('${form.name}: immediately opens ${scenario.destination} '
            'for isSubscribed=${scenario.isSubscribed}, isVIP=${scenario.isVIP}; '
            'retries only after purchase=$purchased', (tester) async {
          tester.view.physicalSize = const Size(393, 852);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          final container = ProviderContainer();
          addTearDown(container.dispose);
          container
              .read(profileProvider.notifier)
              .setProfile(
                UserProfile.fromJson({
                  'isSubscribed': scenario.isSubscribed,
                  'isVIP': scenario.isVIP,
                }),
              );

          var submitCount = 0;
          final errorMessage = scenario.isSubscribed || scenario.isVIP
              ? 'Credit balance too low.'
              : '';
          Future<I2VGeneration> submit() async {
            submitCount += 1;
            if (submitCount == 1) {
              throw ApiException(
                message: errorMessage,
                errorCode: ApiErrorCode.insufficientCredit,
                statusCode: 400,
              );
            }
            // Stop the retry at a regular error so this test only exercises
            // form navigation, without starting background generation polls.
            throw const ApiException(
              message: 'Generation service unavailable.',
              statusCode: 500,
            );
          }

          final screen = _buildForm(form, submit);
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(theme: AppTheme.dark, home: screen),
            ),
          );
          await _prepareAndGenerate(tester, form);

          expect(submitCount, 1);
          expect(find.byType(GenerationFailureDialog), findsNothing);
          for (final destination in [BuyCredits, AllPlans, FreeTrialScreen]) {
            expect(
              find.byType(destination),
              destination == scenario.destination
                  ? findsOneWidget
                  : findsNothing,
            );
          }
          final destination = find.byType(scenario.destination);
          final toast = find.descendant(
            of: destination,
            matching: find.byType(SnackBar),
          );
          expect(toast, findsOneWidget);
          expect(
            tester.widget<SnackBar>(toast).behavior,
            SnackBarBehavior.floating,
          );
          final toastText = tester.widget<RichText>(
            find.descendant(of: toast, matching: find.byType(RichText)),
          );
          final toastMaterial = tester.widget<Material>(
            find.descendant(of: toast, matching: find.byType(Material)).first,
          );
          final textColor = toastText.text.style!.color!;
          final backgroundColor = toastMaterial.color!;
          expect(textColor, AppColors.textPrimary);
          expect(backgroundColor, AppColors.surfaceLight);
          expect(
            (textColor.computeLuminance() + 0.05) /
                (backgroundColor.computeLuminance() + 0.05),
            greaterThanOrEqualTo(7),
          );
          expect(
            find.descendant(
              of: toast,
              matching: find.text(
                errorMessage.isEmpty
                    ? 'Not enough credits to generate this video.'
                    : errorMessage,
              ),
            ),
            findsOneWidget,
          );
          expect(switch (tester.widget(destination)) {
            BuyCredits screen => screen.returnPurchaseResult,
            AllPlans screen => screen.returnPurchaseResult,
            FreeTrialScreen screen => screen.returnPurchaseResult,
            _ => false,
          }, isTrue);

          await tester.pump(const Duration(seconds: 4));
          await tester.pumpAndSettle();
          expect(find.byType(SnackBar), findsNothing);
          expect(destination, findsOneWidget);

          final navigator = Navigator.of(tester.element(destination));
          if (purchased) {
            navigator.pop(true);
          } else {
            navigator.pop();
          }
          await tester.pumpAndSettle();

          expect(find.byType(scenario.destination), findsNothing);
          expect(find.byType(screen.runtimeType), findsOneWidget);
          expect(submitCount, purchased ? 2 : 1);
          expect(
            find.byType(GenerationFailureDialog),
            purchased ? findsOneWidget : findsNothing,
          );
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}

Widget _buildForm(
  _GenerationForm form,
  Future<I2VGeneration> Function() submit,
) {
  final imagePath = File('assets/images/create_video.png').absolute.path;
  return switch (form) {
    _GenerationForm.image => ImageToVideoScreen(
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
    _GenerationForm.text => TextToVideoScreen(
      submit: ({required prompt, required isHd, required isLongTime}) =>
          submit(),
    ),
    _GenerationForm.theme => ThemeToVideoScreen(
      theme: const VideoPost(
        id: 'mad_dance',
        themeKey: 'mad_dance',
        thumbnailUrl: 'https://example.test/mad-dance.jpg',
        videoUrl: null,
        description: 'Mad dance',
      ),
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
}

Future<void> _prepareAndGenerate(
  WidgetTester tester,
  _GenerationForm form,
) async {
  switch (form) {
    case _GenerationForm.image:
      await tester.tap(find.text('Select image'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('galleryImageSource')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('imageToVideoPromptField')),
        'Gentle cinematic camera movement',
      );
    case _GenerationForm.text:
      await tester.enterText(
        find.byKey(const Key('textToVideoPromptField')),
        'A cinematic city at night',
      );
    case _GenerationForm.theme:
      await tester.tap(find.byKey(const Key('firstFrameCard')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('galleryFrameSource')));
      await tester.pumpAndSettle();
  }
  await tester.ensureVisible(find.text('Generate'));
  await tester.pump();
  await tester.tap(find.text('Generate'));
  await tester.pumpAndSettle();
}

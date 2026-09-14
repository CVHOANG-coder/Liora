import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_gen/core/constants/app_features.dart';
import 'package:video_gen/core/firebase/firebase_service.dart';
import 'package:video_gen/main.dart';
import 'package:video_gen/data/video_categories.dart';
import 'package:video_gen/presentation/providers/theme_provider.dart';
import 'package:video_gen/presentation/screens/home/home_screen.dart';
import 'package:video_gen/presentation/screens/image_to_video/image_to_video_screen.dart';
import 'package:video_gen/presentation/screens/in_app_purchase/free_trial_screen.dart';
import 'package:video_gen/presentation/screens/main/main_screen.dart';
import 'package:video_gen/presentation/screens/onboarding/onboarding_screen.dart';
import 'package:video_gen/presentation/screens/profile/profile_screen.dart';
import 'package:video_gen/presentation/screens/text_to_video/text_to_video_screen.dart';

void main() {
  testWidgets('requests notification permission when Home first opens', (
    tester,
  ) async {
    var permissionRequests = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          themeCategoriesProvider.overrideWith(
            (ref) async => const <VideoCategory>[],
          ),
        ],
        child: MaterialApp(
          home: MainScreen(
            showTrialOffer: false,
            notificationPermissionRequester: () async {
              permissionRequests += 1;
              return NotificationPermissionFlowResult.granted;
            },
          ),
        ),
      ),
    );
    await tester.pump();

    expect(permissionRequests, 1);
  });

  testWidgets('requests notification permission after the trial is closed', (
    tester,
  ) async {
    if (!AppFeatures.commerceEnabled) return;
    var permissionRequests = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          themeCategoriesProvider.overrideWith(
            (ref) async => const <VideoCategory>[],
          ),
        ],
        child: MaterialApp(
          home: MainScreen(
            notificationPermissionRequester: () async {
              permissionRequests += 1;
              return NotificationPermissionFlowResult.denied;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(FreeTrialScreen), findsOneWidget);
    expect(permissionRequests, 0);

    Navigator.of(tester.element(find.byType(FreeTrialScreen))).pop();
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(permissionRequests, 1);
  });

  testWidgets('Home avatar selects the Profile tab', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          themeCategoriesProvider.overrideWith(
            (ref) async => const <VideoCategory>[],
          ),
        ],
        child: MaterialApp(
          home: MainScreen(
            showTrialOffer: false,
            notificationPermissionRequester: () async =>
                NotificationPermissionFlowResult.granted,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('homeAvatarButton')));
    await tester.pumpAndSettle();

    final profileTicker = tester.widget<TickerMode>(
      find
          .ancestor(
            of: find.byType(ProfileScreen),
            matching: find.byType(TickerMode),
          )
          .first,
    );
    expect(profileTicker.enabled, isTrue);
    expect(find.byKey(const Key('profileTab')).hitTestable(), findsOneWidget);
    expect(find.byKey(const Key('homeTab')).hitTestable(), findsOneWidget);
  });

  testWidgets('navigates between home and profile', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          themeCategoriesProvider.overrideWith(
            (ref) async => const <VideoCategory>[],
          ),
        ],
        child: const VideoGenApp(home: OnboardingScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<MaterialApp>(find.byType(MaterialApp)).title, 'Liora');
    expect(find.text('Liora'), findsOneWidget);
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();
    expect(find.text('Create AI'), findsOneWidget);
    for (var page = 1; page < 4; page++) {
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
    }
    await _dismissInitialTrialOffer(tester);
    expect(find.text('Create AI short films'), findsOneWidget);
    expect(find.text('Me'), findsOneWidget);

    await tester.tap(find.byKey(const Key('profileTab')));
    await tester.pumpAndSettle();

    expect(find.text('Liora User'), findsOneWidget);
    expect(find.text('Profile unavailable'), findsOneWidget);
  });

  testWidgets('center add button opens Image to Video directly', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          themeCategoriesProvider.overrideWith(
            (ref) async => const <VideoCategory>[],
          ),
        ],
        child: const VideoGenApp(home: OnboardingScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();
    for (var page = 1; page < 4; page++) {
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
    }
    await _dismissInitialTrialOffer(tester);
    await tester.tap(find.byKey(const Key('createButton')));
    await tester.pumpAndSettle();

    expect(find.byType(ImageToVideoScreen), findsOneWidget);
  });

  testWidgets('center add button skips the creation mode sheet', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: MainScreen(showTrialOffer: false)),
      ),
    );

    await tester.tap(find.byKey(const Key('createButton')));
    await tester.pumpAndSettle();

    expect(find.byType(ImageToVideoScreen), findsOneWidget);
    expect(find.byKey(const Key('imageToVideoImageCard')), findsOneWidget);
  });

  testWidgets('Home Text to Video card opens the generation form', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          themeCategoriesProvider.overrideWith(
            (ref) async => const <VideoCategory>[],
          ),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('homeTextToVideoCard')));
    await tester.pumpAndSettle();

    expect(find.byType(TextToVideoScreen), findsOneWidget);
    expect(find.byKey(const Key('textToVideoPromptField')), findsOneWidget);
  });
}

Future<void> _dismissInitialTrialOffer(WidgetTester tester) async {
  if (!AppFeatures.commerceEnabled) return;
  expect(find.byType(FreeTrialScreen), findsOneWidget);
  Navigator.of(tester.element(find.byType(FreeTrialScreen))).pop();
  await tester.pumpAndSettle();
}

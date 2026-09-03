import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_gen/core/constants/app_features.dart';
import 'package:video_gen/core/storage/onboarding_preferences.dart';
import 'package:video_gen/data/video_categories.dart';
import 'package:video_gen/presentation/providers/theme_provider.dart';
import 'package:video_gen/presentation/screens/splash/splash_screen.dart';

void main() {
  testWidgets('shows splash branding and opens Home directly', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          themeCategoriesProvider.overrideWith(
            (ref) async => const <VideoCategory>[],
          ),
        ],
        child: const MaterialApp(
          home: SplashScreen(
            duration: Duration(milliseconds: 100),
            bootstrap: _successfulBootstrap,
          ),
        ),
      ),
    );

    expect(find.text('Liora'), findsOneWidget);
    expect(find.text('Create cinematic AI videos'), findsOneWidget);
    expect(find.text('Loading...'), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.text('Get Started'), findsNothing);
    expect(find.text('Create AI short films'), findsOneWidget);
    expect(find.text('Liora'), findsOneWidget);
  });

  testWidgets('stays on splash and retries when sign in fails', (tester) async {
    var shouldFail = true;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          themeCategoriesProvider.overrideWith(
            (ref) async => const <VideoCategory>[],
          ),
        ],
        child: MaterialApp(
          home: SplashScreen(
            duration: const Duration(milliseconds: 50),
            bootstrap: () async {
              if (shouldFail) throw Exception('offline');
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Unable to sign in. Please try again.'), findsOneWidget);
    expect(find.byKey(const Key('splashRetryButton')), findsOneWidget);

    shouldFail = false;
    await tester.tap(find.byKey(const Key('splashRetryButton')));
    await tester.pumpAndSettle();

    expect(find.text('Get Started'), findsNothing);
    expect(find.text('Create AI short films'), findsOneWidget);
  });

  testWidgets('disabled onboarding does not read onboarding preferences', (
    tester,
  ) async {
    final preferences = _DeferredOnboardingPreferences();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          themeCategoriesProvider.overrideWith(
            (ref) async => const <VideoCategory>[],
          ),
        ],
        child: MaterialApp(
          home: SplashScreen(
            duration: const Duration(milliseconds: 100),
            bootstrap: _successfulBootstrap,
            onboardingPreferences: preferences,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Get Started'), findsNothing);
    expect(find.text('Create AI short films'), findsOneWidget);
    expect(preferences.readCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'onboarding flow remains available behind the feature flag',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            themeCategoriesProvider.overrideWith(
              (ref) async => const <VideoCategory>[],
            ),
          ],
          child: MaterialApp(
            home: SplashScreen(
              duration: const Duration(milliseconds: 100),
              bootstrap: _successfulBootstrap,
              onboardingPreferences: _ImmediateOnboardingPreferences(false),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Get Started'), findsOneWidget);
      expect(find.text('Create AI short films'), findsNothing);
    },
    skip: !AppFeatures.onboardingEnabled,
  );
}

Future<void> _successfulBootstrap() async {}

class _DeferredOnboardingPreferences implements OnboardingPreferences {
  final result = Completer<bool>();
  int readCount = 0;

  @override
  Future<bool> isCompleted() {
    readCount += 1;
    return result.future;
  }

  @override
  Future<void> markCompleted() async {}
}

class _ImmediateOnboardingPreferences implements OnboardingPreferences {
  const _ImmediateOnboardingPreferences(this.completed);

  final bool completed;

  @override
  Future<bool> isCompleted() async => completed;

  @override
  Future<void> markCompleted() async {}
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_gen/core/storage/onboarding_preferences.dart';
import 'package:video_gen/presentation/screens/splash/splash_screen.dart';

void main() {
  testWidgets('shows splash branding and opens onboarding', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
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

    expect(find.text('Get Started'), findsOneWidget);
    expect(find.text('Liora'), findsOneWidget);
  });

  testWidgets('stays on splash and retries when sign in fails', (tester) async {
    var shouldFail = true;

    await tester.pumpWidget(
      ProviderScope(
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

    expect(find.text('Get Started'), findsOneWidget);
  });

  testWidgets('progress highlight reaches the end before leaving splash', (
    tester,
  ) async {
    final preferences = _DeferredOnboardingPreferences();
    await tester.pumpWidget(
      ProviderScope(
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

    final track = tester.getRect(find.byKey(const Key('splashProgressTrack')));
    final fill = tester.getRect(find.byKey(const Key('splashProgressFill')));
    final highlight = tester.getRect(
      find.byKey(const Key('splashProgressHighlight')),
    );
    expect(fill.width, closeTo(track.width, 0.01));
    expect(highlight.right, closeTo(track.right, 0.01));
    expect(find.text('Get Started'), findsNothing);
    expect(tester.takeException(), isNull);

    preferences.result.complete(false);
    await tester.pumpAndSettle();
    expect(find.text('Get Started'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _successfulBootstrap() async {}

class _DeferredOnboardingPreferences implements OnboardingPreferences {
  final result = Completer<bool>();

  @override
  Future<bool> isCompleted() => result.future;

  @override
  Future<void> markCompleted() async {}
}

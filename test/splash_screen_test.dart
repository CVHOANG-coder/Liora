import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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

    expect(find.text('Nostalia'), findsOneWidget);
    expect(find.text('Create cinematic AI videos'), findsOneWidget);
    expect(find.text('Loading...'), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.text('Get Started'), findsOneWidget);
    expect(find.text('Nostalia'), findsOneWidget);
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
}

Future<void> _successfulBootstrap() async {}

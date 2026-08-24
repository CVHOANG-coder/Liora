import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_gen/presentation/screens/generation_history/generation_history_screen.dart';
import 'package:video_gen/presentation/screens/profile/profile_screen.dart';

void main() {
  testWidgets('shows the app version from package metadata', (tester) async {
    tester.view.physicalSize = const Size(393, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appVersionProvider.overrideWith((ref) async => '1.0.0')],
        child: const MaterialApp(home: ProfileScreen()),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('profileAppVersion')), findsOneWidget);
    expect(find.text('V 1.0.0'), findsOneWidget);
  });

  testWidgets('profile keeps Video row and removes unused feature rows', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: ProfileScreen())),
    );
    await tester.pump();

    expect(find.text('AI Chat'), findsNothing);
    expect(find.text('Packs'), findsNothing);
    expect(find.text('Creations'), findsNothing);
    expect(find.byKey(const Key('videoHistoryRow')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('videoHistoryRow')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('videoHistoryRow')),
        matching: find.byType(InkWell),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(GenerationHistoryScreen), findsOneWidget);
    expect(find.text('Video History'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

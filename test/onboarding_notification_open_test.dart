import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_gen/data/video_categories.dart';
import 'package:video_gen/main.dart';
import 'package:video_gen/presentation/providers/theme_provider.dart';
import 'package:video_gen/presentation/screens/image_to_video/image_to_video_screen.dart';
import 'package:video_gen/presentation/screens/main/main_screen.dart';
import 'package:video_gen/presentation/screens/splash/splash_screen.dart';

void main() {
  testWidgets(
    'Open waits for startup, opens image-to-video, and supports warm taps',
    (tester) async {
      const channel = MethodChannel('liora/video_onboarding_activity');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        return call.method == 'listenForOpens' ? true : null;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      final bootstrap = Completer<void>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            themeCategoriesProvider.overrideWith(
              (ref) async => const <VideoCategory>[],
            ),
          ],
          child: VideoGenApp(
            home: SplashScreen(
              duration: const Duration(milliseconds: 50),
              bootstrap: () => bootstrap.future,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.byType(ImageToVideoScreen), findsNothing);

      bootstrap.complete();
      await tester.pumpAndSettle();
      expect(find.byType(ImageToVideoScreen), findsOneWidget);
      expect(find.byType(SplashScreen), findsNothing);
      Navigator.of(tester.element(find.byType(ImageToVideoScreen))).pop();
      await tester.pumpAndSettle();
      expect(find.byType(MainScreen), findsOneWidget);

      Future<void> tapOpen() async {
        tester.binding.channelBuffers.push(
          channel.name,
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall('openImageToVideo'),
          ),
          (_) {},
        );
        await tester.pumpAndSettle();
      }

      await tapOpen();
      expect(find.byType(ImageToVideoScreen), findsOneWidget);
      await tapOpen();
      expect(
        find.byType(ImageToVideoScreen, skipOffstage: false),
        findsOneWidget,
      );
      Navigator.of(tester.element(find.byType(ImageToVideoScreen))).pop();
      await tester.pumpAndSettle();
      expect(find.byType(MainScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

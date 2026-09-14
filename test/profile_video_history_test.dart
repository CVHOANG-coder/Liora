import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_gen/data/models/generation_history.dart';
import 'package:video_gen/data/models/i2v_request_status.dart';
import 'package:video_gen/presentation/screens/generation_history/generation_history_screen.dart';
import 'package:video_gen/presentation/screens/image_to_video/image_to_video_screen.dart';
import 'package:video_gen/presentation/screens/profile/profile_screen.dart';

void main() {
  testWidgets('shows generated videos inline and hides the app version', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileVideoHistoryProvider.overrideWith(
            (ref) async => GenerationHistoryPage(
              requests: [
                I2VRequestStatus.fromJson({
                  'request_id': 'profile-video-1',
                  'request_status': 'COMPLETED',
                  'prompt': 'A cinematic mountain sunrise',
                  'result_data': 'https://example.com/video.mp4',
                  'image_url': 'https://example.com/preview.jpg',
                }),
              ],
              pagination: const GenerationHistoryPagination(
                page: 1,
                limit: 6,
                total: 1,
                totalPages: 1,
              ),
            ),
          ),
        ],
        child: const MaterialApp(home: ProfileScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('profileVideo_profile-video-1')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('A cinematic mountain sunrise'), findsOneWidget);
    expect(find.byKey(const Key('profileAppVersion')), findsNothing);
  });

  testWidgets('View all opens the complete video history', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileVideoHistoryProvider.overrideWith(
            (ref) async => const GenerationHistoryPage(
              requests: [],
              pagination: GenerationHistoryPagination(
                page: 1,
                limit: 6,
                total: 0,
                totalPages: 1,
              ),
            ),
          ),
        ],
        child: const MaterialApp(home: ProfileScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const Key('createImageVideoFromProfile')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('emptyProfileVideoIcon')), findsOneWidget);
    expect(find.text('Create video from image'), findsOneWidget);

    await tester.tap(find.byKey(const Key('createImageVideoFromProfile')));
    await tester.pumpAndSettle();
    expect(find.byType(ImageToVideoScreen), findsOneWidget);

    Navigator.of(tester.element(find.byType(ImageToVideoScreen))).pop();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('viewAllProfileVideos')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('viewAllProfileVideos')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(GenerationHistoryScreen), findsOneWidget);
    expect(find.text('Video History'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

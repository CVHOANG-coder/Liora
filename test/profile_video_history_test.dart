import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_gen/core/events/video_generation_events.dart';
import 'package:video_gen/data/models/generation_history.dart';
import 'package:video_gen/data/models/i2v_request_status.dart';
import 'package:video_gen/presentation/screens/image_to_video/generated_video_screen.dart';
import 'package:video_gen/presentation/screens/image_to_video/image_to_video_screen.dart';
import 'package:video_gen/presentation/screens/profile/profile_screen.dart';
import 'package:video_gen/presentation/widgets/cached_video_thumbnail.dart';

void main() {
  testWidgets('long press selects videos and confirms batch deletion', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final deletedIds = <String>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileVideoHistoryProvider.overrideWith(
            (ref) async => GenerationHistoryPage(
              requests: [
                for (var index = 1; index <= 3; index++)
                  I2VRequestStatus.fromJson({
                    'request_id': 'select-video-$index',
                    'request_status': 'COMPLETED',
                    'result_data': 'https://example.com/video-$index.mp4',
                  }),
              ],
              pagination: const GenerationHistoryPagination(
                page: 1,
                limit: 10,
                total: 3,
                totalPages: 1,
              ),
            ),
          ),
          profileVideoDeleterProvider.overrideWith(
            (ref) =>
                (requestId) async => deletedIds.add(requestId),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: ProfileScreen())),
      ),
    );
    await tester.pumpAndSettle();
    final first = find.byKey(const Key('profileVideo_select-video-1'));
    final second = find.byKey(const Key('profileVideo_select-video-2'));
    await tester.scrollUntilVisible(
      first,
      200,
      scrollable: find.byType(Scrollable).first,
    );

    await tester.longPress(first);
    await tester.pump();
    expect(find.text('1 selected'), findsOneWidget);
    final selectedCenter = tester.getCenter(find.text('1 selected')).dy;
    expect(
      selectedCenter,
      closeTo(
        tester
            .getCenter(find.byKey(const Key('cancelProfileVideoSelection')))
            .dy,
        1,
      ),
    );
    expect(
      selectedCenter,
      closeTo(
        tester
            .getCenter(find.byKey(const Key('profileDeleteSelectedButton')))
            .dy,
        1,
      ),
    );
    expect(find.byKey(const Key('profileSettingsButton')), findsNothing);
    expect(
      find.byKey(const Key('profileDeleteSelectedButton')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('profileVideoSelection_select-video-1')),
      findsOneWidget,
    );

    await tester.tap(second);
    await tester.pump();
    expect(find.text('2 selected'), findsOneWidget);
    await tester.tap(second);
    await tester.pump();
    expect(find.text('1 selected'), findsOneWidget);
    await tester.tap(second);
    await tester.pump();
    expect(find.text('2 selected'), findsOneWidget);
    await tester.tap(find.byKey(const Key('profileDeleteSelectedButton')));
    await tester.pumpAndSettle();
    expect(find.text('Delete 2 videos?'), findsOneWidget);
    expect(deletedIds, isEmpty);

    await tester.tap(
      find.byKey(const Key('cancelDeleteSelectedProfileVideos')),
    );
    await tester.pumpAndSettle();
    expect(deletedIds, isEmpty);
    expect(find.text('2 selected'), findsOneWidget);

    await tester.tap(find.byKey(const Key('cancelProfileVideoSelection')));
    await tester.pump();
    expect(find.byKey(const Key('profileSettingsButton')), findsOneWidget);
    await tester.longPress(first);
    await tester.pump();
    await tester.tap(second);
    await tester.pump();

    await tester.tap(find.byKey(const Key('profileDeleteSelectedButton')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('confirmDeleteSelectedProfileVideos')),
    );
    await tester.pumpAndSettle();
    expect(deletedIds, ['select-video-1', 'select-video-2']);
    expect(find.byKey(const Key('profileVideo_select-video-1')), findsNothing);
    expect(find.byKey(const Key('profileVideo_select-video-2')), findsNothing);
    expect(
      find.byKey(const Key('profileVideo_select-video-3')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('profileSettingsButton')), findsOneWidget);
  });

  testWidgets('failed deletions stay selected for retry', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
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
                for (var index = 1; index <= 2; index++)
                  I2VRequestStatus.fromJson({
                    'request_id': 'retry-video-$index',
                    'request_status': 'COMPLETED',
                    'result_data': 'https://example.com/video-$index.mp4',
                  }),
              ],
              pagination: const GenerationHistoryPagination(
                page: 1,
                limit: 10,
                total: 2,
                totalPages: 1,
              ),
            ),
          ),
          profileVideoDeleterProvider.overrideWith(
            (ref) => (requestId) async {
              if (requestId == 'retry-video-2') {
                throw Exception('Delete failed');
              }
            },
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: ProfileScreen())),
      ),
    );
    await tester.pumpAndSettle();
    final first = find.byKey(const Key('profileVideo_retry-video-1'));
    final second = find.byKey(const Key('profileVideo_retry-video-2'));
    await tester.scrollUntilVisible(
      first,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.longPress(first);
    await tester.pump();
    await tester.tap(second);
    await tester.pump();
    await tester.tap(find.byKey(const Key('profileDeleteSelectedButton')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('confirmDeleteSelectedProfileVideos')),
    );
    await tester.pumpAndSettle();

    expect(first, findsNothing);
    expect(second, findsOneWidget);
    expect(find.text('1 selected'), findsOneWidget);
    expect(
      find.byKey(const Key('profileDeleteSelectedButton')),
      findsOneWidget,
    );
  });

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
                I2VRequestStatus.fromJson({
                  'request_id': 'profile-video-2',
                  'request_status': 'COMPLETED',
                  'prompt': 'A city at night',
                  'result_data': 'https://example.com/video-2.mp4',
                }),
                I2VRequestStatus.fromJson({
                  'request_id': 'profile-video-3',
                  'request_status': 'IN_QUEUE',
                  'prompt': 'Ocean waves',
                }),
              ],
              pagination: const GenerationHistoryPagination(
                page: 1,
                limit: 6,
                total: 3,
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
    expect(find.text('A cinematic mountain sunrise'), findsNothing);
    expect(find.text('Ocean waves'), findsNothing);
    expect(find.text('IN QUEUE'), findsNothing);
    expect(find.byKey(const Key('profileAppVersion')), findsNothing);

    final grid = tester.widget<SliverGrid>(
      find.byKey(const Key('profileVideoGrid')),
    );
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, 3);
    expect(delegate.childAspectRatio, 9 / 16);

    final cards = [
      for (var index = 1; index <= 3; index++)
        tester.getRect(find.byKey(Key('profileVideo_profile-video-$index'))),
    ];
    expect(cards[0].left, closeTo(14, 0.1));
    expect(cards[1].left - cards[0].right, greaterThan(0));
    expect(cards[2].left - cards[1].right, greaterThan(0));
    expect(393 - cards[2].right, closeTo(14, 0.1));
    expect(cards[0].height / cards[0].width, closeTo(16 / 9, 0.01));
    final cardMaterial = tester.widget<Material>(
      find
          .ancestor(
            of: find.byKey(const Key('profileVideo_profile-video-1')),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(cardMaterial.borderRadius, BorderRadius.circular(12));
    final thumbnail = tester.widget<CachedVideoThumbnail>(
      find.descendant(
        of: find.byKey(const Key('profileVideo_profile-video-1')),
        matching: find.byType(CachedVideoThumbnail),
      ),
    );
    expect(thumbnail.preferVideoFrame, isTrue);
    expect(thumbnail.frameTimeMs, 0);
    expect(thumbnail.maxDecodeWidth, 360);
    expect(thumbnail.videoUrl, 'https://example.com/video.mp4');
  });

  testWidgets('opens a video directly from the Profile history', (
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
                  'request_id': 'profile-direct-video',
                  'request_status': 'COMPLETED',
                  'prompt': 'A mountain sunrise',
                  'result_data': 'https://example.com/video.mp4',
                }),
              ],
              pagination: const GenerationHistoryPagination(
                page: 1,
                limit: 10,
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

    final video = find.byKey(const Key('profileVideo_profile-direct-video'));
    await tester.scrollUntilVisible(
      video,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(video);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(GeneratedVideoScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('shows history directly without a View all link', (tester) async {
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
    expect(find.text('Create Video Now'), findsOneWidget);
    expect(find.byKey(const Key('viewAllProfileVideos')), findsNothing);

    await tester.tap(find.byKey(const Key('createImageVideoFromProfile')));
    await tester.pumpAndSettle();
    expect(find.byType(ImageToVideoScreen), findsOneWidget);

    Navigator.of(tester.element(find.byType(ImageToVideoScreen))).pop();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('viewAllProfileVideos')), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('loads further history pages in the Profile list', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    I2VRequestStatus video(int index) => I2VRequestStatus.fromJson({
      'request_id': 'profile-video-$index',
      'request_status': 'COMPLETED',
      'prompt': 'Generated video $index',
      'result_data': 'https://example.com/video-$index.mp4',
    });

    var nextPageLoads = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileVideoHistoryProvider.overrideWith(
            (ref) async => GenerationHistoryPage(
              requests: [for (var i = 1; i <= 4; i++) video(i)],
              pagination: const GenerationHistoryPagination(
                page: 1,
                limit: 10,
                total: 6,
                totalPages: 2,
              ),
            ),
          ),
          profileHistoryPageFetcherProvider.overrideWith(
            (ref) => ({required page, required limit}) async {
              nextPageLoads++;
              expect(page, 2);
              expect(limit, 10);
              return GenerationHistoryPage(
                requests: [video(5), video(6)],
                pagination: const GenerationHistoryPagination(
                  page: 2,
                  limit: 10,
                  total: 6,
                  totalPages: 2,
                ),
              );
            },
          ),
        ],
        child: const MaterialApp(home: ProfileScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const PageStorageKey('profileScroll')),
      const Offset(0, -700),
    );
    await tester.pumpAndSettle();

    expect(nextPageLoads, 1);
    expect(find.byKey(const Key('viewAllProfileVideos')), findsNothing);
    await tester.scrollUntilVisible(
      find.byKey(const Key('profileVideo_profile-video-6')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Generated video 6'), findsNothing);
    expect(
      find.byKey(const Key('profileVideo_profile-video-6')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('reloads videos when another flow reports generation success', (
    tester,
  ) async {
    var loadCount = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileVideoHistoryProvider.overrideWith((ref) async {
            loadCount += 1;
            return GenerationHistoryPage(
              requests: [
                I2VRequestStatus.fromJson({
                  'request_id': 'profile-video-$loadCount',
                  'request_status': 'COMPLETED',
                  'prompt': 'Generated video $loadCount',
                  'result_data': 'https://example.com/video-$loadCount.mp4',
                }),
              ],
              pagination: const GenerationHistoryPagination(
                page: 1,
                limit: 6,
                total: 1,
                totalPages: 1,
              ),
            );
          }),
        ],
        child: const MaterialApp(home: ProfileScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(loadCount, 1);

    VideoGenerationEvents.notifySuccess('request-from-another-screen');
    await tester.pumpAndSettle();

    expect(loadCount, 2);
    expect(find.text('Generated video 2'), findsNothing);
    expect(
      find.byKey(const Key('profileVideo_profile-video-2')),
      findsOneWidget,
    );
  });

  testWidgets('pulling down refreshes profile video history', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var loadCount = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileVideoHistoryProvider.overrideWith((ref) async {
            loadCount += 1;
            return const GenerationHistoryPage(
              requests: [],
              pagination: GenerationHistoryPagination(
                page: 1,
                limit: 6,
                total: 0,
                totalPages: 1,
              ),
            );
          }),
        ],
        child: const MaterialApp(home: ProfileScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(loadCount, 1);
    expect(find.text('History videos'), findsNothing);
    expect(find.byKey(const Key('refreshProfileVideos')), findsNothing);

    await tester.drag(
      find.byKey(const PageStorageKey('profileScroll')),
      const Offset(0, 400),
    );
    await tester.pumpAndSettle();

    expect(loadCount, 2);
    expect(find.byKey(const Key('emptyProfileVideos')), findsOneWidget);
  });
}

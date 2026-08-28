import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_gen/core/firebase/firebase_service.dart';
import 'package:video_gen/data/models/generation_history.dart';
import 'package:video_gen/data/models/generation_progress.dart';
import 'package:video_gen/data/models/i2v_generation.dart';
import 'package:video_gen/data/models/i2v_request_status.dart';
import 'package:video_gen/data/video_categories.dart';
import 'package:video_gen/presentation/providers/theme_provider.dart';
import 'package:video_gen/presentation/screens/generation_history/generation_history_screen.dart';
import 'package:video_gen/presentation/screens/home/home_screen.dart';
import 'package:video_gen/presentation/screens/image_to_video/creating_video_screen.dart';
import 'package:video_gen/presentation/screens/in_app_purchase/free_trial_screen.dart';
import 'package:video_gen/shared/themes/app_theme.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final size in [const Size(320, 568), const Size(393, 852)]) {
    testWidgets('Home header stays fixed and interactive at $size', (
      tester,
    ) async {
      _configurePhone(tester, size);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            themeCategoriesProvider.overrideWith(
              (_) async => List.generate(
                6,
                (index) => VideoCategory(
                  id: 'category-$index',
                  title: 'Category $index',
                  posts: const [],
                ),
              ),
            ),
          ],
          child: MaterialApp(theme: AppTheme.dark, home: const HomeScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await _checkFixedHeader(
        tester,
        headerKey: 'homeHeader',
        scrollKey: 'homeScroll',
        actionKey: 'homeProButton',
      );
      await tester.tap(find.byKey(const Key('homeProButton')));
      await tester.pumpAndSettle();
      expect(find.byType(FreeTrialScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('History header stays fixed and refresh works at $size', (
      tester,
    ) async {
      _configurePhone(tester, size);
      var fetchCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: GenerationHistoryScreen(
            fetcher: ({required page, required limit}) async {
              fetchCount++;
              return GenerationHistoryPage(
                requests: List.generate(
                  24,
                  (index) => I2VRequestStatus.fromJson({
                    'request_id': 'history-$index',
                    'request_status': 'PENDING',
                    'prompt': 'Video $index',
                  }),
                ),
                pagination: const GenerationHistoryPagination(
                  page: 1,
                  limit: 24,
                  total: 24,
                  totalPages: 1,
                ),
              );
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await _checkFixedHeader(
        tester,
        headerKey: 'generationHistoryHeader',
        scrollKey: 'generationHistoryScroll',
        actionKey: 'generationHistoryBack',
      );
      await tester.tap(find.byTooltip('Refresh videos'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(fetchCount, 2);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets(
      'Creating header stays fixed and Back still confirms at $size',
      (tester) async {
        _configurePhone(tester, size);
        final generation = I2VGenerationResponse.fromJson({
          'success': true,
          'data': {
            'request_id': 'fixed-header-request',
            'status': 'IN_QUEUE',
            'params': <String, dynamic>{},
          },
        }).data;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.dark,
            home: CreatingVideoScreen(
              generation: generation,
              initialProgress: GenerationProgress.create(
                requestId: generation.requestId,
                startedAt: DateTime.now(),
                videoDurationSeconds: 5,
                isHd: false,
              ),
              notificationPermissionRequester: () async =>
                  NotificationPermissionFlowResult.granted,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await _checkFixedHeader(
          tester,
          headerKey: 'creatingVideoHeader',
          scrollKey: 'creatingVideoScroll',
          actionKey: 'creatingVideoBack',
        );
        await tester.tap(find.byKey(const Key('creatingVideoBack')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(
          find.byKey(const Key('leaveCreatingVideoDialog')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('keepWaitingForVideo')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(CreatingVideoScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}

void _configurePhone(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.view.padding = const FakeViewPadding(top: 44, bottom: 34);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetPadding);
}

Future<void> _checkFixedHeader(
  WidgetTester tester, {
  required String headerKey,
  required String scrollKey,
  required String actionKey,
}) async {
  final header = find.byKey(Key(headerKey));
  final scroll = find.byKey(PageStorageKey<String>(scrollKey));
  final action = find.byKey(Key(actionKey));
  final headerRect = tester.getRect(header);
  final actionRect = tester.getRect(action);
  final scrollable = tester.state<ScrollableState>(
    find.descendant(of: scroll, matching: find.byType(Scrollable)).first,
  );

  expect(
    find.ancestor(of: header, matching: find.byType(Scrollable)),
    findsNothing,
  );
  expect(actionRect.top, greaterThanOrEqualTo(44));
  expect(tester.getTopLeft(scroll).dy, greaterThanOrEqualTo(headerRect.bottom));

  await tester.drag(scroll, const Offset(0, -350));
  await tester.pump(const Duration(milliseconds: 600));
  expect(scrollable.position.pixels, greaterThan(0));
  expect(tester.getRect(header), headerRect);
  expect(tester.getRect(action), actionRect);
  expect(action.hitTestable(), findsOneWidget);

  scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
  await tester.pump(const Duration(milliseconds: 300));
  expect(tester.getRect(header), headerRect);
  expect(action.hitTestable(), findsOneWidget);
  expect(tester.takeException(), isNull);
}

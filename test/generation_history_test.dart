import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_gen/data/models/generation_history.dart';
import 'package:video_gen/data/models/generation_progress.dart';
import 'package:video_gen/data/models/i2v_request_status.dart';
import 'package:video_gen/data/services/generation_progress_repository.dart';
import 'package:video_gen/presentation/screens/generation_history/generation_history_screen.dart';
import 'package:video_gen/presentation/screens/image_to_video/creating_video_screen.dart';
import 'package:video_gen/presentation/screens/image_to_video/generated_video_screen.dart';

void main() {
  test('parses generation history and pagination', () {
    final page = GenerationHistoryPage.fromJson(
      _response(
        page: 1,
        totalPages: 3,
        requests: <Map<String, dynamic>>[_request('completed-1', 'COMPLETED')],
      ),
    );

    expect(page.requests, hasLength(1));
    expect(page.requests.single.requestId, 'completed-1');
    expect(page.requests.single.isCompleted, isTrue);
    expect(page.requests.single.resultUrl, endsWith('completed-1.mp4'));
    expect(page.pagination.page, 1);
    expect(page.pagination.totalPages, 3);
    expect(page.pagination.hasMore, isTrue);
  });

  testWidgets('loads more pages and pull-to-refresh reloads page one', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fetchedPages = <int>[];

    Future<GenerationHistoryPage> fetch({
      required int page,
      required int limit,
    }) async {
      fetchedPages.add(page);
      final start = (page - 1) * limit;
      final count = page == 1 ? limit : 2;
      return GenerationHistoryPage.fromJson(
        _response(
          page: page,
          totalPages: 2,
          requests: List<Map<String, dynamic>>.generate(
            count,
            (index) => _request('request-${start + index}', 'COMPLETED'),
          ),
        ),
      );
    }

    await tester.pumpWidget(
      MaterialApp(home: GenerationHistoryScreen(fetcher: fetch)),
    );
    await tester.pumpAndSettle();

    expect(fetchedPages, <int>[1]);
    expect(find.byKey(const ValueKey<String>('request-0')), findsOneWidget);
    expect(find.byType(SliverGrid), findsOneWidget);
    expect(find.text('My videos'), findsOneWidget);
    expect(find.text('20 videos'), findsOneWidget);

    final firstTile = find.byKey(const ValueKey<String>('request-0'));
    final secondTile = find.byKey(const ValueKey<String>('request-1'));
    final fourthTile = find.byKey(const ValueKey<String>('request-3'));
    final tileSize = tester.getSize(firstTile);
    expect(tileSize.width / tileSize.height, closeTo(9 / 16, 0.01));
    expect(tester.getTopLeft(secondTile).dy, tester.getTopLeft(firstTile).dy);
    expect(
      tester.getTopLeft(fourthTile).dy,
      greaterThan(tester.getTopLeft(firstTile).dy),
    );

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1200));
    await tester.pumpAndSettle();

    expect(fetchedPages, contains(2));
    expect(find.byKey(const ValueKey<String>('request-11')), findsOneWidget);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, 1800));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 320));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(fetchedPages.where((page) => page == 1).length, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens queued history item in the polling screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GenerationHistoryScreen(
          progressRepository: _MemoryProgressRepository(),
          fetcher: ({required page, required limit}) async =>
              GenerationHistoryPage.fromJson(
                _response(
                  page: 1,
                  totalPages: 1,
                  requests: <Map<String, dynamic>>[
                    _request('queued-1', 'IN_QUEUE'),
                  ],
                ),
              ),
          statusFetcher: (_) async =>
              I2VRequestStatus.fromJson(_request('queued-1', 'IN_QUEUE')),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.byKey(const Key('openHistoryRequest_queued-1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(CreatingVideoScreen), findsOneWidget);
    expect(find.text('Creating Video'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('opens completed history item in the video player', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GenerationHistoryScreen(
          fetcher: ({required page, required limit}) async =>
              GenerationHistoryPage.fromJson(
                _response(
                  page: 1,
                  totalPages: 1,
                  requests: <Map<String, dynamic>>[
                    _request('completed-1', 'COMPLETED'),
                  ],
                ),
              ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('openHistoryRequest_completed-1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(GeneratedVideoScreen), findsOneWidget);
    expect(find.text('Your Video'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('confirms deletion then removes and refreshes history', (
    tester,
  ) async {
    var deleted = false;
    String? deletedRequestId;
    final progressRepository = _MemoryProgressRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: GenerationHistoryScreen(
          progressRepository: progressRepository,
          fetcher: ({required page, required limit}) async =>
              GenerationHistoryPage.fromJson(
                _response(
                  page: 1,
                  totalPages: 1,
                  requests: deleted
                      ? <Map<String, dynamic>>[]
                      : <Map<String, dynamic>>[
                          _request('delete-me', 'COMPLETED'),
                        ],
                ),
              ),
          deleter: (requestId) async {
            deletedRequestId = requestId;
            deleted = true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('deleteHistoryRequest_delete-me')));
    await tester.pumpAndSettle();

    expect(find.text('Delete video?'), findsOneWidget);
    expect(find.textContaining('permanently removed'), findsOneWidget);
    expect(deletedRequestId, isNull);

    await tester.tap(find.byKey(const Key('confirmDeleteHistoryRequest')));
    await tester.pumpAndSettle();

    expect(deletedRequestId, 'delete-me');
    expect(find.byKey(const ValueKey<String>('delete-me')), findsNothing);
    expect(find.text('Video removed from history.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Map<String, dynamic> _response({
  required int page,
  required int totalPages,
  required List<Map<String, dynamic>> requests,
}) {
  return <String, dynamic>{
    'success': true,
    'message': 'success',
    'data': <String, dynamic>{
      'requests': requests,
      'pagination': <String, dynamic>{
        'page': page,
        'limit': 10,
        'total': totalPages * 10,
        'total_pages': totalPages,
      },
    },
  };
}

Map<String, dynamic> _request(String id, String status) {
  return <String, dynamic>{
    'request_id': id,
    'service_type': 'I2V_GENERATOR',
    'prompt': 'A calm seaside at golden hour',
    'image_url': '',
    'image2_url': '',
    'is_hd': false,
    'is_long_time': false,
    'duration': 5,
    'request_status': status,
    'result_data': 'https://example.test/$id.mp4',
    'thumbnail_url': '',
    'error_message': '',
    'create_time': '2026-08-23T16:25:36.592Z',
    'completed_time': '2026-08-23T16:26:37.824Z',
  };
}

class _MemoryProgressRepository implements GenerationProgressRepository {
  final Map<String, GenerationProgress> values = <String, GenerationProgress>{};

  @override
  Future<GenerationProgress?> load(String requestId) async => values[requestId];

  @override
  Future<void> save(GenerationProgress progress) async {
    values[progress.requestId] = progress;
  }

  @override
  Future<void> remove(String requestId) async {
    values.remove(requestId);
  }

  @override
  Future<void> updateStep(String requestId, int stepIndex) async {
    final progress = values[requestId];
    if (progress != null) {
      values[requestId] = progress.copyWith(savedStepIndex: stepIndex);
    }
  }
}

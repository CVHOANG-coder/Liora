import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_gen/core/events/video_generation_events.dart';
import 'package:video_gen/core/notifications/video_onboarding_service.dart';
import 'package:video_gen/data/models/generation_history.dart';
import 'package:video_gen/data/models/i2v_request_status.dart';
import 'package:video_gen/data/services/generation_history_service.dart';
import 'package:video_onboarding_activity/video_onboarding_activity.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('liora/video_onboarding_activity');
  final calls = <MethodCall>[];
  var count = 0;

  setUp(() {
    calls.clear();
    count = 0;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return call.method == 'completedCount' ? count : null;
        });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'normalizes IDs and sends a single batch for native deduplication',
    () async {
      await VideoOnboardingActivity.recordCompleted([
        ' one ',
        'one',
        '',
        'two',
      ]);
      expect(calls.single.method, 'recordCompleted');
      expect(calls.single.arguments, {
        'requestIds': ['one', 'two'],
      });
    },
  );

  test(
    'success events update onboarding alongside existing subscribers',
    () async {
      final received = <String>[];
      final subscription = VideoGenerationEvents.successes.listen(received.add);
      VideoGenerationEvents.notifySuccess(' ready-video ');
      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();
      expect(received, ['ready-video']);
      expect(calls.single.arguments, {
        'requestIds': ['ready-video'],
      });
    },
  );

  test(
    'restores completed videos across pages and excludes failures',
    () async {
      final history = _History([
        [_request('done-1', 'COMPLETED'), _request('failed', 'FAILED')],
        [_request('done-2', 'COMPLETED'), _request('pending', 'PENDING')],
        [_request('done-3', 'COMPLETED')],
        [_request('older', 'COMPLETED')],
      ]);
      await VideoOnboardingService.refresh(() => history);
      expect(history.pagesFetched, [1, 2, 3]);
      expect(calls.map((call) => call.method), [
        'completedCount',
        'recordCompleted',
        'refresh',
      ]);
      expect(calls[1].arguments, {
        'requestIds': ['done-1', 'done-2', 'done-3'],
      });
    },
  );

  test('completed onboarding cancels without fetching history again', () async {
    count = 3;
    final history = _History([]);
    await VideoOnboardingService.refresh(() => history);
    expect(history.pagesFetched, isEmpty);
    expect(calls.map((call) => call.method), ['completedCount', 'refresh']);
  });

  test('offline launch still refreshes from persisted progress', () async {
    await VideoOnboardingService.refresh(() => _History([]));
    expect(calls.map((call) => call.method), ['completedCount', 'refresh']);
  });

  test('iOS never posts or reads Android onboarding notifications', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final history = _History([]);
    await VideoOnboardingActivity.refresh();
    await VideoOnboardingActivity.recordCompleted(['one']);
    await VideoOnboardingService.refresh(() => history);
    expect(calls, isEmpty);
    expect(history.pagesFetched, isEmpty);
  });
}

class _History extends GenerationHistoryService {
  _History(this.pages) : super(Dio());
  final List<List<I2VRequestStatus>> pages;
  final List<int> pagesFetched = [];

  @override
  Future<GenerationHistoryPage> fetch({
    required int page,
    int limit = 10,
  }) async {
    pagesFetched.add(page);
    if (pages.isEmpty) throw Exception('offline');
    return GenerationHistoryPage(
      requests: pages[page - 1],
      pagination: GenerationHistoryPagination(
        page: page,
        limit: limit,
        total: 10,
        totalPages: pages.length,
      ),
    );
  }
}

I2VRequestStatus _request(String id, String status) =>
    I2VRequestStatus.fromJson({
      'request_id': id,
      'service_type': 'I2V_GENERATOR',
      'request_status': status,
      'result_data': '',
      'duration': 5,
    });

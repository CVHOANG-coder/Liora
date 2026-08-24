import 'package:flutter_test/flutter_test.dart';
import 'package:video_gen/core/firebase/firebase_service.dart';

void main() {
  test('builds the Firebase topic from user_code', () {
    expect(firebaseUserTopicFor('USER001'), 'user_USER001');
    expect(firebaseUserTopicFor('  abc-123  '), 'user_abc-123');
  });

  test('rejects missing or invalid user_code values', () {
    expect(firebaseUserTopicFor(''), isNull);
    expect(firebaseUserTopicFor('contains spaces'), isNull);
    expect(firebaseUserTopicFor('contains/slash'), isNull);
  });

  test('parses generated-video notification navigation data', () {
    final notification = VideoNotificationOpen.fromData(<String, dynamic>{
      'type': 'video_generated',
      'request_id': '8f3c2a1e-request',
      'status': 'COMPLETED',
      'result_url': 'https://example.test/video.mp4',
    });

    expect(notification.type, 'video_generated');
    expect(notification.requestId, '8f3c2a1e-request');
    expect(notification.status, 'COMPLETED');
    expect(notification.resultUrl, endsWith('video.mp4'));
  });

  test('defaults failed-video status and rejects unrelated notifications', () {
    final failed = VideoNotificationOpen.fromData(<String, dynamic>{
      'type': 'video_failed',
      'request_id': 'failed-request',
    });

    expect(failed.status, 'FAILED');
    expect(
      () => VideoNotificationOpen.fromData(<String, dynamic>{
        'type': 'promotion',
        'request_id': 'request-1',
      }),
      throwsFormatException,
    );
    expect(
      () => VideoNotificationOpen.fromData(<String, dynamic>{
        'type': 'video_generated',
      }),
      throwsFormatException,
    );
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:video_gen/core/firebase/firebase_service.dart';
import 'package:video_gen/data/models/user_profile.dart';

void main() {
  test('builds the Firebase topic from user_code', () {
    expect(firebaseUserTopicFor('USER001'), 'user_USER001');
    expect(firebaseUserTopicFor('  abc-123  '), 'user_abc-123');
  });

  test('rejects missing or invalid user_code values', () {
    expect(firebaseUserTopicFor(''), isNull);
    expect(firebaseUserTopicFor('contains spaces'), isNull);
    expect(firebaseUserTopicFor('contains/slash'), isNull);
    expect(firebaseUserTopicFor('null'), isNull);
    expect(firebaseUserTopicFor('undefined'), isNull);
    expect(firebaseUserTopicFor('---'), isNull);
    expect(firebaseUserTopicFor('a' * 896), isNull);
  });

  test('does not subscribe without a valid user_code', () async {
    expect(await FirebaseService.subscribeToUserTopic(''), isFalse);
    expect(await FirebaseService.subscribeToUserTopic('null'), isFalse);
    expect(await FirebaseService.subscribeToUserTopic('bad/code'), isFalse);
  });

  test('profile does not coerce a non-string user_code into a topic', () {
    final profile = UserProfile.fromJson(<String, dynamic>{
      'id': 2,
      'user_code': 12345,
    });
    expect(profile.userCode, isEmpty);
    expect(firebaseUserTopicFor(profile.userCode), isNull);
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

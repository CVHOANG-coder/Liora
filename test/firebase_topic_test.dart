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
}

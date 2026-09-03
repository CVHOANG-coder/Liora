import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_gen/core/constants/app_features.dart';
import 'package:video_gen/core/firebase/firebase_service.dart';
import 'package:video_gen/data/models/i2v_request_status.dart';
import 'package:video_gen/presentation/screens/image_to_video/generated_video_screen.dart';
import 'package:video_gen/presentation/screens/notifications/video_notification_request_screen.dart';

void main() {
  testWidgets('opens the generated video from a completed notification', (
    tester,
  ) async {
    final notification = VideoNotificationOpen.fromData(<String, dynamic>{
      'type': 'video_generated',
      'request_id': 'completed-request',
      'status': 'COMPLETED',
      'result_url': 'https://example.test/payload-result.mp4',
    });

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: VideoNotificationRequestScreen(
            notification: notification,
            statusFetcher: (_) async =>
                _status(requestId: 'completed-request', status: 'COMPLETED'),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(GeneratedVideoScreen), findsOneWidget);
    expect(find.text('Your Video'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens the failed request when status API is unavailable', (
    tester,
  ) async {
    final notification = VideoNotificationOpen.fromData(<String, dynamic>{
      'type': 'video_failed',
      'request_id': 'failed-request',
      'status': 'ERROR',
    });

    await tester.pumpWidget(
      MaterialApp(
        home: VideoNotificationRequestScreen(
          notification: notification,
          statusFetcher: (_) async => throw Exception('offline'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Video Generation Failed'), findsOneWidget);
    expect(
      find.text('Your credits have been refunded.'),
      AppFeatures.commerceEnabled ? findsOneWidget : findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}

I2VRequestStatus _status({required String requestId, required String status}) {
  return I2VRequestStatus.fromJson(<String, dynamic>{
    'request_id': requestId,
    'service_type': 'I2V_GENERATOR',
    'request_status': status,
    'result_data': '',
    'duration': 5,
  });
}

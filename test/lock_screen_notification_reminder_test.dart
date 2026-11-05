import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_gen/presentation/widgets/lock_screen_notification_reminder.dart';
import 'package:video_gen/shared/themes/app_theme.dart';

void main() {
  const onboarding = MethodChannel('liora/video_onboarding_activity');
  const permissions = MethodChannel('flutter.baseflow.com/permissions/methods');
  var eligible = true;
  final settingsCalls = <String>[];

  setUp(() {
    eligible = true;
    settingsCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(onboarding, (call) async {
          if (call.method == 'claimLockScreenSetup') return eligible;
          if (call.method == 'openNotificationSettings') {
            settingsCalls.add(call.method);
            return true;
          }
          return null;
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissions, (call) async {
          settingsCalls.add(call.method);
          return true;
        });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    for (final channel in [onboarding, permissions]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    }
  });

  Future<void> openReminder(WidgetTester tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showLockScreenNotificationReminder(context),
              child: const Text('Show reminder'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Show reminder'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Android reminder explains lock screen and opens app notification settings',
    (tester) async {
      await openReminder(tester);
      expect(find.text('Your video, ready to watch'), findsOneWidget);
      expect(find.byIcon(Icons.screen_lock_portrait_rounded), findsOneWidget);
      expect(
        find.textContaining('Allow lock screen notifications'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('notificationOpenSettingsButton')));
      await tester.pumpAndSettle();
      expect(settingsCalls, ['openNotificationSettings']);
      expect(find.byType(Dialog), findsNothing);
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets('Not Now dismisses without opening settings', (tester) async {
    await openReminder(tester);
    await tester.tap(find.byKey(const Key('notificationNotNowButton')));
    await tester.pumpAndSettle();
    expect(settingsCalls, isEmpty);
    expect(find.byType(Dialog), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('does not remind again or show on iOS', (tester) async {
    eligible = false;
    await openReminder(tester);
    expect(find.byType(Dialog), findsNothing);
    debugDefaultTargetPlatformOverride = null;
    eligible = true;
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await tester.tap(find.text('Show reminder'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });
}

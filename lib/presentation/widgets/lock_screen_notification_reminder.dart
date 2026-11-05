import 'package:flutter/material.dart';
import 'package:video_onboarding_activity/video_onboarding_activity.dart';

import 'notification_permission_dialog.dart';

/// Android exposes lock-screen options in system settings, not a runtime prompt.
Future<void> showLockScreenNotificationReminder(BuildContext context) async {
  if (!VideoOnboardingActivity.isSupported) return;
  if (!await VideoOnboardingActivity.claimLockScreenSetup()) return;
  if (!context.mounted) return;
  final openSettings = await NotificationPermissionDialog.show(
    context,
    lockScreen: true,
  );
  if (openSettings) await VideoOnboardingActivity.openNotificationSettings();
}

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Registered with both the app engine and Firebase's background engine.
abstract final class VideoOnboardingActivity {
  static const _channel = MethodChannel('liora/video_onboarding_activity');

  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<void> refresh() => _invoke('refresh');

  /// Android has no runtime lock-screen permission; offer its settings once.
  static Future<bool> claimLockScreenSetup() =>
      _invokeBool('claimLockScreenSetup');

  static Future<bool> openNotificationSettings() =>
      _invokeBool('openNotificationSettings');

  static Future<bool> _invokeBool(String method) async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>(method) ?? false;
    } on PlatformException catch (error) {
      debugPrint('Could not configure video onboarding notification: $error');
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Installs the warm-launch handler before consuming any cold-launch tap.
  static Future<void> listenForOpens(VoidCallback onOpen) async {
    if (!isSupported) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'openImageToVideo') onOpen();
    });
    try {
      final pending = await _channel.invokeMethod<bool>('listenForOpens');
      if (pending == true) onOpen();
    } on PlatformException catch (error) {
      debugPrint('Could not listen for video onboarding opens: $error');
    } on MissingPluginException {
      // Unsupported hosts and tests have no native activity.
    }
  }

  static void stopListeningForOpens() => _channel.setMethodCallHandler(null);

  static Future<int?> completedCount() async {
    if (!isSupported) return null;
    try {
      return await _channel.invokeMethod<int>('completedCount');
    } on PlatformException catch (error) {
      debugPrint('Could not read video onboarding progress: $error');
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  static Future<void> recordCompleted(Iterable<String> requestIds) async {
    final ids = requestIds.map((id) => id.trim()).where((id) => id.isNotEmpty);
    if (ids.isEmpty) return;
    await _invoke('recordCompleted', {'requestIds': ids.toSet().toList()});
  }

  static Future<void> _invoke(String method, [Object? arguments]) async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on PlatformException catch (error) {
      debugPrint('Could not update video onboarding notification: $error');
    } on MissingPluginException {
      // Allows unsupported hosts and tests to run without a native engine.
    }
  }
}

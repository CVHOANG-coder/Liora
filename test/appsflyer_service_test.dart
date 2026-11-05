import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_gen/core/analytics/appsflyer_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'initializes once and reports every native foreground session',
    () async {
      final sdk = _FakeSdk();
      final service = AppsFlyerService(
        sdk: sdk,
        platform: TargetPlatform.android,
      );

      await Future.wait([service.initialize(), service.initialize()]);
      await service.initialize();

      expect(sdk.calls, ['debug:false', 'init', 'listen']);
      expect(sdk.devKey, isNotEmpty);
      expect(sdk.sessions, 0);
      sdk.onReady!();
      await pumpEventQueue();
      sdk.onReady!();
      await pumpEventQueue();
      expect(sdk.sessions, 2);
    },
  );

  test('handles a session emitted during listener registration', () async {
    final sdk = _FakeSdk()..readyOnRegistration = true;
    await AppsFlyerService(
      sdk: sdk,
      platform: TargetPlatform.android,
    ).initialize();
    await pumpEventQueue();
    expect(sdk.sessions, 1);
  });

  test('initialization failure does not escape into app startup', () async {
    final sdk = _FakeSdk()..failInit = true;
    await AppsFlyerService(
      sdk: sdk,
      platform: TargetPlatform.android,
    ).initialize();
    expect(sdk.onReady, isNull);
    expect(sdk.sessions, 0);
  });

  test(
    'a failed session does not prevent the next foreground session',
    () async {
      final sdk = _FakeSdk()..failStart = true;
      await AppsFlyerService(
        sdk: sdk,
        platform: TargetPlatform.android,
      ).initialize();
      sdk.onReady!();
      await pumpEventQueue();
      sdk.failStart = false;
      sdk.onReady!();
      await pumpEventQueue();
      expect(sdk.sessions, 2);
    },
  );

  for (final platform in [TargetPlatform.iOS, TargetPlatform.macOS]) {
    test('$platform does not initialize Android attribution', () async {
      final sdk = _FakeSdk();
      await AppsFlyerService(sdk: sdk, platform: platform).initialize();
      expect(sdk.calls, isEmpty);
    });
  }
}

class _FakeSdk extends AppsFlyerSdk {
  _FakeSdk()
    : super.private(
        const MethodChannel('test-appsflyer'),
        const EventChannel('test-appsflyer-events'),
      );

  final calls = <String>[];
  String? devKey;
  OnSessionReady? onReady;
  bool readyOnRegistration = false;
  bool failInit = false;
  bool failStart = false;
  int sessions = 0;

  @override
  Future<void> enableDebug(bool enabled) async => calls.add('debug:$enabled');

  @override
  Future<void> init({required String devKey, String? appId}) async {
    calls.add('init');
    this.devKey = devKey;
    if (failInit) throw PlatformException(code: 'unavailable');
  }

  @override
  Future<void> registerSessionReadyListener(OnSessionReady onReady) async {
    calls.add('listen');
    this.onReady = onReady;
    if (readyOnRegistration) onReady();
  }

  @override
  Future<void> start({bool awaitResponse = false}) async {
    sessions++;
    if (failStart) throw PlatformException(code: 'offline');
  }
}

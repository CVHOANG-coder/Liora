import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_gen/core/analytics/appsflyer_service.dart';
import 'package:video_gen/core/analytics/install_source_reporter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'forwards known conversion results and ignores unknown or failed data',
    () async {
      final sdk = _FakeSdk();
      final results = <InstallSource>[];
      final service = AppsFlyerService(
        sdk: sdk,
        platform: TargetPlatform.android,
      )..onInstallSource = results.add;
      await service.initialize();
      sdk.onConversion!({
        'af_status': 'Non-organic',
        'media_source': 'Facebook Ads',
      });
      sdk.onConversion!({'af_status': 'Organic'});
      sdk.onConversion!({
        'af_status': 'Non-organic',
        'media_source': 'restricted',
      });
      sdk.onConversionFailure!({'error': 'network'});
      expect(results, [InstallSource.ads, InstallSource.organic]);
      await service.setCustomerUserId(42);
      expect(sdk.customerUserId, '42');
    },
  );

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

      expect(sdk.calls, ['debug:false', 'init', 'conversion', 'listen']);
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
  OnConversionDataSuccess? onConversion;
  OnConversionDataFailure? onConversionFailure;
  String? customerUserId;

  @override
  Future<void> setCustomerUserId(String customerId) async {
    customerUserId = customerId;
  }

  @override
  Future<void> registerConversionListener({
    OnConversionDataSuccess? onConversionDataSuccess,
    OnConversionDataFailure? onConversionDataFail,
  }) async {
    calls.add('conversion');
    onConversion = onConversionDataSuccess;
    onConversionFailure = onConversionDataFail;
  }

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

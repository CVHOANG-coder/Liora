import 'dart:async';

import 'package:facebook_app_events/facebook_app_events.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_gen/core/analytics/meta_app_events_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(channelName);
  final calls = <MethodCall>[];
  late PermissionStatus status;
  late PermissionStatus requestResult;
  late int promptCount;
  late MetaAppEventsService service;

  List<Object?> argumentsFor(String method) => calls
      .where((call) => call.method == method)
      .map((call) => call.arguments)
      .toList();

  MetaAppEventsService createService(TargetPlatform platform) =>
      MetaAppEventsService(
        platform: platform,
        trackingStatus: () async => status,
        requestTracking: () async {
          promptCount++;
          return status = requestResult;
        },
      );

  setUp(() {
    calls.clear();
    status = PermissionStatus.denied;
    requestResult = PermissionStatus.granted;
    promptCount = 0;
    service = createService(TargetPlatform.iOS);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('Android enables app events without asking for ATT', () async {
    service = createService(TargetPlatform.android);
    await service.initialize();
    await service.requestTrackingAuthorization();
    await service.refreshTrackingAuthorization();

    expect(promptCount, 0);
    expect(argumentsFor('setAdvertiserIdCollectionEnabled'), [false, true]);
    expect(argumentsFor('setLimitEventAndDataUsage'), [false]);
    expect(argumentsFor('setAutoLogAppEventsEnabled'), [true]);
    expect(argumentsFor('activateApp'), [{}]);
    expect(argumentsFor('setAdvertiserTracking'), isEmpty);
  });

  test(
    'iOS initialization does not prompt or collect IDFA before ATT',
    () async {
      await service.initialize();

      expect(promptCount, 0);
      expect(argumentsFor('setAdvertiserIdCollectionEnabled'), [false, false]);
      expect(argumentsFor('setLimitEventAndDataUsage'), [true]);
      expect(argumentsFor('setAutoLogAppEventsEnabled'), isEmpty);
      expect(argumentsFor('activateApp'), isEmpty);
      expect(argumentsFor('setUserData'), isEmpty);
      expect(argumentsFor('setUserID'), isEmpty);
      expect(argumentsFor('setAdvertiserTracking'), [
        {'enabled': false, 'collectId': true},
        {'enabled': false, 'collectId': true},
      ]);
    },
  );

  test('initialization is coalesced and activates only once', () async {
    service = createService(TargetPlatform.android);
    await Future.wait([service.initialize(), service.initialize()]);
    await service.initialize();
    expect(argumentsFor('activateApp'), hasLength(1));
  });

  test('iOS authorization enables IDFA only after consent', () async {
    await service.initialize();
    await service.requestTrackingAuthorization();
    await service.requestTrackingAuthorization();

    expect(promptCount, 1);
    expect(argumentsFor('setAdvertiserIdCollectionEnabled').last, true);
    expect(argumentsFor('setLimitEventAndDataUsage').last, false);
    expect(argumentsFor('setAdvertiserTracking').last, {
      'enabled': true,
      'collectId': true,
    });
    expect(argumentsFor('activateApp'), hasLength(1));
    expect(
      calls.indexWhere((call) => call.method == 'activateApp'),
      greaterThan(
        calls.indexWhere(
          (call) =>
              call.method == 'setAdvertiserIdCollectionEnabled' &&
              call.arguments == true,
        ),
      ),
    );
  });

  test('a previously granted authorization does not prompt', () async {
    status = PermissionStatus.granted;
    await service.initialize();
    await service.requestTrackingAuthorization();

    expect(promptCount, 0);
    expect(argumentsFor('setAdvertiserIdCollectionEnabled').last, true);
  });

  for (final deniedStatus in [
    PermissionStatus.permanentlyDenied,
    PermissionStatus.restricted,
  ]) {
    test('iOS $deniedStatus neither prompts nor collects IDFA', () async {
      status = deniedStatus;
      await service.initialize();
      await service.requestTrackingAuthorization();

      expect(promptCount, 0);
      expect(
        argumentsFor('setAdvertiserIdCollectionEnabled'),
        everyElement(false),
      );
      expect(argumentsFor('setLimitEventAndDataUsage'), everyElement(true));
    });
  }

  test(
    'rejecting the first prompt keeps IDFA off and does not re-prompt',
    () async {
      requestResult = PermissionStatus.permanentlyDenied;
      await service.initialize();
      await service.requestTrackingAuthorization();
      await service.requestTrackingAuthorization();

      expect(promptCount, 1);
      expect(
        argumentsFor('setAdvertiserIdCollectionEnabled'),
        everyElement(false),
      );
      expect(argumentsFor('setLimitEventAndDataUsage'), everyElement(true));
    },
  );

  test('revoking ATT in Settings disables collection on resume', () async {
    status = PermissionStatus.granted;
    await service.initialize();
    status = PermissionStatus.permanentlyDenied;
    await service.refreshTrackingAuthorization();

    expect(promptCount, 0);
    expect(argumentsFor('setAdvertiserIdCollectionEnabled').last, false);
    expect(argumentsFor('setLimitEventAndDataUsage').last, true);
    expect(argumentsFor('activateApp'), hasLength(1));
    expect(argumentsFor('setAdvertiserTracking').last, {
      'enabled': false,
      'collectId': true,
    });
  });

  test(
    'concurrent prompts and resume do not race the permission result',
    () async {
      final authorization = Completer<PermissionStatus>();
      service = MetaAppEventsService(
        platform: TargetPlatform.iOS,
        trackingStatus: () async => status,
        requestTracking: () {
          promptCount++;
          return authorization.future;
        },
      );
      await service.initialize();
      final first = service.requestTrackingAuthorization();
      final second = service.requestTrackingAuthorization();
      await service.refreshTrackingAuthorization();
      authorization.complete(PermissionStatus.granted);
      await Future.wait([first, second]);

      expect(promptCount, 1);
      expect(argumentsFor('setAdvertiserIdCollectionEnabled'), [
        false,
        false,
        true,
      ]);
    },
  );

  test('permission errors fail closed without breaking startup', () async {
    var failPermissionRead = false;
    service = MetaAppEventsService(
      platform: TargetPlatform.iOS,
      trackingStatus: () async {
        if (failPermissionRead) throw PlatformException(code: 'permission');
        return PermissionStatus.granted;
      },
    );
    await service.initialize();
    failPermissionRead = true;
    await service.refreshTrackingAuthorization();

    expect(argumentsFor('setAdvertiserIdCollectionEnabled').last, false);
    expect(argumentsFor('setLimitEventAndDataUsage').last, true);
  });

  test('SDK failure never throws into app startup or navigation', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async {
          throw PlatformException(code: 'unavailable');
        });
    await service.initialize();
    await service.requestTrackingAuthorization();
    await service.refreshTrackingAuthorization();
    expect(promptCount, 0);
  });

  test(
    'uninitialized service and desktop do not access native plugins',
    () async {
      await service.requestTrackingAuthorization();
      await service.refreshTrackingAuthorization();
      service = createService(TargetPlatform.macOS);
      await service.initialize();
      await service.requestTrackingAuthorization();
      expect(calls, isEmpty);
      expect(promptCount, 0);
    },
  );
}

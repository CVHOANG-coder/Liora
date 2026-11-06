import 'dart:async';

import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'package:flutter/foundation.dart';

import 'install_source_reporter.dart';

/// Android install/session attribution. The SDK collects Play Install Referrer
/// and available advertising identifiers; Google Ads linking is configured in
/// the AppsFlyer dashboard. No custom purchase events are sent here.
class AppsFlyerService {
  AppsFlyerService({AppsFlyerSdk? sdk, TargetPlatform? platform})
    : _sdk = sdk ?? AppsFlyerSdk.instance,
      _platform = platform ?? defaultTargetPlatform;

  static final instance = AppsFlyerService();

  static const _devKey = String.fromEnvironment(
    'APPSFLYER_DEV_KEY',
    defaultValue: 'sCF6QMgCGcPGWXvzmUZRYN',
  );

  final AppsFlyerSdk _sdk;
  final TargetPlatform _platform;
  Future<void>? _initialization;
  void Function(InstallSource source)? onInstallSource;

  Future<void> initialize() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    if (kIsWeb || _platform != TargetPlatform.android) return;
    try {
      await _sdk.enableDebug(
        kDebugMode && const bool.fromEnvironment('APPSFLYER_DEBUG_LOGGING'),
      );
      await _sdk.init(devKey: _devKey);
      await _sdk.registerConversionListener(
        onConversionDataSuccess: (data) {
          final source = InstallSource.fromConversionData(data);
          if (source != null) onInstallSource?.call(source);
        },
        onConversionDataFail: (_) {
          // Missing attribution must never be interpreted as organic.
          if (kDebugMode) debugPrint('AppsFlyer: conversion data unavailable.');
        },
      );
      // SDK 7 emits this on each foreground session, including a buffered first
      // session. Register last; its callback may run immediately. Do not gate
      // this on login, onboarding, or a network response.
      await _sdk.registerSessionReadyListener(() => unawaited(_startSession()));
    } catch (error) {
      _reportFailure('initialize', error);
    }
  }

  Future<void> setCustomerUserId(int userId) async {
    if (kIsWeb || _platform != TargetPlatform.android || userId <= 0) return;
    await initialize();
    try {
      await _sdk.setCustomerUserId(userId.toString());
    } catch (error) {
      _reportFailure('set customer user ID', error);
    }
  }

  Future<void> _startSession() async {
    try {
      await _sdk.start();
    } catch (error) {
      _reportFailure('start session', error);
    }
  }

  void _reportFailure(String operation, Object error) {
    if (kDebugMode) {
      debugPrint('AppsFlyer: $operation failed (${error.runtimeType}).');
    }
  }
}

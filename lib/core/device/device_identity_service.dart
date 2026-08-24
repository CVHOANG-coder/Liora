import 'dart:math';
import 'package:android_id/android_id.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../network/api_config.dart';

abstract interface class DeviceIdentityProvider {
  Future<String> getDeviceId();

  String get platform;

  String get countryCode;
}

class DeviceIdentityService implements DeviceIdentityProvider {
  DeviceIdentityService({
    AndroidId? androidId,
    DeviceInfoPlugin? deviceInfo,
    SharedPreferencesAsync? preferences,
  }) : _androidId = androidId ?? const AndroidId(),
       _deviceInfo = deviceInfo ?? DeviceInfoPlugin(),
       _preferences = preferences ?? SharedPreferencesAsync();

  static const _fallbackDeviceIdKey = 'fallback_device_id';

  final AndroidId _androidId;
  final DeviceInfoPlugin _deviceInfo;
  final SharedPreferencesAsync _preferences;

  @override
  String get platform => switch (defaultTargetPlatform) {
    TargetPlatform.android => 'ANDROID',
    TargetPlatform.iOS => 'IOS',
    TargetPlatform.macOS => 'MACOS',
    TargetPlatform.windows => 'WINDOWS',
    TargetPlatform.linux => 'LINUX',
    TargetPlatform.fuchsia => 'FUCHSIA',
  };

  @override
  String get countryCode {
    for (final locale in PlatformDispatcher.instance.locales) {
      final code = locale.countryCode;
      if (code != null && code.isNotEmpty) return code.toUpperCase();
    }
    return ApiConfig.fallbackCountryCode;
  }

  @override
  Future<String> getDeviceId() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final androidId = await _readAndroidId();
      if (androidId != null) return androidId;
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      final identifier = (await _deviceInfo.iosInfo).identifierForVendor;
      if (identifier != null && identifier.isNotEmpty) return identifier;
    }

    return _getOrCreateFallbackId();
  }

  Future<String?> _readAndroidId() async {
    try {
      final value = await _androidId.getId();
      return value == null || value.isEmpty ? null : value;
    } catch (_) {
      return null;
    }
  }

  Future<String> _getOrCreateFallbackId() async {
    final stored = await _preferences.getString(_fallbackDeviceIdKey);
    if (stored != null && stored.isNotEmpty) return stored;

    final random = Random.secure();
    final value = List<int>.generate(
      16,
      (_) => random.nextInt(256),
    ).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    await _preferences.setString(_fallbackDeviceIdKey, value);
    return value;
  }
}

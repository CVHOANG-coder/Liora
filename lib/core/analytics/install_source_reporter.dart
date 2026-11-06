import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum InstallSource {
  ads('ADS'),
  organic('ORGANIC');

  const InstallSource(this.apiValue);
  final String apiValue;

  static InstallSource? fromConversionData(Map<String, dynamic> data) {
    final status = data['af_status']?.toString().trim().toLowerCase();
    final media = data['media_source']?.toString().trim().toLowerCase();
    if (status == 'organic' &&
        (media == null || media == '' || media == 'organic')) {
      return organic;
    }
    if (status == 'non-organic' &&
        media != null &&
        !{
          '',
          'organic',
          'unknown',
          'restricted',
          'null',
          'n/a',
        }.contains(media)) {
      return ads;
    }
    return null;
  }
}

/// Serializes attribution and authentication changes. Preferences contain only
/// the classified source and per-user acknowledgements, never raw ad payloads.
class InstallSourceReporter {
  InstallSourceReporter({
    required this.send,
    Future<SharedPreferences> Function()? loadPreferences,
    this.retryDelay = const Duration(seconds: 30),
  }) : _loadPreferences = loadPreferences ?? SharedPreferences.getInstance;

  final Future<void> Function(int userId, String source) send;
  final Future<SharedPreferences> Function() _loadPreferences;
  final Duration retryDelay;
  static const _sourceKey = 'install_attribution_source_v1';
  static String _sentKey(int userId) => 'install_attribution_sent_v1_$userId';
  static String _reportedKey(int userId) =>
      'install_attribution_reported_v1_$userId';

  SharedPreferences? _preferences;
  int? _userId;
  InstallSource? _source;
  final Set<int> _reportedUsers = {};
  Future<void> _queue = Future<void>.value();
  Timer? _retry;
  bool _disposed = false;

  Future<void> recordSource(InstallSource source) => _enqueue(() async {
    // Preserve a positive paid attribution even if a later cached callback
    // reports organic. This also matches the backend's ADS locking rule.
    if (_source != InstallSource.ads) _source = source;
  });

  Future<void> updateUser(int? userId) => _enqueue(() async {
    _userId = userId != null && userId > 0 ? userId : null;
  });

  Future<void> retryPending() => _enqueue(() async {});

  Future<void> _enqueue(Future<void> Function() change) {
    _queue = _queue.then((_) async {
      if (_disposed) return;
      try {
        // Apply changes even when preference initialization is unavailable.
        // A later retry can persist the attribution still held in memory.
        await change();
        final preferences = _preferences ??= await _loadPreferences();
        final cached = preferences.getString(_sourceKey);
        if (cached == 'ADS') {
          _source = InstallSource.ads;
        } else if (_source == null && cached == 'ORGANIC') {
          _source = InstallSource.organic;
        }
        final userId = _userId;
        if (userId != null) {
          final legacySent = preferences.getString(_sentKey(userId));
          if (_reportedUsers.contains(userId) ||
              preferences.getBool(_reportedKey(userId)) == true ||
              legacySent == 'ADS' ||
              legacySent == 'ORGANIC') {
            _reportedUsers.add(userId);
            await _persistReported(preferences, userId);
            _retry?.cancel();
            return;
          }
        }
        final source = _source;
        if (source == null) return;
        if (!await preferences.setString(_sourceKey, source.apiValue)) {
          throw StateError('Could not persist install attribution.');
        }
        if (userId == null) return;
        await send(userId, source.apiValue);
        // Remember success before writing preferences: a storage failure should
        // retry saving the flag, not repeat an already successful HTTP request.
        _reportedUsers.add(userId);
        await _persistReported(preferences, userId);
        _retry?.cancel();
      } catch (error) {
        if (kDebugMode) {
          debugPrint('Install source: pending retry (${error.runtimeType}).');
        }
        if (!_disposed && !(_retry?.isActive ?? false)) {
          _retry = Timer(retryDelay, () => unawaited(retryPending()));
        }
      }
    });
    return _queue;
  }

  Future<void> _persistReported(
    SharedPreferences preferences,
    int userId,
  ) async {
    final key = _reportedKey(userId);
    if (preferences.getBool(key) != true &&
        !await preferences.setBool(key, true)) {
      throw StateError('Could not persist attribution acknowledgement.');
    }
  }

  void dispose() {
    _disposed = true;
    _retry?.cancel();
  }
}

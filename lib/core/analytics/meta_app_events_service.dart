import 'package:facebook_app_events/facebook_app_events.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Meta install/activation measurement. No profile data or custom user IDs are
/// sent; the native SDK owns automatic lifecycle and purchase events.
class MetaAppEventsService {
  MetaAppEventsService({
    FacebookAppEvents? appEvents,
    TargetPlatform? platform,
    Future<PermissionStatus> Function()? trackingStatus,
    Future<PermissionStatus> Function()? requestTracking,
  }) : _appEvents = appEvents ?? FacebookAppEvents(),
       _platform = platform ?? defaultTargetPlatform,
       _trackingStatus = trackingStatus ?? _readTrackingStatus,
       _requestTracking = requestTracking ?? _requestTrackingPermission;

  static final instance = MetaAppEventsService();

  static Future<PermissionStatus> _readTrackingStatus() =>
      Permission.appTrackingTransparency.status;

  static Future<PermissionStatus> _requestTrackingPermission() =>
      Permission.appTrackingTransparency.request();

  final FacebookAppEvents _appEvents;
  final TargetPlatform _platform;
  final Future<PermissionStatus> Function() _trackingStatus;
  final Future<PermissionStatus> Function() _requestTracking;
  Future<void>? _initialization;
  Future<void>? _authorizationRequest;
  Future<void>? _activation;
  bool _initialized = false;

  bool get _isIOS => _platform == TargetPlatform.iOS;
  bool get _isSupported =>
      !kIsWeb && (_isIOS || _platform == TargetPlatform.android);

  Future<void> initialize() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    if (!_isSupported) return;
    try {
      await _appEvents.setDebugLoggingEnabled(
        kDebugMode && const bool.fromEnvironment('META_DEBUG_LOGGING'),
      );
      // Native defaults are also false. Reset a value persisted by an earlier
      // session before checking the current system authorization.
      await _setAdvertiserCollection(false);
      final status = _isIOS ? await _trackingStatus() : null;
      await _applyTrackingStatus(status: status);
      // The native install ping is sent once. On a fresh iOS install, wait for
      // the first ATT decision so consent is applied before that ping is sent.
      if (!_isIOS || status != PermissionStatus.denied) {
        await _startAppEvents();
      }
      _initialized = true;
    } catch (error) {
      _reportFailure('initialize', error);
    }
  }

  Future<void> _startAppEvents() => _activation ??= _activateApp();

  Future<void> _activateApp() async {
    await _appEvents.setAutoLogAppEventsEnabled(true);
    await _appEvents.activateApp();
  }

  /// Call only once the app has visible, active UI, before another permission
  /// dialog (e.g. notification permission on Home) can be presented.
  Future<void> requestTrackingAuthorization() async {
    if (!_initialized || !_isIOS) return;
    final pending = _authorizationRequest;
    if (pending != null) return pending;
    final request = _authorizeTracking();
    _authorizationRequest = request;
    try {
      await request;
    } finally {
      _authorizationRequest = null;
    }
  }

  Future<void> _authorizeTracking() async {
    try {
      var status = await _trackingStatus();
      // permission_handler maps ATT notDetermined to denied; a user rejection
      // maps to permanentlyDenied and must not show the prompt again.
      if (status == PermissionStatus.denied) {
        status = await _requestTracking();
      }
      await _applyTrackingStatus(status: status);
      await _startAppEvents();
    } catch (error) {
      await _disableTrackingAfterFailure(error);
    }
  }

  /// Re-read ATT after returning from Settings. Never prompt on resume, and do
  /// not overwrite a pending permission result with the preceding status.
  Future<void> refreshTrackingAuthorization() async {
    if (!_initialized || !_isIOS || _authorizationRequest != null) return;
    try {
      await _applyTrackingStatus();
    } catch (error) {
      await _disableTrackingAfterFailure(error);
    }
  }

  Future<void> _applyTrackingStatus({PermissionStatus? status}) async {
    final allowed = !_isIOS || (status ?? await _trackingStatus()).isGranted;
    await _setAdvertiserCollection(allowed);
    // Without ATT consent, keep events limited to analytics/conversions and
    // leave the native SDK to enforce Apple's tracking restrictions.
    await _appEvents.setLimitEventAndDataUsage(!allowed);
  }

  Future<void> _setAdvertiserCollection(bool allowed) async {
    await _appEvents.setAdvertiserIdCollectionEnabled(allowed);
    if (_isIOS) {
      // FBSDK 18 still needs the ATE flag on iOS 15/16 (our minimum is 15).
      // On iOS 17+ this setter is ignored and the SDK reads ATT directly.
      // Always mirror the actual ATT result, never override a denial.
      // ignore: deprecated_member_use
      await _appEvents.setAdvertiserTracking(enabled: allowed);
    }
  }

  Future<void> _disableTrackingAfterFailure(Object error) async {
    _reportFailure('tracking authorization', error);
    try {
      await _setAdvertiserCollection(false);
      await _appEvents.setLimitEventAndDataUsage(true);
    } catch (error) {
      _reportFailure('disable advertising identifiers', error);
    }
  }

  void _reportFailure(String operation, Object error) {
    if (kDebugMode) {
      // Do not print SDK arguments, which can include app credentials.
      debugPrint('Meta App Events: $operation failed (${error.runtimeType}).');
    }
  }
}

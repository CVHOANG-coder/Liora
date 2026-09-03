import 'dart:async';
// TEMP: Firebase imports are disabled until the new Firebase apps exist.
// import 'dart:convert';
// import 'package:firebase_analytics/firebase_analytics.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:flutter/foundation.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'package:shared_preferences/shared_preferences.dart';

/* TEMP: Firebase Messaging and Analytics implementation disabled.
const _notificationChannel = AndroidNotificationChannel(
  'high_importance_channel',
  'Important notifications',
  description: 'Notifications about videos, account updates, and offers.',
  importance: Importance.high,
);

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}
*/

enum NotificationPermissionFlowResult {
  granted,
  denied,
  settingsRequired,
  skipped,
}

typedef NotificationPermissionRequester =
    Future<NotificationPermissionFlowResult> Function();
typedef NotificationSettingsOpener = Future<bool> Function();

class VideoNotificationOpen {
  const VideoNotificationOpen({
    required this.type,
    required this.requestId,
    required this.status,
    required this.resultUrl,
    required this.replaceCurrentRoute,
  });

  factory VideoNotificationOpen.fromData(
    Map<String, dynamic> data, {
    bool replaceCurrentRoute = false,
  }) {
    final type = data['type']?.toString().trim().toLowerCase() ?? '';
    if (type != 'video_generated' && type != 'video_failed') {
      throw const FormatException('Unsupported notification type.');
    }

    final requestId = data['request_id']?.toString().trim() ?? '';
    if (requestId.isEmpty) {
      throw const FormatException('Video notification is missing request_id.');
    }

    final rawStatus = data['status']?.toString().trim().toUpperCase() ?? '';
    const supportedStatuses = <String>{
      'IN_QUEUE',
      'PENDING',
      'COMPLETED',
      'FAILED',
      'ERROR',
      'CANCELLED',
      'DELETED',
    };
    final fallbackStatus = type == 'video_generated' ? 'COMPLETED' : 'FAILED';
    return VideoNotificationOpen(
      type: type,
      requestId: requestId,
      status: supportedStatuses.contains(rawStatus)
          ? rawStatus
          : fallbackStatus,
      resultUrl: data['result_url']?.toString().trim() ?? '',
      replaceCurrentRoute: replaceCurrentRoute,
    );
  }

  final String type;
  final String requestId;
  final String status;
  final String resultUrl;
  final bool replaceCurrentRoute;
}

String? firebaseUserTopicFor(String userCode) {
  final normalizedUserCode = userCode.trim();
  if (normalizedUserCode.isEmpty) return null;

  final topic = 'user_$normalizedUserCode';
  final validTopic = RegExp(r'^[a-zA-Z0-9-_.~%]{1,900}$');
  return validTopic.hasMatch(topic) ? topic : null;
}

/* TEMP: Original Firebase service implementation disabled.
class FirebaseService {
  FirebaseService._();

  static final FirebaseAnalytics analytics = FirebaseAnalytics.instance;
  static final FirebaseMessaging messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static final SharedPreferencesAsync _preferences = SharedPreferencesAsync();
  static final StreamController<VideoNotificationOpen>
  _notificationOpenController =
      StreamController<VideoNotificationOpen>.broadcast(sync: true);

  static const _homePermissionAttemptedKey =
      'notifications.home_permission_attempted';
  static const _deniedOnHomeKey = 'notifications.denied_on_home';
  static const _creatingPermissionAttemptedKey =
      'notifications.creating_permission_attempted';

  static FirebaseAnalyticsObserver? analyticsObserver;
  static bool _initialized = false;
  static Future<void>? _initializationFuture;
  static Future<NotificationPermissionFlowResult>?
  _homePermissionRequestInFlight;
  static Future<NotificationPermissionFlowResult>?
  _creatingPermissionRequestInFlight;
  static String? _pendingUserTopic;
  static Future<bool>? _topicSubscriptionInFlight;
  static bool _notificationNavigationReady = false;
  static VideoNotificationOpen? _pendingNotificationOpen;

  static Stream<VideoNotificationOpen> get notificationOpens =>
      _notificationOpenController.stream;

  static bool markNotificationNavigationReady() {
    _notificationNavigationReady = true;
    final pending = _pendingNotificationOpen;
    _pendingNotificationOpen = null;
    if (pending == null) return false;
    _notificationOpenController.add(pending);
    return true;
  }

  static Future<void> initialize() {
    return _initializationFuture ??= _initializeFirebase();
  }

  static Future<void> _initializeFirebase() async {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await analytics.setAnalyticsCollectionEnabled(true);
    analyticsObserver = FirebaseAnalyticsObserver(analytics: analytics);

    await _initializeNotifications();
    _listenForMessages();
    await _logInitialNotificationIfNeeded();
    _initialized = true;
  }

  static Future<bool> subscribeToUserTopic(String userCode) async {
    final topic = firebaseUserTopicFor(userCode);
    if (topic == null) {
      if (kDebugMode) {
        debugPrint('Skipped FCM topic subscription: invalid user_code.');
      }
      return false;
    }

    final initialization = _initializationFuture;
    if (initialization == null) {
      if (kDebugMode) {
        debugPrint('Skipped FCM topic subscription: Firebase is not starting.');
      }
      return false;
    }

    try {
      await initialization;
      _pendingUserTopic = topic;
      return _trySubscribeToPendingUserTopic();
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Could not wait for Firebase topic subscription: $error');
      }
      return false;
    }
  }

  static Future<bool> _trySubscribeToPendingUserTopic() {
    final inFlight = _topicSubscriptionInFlight;
    if (inFlight != null) return inFlight;

    final subscription = _subscribeToPendingUserTopic();
    _topicSubscriptionInFlight = subscription;
    return subscription.whenComplete(() => _topicSubscriptionInFlight = null);
  }

  static Future<bool> _subscribeToPendingUserTopic() async {
    final topic = _pendingUserTopic;
    if (topic == null) return true;

    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        final apnsToken = await messaging.getAPNSToken();
        if (apnsToken == null) {
          if (kDebugMode) {
            debugPrint(
              'FCM topic $topic is pending until the APNs token is ready.',
            );
          }
          return false;
        }
      }

      await messaging.subscribeToTopic(topic);
      if (_pendingUserTopic == topic) _pendingUserTopic = null;
      if (kDebugMode) debugPrint('Subscribed to FCM topic: $topic');
      return true;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Could not subscribe to FCM topic $topic: $error');
      }
      return false;
    }
  }

  static Future<void> _initializeNotifications() async {
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('ic_stat_notification'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );

    await _localNotifications.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        unawaited(_handleLocalNotificationOpen(response));
      },
    );

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(_notificationChannel);
    }

    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  static Future<NotificationPermissionFlowResult>
  requestNotificationPermissionOnHome() {
    if (!_initialized) {
      return Future.value(NotificationPermissionFlowResult.skipped);
    }
    final inFlight = _homePermissionRequestInFlight;
    if (inFlight != null) return inFlight;

    final request = _requestNotificationPermissionOnHome();
    _homePermissionRequestInFlight = request;
    return request.whenComplete(() => _homePermissionRequestInFlight = null);
  }

  static Future<NotificationPermissionFlowResult>
  requestNotificationPermissionOnCreatingVideo() {
    if (!_initialized) {
      return Future.value(NotificationPermissionFlowResult.skipped);
    }
    final inFlight = _creatingPermissionRequestInFlight;
    if (inFlight != null) return inFlight;

    final request = _requestNotificationPermissionOnCreatingVideo();
    _creatingPermissionRequestInFlight = request;
    return request.whenComplete(
      () => _creatingPermissionRequestInFlight = null,
    );
  }

  static Future<bool> openNotificationSettings() => openAppSettings();

  static Future<NotificationPermissionFlowResult>
  _requestNotificationPermissionOnHome() async {
    try {
      if (await _preferences.getBool(_homePermissionAttemptedKey) ?? false) {
        return NotificationPermissionFlowResult.skipped;
      }

      final currentSettings = await messaging.getNotificationSettings();
      if (_isNotificationAuthorized(currentSettings.authorizationStatus)) {
        await _preferences.setBool(_homePermissionAttemptedKey, true);
        await _preferences.setBool(_deniedOnHomeKey, false);
        return NotificationPermissionFlowResult.granted;
      }

      final result = await _requestSystemNotificationPermission();
      final granted = _isNotificationAuthorized(result.authorizationStatus);
      await _preferences.setBool(_homePermissionAttemptedKey, true);
      await _preferences.setBool(_deniedOnHomeKey, !granted);
      await _logPermissionResult('home', result.authorizationStatus);
      return granted
          ? NotificationPermissionFlowResult.granted
          : NotificationPermissionFlowResult.denied;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Could not request notification permission on Home: $error');
      }
      return NotificationPermissionFlowResult.skipped;
    }
  }

  static Future<NotificationPermissionFlowResult>
  _requestNotificationPermissionOnCreatingVideo() async {
    try {
      final deniedOnHome =
          await _preferences.getBool(_deniedOnHomeKey) ?? false;
      final alreadyAttempted =
          await _preferences.getBool(_creatingPermissionAttemptedKey) ?? false;
      if (!deniedOnHome || alreadyAttempted) {
        return NotificationPermissionFlowResult.skipped;
      }

      final currentSettings = await messaging.getNotificationSettings();
      if (_isNotificationAuthorized(currentSettings.authorizationStatus)) {
        await _preferences.setBool(_deniedOnHomeKey, false);
        return NotificationPermissionFlowResult.granted;
      }

      final result = await _requestSystemNotificationPermission();
      final granted = _isNotificationAuthorized(result.authorizationStatus);
      await _preferences.setBool(_creatingPermissionAttemptedKey, true);
      await _preferences.setBool(_deniedOnHomeKey, !granted);
      await _logPermissionResult('creating_video', result.authorizationStatus);
      return granted
          ? NotificationPermissionFlowResult.granted
          : NotificationPermissionFlowResult.settingsRequired;
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          'Could not request notification permission while creating: $error',
        );
      }
      return NotificationPermissionFlowResult.skipped;
    }
  }

  static Future<NotificationSettings> _requestSystemNotificationPermission() {
    return messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
  }

  static bool _isNotificationAuthorized(AuthorizationStatus status) {
    return status == AuthorizationStatus.authorized ||
        status == AuthorizationStatus.provisional;
  }

  static Future<void> _logPermissionResult(
    String stage,
    AuthorizationStatus status,
  ) async {
    try {
      await analytics.logEvent(
        name: 'notification_permission_result',
        parameters: {'stage': stage, 'status': status.name},
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Could not log notification permission result: $error');
      }
    }
  }

  static void _listenForMessages() {
    FirebaseMessaging.onMessage.listen((message) async {
      await analytics.logEvent(
        name: 'push_received_foreground',
        parameters: {
          'app_state': 'foreground',
          if (message.messageId != null) 'message_id': message.messageId!,
        },
      );

      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        await _showAndroidForegroundNotification(message);
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) async {
      await _logNotificationOpen(message, 'background');
      _queueNotificationOpen(message.data);
    });

    messaging.onTokenRefresh.listen((_) {
      if (_pendingUserTopic != null) {
        unawaited(_trySubscribeToPendingUserTopic());
      }
    });
  }

  static Future<void> _showAndroidForegroundNotification(
    RemoteMessage message,
  ) async {
    final notification = message.notification;
    if (notification == null && message.data.isEmpty) return;

    final type = message.data['type']?.toString().trim().toLowerCase();
    final fallbackTitle = type == 'video_failed'
        ? 'Video generation failed'
        : 'Your video is ready';
    final fallbackBody = type == 'video_failed'
        ? 'Tap to view the request details.'
        : 'Tap to watch your generated video.';

    await _localNotifications.show(
      id: DateTime.now().millisecondsSinceEpoch.remainder(0x7fffffff),
      title: notification?.title ?? fallbackTitle,
      body: notification?.body ?? fallbackBody,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _notificationChannel.id,
          _notificationChannel.name,
          channelDescription: _notificationChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: 'ic_stat_notification',
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  static Future<void> _logInitialNotificationIfNeeded() async {
    final localLaunchDetails = await _localNotifications
        .getNotificationAppLaunchDetails();
    if (localLaunchDetails?.didNotificationLaunchApp ?? false) {
      final payload = localLaunchDetails?.notificationResponse?.payload;
      _queueNotificationPayload(payload, replaceCurrentRoute: true);
      await analytics.logEvent(
        name: 'push_opened',
        parameters: {'source': 'foreground_notification_terminated'},
      );
    }

    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      _queueNotificationOpen(initialMessage.data, replaceCurrentRoute: true);
      await _logNotificationOpen(initialMessage, 'terminated');
    }
  }

  static Future<void> _handleLocalNotificationOpen(
    NotificationResponse response,
  ) async {
    _queueNotificationPayload(response.payload);
    await analytics.logEvent(
      name: 'push_opened',
      parameters: {'source': 'foreground_notification'},
    );
  }

  static void _queueNotificationPayload(
    String? payload, {
    bool replaceCurrentRoute = false,
  }) {
    if (payload == null || payload.trim().isEmpty) return;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map) {
        _queueNotificationOpen(
          Map<String, dynamic>.from(decoded),
          replaceCurrentRoute: replaceCurrentRoute,
        );
      }
    } catch (error) {
      if (kDebugMode) debugPrint('Invalid notification payload: $error');
    }
  }

  static void _queueNotificationOpen(
    Map<String, dynamic> data, {
    bool replaceCurrentRoute = false,
  }) {
    try {
      final notification = VideoNotificationOpen.fromData(
        data,
        replaceCurrentRoute: replaceCurrentRoute,
      );
      if (_notificationNavigationReady) {
        _notificationOpenController.add(notification);
      } else {
        _pendingNotificationOpen = notification;
      }
    } on FormatException catch (error) {
      if (kDebugMode) {
        debugPrint('Ignored notification navigation: ${error.message}');
      }
    }
  }

  static Future<void> _logNotificationOpen(
    RemoteMessage message,
    String appState,
  ) async {
    try {
      await analytics.logEvent(
        name: 'push_opened',
        parameters: {
          'source': 'firebase_messaging',
          'app_state': appState,
          if (message.messageId != null) 'message_id': message.messageId!,
        },
      );
    } catch (error) {
      if (kDebugMode) debugPrint('Could not log notification open: $error');
    }
  }
}
*/

/// No-op facade used while Firebase Analytics and Messaging are disabled.
/// Keeping the public API lets the rest of the app run unchanged and makes
/// re-enabling the original implementation a small, reversible change.
class FirebaseService {
  FirebaseService._();

  static final StreamController<VideoNotificationOpen>
  _notificationOpenController =
      StreamController<VideoNotificationOpen>.broadcast(sync: true);

  static Stream<VideoNotificationOpen> get notificationOpens =>
      _notificationOpenController.stream;

  static Future<void> initialize() async {}

  static Future<bool> subscribeToUserTopic(String userCode) async => false;

  static bool markNotificationNavigationReady() => false;

  static Future<NotificationPermissionFlowResult>
  requestNotificationPermissionOnHome() async =>
      NotificationPermissionFlowResult.skipped;

  static Future<NotificationPermissionFlowResult>
  requestNotificationPermissionOnCreatingVideo() async =>
      NotificationPermissionFlowResult.skipped;

  static Future<bool> openNotificationSettings() async => false;
}

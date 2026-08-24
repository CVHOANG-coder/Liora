import 'dart:async';
import 'dart:convert';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

enum NotificationPermissionFlowResult {
  granted,
  denied,
  settingsRequired,
  skipped,
}

typedef NotificationPermissionRequester =
    Future<NotificationPermissionFlowResult> Function();
typedef NotificationSettingsOpener = Future<bool> Function();

String? firebaseUserTopicFor(String userCode) {
  final normalizedUserCode = userCode.trim();
  if (normalizedUserCode.isEmpty) return null;

  final topic = 'user_$normalizedUserCode';
  final validTopic = RegExp(r'^[a-zA-Z0-9-_.~%]{1,900}$');
  return validTopic.hasMatch(topic) ? topic : null;
}

class FirebaseService {
  FirebaseService._();

  static final FirebaseAnalytics analytics = FirebaseAnalytics.instance;
  static final FirebaseMessaging messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static final SharedPreferencesAsync _preferences = SharedPreferencesAsync();

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
    unawaited(_printRegistrationToken());
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
      onDidReceiveNotificationResponse: (_) {
        analytics.logEvent(
          name: 'push_opened',
          parameters: {'source': 'foreground_notification'},
        );
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

    FirebaseMessaging.onMessageOpenedApp.listen(
      (message) => _logNotificationOpen(message, 'background'),
    );

    messaging.onTokenRefresh.listen((token) {
      if (kDebugMode) {
        debugPrint('FCM token refreshed: $token');
      }
      if (_pendingUserTopic != null) {
        unawaited(_trySubscribeToPendingUserTopic());
      }
      // Send this token to the application backend when a token API is ready.
    });
  }

  static Future<void> _showAndroidForegroundNotification(
    RemoteMessage message,
  ) async {
    final notification = message.notification;
    final android = notification?.android;
    if (notification == null || android == null) return;

    await _localNotifications.show(
      id: DateTime.now().millisecondsSinceEpoch.remainder(0x7fffffff),
      title: notification.title,
      body: notification.body,
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
      await analytics.logEvent(
        name: 'push_opened',
        parameters: {'source': 'foreground_notification_terminated'},
      );
    }

    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      await _logNotificationOpen(initialMessage, 'terminated');
    }
  }

  static Future<void> _logNotificationOpen(
    RemoteMessage message,
    String appState,
  ) {
    return analytics.logEvent(
      name: 'push_opened',
      parameters: {
        'source': 'firebase_messaging',
        'app_state': appState,
        if (message.messageId != null) 'message_id': message.messageId!,
      },
    );
  }

  static Future<void> _printRegistrationToken() async {
    try {
      if (kIsWeb) return;

      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final apnsToken = await messaging.getAPNSToken();
        if (apnsToken == null) {
          if (kDebugMode) {
            debugPrint('APNs token is not available yet; waiting for refresh.');
          }
          return;
        }
      }

      final token = await messaging.getToken();
      if (kDebugMode) {
        debugPrint('FCM token: $token');
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Could not retrieve the FCM token: $error');
      }
    }
  }
}

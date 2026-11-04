import 'dart:async';
import 'dart:ui';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:video_onboarding_activity/video_onboarding_activity.dart';

import 'core/analytics/meta_app_events_service.dart';
import 'core/constants/app_features.dart';
import 'core/network/api_client.dart';
import 'core/notifications/video_onboarding_service.dart';
import 'core/firebase/firebase_service.dart';
import 'core/firebase/flutter_error_handler.dart';
import 'shared/themes/app_theme.dart';
import 'presentation/screens/splash/splash_screen.dart';
import 'presentation/screens/notifications/video_notification_request_screen.dart';
import 'presentation/providers/purchase_provider.dart';
import 'presentation/screens/image_to_video/image_to_video_screen.dart';
import 'presentation/screens/main/main_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseService.initialize();
  FlutterError.onError = FlutterErrorHandler(
    recordError: FirebaseCrashlytics.instance.recordFlutterError,
  ).call;
  PlatformDispatcher.instance.onError = (error, stack) {
    unawaited(
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true),
    );
    return true;
  };
  await MetaAppEventsService.instance.initialize();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const ProviderScope(child: VideoGenApp()));
}

class VideoGenApp extends ConsumerStatefulWidget {
  const VideoGenApp({super.key, this.home});

  final Widget? home;

  @override
  ConsumerState<VideoGenApp> createState() => _VideoGenAppState();
}

class _VideoGenAppState extends ConsumerState<VideoGenApp>
    with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final Set<String> _openingRequestIds = <String>{};
  StreamSubscription<VideoNotificationOpen>? _notificationOpenSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _notificationOpenSubscription = FirebaseService.notificationOpens.listen(
      (notification) => unawaited(_openVideoNotification(notification)),
    );
    unawaited(
      VideoOnboardingActivity.listenForOpens(
        FirebaseService.openImageToVideoFromOnboarding,
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_refreshVideoOnboarding());
    });
  }

  Future<void> _refreshVideoOnboarding() => VideoOnboardingService.refresh(
    () => ApiClient.instance.generationHistoryService,
  );

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(MetaAppEventsService.instance.refreshTrackingAuthorization());
      unawaited(_refreshVideoOnboarding());
    }
  }

  Future<void> _openVideoNotification(
    VideoNotificationOpen notification,
  ) async {
    if (!_openingRequestIds.add(notification.requestId)) return;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) {
      _openingRequestIds.remove(notification.requestId);
      return;
    }

    final navigator = _navigatorKey.currentState;
    if (navigator == null) {
      _openingRequestIds.remove(notification.requestId);
      return;
    }

    final opensImageToVideo = notification.type == 'create_image_to_video';
    final route = MaterialPageRoute<void>(
      builder: (_) => opensImageToVideo
          ? const ImageToVideoScreen()
          : VideoNotificationRequestScreen(notification: notification),
    );
    try {
      if (opensImageToVideo && notification.replaceCurrentRoute) {
        // Replace Splash with Home underneath the form, so Back remains useful.
        unawaited(
          navigator.pushReplacement<void, void>(
            MaterialPageRoute<void>(
              builder: (_) => const MainScreen(showTrialOffer: false),
            ),
          ),
        );
        await navigator.push(route);
      } else if (notification.replaceCurrentRoute) {
        await navigator.pushReplacement(route);
      } else {
        await navigator.push(route);
      }
    } finally {
      _openingRequestIds.remove(notification.requestId);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notificationOpenSubscription?.cancel();
    VideoOnboardingActivity.stopListeningForOpens();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (AppFeatures.commerceEnabled) {
      // Start listening before purchase screens open so the active app store
      // can redeliver pending transactions from a previous session.
      ref.watch(purchaseControllerProvider);
    }
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Liora',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      navigatorObservers: <NavigatorObserver>[
        ?FirebaseService.analyticsObserver,
      ],
      home: widget.home ?? const SplashScreen(),
    );
  }
}

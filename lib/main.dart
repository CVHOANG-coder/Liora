import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import 'core/firebase/firebase_service.dart';
import 'shared/themes/app_theme.dart';
import 'presentation/screens/splash/splash_screen.dart';
import 'presentation/screens/notifications/video_notification_request_screen.dart';
import 'presentation/providers/purchase_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseService.initialize();
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

class _VideoGenAppState extends ConsumerState<VideoGenApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final Set<String> _openingRequestIds = <String>{};
  StreamSubscription<VideoNotificationOpen>? _notificationOpenSubscription;

  @override
  void initState() {
    super.initState();
    _notificationOpenSubscription = FirebaseService.notificationOpens.listen(
      (notification) => unawaited(_openVideoNotification(notification)),
    );
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

    final route = MaterialPageRoute<void>(
      builder: (_) =>
          VideoNotificationRequestScreen(notification: notification),
    );
    try {
      if (notification.replaceCurrentRoute) {
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
    _notificationOpenSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Start listening before the purchase screens open so Google Play can
    // redeliver pending purchases from a previous app session.
    ref.watch(purchaseControllerProvider);
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Nostalia: AI Video Generator',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      navigatorObservers: [?FirebaseService.analyticsObserver],
      home: widget.home ?? const SplashScreen(),
    );
  }
}

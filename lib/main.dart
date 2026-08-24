import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import 'core/firebase/firebase_service.dart';
import 'shared/themes/app_theme.dart';
import 'presentation/screens/splash/splash_screen.dart';
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

class VideoGenApp extends ConsumerWidget {
  const VideoGenApp({super.key, this.home});

  final Widget? home;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Start listening before the purchase screens open so Google Play can
    // redeliver pending purchases from a previous app session.
    ref.watch(purchaseControllerProvider);
    return MaterialApp(
      title: 'Nostalia: AI Video Generator',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      navigatorObservers: [?FirebaseService.analyticsObserver],
      home: home ?? const SplashScreen(),
    );
  }
}

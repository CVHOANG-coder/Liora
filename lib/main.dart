import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'shared/themes/app_theme.dart';
import 'presentation/screens/onboarding/onboarding_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const VideoGenApp());
}

class VideoGenApp extends StatelessWidget {
  const VideoGenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VideoGen',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const OnboardingScreen(),
    );
  }
}

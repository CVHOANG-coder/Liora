import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../../core/analytics/meta_app_events_service.dart';
import '../../../core/firebase/firebase_service.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/storage/onboarding_preferences.dart';
import '../../providers/profile_provider.dart';
import '../../providers/package_provider.dart';
import '../in_app_purchase/all_plans_screen.dart';
import '../main/main_screen.dart';
import '../onboarding/onboarding_screen.dart';
import '../support/support_contact_screen.dart';

typedef SplashBootstrap = Future<void> Function();

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({
    super.key,
    this.duration = const Duration(milliseconds: 2200),
    this.bootstrap,
    this.onboardingPreferences,
  });

  final Duration duration;
  final SplashBootstrap? bootstrap;
  final OnboardingPreferences? onboardingPreferences;

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final OnboardingPreferences _onboardingPreferences;
  bool _isAuthenticating = true;
  String? _errorMessage;
  String? _errorCode;
  int _repeatableSystemFailureCount = 0;

  @override
  void initState() {
    super.initState();
    _onboardingPreferences =
        widget.onboardingPreferences ??
        SharedPreferencesOnboardingPreferences();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    WidgetsBinding.instance.addPostFrameCallback((_) => _authenticate());
  }

  Future<void> _authenticate() async {
    setState(() {
      _isAuthenticating = true;
      _errorMessage = null;
      _errorCode = null;
    });

    _controller.reset();
    final loadingAnimation = _controller.animateTo(
      0.82,
      duration: widget.duration,
      curve: Curves.easeOutCubic,
    );

    try {
      if (widget.bootstrap case final bootstrap?) {
        await bootstrap();
      } else {
        final profile = await ApiClient.instance.bootstrapSession();
        ref.read(profileProvider.notifier).setProfile(profile);
        await FirebaseService.subscribeToUserTopic(profile.userCode);
        try {
          final catalog = await ApiClient.instance.fetchPackages();
          ref.read(packageCatalogProvider.notifier).setCatalog(catalog);
        } catch (_) {
          // Package pricing has local fallbacks and must not block app startup.
        }
      }

      if (!mounted) return;
      await loadingAnimation.orCancel;
      await _controller.animateTo(
        1,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
      if (!mounted) return;
      // The first frame is visible and no notification prompt is open yet.
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        await MetaAppEventsService.instance.requestTrackingAuthorization();
      }
      if (!mounted) return;
      final openedNotification =
          FirebaseService.markNotificationNavigationReady();
      if (!openedNotification) {
        final onboardingCompleted = await _hasCompletedOnboarding();
        if (onboardingCompleted) {
          _openMain();
        } else {
          _openOnboarding();
        }
      }
    } on TickerCanceled {
      return;
    } catch (error) {
      if (!mounted) return;
      _controller.stop();
      final errorCode = error is ApiException ? error.errorCode : null;
      if (errorCode == ApiErrorCode.userNotFound ||
          errorCode == ApiErrorCode.internalError) {
        _repeatableSystemFailureCount += 1;
      } else {
        _repeatableSystemFailureCount = 0;
      }
      setState(() {
        _isAuthenticating = false;
        _errorCode = errorCode;
        _errorMessage = error is ApiException
            ? apiErrorDisplayMessage(
                error,
                fallbackMessage: 'Unable to sign in. Please try again.',
              )
            : 'Unable to sign in. Please try again.';
      });
    }
  }

  Future<bool> _hasCompletedOnboarding() async {
    try {
      return await _onboardingPreferences.isCompleted();
    } catch (_) {
      // A storage error should not prevent the user from entering the app.
      return false;
    }
  }

  void _openMain() {
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const MainScreen()),
    );
  }

  void _openErrorAction() {
    switch (_errorCode) {
      case ApiErrorCode.accountBanned:
        _openSupport();
      case ApiErrorCode.subscriptionExpired:
        Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const AllPlans()));
      default:
        _authenticate();
    }
  }

  void _openSupport() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SupportContactScreen(
          errorCode: _errorCode,
          errorMessage: _errorMessage,
        ),
      ),
    );
  }

  void _openOnboarding() {
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (_, animation, secondaryAnimation) =>
            const OnboardingScreen(),
        transitionsBuilder: (_, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 450),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Color(0xFF03020A),
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF03020A),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final size = constraints.biggest;
            return Stack(
              fit: StackFit.expand,
              children: [
                _SplashArtwork(size: size, compact: !_isAuthenticating),
                _SplashContent(
                  size: size,
                  progress: _controller,
                  isAuthenticating: _isAuthenticating,
                  errorMessage: _errorMessage,
                  errorCode: _errorCode,
                  showSupport:
                      _repeatableSystemFailureCount >= 3 ||
                      _errorCode == ApiErrorCode.accountBanned,
                  onPrimaryAction: _openErrorAction,
                  onContactSupport: _openSupport,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// Limit the composition by height as well as width on landscape/tablet layouts.
double _splashLayoutWidth(Size size) =>
    size.width.clamp(0.0, size.height * 941 / 1672);

const _splashGradient = LinearGradient(
  colors: [Color(0xFFEC5FB6), Color(0xFFB14DE4), Color(0xFF5B5FF4)],
);

class _SplashArtwork extends StatelessWidget {
  const _SplashArtwork({required this.size, required this.compact});

  final Size size;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final width = _splashLayoutWidth(size);
    final artworkWidth = width * (compact ? 0.56 : 0.66);
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Color(0xFF03020A)),
          Positioned(
            left: (size.width - width) / 2,
            top: size.height * (compact ? 0.1 : 0.2),
            width: width,
            height: size.height * 0.53,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    Color(0x553C1A64),
                    Color(0x182B134B),
                    Colors.transparent,
                  ],
                  stops: [0, 0.5, 1],
                  radius: 0.65,
                ),
              ),
            ),
          ),
          CustomPaint(painter: _SplashStarsPainter()),
          Positioned(
            top: size.height * (compact ? 0.17 : 0.272),
            left: (size.width - artworkWidth) / 2,
            width: artworkWidth,
            height: artworkWidth * 1040 / 1027,
            child: Image.asset(
              'assets/images/splash_icon.png',
              key: const Key('splashArtwork'),
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              excludeFromSemantics: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _SplashStarsPainter extends CustomPainter {
  static const _stars = [
    Offset(0.25, 0.225),
    Offset(0.31, 0.245),
    Offset(0.44, 0.24),
    Offset(0.68, 0.222),
    Offset(0.79, 0.235),
    Offset(0.19, 0.294),
    Offset(0.77, 0.282),
    Offset(0.21, 0.358),
    Offset(0.145, 0.388),
    Offset(0.2, 0.453),
    Offset(0.215, 0.505),
    Offset(0.77, 0.484),
    Offset(0.83, 0.441),
    Offset(0.29, 0.576),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final width = _splashLayoutWidth(size);
    final scale = width / 393;
    final left = (size.width - width) / 2;
    for (var index = 0; index < _stars.length; index++) {
      final star = _stars[index];
      final center = Offset(left + star.dx * width, star.dy * size.height);
      final bright = index == 8 || index == 9 || index == 11;
      final radius = (bright ? 1.2 : 0.6) * scale;
      canvas.drawCircle(
        center,
        radius * 2,
        Paint()
          ..color = Color(bright ? 0x447D4CA4 : 0x225E3989)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2 * scale),
      );
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = Color(bright ? 0xB9C08AE1 : 0x59684691)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 0.7 * scale),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SplashStarsPainter oldDelegate) => false;
}

class _SplashContent extends StatelessWidget {
  const _SplashContent({
    required this.size,
    required this.progress,
    required this.isAuthenticating,
    required this.errorMessage,
    required this.errorCode,
    required this.showSupport,
    required this.onPrimaryAction,
    required this.onContactSupport,
  });

  final Size size;
  final Animation<double> progress;
  final bool isAuthenticating;
  final String? errorMessage;
  final String? errorCode;
  final bool showSupport;
  final VoidCallback onPrimaryAction;
  final VoidCallback onContactSupport;

  @override
  Widget build(BuildContext context) {
    final width = _splashLayoutWidth(size);
    final scale = width / 393;
    final titleSize = width * (isAuthenticating ? 0.18 : 0.14);
    final footerWidth = width * 0.68;
    final safeBottom = MediaQuery.paddingOf(context).bottom;

    return Stack(
      children: [
        Positioned(
          left: (size.width - width * 0.9) / 2,
          width: width * 0.9,
          top: size.height * (isAuthenticating ? 0.669 : 0.56),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: ShaderMask(
                  blendMode: BlendMode.srcIn,
                  shaderCallback: _splashGradient.createShader,
                  child: Text(
                    'Liora',
                    key: const Key('splashTitle'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Times New Roman',
                      fontFamilyFallback: const ['Times', 'serif'],
                      fontSize: titleSize,
                      height: 1,
                      fontWeight: FontWeight.w400,
                      letterSpacing: -0.7 * scale,
                    ),
                  ),
                ),
              ),
              SizedBox(height: size.height * 0.009),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Create cinematic AI videos',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: const Color(0xFF9C99A6),
                    fontSize: 13.4 * scale,
                    height: 1.2,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.6 * scale,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (isAuthenticating)
          Positioned(
            left: (size.width - footerWidth) / 2,
            width: footerWidth,
            // Keep the loader clear of system navigation on short devices.
            bottom: (size.height * 0.067).clamp(safeBottom + 8, size.height),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: progress,
                  builder: (context, child) => _GradientProgressBar(
                    progress: progress.value,
                    scale: scale,
                  ),
                ),
                SizedBox(height: size.height * 0.026),
                Text(
                  'Loading...',
                  key: const Key('splashLoadingLabel'),
                  style: TextStyle(
                    color: const Color(0xFF8171B2),
                    fontSize: 12 * scale,
                    height: 1.3,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 3.5 * scale,
                  ),
                ),
              ],
            ),
          )
        else
          Positioned(
            left: (size.width - width * 0.84) / 2,
            width: width * 0.84,
            top: size.height * 0.735,
            bottom: safeBottom + 12,
            child: SingleChildScrollView(
              key: const Key('splashErrorScroll'),
              child: Column(
                children: [
                  Text(
                    errorMessage ?? 'Unable to connect to the server.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFD6CFDE),
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    key: const Key('splashRetryButton'),
                    onPressed: onPrimaryAction,
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFEC5FB6),
                    ),
                    child: Text(switch (errorCode) {
                      ApiErrorCode.accountBanned => 'Contact Support',
                      ApiErrorCode.subscriptionExpired => 'Renew Plan',
                      _ => 'Retry',
                    }),
                  ),
                  if (showSupport && errorCode != ApiErrorCode.accountBanned)
                    TextButton(
                      onPressed: onContactSupport,
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFBEB8C8),
                      ),
                      child: const Text('Contact Support'),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _GradientProgressBar extends StatelessWidget {
  const _GradientProgressBar({required this.progress, required this.scale});

  final double progress;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final value = progress.clamp(0.0, 1.0);
    final dotSize = 11 * scale;
    return Semantics(
      label: 'Loading',
      value: '${(value * 100).round()}%',
      child: SizedBox(
        key: const Key('splashProgress'),
        height: dotSize,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final fillWidth = constraints.maxWidth * value;
            return Stack(
              alignment: Alignment.centerLeft,
              clipBehavior: Clip.none,
              children: [
                Container(
                  key: const Key('splashProgressTrack'),
                  height: 5.5 * scale,
                  decoration: BoxDecoration(
                    color: const Color(0xFF252432),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                Container(
                  key: const Key('splashProgressFill'),
                  width: fillWidth,
                  height: 5.5 * scale,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(99),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFEE3ECD),
                        Color(0xFFAD45F4),
                        Color(0xFF4366FF),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0x339C3FEA),
                        blurRadius: 8 * scale,
                      ),
                    ],
                  ),
                ),
                if (value > 0)
                  Positioned(
                    // Follow the fill all the way to completion, keeping the
                    // dot inside the track at either end.
                    left: (fillWidth - dotSize / 2).clamp(
                      0.0,
                      (constraints.maxWidth - dotSize).clamp(
                        0.0,
                        double.infinity,
                      ),
                    ),
                    child: Container(
                      key: const Key('splashProgressHighlight'),
                      width: dotSize,
                      height: dotSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xE4A254FB),
                            blurRadius: 8 * scale,
                            spreadRadius: 2 * scale,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

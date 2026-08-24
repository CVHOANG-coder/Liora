import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

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

      await loadingAnimation.orCancel;
      await _controller.animateTo(
        1,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
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
      _controller.stop();
      if (!mounted) return;
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
                _SplashArtwork(size: size),
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

class _SplashArtwork extends StatelessWidget {
  const _SplashArtwork({required this.size});

  final Size size;

  @override
  Widget build(BuildContext context) {
    // The source artwork intentionally includes generous dark space above and
    // below the logo. Shifting it upward reproduces the reference composition
    // while keeping it responsive on taller and shorter phones.
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Color(0xFF03020A)),
        Transform.translate(
          offset: Offset(0, -size.height * 0.17),
          child: Image.asset(
            'assets/images/bg_splash.png',
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            filterQuality: FilterQuality.high,
          ),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.transparent,
                Color(0x1703020A),
                Color(0xFF03020A),
              ],
              stops: [0.0, 0.66, 0.78, 1.0],
            ),
          ),
        ),
      ],
    );
  }
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
    final titleSize = (size.width * 0.135).clamp(46.0, 70.0);
    final subtitleSize = (size.width * 0.039).clamp(14.0, 20.0);

    return Stack(
      children: [
        Positioned(
          left: 20,
          right: 20,
          top: size.height * 0.655,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [
                    Color(0xFFFF35D4),
                    Color(0xFFFF397D),
                    Color(0xFFFFB044),
                  ],
                ).createShader(bounds),
                child: Text(
                  'Nostalia',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: titleSize,
                    height: 1,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -1.8,
                  ),
                ),
              ),
              SizedBox(height: size.height * 0.012),
              Text(
                'Create cinematic AI videos',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: const Color(0xFFBEB8C8),
                  fontSize: subtitleSize,
                  height: 1.2,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: size.width * 0.24,
          right: size.width * 0.24,
          top: size.height * 0.835,
          child: AnimatedBuilder(
            animation: progress,
            builder: (context, child) {
              return Column(
                children: [
                  _GradientProgressBar(progress: progress.value),
                  SizedBox(height: size.height * 0.022),
                  if (isAuthenticating)
                    const Text(
                      'Loading...',
                      style: TextStyle(
                        color: Color(0xFFE34CFF),
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 4.2,
                      ),
                    )
                  else ...[
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
                        foregroundColor: const Color(0xFFFF56D5),
                        visualDensity: VisualDensity.compact,
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
                          visualDensity: VisualDensity.compact,
                        ),
                        child: const Text('Contact Support'),
                      ),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _GradientProgressBar extends StatelessWidget {
  const _GradientProgressBar({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 10,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final indicatorX = (constraints.maxWidth - 10) * progress;
          return Stack(
            alignment: Alignment.centerLeft,
            clipBehavior: Clip.none,
            children: [
              Container(
                height: 3,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFC92CFF),
                      Color(0xFFFF329C),
                      Color(0xFFFF763B),
                    ],
                  ),
                  boxShadow: const [
                    BoxShadow(color: Color(0x99FF2FA6), blurRadius: 8),
                  ],
                ),
              ),
              Positioned(
                left: indicatorX,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFFFF3B93),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

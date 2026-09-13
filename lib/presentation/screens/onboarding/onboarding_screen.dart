import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/storage/onboarding_preferences.dart';
import '../main/main_screen.dart';

const _onboardingBackground = Color(0xFF02050C);
const _onboardingSurface = Color(0xFF0B101D);
const _onboardingAccentGradient = LinearGradient(
  colors: [AppColors.primaryDark, AppColors.primary, AppColors.accent],
  stops: [0, 0.54, 1],
);

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, this.onboardingPreferences});

  final OnboardingPreferences? onboardingPreferences;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final PageController _pageController;
  late final OnboardingPreferences _onboardingPreferences;
  int _currentPage = 0;
  bool _isCompleting = false;

  static const _pageCount = 4;

  @override
  void initState() {
    super.initState();
    _onboardingPreferences =
        widget.onboardingPreferences ??
        SharedPreferencesOnboardingPreferences();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _continue() {
    if (_currentPage < _pageCount - 1) {
      _goToPage(_currentPage + 1);
      return;
    }

    _completeOnboarding();
  }

  Future<void> _completeOnboarding() async {
    if (_isCompleting) return;
    _isCompleting = true;

    try {
      await _onboardingPreferences.markCompleted();
    } catch (_) {
      // The user can still continue if local persistence is temporarily unavailable.
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const MainScreen()),
    );
  }

  void _goToPage(int page) {
    if (page == _currentPage) return;
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _pageController,
          itemCount: _pageCount,
          pageSnapping: true,
          allowImplicitScrolling: true,
          physics: const BouncingScrollPhysics(),
          onPageChanged: (page) => setState(() => _currentPage = page),
          itemBuilder: (_, page) => switch (page) {
            0 => _WelcomePage(
              onContinue: _continue,
              isActive: _currentPage == page,
            ),
            1 => _CreativePage(
              onContinue: _continue,
              isActive: _currentPage == page,
            ),
            2 => _ImageToVideoPage(
              onContinue: _continue,
              isActive: _currentPage == page,
            ),
            _ => _FusionVideoPage(
              onContinue: _continue,
              isActive: _currentPage == page,
            ),
          },
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 24,
          child: _PageIndicator(
            activePage: _currentPage,
            pageCount: _pageCount,
            onPageSelected: _goToPage,
          ),
        ),
      ],
    );
  }
}

class _WelcomePage extends StatelessWidget {
  const _WelcomePage({required this.onContinue, required this.isActive});

  final VoidCallback onContinue;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _onboardingBackground,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _OnboardingVideo(
            assetPath: 'assets/videos/Welcome_ping_pong.mp4',
            isActive: isActive,
            key: const Key('onboardingWelcomeVideo'),
          ),
          const _ArtworkShade(),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                const Spacer(),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 22),
                  child: _WelcomeCopy(),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _GradientActionButton(
                    label: 'Get Started',
                    onPressed: onContinue,
                  ),
                ),
                const SizedBox(height: 74),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingVideo extends StatefulWidget {
  const _OnboardingVideo({
    super.key,
    required this.assetPath,
    required this.isActive,
  });

  final String assetPath;
  final bool isActive;

  @override
  State<_OnboardingVideo> createState() => _OnboardingVideoState();
}

class _OnboardingVideoState extends State<_OnboardingVideo>
    with WidgetsBindingObserver {
  late final VideoPlayerController _controller;
  var _isInitialized = false;
  var _isAppActive = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isAppActive = _canPlayForLifecycle(WidgetsBinding.instance.lifecycleState);
    _controller = VideoPlayerController.asset(widget.assetPath);
    unawaited(_initialize());
  }

  @override
  void didUpdateWidget(covariant _OnboardingVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive) unawaited(_syncPlayback());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // iOS can remain inactive briefly after Splash or a system permission
    // prompt; the video should keep playing while it is still visible.
    _isAppActive = _canPlayForLifecycle(state);
    unawaited(_syncPlayback());
  }

  static bool _canPlayForLifecycle(AppLifecycleState? state) => switch (state) {
    AppLifecycleState.paused ||
    AppLifecycleState.detached ||
    AppLifecycleState.hidden => false,
    _ => true,
  };

  Future<void> _initialize() async {
    try {
      await _controller.initialize();
      await _controller.setLooping(true);
      await _controller.setVolume(0);
      if (!mounted) return;
      setState(() => _isInitialized = true);
      await _syncPlayback();
    } catch (_) {
      // Keep onboarding usable if a device cannot decode an intro video.
    }
  }

  Future<void> _syncPlayback() async {
    if (!_isInitialized) return;
    try {
      if (widget.isActive && _isAppActive) {
        // Wait for the texture to attach before starting playback. This avoids
        // a stalled first frame when onboarding replaces the Splash route.
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted || !widget.isActive || !_isAppActive) return;
        await _controller.play();
      } else {
        await _controller.pause();
      }
    } catch (_) {
      // A page can be disposed while a platform play/pause call is pending.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) return const ColoredBox(color: Colors.black);
    final size = _controller.value.size;
    if (size.isEmpty) return const ColoredBox(color: Colors.black);

    return LayoutBuilder(
      builder: (context, constraints) {
        final videoHeight = constraints.maxWidth * size.height / size.width;
        final transitionTop = (videoHeight - 140).clamp(
          0.0,
          constraints.maxHeight,
        );

        return Stack(
          fit: StackFit.expand,
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: constraints.maxWidth,
                height: videoHeight,
                child: VideoPlayer(_controller),
              ),
            ),
            if (videoHeight < constraints.maxHeight)
              Positioned(
                top: transitionTop,
                left: 0,
                right: 0,
                height: 240,
                child: const _VideoBottomTransition(),
              ),
          ],
        );
      },
    );
  }
}

class _VideoBottomTransition extends StatelessWidget {
  const _VideoBottomTransition();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (bounds) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black],
              stops: [0.0, 0.62],
            ).createShader(bounds),
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: const ColoredBox(color: Color(0x2402050C)),
              ),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, _onboardingBackground],
                stops: [0.18, 1.0],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArtworkShade extends StatelessWidget {
  const _ArtworkShade();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.05),
              Colors.transparent,
              const Color(0xD902050C),
              _onboardingBackground,
            ],
            stops: const [0.0, 0.38, 0.70, 0.91],
          ),
        ),
      ),
    );
  }
}

class _WelcomeCopy extends StatelessWidget {
  const _WelcomeCopy();

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Welcome to ',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 38,
                      height: 1.05,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.15,
                    ),
                  ),
                  ShaderMask(
                    shaderCallback: _onboardingAccentGradient.createShader,
                    child: const Text(
                      'Liora',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 38,
                        height: 1.05,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Create stunning AI videos from text and images. 🎬',
              textAlign: TextAlign.center,
              maxLines: 1,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.25,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.15,
              ),
            ),
          ],
        ),
        const Positioned(right: 13, top: -28, child: _Sparkles()),
      ],
    );
  }
}

class _Sparkles extends StatelessWidget {
  const _Sparkles();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 38,
      height: 38,
      child: Stack(
        children: [
          const Positioned(
            left: 0,
            bottom: 0,
            child: Text(
              '✦',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 32,
                height: 1,
              ),
            ),
          ),
          const Positioned(
            right: 0,
            top: 0,
            child: Text(
              '✦',
              style: TextStyle(
                color: AppColors.accent,
                fontSize: 22,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GradientActionButton extends StatelessWidget {
  const _GradientActionButton({
    required this.label,
    required this.onPressed,
    this.showArrow = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool showArrow;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(40),
        gradient: _onboardingAccentGradient,
        boxShadow: const [
          BoxShadow(color: Color(0x99B982FF), blurRadius: 24, spreadRadius: 2),
          BoxShadow(
            color: Color(0x55FF87C8),
            blurRadius: 28,
            offset: Offset(8, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(40),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(40),
          child: Center(
            child: _ActionLabel(label: label, showArrow: showArrow),
          ),
        ),
      ),
    );
  }
}

class _ActionLabel extends StatelessWidget {
  const _ActionLabel({required this.label, required this.showArrow});

  final String label;
  final bool showArrow;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.25,
          ),
        ),
        if (showArrow) ...[
          const SizedBox(width: 12),
          const Icon(
            Icons.arrow_forward_rounded,
            size: 31,
            color: Colors.white,
          ),
        ],
      ],
    );
  }
}

class _CreativePage extends StatelessWidget {
  const _CreativePage({required this.onContinue, required this.isActive});

  final VoidCallback onContinue;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _onboardingBackground,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _OnboardingVideo(
            assetPath: 'assets/videos/T2V_OB.mp4',
            isActive: isActive,
            key: const Key('onboardingTextToVideo'),
          ),
          const _CreativeShade(),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                const Spacer(),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: _CreativeCopy(),
                ),
                // const SizedBox(height: 150),
                // const Padding(
                //   padding: EdgeInsets.symmetric(horizontal: 18),
                //   child: _FeatureGrid(),
                // ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _GradientActionButton(
                    label: 'Continue',
                    showArrow: true,
                    onPressed: onContinue,
                  ),
                ),
                const SizedBox(height: 68),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageToVideoPage extends StatelessWidget {
  const _ImageToVideoPage({required this.onContinue, required this.isActive});

  final VoidCallback onContinue;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _onboardingBackground,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _OnboardingVideo(
            assetPath: 'assets/videos/I2V_OB.mp4',
            isActive: isActive,
            key: const Key('onboardingImageToVideo'),
          ),
          const _ImageToVideoShade(),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                const Spacer(),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 22),
                  child: _ImageToVideoCopy(),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _GradientActionButton(
                    label: 'Continue',
                    showArrow: true,
                    onPressed: onContinue,
                  ),
                ),
                const SizedBox(height: 68),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageToVideoShade extends StatelessWidget {
  const _ImageToVideoShade();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.03),
              Colors.transparent,
              const Color(0xB302050C),
              const Color(0xF2070C17),
              _onboardingBackground,
            ],
            stops: const [0.0, 0.40, 0.64, 0.86, 1.0],
          ),
        ),
      ),
    );
  }
}

class _ImageToVideoCopy extends StatelessWidget {
  const _ImageToVideoCopy();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Image ',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 38,
                  height: 1.0,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.1,
                ),
              ),
              ShaderMask(
                shaderCallback: _onboardingAccentGradient.createShader,
                child: const Text(
                  'To Video',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 38,
                    height: 1.0,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.1,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Upload images, write prompt',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 16,
            height: 1.25,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _FusionVideoPage extends StatelessWidget {
  const _FusionVideoPage({required this.onContinue, required this.isActive});

  final VoidCallback onContinue;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _onboardingBackground,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _OnboardingVideo(
            assetPath: 'assets/videos/Themes2V_OB.mp4',
            isActive: isActive,
            key: const Key('onboardingThemesToVideo'),
          ),
          const _FusionVideoShade(),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                const Spacer(),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 22),
                  child: _FusionVideoCopy(),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _GradientActionButton(
                    label: 'Continue',
                    showArrow: true,
                    onPressed: onContinue,
                  ),
                ),
                const SizedBox(height: 68),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FusionVideoShade extends StatelessWidget {
  const _FusionVideoShade();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.03),
              Colors.transparent,
              const Color(0xB302050C),
              const Color(0xF2070C17),
              _onboardingBackground,
            ],
            stops: const [0.0, 0.42, 0.65, 0.86, 1.0],
          ),
        ),
      ),
    );
  }
}

class _FusionVideoCopy extends StatelessWidget {
  const _FusionVideoCopy();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FittedBox(
          key: const Key('fusionVideoTitle'),
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Fusion ',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 38,
                  height: 1.0,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.1,
                ),
              ),
              ShaderMask(
                shaderCallback: _onboardingAccentGradient.createShader,
                child: const Text(
                  'Video',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 38,
                    height: 1.0,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.1,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Blend characters, styles, and creatures\ninto one cinematic video',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 16,
            height: 1.3,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _CreativeShade extends StatelessWidget {
  const _CreativeShade();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.02),
              Colors.transparent,
              const Color(0xB302050C),
              const Color(0xF2070C17),
              _onboardingBackground,
            ],
            stops: const [0.0, 0.34, 0.63, 0.86, 1.0],
          ),
        ),
      ),
    );
  }
}

class _CreativeCopy extends StatelessWidget {
  const _CreativeCopy();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Text ',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 38,
                  height: 1.0,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.1,
                ),
              ),
              ShaderMask(
                shaderCallback: _onboardingAccentGradient.createShader,
                child: const Text(
                  'To Video',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 38,
                    height: 1.0,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.1,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),
        const Text(
          'Trending styles, and fast creative tools.',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 16,
            height: 1.35,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xCC0B101D),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x664B5677)),
      ),
      child: Column(
        children: [
          const Row(
            children: [
              Expanded(
                child: _FeatureCard(
                  title: 'Text to Video',
                  description: 'Turn ideas into short\ncinematic clips',
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _FeatureCard(
                  title: 'Image to Video',
                  description: 'Animate photos, art,\nand characters',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Row(
            children: [
              Expanded(
                child: _FeatureCard(
                  title: 'Hot Styles',
                  description: 'Explore viral looks\nand templates',
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _FeatureCard(
                  title: 'AI Tools',
                  description: 'Prompt assist, subtitles,\nand quick editing',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 76,
      decoration: BoxDecoration(
        color: _onboardingSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x66394462)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.25,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                height: 1.15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageIndicator extends StatelessWidget {
  const _PageIndicator({
    required this.activePage,
    required this.pageCount,
    required this.onPageSelected,
  });

  final int activePage;
  final int pageCount;
  final ValueChanged<int> onPageSelected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Onboarding page ${activePage + 1} of $pageCount',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(pageCount, (page) {
          final active = page == activePage;
          return Semantics(
            button: true,
            selected: active,
            label: 'Go to onboarding page ${page + 1}',
            child: GestureDetector(
              key: Key('onboardingDot$page'),
              onTap: () => onPageSelected(page),
              behavior: HitTestBehavior.opaque,
              child: SizedBox(
                width: 24,
                height: 32,
                child: Center(child: _IndicatorDot(active: active)),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _IndicatorDot extends StatelessWidget {
  const _IndicatorDot({this.active = false});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: active ? AppColors.primary : AppColors.divider,
        shape: BoxShape.circle,
        boxShadow: active
            ? const [BoxShadow(color: Color(0xAAB982FF), blurRadius: 10)]
            : null,
      ),
    );
  }
}

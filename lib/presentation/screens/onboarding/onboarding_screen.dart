import 'package:flutter/material.dart';

import '../../../core/storage/onboarding_preferences.dart';
import '../main/main_screen.dart';

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
            0 => _WelcomePage(onContinue: _continue),
            1 => _CreativePage(onContinue: _continue),
            2 => _ImageToVideoPage(onContinue: _continue),
            _ => _FusionVideoPage(onContinue: _continue),
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
  const _WelcomePage({required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Image(
            image: AssetImage('assets/images/on_boarding/bg1.png'),
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
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
              const Color(0xD9090810),
              const Color(0xFF09080F),
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
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [
                        Color(0xFFFF149D),
                        Color(0xFFFF3B6B),
                        Color(0xFFFFA30F),
                      ],
                    ).createShader(bounds),
                    child: const Text(
                      'Nostalia',
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
                color: Color(0xFFD0CDD5),
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
                color: Color(0xFFFFA30F),
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
                color: Color(0xFFFF229C),
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
        gradient: const LinearGradient(
          colors: [Color(0xFFFF0B9F), Color(0xFFFF3D64), Color(0xFFFFA20E)],
          stops: [0.0, 0.56, 1.0],
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x99FF0B9F), blurRadius: 24, spreadRadius: 2),
          BoxShadow(
            color: Color(0x55FF7E19),
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
  const _CreativePage({required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF08070E),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Image(
            image: AssetImage('assets/images/on_boarding/bg2.png'),
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
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
                const SizedBox(height: 22),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 18),
                  child: _FeatureGrid(),
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

class _ImageToVideoPage extends StatelessWidget {
  const _ImageToVideoPage({required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF08070E),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Image(
            image: AssetImage('assets/images/on_boarding/bg3.png'),
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
          const _ImageToVideoShade(),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                const Spacer(),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: _ImageToVideoArtwork(),
                ),
                const SizedBox(height: 25),
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
              const Color(0xB5080710),
              const Color(0xF5080710),
              const Color(0xFF08070E),
            ],
            stops: const [0.0, 0.40, 0.64, 0.86, 1.0],
          ),
        ),
      ),
    );
  }
}

class _ImageToVideoArtwork extends StatelessWidget {
  const _ImageToVideoArtwork();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/on_boarding/item_slide3.png',
      width: double.infinity,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
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
                '2 Image ',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 38,
                  height: 1.0,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.1,
                ),
              ),
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [
                    Color(0xFFFF119D),
                    Color(0xFFFF5663),
                    Color(0xFFFFA20D),
                  ],
                ).createShader(bounds),
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
          'Upload 2 images, write prompt',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFFD0CDD5),
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
  const _FusionVideoPage({required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF08070E),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Image(
            image: AssetImage('assets/images/on_boarding/bg5.png'),
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
          const _FusionVideoShade(),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                const Spacer(),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: _FusionVideoArtwork(),
                ),
                const SizedBox(height: 24),
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
              const Color(0xB5080710),
              const Color(0xF5080710),
              const Color(0xFF08070E),
            ],
            stops: const [0.0, 0.42, 0.65, 0.86, 1.0],
          ),
        ),
      ),
    );
  }
}

class _FusionVideoArtwork extends StatelessWidget {
  const _FusionVideoArtwork();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/on_boarding/item_slide5.png',
      width: double.infinity,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
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
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [
                    Color(0xFFFF119D),
                    Color(0xFFFF5663),
                    Color(0xFFFFA20D),
                  ],
                ).createShader(bounds),
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
            color: Color(0xFFD0CDD5),
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
              const Color(0xB7080710),
              const Color(0xF4080710),
              const Color(0xFF08070E),
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Create AI',
          style: TextStyle(
            color: Colors.white,
            fontSize: 38,
            height: 1.0,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.05,
          ),
        ),
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFFFF119D), Color(0xFFFF5663), Color(0xFFFFA20D)],
          ).createShader(bounds),
          child: const Text(
            'videos your way',
            style: TextStyle(
              color: Colors.white,
              fontSize: 38,
              height: 1.0,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.05,
            ),
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Text to video, image to video, trending styles,\nand fast creative tools.',
          style: TextStyle(
            color: Color(0xFFD0CDD5),
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
        color: const Color(0x661C1724),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x663E3447)),
      ),
      child: Column(
        children: [
          const Row(
            children: [
              Expanded(
                child: _FeatureCard(
                  iconAsset: 'assets/images/on_boarding/text_to_image.png',
                  title: 'Text to Video',
                  description: 'Turn ideas into short\ncinematic clips',
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _FeatureCard(
                  iconAsset: 'assets/images/on_boarding/image_to_video.png',
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
                  iconAsset: 'assets/images/on_boarding/hot_style.png',
                  title: 'Hot Styles',
                  description: 'Explore viral looks\nand templates',
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _FeatureCard(
                  iconAsset: 'assets/images/on_boarding/AI_tool.png',
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
  const _FeatureCard({
    required this.iconAsset,
    required this.title,
    required this.description,
  });

  final String iconAsset;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0x54130F1B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x332C2435)),
      ),
      child: Row(
        children: [
          Image.asset(iconAsset, width: 60, height: 60),
          const SizedBox(width: 8),
          Expanded(
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
                    color: Color(0xFFBDB8C4),
                    fontSize: 11,
                    height: 1.15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
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
        color: active ? const Color(0xFFFF159D) : const Color(0xFF47464D),
        shape: BoxShape.circle,
        boxShadow: active
            ? const [BoxShadow(color: Color(0xAAFF159D), blurRadius: 10)]
            : null,
      ),
    );
  }
}

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../../core/media/video_cache_service.dart';
import '../../../data/video_categories.dart';
import '../../widgets/cached_video_thumbnail.dart';
import '../theme_to_video/theme_to_video_screen.dart';

const _detailBackground = Color(0xFF030611);
const _pink = Color(0xFFED58BD);
const _outlineGradient = LinearGradient(
  colors: [Color(0xFFEFA1CF), Color(0xFF9D60EB), Color(0xFF87A9FF)],
);

class VideoDetailScreen extends StatefulWidget {
  const VideoDetailScreen({super.key, required this.post});

  final VideoPost post;

  @override
  State<VideoDetailScreen> createState() => _VideoDetailScreenState();
}

class _VideoDetailScreenState extends State<VideoDetailScreen> {
  bool _isMuted = true;

  void _useTemplate() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ThemeToVideoScreen(theme: widget.post),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: _detailBackground,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: _detailBackground,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final scale = (constraints.maxWidth / 393).clamp(0.8, 1.3);
            return DecoratedBox(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.1),
                  radius: 1.1,
                  colors: [Color(0xFF0D0A24), _detailBackground],
                ),
              ),
              child: SafeArea(
                minimum: EdgeInsets.only(bottom: 30 * scale),
                child: Padding(
                  padding: EdgeInsets.only(top: 16 * scale),
                  child: Column(
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 19 * scale),
                        child: _DetailHeader(
                          scale: scale,
                          isMuted: _isMuted,
                          onBack: () => Navigator.maybePop(context),
                          onToggleMute: () =>
                              setState(() => _isMuted = !_isMuted),
                        ),
                      ),
                      SizedBox(height: 12 * scale),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 24 * scale),
                          child: _TemplatePreview(
                            post: widget.post,
                            isMuted: _isMuted,
                            scale: scale,
                          ),
                        ),
                      ),
                      SizedBox(height: 11 * scale),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24 * scale),
                        child: _GradientButton(
                          scale: scale,
                          onPressed: _useTemplate,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({
    required this.scale,
    required this.isMuted,
    required this.onBack,
    required this.onToggleMute,
  });

  final double scale;
  final bool isMuted;
  final VoidCallback onBack;
  final VoidCallback onToggleMute;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const Key('videoDetailHeader'),
      height: (44 * scale).clamp(44.0, double.infinity),
      child: Row(
        children: [
          _RoundButton(
            key: const Key('videoDetailBackButton'),
            icon: Icons.arrow_back_ios_new_rounded,
            label: 'Back',
            scale: scale,
            onTap: onBack,
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 10 * scale),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/images/home/lola_logo.png',
                      width: 22 * scale,
                      height: 23 * scale,
                      fit: BoxFit.contain,
                      excludeFromSemantics: true,
                    ),
                    SizedBox(width: 8 * scale),
                    Text.rich(
                      const TextSpan(
                        text: 'Liora',
                        children: [
                          TextSpan(
                            text: ' AI',
                            style: TextStyle(color: _pink),
                          ),
                        ],
                      ),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14 * scale,
                        height: 1.2,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2 * scale,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _RoundButton(
            key: const Key('videoMuteButton'),
            icon: isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
            label: isMuted ? 'Turn sound on' : 'Mute',
            scale: scale,
            onTap: onToggleMute,
          ),
        ],
      ),
    );
  }
}

class _TemplatePreview extends StatelessWidget {
  const _TemplatePreview({
    required this.post,
    required this.isMuted,
    required this.scale,
  });

  final VideoPost post;
  final bool isMuted;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final radius = 22 * scale;
    return Container(
      key: const Key('videoDetailFrame'),
      padding: const EdgeInsets.all(0.6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: _outlineGradient,
        boxShadow: [
          BoxShadow(
            color: const Color(0x29BA49BA),
            blurRadius: 22 * scale,
            offset: Offset(-4 * scale, 0),
          ),
          BoxShadow(
            color: const Color(0x234541D1),
            blurRadius: 22 * scale,
            offset: Offset(4 * scale, 0),
          ),
        ],
      ),
      child: Container(
        padding: EdgeInsets.all(8 * scale - 0.6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius - 0.6),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF190C24), Color(0xFF080B21), Color(0xFF0B081E)],
          ),
        ),
        child: ClipRRect(
          key: const Key('videoDetailMedia'),
          borderRadius: BorderRadius.circular(14 * scale),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _VideoCover(post: post, isMuted: isMuted),
              const IgnorePointer(child: _ScreenOverlay()),
              Positioned(
                left: 11 * scale,
                right: 31 * scale,
                bottom: 10 * scale,
                child: _BottomDetails(post: post, scale: scale),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VideoCover extends StatefulWidget {
  const _VideoCover({required this.post, required this.isMuted});

  final VideoPost post;
  final bool isMuted;

  @override
  State<_VideoCover> createState() => _VideoCoverState();
}

class _VideoCoverState extends State<_VideoCover> with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  bool _isReady = false;
  bool _pausedByUser = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    final videoUrl = widget.post.videoUrl;
    if (videoUrl == null || videoUrl.isEmpty) return;

    final uri = Uri.tryParse(videoUrl);
    if (uri == null) return;

    final controller = await VideoCacheService.instance.createController(
      uri,
      cacheKey: 'template:${widget.post.id}',
    );
    if (!mounted) {
      await controller.dispose();
      return;
    }
    _controller = controller;

    try {
      await controller.initialize();
      if (!mounted || !identical(_controller, controller)) return;

      await controller.setLooping(true);
      await controller.setVolume(widget.isMuted ? 0 : 1);
      await controller.play();

      if (mounted) setState(() => _isReady = true);
    } catch (_) {
      if (identical(_controller, controller)) {
        _controller = null;
        await controller.dispose();
      }
    }
  }

  @override
  void didUpdateWidget(covariant _VideoCover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isMuted != widget.isMuted) {
      _controller?.setVolume(widget.isMuted ? 0 : 1);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (!_isReady || controller == null) return;

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      controller.pause();
    } else if (state == AppLifecycleState.resumed && !_pausedByUser) {
      controller.play();
    }
  }

  void _togglePlayback() {
    final controller = _controller;
    if (!_isReady || controller == null) return;

    setState(() {
      if (controller.value.isPlaying) {
        controller.pause();
        _pausedByUser = true;
      } else {
        controller.play();
        _pausedByUser = false;
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final controller = _controller;
    _controller = null;
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: 'video_${widget.post.id}',
      child: GestureDetector(
        onTap: _togglePlayback,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedVideoThumbnail(
              cacheKey: 'template:${widget.post.id}',
              imageUrl: widget.post.thumbnailUrl ?? '',
              videoUrl: widget.post.videoUrl ?? '',
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
              maxDecodeWidth: 1080,
              placeholder: const ColoredBox(
                color: Color(0xFF171016),
                child: Center(
                  child: Icon(
                    Icons.movie_creation_outlined,
                    color: Color(0xFF837680),
                    size: 46,
                  ),
                ),
              ),
              errorWidget: const ColoredBox(
                color: Color(0xFF171016),
                child: Center(
                  child: Icon(
                    Icons.image_not_supported_outlined,
                    color: Color(0xFF837680),
                    size: 46,
                  ),
                ),
              ),
            ),
            if (_isReady) _CoverVideo(controller: _controller!),
            if (_isReady && !(_controller?.value.isPlaying ?? false))
              const Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0x99000000),
                  ),
                  child: SizedBox.square(
                    dimension: 62,
                    child: Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CoverVideo extends StatelessWidget {
  const _CoverVideo({required this.controller});

  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    final size = controller.value.size;

    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: VideoPlayer(controller),
        ),
      ),
    );
  }
}

class _ScreenOverlay extends StatelessWidget {
  const _ScreenOverlay();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.transparent,
            Color(0x6B060515),
            Color(0xF5060515),
            Color(0xFF060515),
          ],
          stops: [0, 0.63, 0.75, 0.88, 1],
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    super.key,
    required this.icon,
    required this.label,
    required this.scale,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final double scale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: (44 * scale).clamp(44.0, double.infinity),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Center(
              child: Container(
                width: 38 * scale,
                height: 38 * scale,
                padding: const EdgeInsets.all(0.6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: _outlineGradient,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0x535C3191),
                      blurRadius: 12 * scale,
                    ),
                  ],
                ),
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF25102D), Color(0xFF0A0C25)],
                    ),
                  ),
                  child: Icon(icon, size: 19 * scale, color: Colors.white),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomDetails extends StatelessWidget {
  const _BottomDetails({required this.post, required this.scale});

  final VideoPost post;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('videoDetailMetadata'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ThemeDescription(description: post.description, scale: scale),
        SizedBox(height: 8 * scale),
        _GlassPill(
          key: const Key('videoDetailAudio'),
          scale: scale,
          child: Row(
            children: [
              Icon(
                Icons.music_note_rounded,
                color: const Color(0xFFD168EB),
                size: 20 * scale,
              ),
              SizedBox(width: 9 * scale),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Original audio from Liora AI',
                    maxLines: 1,
                    style: TextStyle(
                      color: const Color(0xFFF3EAF7),
                      fontSize: 12 * scale,
                      height: 1.2,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.2 * scale,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12 * scale),
              Container(
                width: 0.5,
                height: 18 * scale,
                color: const Color(0xFF81758E),
              ),
              SizedBox(width: 12 * scale),
              Icon(
                Icons.graphic_eq_rounded,
                color: const Color(0xFFB04BF2),
                size: 22 * scale,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ThemeDescription extends StatelessWidget {
  const _ThemeDescription({required this.description, required this.scale});

  final String description;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final label = description.trim().isEmpty
        ? 'AI video template'
        : description.trim();

    return _GlassPill(
      key: const Key('videoDetailTemplateName'),
      compact: true,
      scale: scale,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome_rounded, color: _pink, size: 18 * scale),
          SizedBox(width: 8 * scale),
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: 13 * scale,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassPill extends StatelessWidget {
  const _GlassPill({
    super.key,
    required this.child,
    required this.scale,
    this.compact = false,
  });

  final Widget child;
  final double scale;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(24 * scale);
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 9, sigmaY: 9),
        child: Container(
          padding: const EdgeInsets.all(0.5),
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              colors: [
                const Color(0xFFF455A3),
                const Color(0xFFB455DE),
                compact ? const Color(0xFFC875E6) : const Color(0xFF7789F7),
              ],
            ),
          ),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: 12 * scale,
              vertical: (compact ? 6.5 : 7.5) * scale,
            ),
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF200D26),
                  Color(0xFF140B23),
                  Color(0xFF0A0D21),
                ],
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({required this.onPressed, required this.scale});

  final VoidCallback onPressed;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final radius = 30 * scale;
    return Container(
      key: const Key('videoDetailCta'),
      width: double.infinity,
      height: 56 * scale,
      padding: const EdgeInsets.all(0.8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: const LinearGradient(
          colors: [Color(0xFFFFDEEF), Color(0xFFF4B5F3), Color(0xFF99BDFF)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0x7AFB269E),
            blurRadius: 22 * scale,
            offset: Offset(-10 * scale, 0),
          ),
          BoxShadow(
            color: const Color(0x735451F4),
            blurRadius: 22 * scale,
            offset: Offset(10 * scale, 0),
          ),
        ],
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius - 0.8),
          gradient: const LinearGradient(
            colors: [Color(0xFFFF349F), Color(0xFFA244C5), Color(0xFF285CF1)],
          ),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(radius - 0.8),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: const Key('useVideoTemplateButton'),
            onTap: onPressed,
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16 * scale),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Use AI Template',
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'Times New Roman',
                          fontFamilyFallback: const ['Times', 'serif'],
                          fontSize: 21 * scale,
                          height: 1.15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2 * scale,
                          shadows: const [
                            Shadow(color: Color(0x33000000), blurRadius: 3),
                          ],
                        ),
                      ),
                      SizedBox(width: 6 * scale),
                      ExcludeSemantics(
                        child: Icon(
                          Icons.auto_awesome_rounded,
                          color: const Color(0xFFFFD54A),
                          size: 22 * scale,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

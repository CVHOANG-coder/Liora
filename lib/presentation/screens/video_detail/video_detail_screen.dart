import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../../data/video_categories.dart';
import '../theme_to_video/theme_to_video_screen.dart';

const _pink = Color(0xFFFF28A9);

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
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            _VideoCover(post: widget.post, isMuted: _isMuted),
            const _ScreenOverlay(),
            SafeArea(
              minimum: const EdgeInsets.fromLTRB(18, 10, 18, 12),
              child: Stack(
                children: [
                  Align(
                    alignment: Alignment.topCenter,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _RoundButton(
                          key: const Key('videoDetailBackButton'),
                          icon: Icons.arrow_back_ios_new_rounded,
                          label: 'Back',
                          onTap: () => Navigator.maybePop(context),
                        ),
                        _RoundButton(
                          key: const Key('videoMuteButton'),
                          icon: _isMuted
                              ? Icons.volume_off_rounded
                              : Icons.volume_up_rounded,
                          label: _isMuted ? 'Turn sound on' : 'Mute',
                          onTap: () => setState(() => _isMuted = !_isMuted),
                        ),
                      ],
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: _BottomDetails(
                      post: widget.post,
                      onUseTemplate: _useTemplate,
                    ),
                  ),
                ],
              ),
            ),
          ],
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

    final controller = VideoPlayerController.networkUrl(uri);
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
            Image.network(
              widget.post.thumbnailUrl!,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return const ColoredBox(
                  color: Color(0xFF171016),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: _pink,
                      strokeWidth: 2,
                    ),
                  ),
                );
              },
              errorBuilder: (_, _, _) => const ColoredBox(
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
            Color(0x8F050006),
            Color(0x08000000),
            Color(0x14000000),
            Color(0xEE09020C),
            Colors.black,
          ],
          stops: [0, 0.18, 0.49, 0.82, 1],
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
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0x7A050208),
          border: Border.all(color: const Color(0xFF817B83), width: 1.2),
          boxShadow: const [
            BoxShadow(color: Color(0x66000000), blurRadius: 12),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox.square(
              dimension: 48,
              child: Icon(icon, size: 25, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomDetails extends StatelessWidget {
  const _BottomDetails({required this.post, required this.onUseTemplate});

  final VideoPost post;
  final VoidCallback onUseTemplate;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ThemeDescription(description: post.description),
        const SizedBox(height: 10),
        _GlassPill(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.music_note_rounded, color: _pink, size: 18),
              const SizedBox(width: 8),
              const Flexible(
                child: Text(
                  'Original audio from Nostalia AI',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Color(0xFFF6EAF2), fontSize: 13),
                ),
              ),
              const SizedBox(width: 10),
              Container(width: 1, height: 17, color: const Color(0xFF8C567A)),
              const SizedBox(width: 10),
              const Icon(Icons.graphic_eq_rounded, color: _pink, size: 20),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _GradientButton(onPressed: onUseTemplate),
      ],
    );
  }
}

class _ThemeDescription extends StatelessWidget {
  const _ThemeDescription({required this.description});

  final String description;

  @override
  Widget build(BuildContext context) {
    final label = description.trim().isEmpty
        ? 'AI video template'
        : description;

    return _GlassPill(
      compact: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.auto_awesome_rounded, color: _pink, size: 18),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassPill extends StatelessWidget {
  const _GlassPill({required this.child, this.compact = false});

  final Widget child;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 9, sigmaY: 9),
        child: Container(
          padding: compact
              ? const EdgeInsets.symmetric(horizontal: 12, vertical: 7)
              : const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: const Color(0x942B0921),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0x99C02579), width: 0.8),
            boxShadow: const [
              BoxShadow(color: Color(0x55FF169D), blurRadius: 14),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 64,
      padding: const EdgeInsets.all(1.4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        gradient: const LinearGradient(
          colors: [Colors.white, _pink, Color(0xFFFFC15A)],
        ),
        boxShadow: const [
          BoxShadow(color: Color(0xB8FF139B), blurRadius: 25, spreadRadius: 1),
          BoxShadow(
            color: Color(0x88FF813D),
            blurRadius: 22,
            offset: Offset(12, 4),
          ),
        ],
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(33),
          gradient: const LinearGradient(
            colors: [Color(0xFFFF00B8), Color(0xFFFF2F82), Color(0xFFFF8D2F)],
          ),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(33),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: const Key('useVideoTemplateButton'),
            onTap: onPressed,
            child: const Center(
              child: Text(
                'Use AI Template ✨',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.35,
                  shadows: [Shadow(color: Color(0x66000000), blurRadius: 5)],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

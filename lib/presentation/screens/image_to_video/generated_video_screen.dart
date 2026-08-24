import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../../core/storage/playback_preferences.dart';
import '../../../data/models/i2v_request_status.dart';
import '../../../data/services/video_download_service.dart';
import '../main/main_screen.dart';

typedef GeneratedVideoDownloader =
    Future<void> Function(
      String videoUrl,
      String requestId,
      void Function(int received, int total) onProgress,
    );

class GeneratedVideoScreen extends StatefulWidget {
  const GeneratedVideoScreen({
    super.key,
    required this.result,
    this.downloader,
    this.returnToPreviousOnBack = false,
  });

  final I2VRequestStatus result;
  final GeneratedVideoDownloader? downloader;
  final bool returnToPreviousOnBack;

  @override
  State<GeneratedVideoScreen> createState() => _GeneratedVideoScreenState();
}

class _GeneratedVideoScreenState extends State<GeneratedVideoScreen> {
  VideoPlayerController? _controller;
  bool _isReady = false;
  bool _isMuted = false;
  bool _isDownloading = false;
  double? _downloadProgress;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    final uri = Uri.tryParse(widget.result.resultUrl);
    if (uri == null || !uri.hasScheme) return;
    final controller = VideoPlayerController.networkUrl(uri);
    _controller = controller;
    try {
      await controller.initialize();
      if (!mounted || !identical(controller, _controller)) return;
      var playbackSettings = const PlaybackSettings(
        autoplayVideos: true,
        startMuted: false,
      );
      try {
        playbackSettings = await SharedPreferencesPlaybackPreferences().load();
      } catch (_) {
        // Playback should still work if local preferences are unavailable.
      }
      if (!mounted || !identical(controller, _controller)) return;
      await controller.setLooping(true);
      await controller.setVolume(playbackSettings.startMuted ? 0 : 1);
      if (playbackSettings.autoplayVideos) await controller.play();
      if (mounted) {
        setState(() {
          _isReady = true;
          _isMuted = playbackSettings.startMuted;
        });
      }
    } catch (_) {
      if (identical(controller, _controller)) _controller = null;
      await controller.dispose();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlayback() {
    final controller = _controller;
    if (!_isReady || controller == null) return;
    controller.value.isPlaying ? controller.pause() : controller.play();
  }

  Future<void> _toggleMuted() async {
    final controller = _controller;
    if (controller == null) return;
    setState(() => _isMuted = !_isMuted);
    await controller.setVolume(_isMuted ? 0 : 1);
  }

  Future<void> _downloadVideo() async {
    if (_isDownloading) return;
    setState(() {
      _isDownloading = true;
      _downloadProgress = null;
    });
    try {
      final downloader = widget.downloader ?? _defaultDownloader;
      await downloader(widget.result.resultUrl, widget.result.requestId, (
        received,
        total,
      ) {
        if (!mounted || total <= 0) return;
        setState(() => _downloadProgress = received / total);
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Video saved to your photo library.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not save the video. Please check photo permissions.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadProgress = null;
        });
      }
    }
  }

  Future<void> _defaultDownloader(
    String videoUrl,
    String requestId,
    void Function(int received, int total) onProgress,
  ) {
    return VideoDownloadService().saveToGallery(
      videoUrl: videoUrl,
      requestId: requestId,
      onProgress: onProgress,
    );
  }

  void _leaveScreen() {
    if (_leaving) return;
    _leaving = true;
    if (widget.returnToPreviousOnBack) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) =>
            const MainScreen(initialIndex: 1, showTrialOffer: false),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: widget.returnToPreviousOnBack,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _leaveScreen();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
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
              _VideoSurface(
                controller: _controller,
                isReady: _isReady,
                fallbackImage: widget.result.thumbnailUrl.isNotEmpty
                    ? widget.result.thumbnailUrl
                    : widget.result.imageUrl,
                onTap: _togglePlayback,
              ),
              const _VideoOverlay(),
              SafeArea(
                minimum: const EdgeInsets.fromLTRB(18, 10, 18, 20),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _RoundAction(
                          key: const Key('generatedVideoBack'),
                          icon: Icons.arrow_back_ios_new_rounded,
                          onTap: _leaveScreen,
                        ),
                        const Text(
                          'Your Video',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        _RoundAction(
                          icon: _isMuted
                              ? Icons.volume_off_rounded
                              : Icons.volume_up_rounded,
                          onTap: _toggleMuted,
                        ),
                      ],
                    ),
                    const Spacer(),
                    if (_isReady && _controller != null)
                      ValueListenableBuilder<VideoPlayerValue>(
                        valueListenable: _controller!,
                        builder: (context, value, _) => IgnorePointer(
                          ignoring: value.isPlaying,
                          child: AnimatedOpacity(
                            opacity: value.isPlaying ? 0 : 1,
                            duration: const Duration(milliseconds: 180),
                            child: _CenterPlayButton(onTap: _togglePlayback),
                          ),
                        ),
                      ),
                    const Spacer(),
                    _PlaybackControls(
                      controller: _controller,
                      isReady: _isReady,
                      onTogglePlayback: _togglePlayback,
                      isDownloading: _isDownloading,
                      downloadProgress: _downloadProgress,
                      onDownload: _downloadVideo,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VideoSurface extends StatelessWidget {
  const _VideoSurface({
    required this.controller,
    required this.isReady,
    required this.fallbackImage,
    required this.onTap,
  });

  final VideoPlayerController? controller;
  final bool isReady;
  final String fallbackImage;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ColoredBox(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (fallbackImage.isNotEmpty)
              Image.network(
                fallbackImage,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            if (isReady && controller != null)
              Center(
                child: AspectRatio(
                  aspectRatio: controller!.value.aspectRatio,
                  child: VideoPlayer(controller!),
                ),
              )
            else
              const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFFFF35AD),
                  strokeWidth: 2.5,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _VideoOverlay extends StatelessWidget {
  const _VideoOverlay();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x88000000), Colors.transparent, Color(0xDD050208)],
          stops: [0, 0.55, 1],
        ),
      ),
    );
  }
}

class _CenterPlayButton extends StatelessWidget {
  const _CenterPlayButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xB30A070D),
        border: Border.all(color: const Color(0xCCFFFFFF)),
        boxShadow: const [BoxShadow(color: Color(0x77FF2BA7), blurRadius: 24)],
      ),
      child: IconButton(
        key: const Key('generatedVideoCenterPlay'),
        onPressed: onTap,
        icon: const Icon(
          Icons.play_arrow_rounded,
          color: Colors.white,
          size: 42,
        ),
      ),
    );
  }
}

class _PlaybackControls extends StatelessWidget {
  const _PlaybackControls({
    required this.controller,
    required this.isReady,
    required this.onTogglePlayback,
    required this.isDownloading,
    required this.downloadProgress,
    required this.onDownload,
  });

  final VideoPlayerController? controller;
  final bool isReady;
  final VoidCallback onTogglePlayback;
  final bool isDownloading;
  final double? downloadProgress;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final controller = this.controller;
    if (controller == null) {
      return _buildPanel(context, null);
    }
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (context, value, _) => _buildPanel(context, value),
    );
  }

  Widget _buildPanel(BuildContext context, VideoPlayerValue? value) {
    return Container(
      key: const Key('generatedVideoControls'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        color: const Color(0xD90B080E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF43243D)),
        boxShadow: const [BoxShadow(color: Color(0x88000000), blurRadius: 22)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isReady && controller != null)
            VideoProgressIndicator(
              controller!,
              allowScrubbing: true,
              padding: const EdgeInsets.symmetric(vertical: 5),
              colors: const VideoProgressColors(
                playedColor: Color(0xFFFF3CA9),
                bufferedColor: Color(0xFF705168),
                backgroundColor: Color(0xFF332C35),
              ),
            )
          else
            Container(
              height: 3,
              margin: const EdgeInsets.symmetric(vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF332C35),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          const SizedBox(height: 6),
          Row(
            children: [
              SizedBox(
                width: 38,
                height: 38,
                child: IconButton(
                  key: const Key('generatedVideoPlayPause'),
                  tooltip: value?.isPlaying == true ? 'Pause' : 'Play',
                  onPressed: isReady ? onTogglePlayback : null,
                  padding: EdgeInsets.zero,
                  icon: Icon(
                    value?.isPlaying == true
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    size: 30,
                    color: isReady ? Colors.white : const Color(0xFF77717A),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${_formatDuration(value?.position ?? Duration.zero)} / '
                '${_formatDuration(value?.duration ?? Duration.zero)}',
                style: const TextStyle(
                  color: Color(0xFFC7C0CA),
                  fontSize: 12,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const Spacer(),
              _DownloadButton(
                isDownloading: isDownloading,
                progress: downloadProgress,
                onTap: onDownload,
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

class _DownloadButton extends StatelessWidget {
  const _DownloadButton({
    required this.isDownloading,
    required this.progress,
    required this.onTap,
  });

  final bool isDownloading;
  final double? progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final percent = progress == null ? null : (progress! * 100).round();
    return Container(
      height: 42,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(21),
        gradient: const LinearGradient(
          colors: [Color(0xFFFF16A8), Color(0xFFFF4E5D), Color(0xFFFFA42B)],
        ),
        boxShadow: const [BoxShadow(color: Color(0x66FF1AA7), blurRadius: 12)],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(21),
        child: InkWell(
          key: const Key('downloadGeneratedVideo'),
          onTap: isDownloading ? null : onTap,
          borderRadius: BorderRadius.circular(21),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isDownloading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                else
                  const Icon(
                    Icons.download_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                const SizedBox(width: 7),
                Text(
                  isDownloading
                      ? percent == null
                            ? 'Saving'
                            : '$percent%'
                      : 'Save',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({super.key, required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xBB0B0710),
        border: Border.all(color: const Color(0xFFFF3AAD)),
        boxShadow: const [BoxShadow(color: Color(0x66FF22A9), blurRadius: 12)],
      ),
      child: IconButton(
        onPressed: onTap,
        padding: EdgeInsets.zero,
        icon: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}

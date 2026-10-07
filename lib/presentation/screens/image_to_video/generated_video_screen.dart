import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../../../core/network/api_client.dart';
import '../../../core/media/video_cache_service.dart';
import '../../../core/storage/playback_preferences.dart';
import '../../../data/models/i2v_request_status.dart';
import '../../../data/services/video_download_service.dart';
import '../../widgets/cached_video_thumbnail.dart';
import '../../widgets/video_form_style.dart';
import '../../widgets/video_library_widgets.dart';
import '../main/main_screen.dart';

typedef GeneratedVideoDownloader =
    Future<void> Function(
      String videoUrl,
      String requestId,
      void Function(int received, int total) onProgress,
    );

typedef GeneratedVideoSharer =
    Future<void> Function(String videoUrl, String requestId);
typedef GeneratedVideoDeleter = Future<void> Function(String requestId);
typedef GeneratedVideoControllerFactory =
    Future<VideoPlayerController> Function(Uri uri);

class GeneratedVideoScreen extends StatefulWidget {
  const GeneratedVideoScreen({
    super.key,
    required this.result,
    this.downloader,
    this.sharer,
    this.deleter,
    this.controllerFactory,
    this.returnToPreviousOnBack = false,
  });

  final I2VRequestStatus result;
  final GeneratedVideoDownloader? downloader;
  final GeneratedVideoSharer? sharer;
  final GeneratedVideoDeleter? deleter;
  final GeneratedVideoControllerFactory? controllerFactory;
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
  bool _isSharing = false;
  bool _isDeleting = false;
  bool _leaving = false;
  String? _playerError;
  bool _isInitializing = false;
  bool _controlsVisible = true;
  Timer? _controlsHideTimer;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
    _scheduleControlsHide();
  }

  void _scheduleControlsHide() {
    _controlsHideTimer?.cancel();
    if (!_controlsVisible) return;
    _controlsHideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  void _toggleControlsVisibility() {
    if (_controlsVisible) {
      _controlsHideTimer?.cancel();
      setState(() => _controlsVisible = false);
    } else {
      _showControls();
    }
  }

  void _showControls() {
    if (!mounted) return;
    setState(() => _controlsVisible = true);
    _scheduleControlsHide();
  }

  Future<void> _initializePlayer() async {
    if (_isInitializing) return;
    _isInitializing = true;
    setState(() {
      _playerError = null;
      _isReady = false;
    });
    final uri = Uri.tryParse(widget.result.resultUrl);
    VideoPlayerController? controller;
    try {
      final previous = _controller;
      _controller = null;
      await previous?.dispose();
      if (uri == null || !uri.hasScheme) {
        throw const FormatException('Missing video URL');
      }
      controller =
          await (widget.controllerFactory?.call(uri) ??
              VideoCacheService.instance.createController(
                uri,
                cacheKey: 'request:${widget.result.requestId}',
              ));
      if (!mounted) {
        await controller.dispose();
        return;
      }
      _controller = controller;
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
      await controller?.dispose();
      if (mounted) setState(() => _playerError = 'Preview unavailable');
    } finally {
      _isInitializing = false;
    }
  }

  @override
  void dispose() {
    _controlsHideTimer?.cancel();
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
    _scheduleControlsHide();
    setState(() => _isMuted = !_isMuted);
    await controller.setVolume(_isMuted ? 0 : 1);
  }

  Future<void> _downloadVideo() async {
    if (_isDownloading || _isSharing || _isDeleting) return;
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
        setState(() => _downloadProgress = (received / total).clamp(0.0, 1.0));
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

  Future<void> _shareVideo() async {
    if (_isSharing || _isDeleting || _isDownloading) return;
    setState(() => _isSharing = true);
    try {
      final sharer = widget.sharer ?? _defaultSharer;
      await sharer(widget.result.resultUrl, widget.result.requestId);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not share this video.')),
      );
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  Future<void> _defaultSharer(String videoUrl, String requestId) async {
    final uri = Uri.tryParse(videoUrl);
    if (uri == null || !uri.hasScheme) {
      throw const FormatException('The video URL is invalid.');
    }
    await SharePlus.instance.share(
      ShareParams(uri: uri, title: 'Share your Liora video'),
    );
  }

  Future<void> _deleteVideo() async {
    if (_isDeleting || _isSharing || _isDownloading) return;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: const Color(0xCC000000),
      builder: (_) => const _DeleteVideoDialog(),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);
    try {
      final deleter = widget.deleter ?? _defaultDeleter;
      await deleter(widget.result.requestId);
      if (!mounted) return;
      // History refreshes after this route returns. When the result was opened
      // from another screen, navigate to the history tab as usual.
      if (widget.returnToPreviousOnBack) {
        Navigator.of(context).pop(true);
      } else {
        _leaveScreen();
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not delete video: $error')));
      setState(() => _isDeleting = false);
    }
  }

  Future<void> _defaultDeleter(String requestId) {
    return ApiClient.instance.deleteGenerationRequest(requestId);
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
  Widget build(BuildContext context) => PopScope<void>(
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
            SizedBox.expand(
              key: const Key('generatedVideoFrame'),
              child: _VideoSurface(
                controller: _controller,
                isReady: _isReady,
                cacheKey: 'request:${widget.result.requestId}',
                fallbackImage: widget.result.thumbnailUrl.isNotEmpty
                    ? widget.result.thumbnailUrl
                    : widget.result.imageUrl,
                error: _playerError,
                onRetry: _initializePlayer,
                onTap: _toggleControlsVisibility,
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  key: const Key('generatedVideoHeader'),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    children: [
                      _RoundAction(
                        key: const Key('generatedVideoBack'),
                        icon: Icons.arrow_back_rounded,
                        tooltip: 'Back',
                        onTap: _leaveScreen,
                      ),
                      Expanded(
                        child: Text(
                          'Your Video',
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: VideoFormStyle.heading(
                            25,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      _RoundAction(
                        key: const Key('generatedVideoMute'),
                        icon: _isMuted
                            ? Icons.volume_off_outlined
                            : Icons.volume_up_outlined,
                        tooltip: _isMuted ? 'Turn sound on' : 'Mute',
                        onTap: _isReady ? _toggleMuted : null,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_controlsVisible)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.6,
                  ),
                  child: Listener(
                    onPointerDown: (_) => _scheduleControlsHide(),
                    onPointerMove: (_) => _scheduleControlsHide(),
                    onPointerUp: (_) => _scheduleControlsHide(),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                        child: Container(
                          key: const Key('generatedVideoBottom'),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0xB82B2436), Color(0xDF16131E)],
                            ),
                            border: Border(
                              top: BorderSide(color: Color(0x55FFFFFF)),
                            ),
                          ),
                          child: SafeArea(
                            top: false,
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                18,
                                16,
                                12,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _PlaybackControls(
                                    controller: _controller,
                                    isReady: _isReady,
                                    onTogglePlayback: _togglePlayback,
                                  ),
                                  const SizedBox(height: 16),
                                  _ResultActions(
                                    isDownloading: _isDownloading,
                                    downloadProgress: _downloadProgress,
                                    onDownload: _downloadVideo,
                                    isSharing: _isSharing,
                                    isDeleting: _isDeleting,
                                    onShare: _shareVideo,
                                    onDelete: _deleteVideo,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class _VideoSurface extends StatelessWidget {
  const _VideoSurface({
    required this.controller,
    required this.isReady,
    required this.cacheKey,
    required this.fallbackImage,
    required this.error,
    required this.onRetry,
    required this.onTap,
  });
  final VideoPlayerController? controller;
  final bool isReady;
  final String cacheKey;
  final String fallbackImage;
  final String? error;
  final VoidCallback onRetry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final player = controller;
    final videoSize = player?.value.size ?? Size.zero;
    return GestureDetector(
      key: const Key('generatedVideoSurface'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            key: Key('generatedVideoBackdrop'),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF21192D),
                  Color(0xFF100F18),
                  Color(0xFF21192D),
                ],
                stops: [0, 0.5, 1],
              ),
            ),
          ),
          if (isReady && player != null)
            ClipRect(
              child: FittedBox(
                fit: BoxFit.fitWidth,
                child: SizedBox(
                  width: videoSize.width > 0 ? videoSize.width : 9,
                  height: videoSize.height > 0 ? videoSize.height : 16,
                  child: VideoPlayer(player),
                ),
              ),
            )
          else
            CachedVideoThumbnail(
              cacheKey: cacheKey,
              imageUrl: fallbackImage,
              fit: BoxFit.fitWidth,
              placeholder: _placeholder,
              errorWidget: _placeholder,
              maxDecodeWidth: 1080,
            ),
          if (!isReady || player == null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: error == null
                    ? const SizedBox.square(
                        dimension: 28,
                        child: CircularProgressIndicator(
                          color: VideoFormStyle.accent,
                          strokeWidth: 2,
                        ),
                      )
                    : Container(
                        key: const Key('generatedVideoPreviewError'),
                        constraints: const BoxConstraints(maxWidth: 280),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xEC312E42),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.videocam_off_outlined,
                                color: VideoFormStyle.accent,
                                size: 26,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                error!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'You can still save or share this video.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: VideoFormStyle.secondary,
                                  fontSize: 12,
                                  height: 1.4,
                                ),
                              ),
                              TextButton(
                                key: const Key('retryGeneratedVideo'),
                                onPressed: onRetry,
                                style: TextButton.styleFrom(
                                  foregroundColor: VideoFormStyle.accent,
                                ),
                                child: const Text('Retry preview'),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
            ),
        ],
      ),
    );
  }

  Widget get _placeholder => Center(
    child: Opacity(
      opacity: .2,
      child: Image.asset(
        'assets/images/profile/video_icon.png',
        width: 110,
        height: 110,
        excludeFromSemantics: true,
      ),
    ),
  );
}

class _PlaybackControls extends StatelessWidget {
  const _PlaybackControls({
    required this.controller,
    required this.isReady,
    required this.onTogglePlayback,
  });
  final VideoPlayerController? controller;
  final bool isReady;
  final VoidCallback onTogglePlayback;

  @override
  Widget build(BuildContext context) {
    final player = controller;
    if (player == null) return _buildPanel(null);
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: player,
      builder: (context, value, _) => _buildPanel(value),
    );
  }

  Widget _buildPanel(VideoPlayerValue? value) => Container(
    key: const Key('generatedVideoControls'),
    padding: const EdgeInsets.only(top: 8),
    child: Row(
      children: [
        SizedBox.square(
          dimension: 44,
          child: IconButton(
            key: const Key('generatedVideoPlayPause'),
            tooltip: value?.isPlaying == true ? 'Pause' : 'Play',
            onPressed: isReady ? onTogglePlayback : null,
            padding: EdgeInsets.zero,
            icon: Icon(
              value?.isPlaying == true
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
              size: 28,
              color: isReady ? VideoFormStyle.accent : VideoFormStyle.muted,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            children: [
              if (isReady && controller != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: VideoProgressIndicator(
                    controller!,
                    allowScrubbing: true,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    colors: const VideoProgressColors(
                      playedColor: VideoFormStyle.accent,
                      bufferedColor: Color(0xFF55516A),
                      backgroundColor: Color(0xFF22273A),
                    ),
                  ),
                )
              else
                Container(
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF22273A),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDuration(value?.position ?? Duration.zero),
                    style: _timeStyle,
                  ),
                  Text(
                    _formatDuration(value?.duration ?? Duration.zero),
                    style: _timeStyle,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );

  static const _timeStyle = TextStyle(
    color: VideoFormStyle.muted,
    fontSize: 10,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static String _formatDuration(Duration duration) =>
      '${duration.inSeconds ~/ 60}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
}

class _ResultActions extends StatelessWidget {
  const _ResultActions({
    required this.isDownloading,
    required this.downloadProgress,
    required this.onDownload,
    required this.isSharing,
    required this.isDeleting,
    required this.onShare,
    required this.onDelete,
  });
  final bool isDownloading;
  final double? downloadProgress;
  final VoidCallback onDownload;
  final bool isSharing;
  final bool isDeleting;
  final VoidCallback onShare;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final busy = isDownloading || isSharing || isDeleting;
      final percent = downloadProgress == null
          ? null
          : (downloadProgress! * 100).round();
      final save = VideoLibraryAction(
        key: const Key('downloadGeneratedVideo'),
        label: isDownloading
            ? (percent == null ? 'Saving' : 'Saving $percent%')
            : 'Save',
        icon: Icons.download_rounded,
        primary: true,
        busy: isDownloading,
        onTap: busy ? null : onDownload,
      );
      final share = VideoLibraryAction(
        key: const Key('shareGeneratedVideo'),
        label: isSharing ? 'Sharing' : 'Share',
        icon: Icons.ios_share_rounded,
        busy: isSharing,
        onTap: busy ? null : onShare,
      );
      final delete = VideoLibraryAction(
        key: const Key('deleteGeneratedVideo'),
        label: isDeleting ? 'Deleting' : 'Delete',
        iconAsset: VideoLibraryTrashIcon.assetPath,
        destructive: true,
        busy: isDeleting,
        onTap: busy ? null : onDelete,
      );
      if (constraints.maxWidth < 320 ||
          MediaQuery.textScalerOf(context).scale(13) > 17) {
        return Column(
          children: [
            save,
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: share),
                const SizedBox(width: 10),
                Expanded(child: delete),
              ],
            ),
          ],
        );
      }
      return Row(
        children: [
          Expanded(flex: 5, child: save),
          const SizedBox(width: 9),
          Expanded(flex: 4, child: share),
          const SizedBox(width: 9),
          Expanded(flex: 4, child: delete),
        ],
      );
    },
  );
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF342D3E),
        border: Border.all(color: VideoFormStyle.border, width: .6),
      ),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        padding: EdgeInsets.zero,
        icon: Icon(
          icon,
          color: onTap == null ? VideoFormStyle.muted : VideoFormStyle.accent,
          size: 21,
        ),
      ),
    ),
  );
}

class _DeleteVideoDialog extends StatelessWidget {
  const _DeleteVideoDialog();

  @override
  Widget build(BuildContext context) => const VideoLibraryDeleteDialog(
    key: Key('deleteGeneratedVideoDialog'),
    cancelKey: Key('cancelDeleteGeneratedVideo'),
    confirmKey: Key('confirmDeleteGeneratedVideo'),
  );
}

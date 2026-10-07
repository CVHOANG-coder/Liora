import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// A silent, looping banner shared by the subscription screens.
class ProBannerVideo extends StatefulWidget {
  const ProBannerVideo({super.key});

  static const asset = 'assets/videos/banner_Pro.mp4';

  @override
  State<ProBannerVideo> createState() => _ProBannerVideoState();
}

class _ProBannerVideoState extends State<ProBannerVideo>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  ValueListenable<TickerModeData>? _tickerMode;
  bool _ready = false;
  bool _appActive = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  Future<void> _initialize() async {
    final controller = VideoPlayerController.asset(ProBannerVideo.asset);
    _controller = controller;
    try {
      await controller.initialize();
      if (!mounted || _controller != controller) return;
      await controller.setLooping(true);
      await controller.setVolume(0);
      if (!mounted || _controller != controller) return;
      setState(() => _ready = true);
      _syncPlayback();
    } catch (_) {
      // Keep the poster visible if this device cannot decode the video.
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tickerMode = TickerMode.getValuesNotifier(context);
    if (_tickerMode == tickerMode) return;
    _tickerMode?.removeListener(_syncPlayback);
    _tickerMode = tickerMode..addListener(_syncPlayback);
    _syncPlayback();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appActive = state == AppLifecycleState.resumed;
    _syncPlayback();
  }

  void _syncPlayback() {
    final controller = _controller;
    if (!_ready || controller == null) return;
    if (_appActive && (_tickerMode?.value.enabled ?? true)) {
      controller.play();
    } else {
      controller.pause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tickerMode?.removeListener(_syncPlayback);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/images/in_app_purchase/all_plans_hero_v2.png',
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
        ),
        if (_ready && controller != null)
          FittedBox(
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: controller.value.size.width,
              height: controller.value.size.height,
              child: VideoPlayer(controller),
            ),
          ),
      ],
    );
  }
}

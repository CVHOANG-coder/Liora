import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../../core/firebase/firebase_service.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../data/models/generation_progress.dart';
import '../../../data/models/i2v_generation.dart';
import '../../../data/models/i2v_request_status.dart';
import '../../../data/services/generation_progress_repository.dart';
import '../../widgets/notification_permission_dialog.dart';
import '../../widgets/generation_failure_dialog.dart';
import '../../widgets/video_form_style.dart';
import '../generation_history/generation_history_screen.dart';
import 'generated_video_screen.dart';

typedef I2VStatusFetcher = Future<I2VRequestStatus> Function(String requestId);
typedef GenerationHistoryRefresher = Future<void> Function();

class CreatingVideoScreen extends StatefulWidget {
  const CreatingVideoScreen({
    super.key,
    required this.generation,
    this.statusFetcher,
    this.initialPollDelay = const Duration(minutes: 2),
    this.pollInterval = const Duration(seconds: 10),
    this.returnToPreviousOnBack = false,
    this.historyRefresher,
    this.initialProgress,
    this.progressRepository,
    this.videoDurationSeconds,
    this.isHd,
    this.creatorLabel = 'Image to Video',
    this.sourceImagePath,
    this.notificationPermissionRequester,
    this.notificationSettingsOpener,
    this.initialRequestStatus,
    this.openedFromHistory = false,
    this.historyDestinationBuilder,
  });

  final I2VGeneration generation;
  final I2VStatusFetcher? statusFetcher;
  final Duration initialPollDelay;
  final Duration pollInterval;
  final bool returnToPreviousOnBack;
  final GenerationHistoryRefresher? historyRefresher;
  final GenerationProgress? initialProgress;
  final GenerationProgressRepository? progressRepository;
  final int? videoDurationSeconds;
  final bool? isHd;
  final String creatorLabel;
  final String? sourceImagePath;
  final NotificationPermissionRequester? notificationPermissionRequester;
  final NotificationSettingsOpener? notificationSettingsOpener;
  final I2VRequestStatus? initialRequestStatus;
  final bool openedFromHistory;
  final WidgetBuilder? historyDestinationBuilder;

  @override
  State<CreatingVideoScreen> createState() => _CreatingVideoScreenState();
}

class _CreatingVideoScreenState extends State<CreatingVideoScreen> {
  Timer? _initialPollTimer;
  Timer? _pollTimer;
  Timer? _fakeProgressTimer;
  bool _pollInFlight = false;
  bool _resolved = false;
  String _failureTitle = 'Video Generation Failed';
  String? _failureGuidance;
  bool _failureCreditsRefunded = false;
  String? _failureMessage;
  GenerationProgress? _generationProgress;
  double _displayProgress = 0.02;
  int _currentStepIndex = 0;
  Future<void> _pendingStepPersistence = Future<void>.value();
  bool _leaveDialogOpen = false;
  bool _allowPop = false;
  bool _leavingForHistory = false;

  GenerationProgressRepository get _progressRepository =>
      widget.progressRepository ??
      const SharedPreferencesGenerationProgressRepository();

  @override
  void initState() {
    super.initState();
    _initializeProgress();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_requestNotificationPermissionIfNeeded());
      final initialStatus = widget.initialRequestStatus;
      if (initialStatus != null) unawaited(_handleStatus(initialStatus));
    });
  }

  Future<void> _requestNotificationPermissionIfNeeded() async {
    final requester =
        widget.notificationPermissionRequester ??
        FirebaseService.requestNotificationPermissionOnCreatingVideo;
    final result = await requester();
    if (!mounted ||
        result != NotificationPermissionFlowResult.settingsRequired) {
      return;
    }

    final shouldOpenSettings = await NotificationPermissionDialog.show(context);
    if (!shouldOpenSettings || !mounted) return;
    final openSettings =
        widget.notificationSettingsOpener ??
        FirebaseService.openNotificationSettings;
    await openSettings();
  }

  Future<void> _initializeProgress() async {
    var progress = widget.initialProgress;
    if (progress != null) {
      _activateProgress(progress);
      return;
    }
    try {
      progress = await _progressRepository.load(widget.generation.requestId);
    } catch (_) {
      // Fall back to response metadata when local storage is unavailable.
    }
    progress ??= GenerationProgress.create(
      requestId: widget.generation.requestId,
      startedAt: widget.generation.createTime ?? DateTime.now(),
      videoDurationSeconds:
          widget.videoDurationSeconds ??
          (widget.generation.params.duration > 0
              ? widget.generation.params.duration
              : 5),
      isHd: widget.isHd ?? widget.generation.params.megapixels >= 1,
    );
    unawaited(_saveProgressBestEffort(progress));
    _activateProgress(progress);
  }

  Future<void> _saveProgressBestEffort(GenerationProgress progress) async {
    try {
      await _progressRepository.save(progress);
    } catch (_) {
      // The screen can still calculate progress for the current app session.
    }
  }

  void _activateProgress(GenerationProgress progress) {
    if (!mounted || _resolved) return;
    _generationProgress = progress;
    _refreshFakeProgress(persistStep: false);
    _fakeProgressTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _refreshFakeProgress(),
    );
    _schedulePolling(progress.startedAt);
  }

  void _refreshFakeProgress({bool persistStep = true}) {
    final progress = _generationProgress;
    if (!mounted || progress == null || _resolved) return;
    final calculatedStep = progress.stepIndexAt(DateTime.now());
    final nextStep = calculatedStep > progress.savedStepIndex
        ? calculatedStep
        : progress.savedStepIndex.clamp(0, progress.totalSteps - 1);
    final stepProgress = nextStep * 15 / progress.fakeDurationSeconds;
    final nextProgress = progress.progressAt(DateTime.now()) > stepProgress
        ? progress.progressAt(DateTime.now())
        : stepProgress.clamp(0.02, 0.95);
    final changedStep = nextStep != _currentStepIndex;
    setState(() {
      _currentStepIndex = nextStep;
      _displayProgress = nextProgress;
    });
    if (persistStep && changedStep) {
      _generationProgress = progress.copyWith(savedStepIndex: nextStep);
      _pendingStepPersistence = _pendingStepPersistence.then((_) async {
        if (_resolved) return;
        try {
          await _progressRepository.updateStep(progress.requestId, nextStep);
        } catch (_) {
          // Persisting fake progress is best-effort.
        }
      });
    }
  }

  void _schedulePolling(DateTime startedAt) {
    final measuredElapsed = DateTime.now().difference(startedAt);
    final elapsed = measuredElapsed.isNegative
        ? Duration.zero
        : measuredElapsed;
    final remaining = widget.initialPollDelay - elapsed;
    if (remaining <= Duration.zero) {
      _startPolling();
      return;
    }
    _initialPollTimer = Timer(remaining, _startPolling);
  }

  void _startPolling() {
    if (!mounted || _resolved) return;
    _pollStatus();
    _pollTimer = Timer.periodic(widget.pollInterval, (_) => _pollStatus());
  }

  Future<void> _pollStatus() async {
    if (_pollInFlight || _resolved) return;
    _pollInFlight = true;
    try {
      final fetcher =
          widget.statusFetcher ?? ApiClient.instance.fetchImageToVideoStatus;
      final status = await fetcher(widget.generation.requestId);
      if (!mounted || _resolved) return;
      await _handleStatus(status);
    } catch (_) {
      // A temporary polling error should not mark the generation as failed.
      // The next 10-second cycle retries automatically.
    } finally {
      _pollInFlight = false;
    }
  }

  Future<void> _handleStatus(I2VRequestStatus status) async {
    if (!mounted || _resolved || !status.isTerminal) return;
    _resolved = true;
    _stopPolling();
    _fakeProgressTimer?.cancel();
    unawaited(_clearStoredProgress());

    if (status.isCompleted) {
      if (status.resultUrl.isEmpty) {
        _showFailureUi('The generated video URL is missing. Please try again.');
        return;
      }
      unawaited(_refreshGenerationHistory());
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => GeneratedVideoScreen(
            result: status,
            returnToPreviousOnBack: widget.returnToPreviousOnBack,
          ),
        ),
      );
    } else if (status.isFailed) {
      final error = ApiException(
        message: apiErrorDisplayMessage(
          status.errorMessage,
          fallbackMessage:
              'The video could not be generated. Please try again.',
        ),
        errorCode: status.errorCode.isEmpty ? null : status.errorCode,
      );
      final presentation = resolveApiErrorPresentation(
        error,
        fallbackMessage: 'The video could not be generated. Please try again.',
      );
      _showFailureUi(
        presentation.message,
        title: presentation.title,
        guidance: status.errorCode == ApiErrorCode.contentPolicy
            ? 'Return to ${widget.creatorLabel} and edit the content before trying again.'
            : null,
        creditsRefunded: status.creditRefunded,
      );
    } else if (status.isCancelled) {
      _showFailureUi(
        'This video request was cancelled.',
        title: 'Video Generation Cancelled',
        guidance: 'Return to ${widget.creatorLabel} whenever you are ready.',
        creditsRefunded: true,
      );
    } else if (status.isDeleted) {
      _showFailureUi(
        'This video request was deleted and is no longer available.',
        title: 'Video Request Deleted',
        guidance: 'Return to ${widget.creatorLabel} to create a new video.',
      );
    }
  }

  Future<void> _clearStoredProgress() async {
    try {
      await _pendingStepPersistence;
      await _progressRepository.remove(widget.generation.requestId);
    } catch (_) {
      // Terminal navigation must still continue if local cleanup fails.
    }
  }

  Future<void> _refreshGenerationHistory() async {
    try {
      final refresher = widget.historyRefresher;
      if (refresher != null) {
        await refresher();
        return;
      }
      await ApiClient.instance.fetchGenerationHistory(page: 1, limit: 10);
    } catch (_) {
      // Refreshing history is best-effort and must not block a completed video.
    }
  }

  void _showFailureUi(
    String message, {
    String title = 'Video Generation Failed',
    String? guidance,
    bool creditsRefunded = false,
  }) {
    if (mounted) {
      setState(() {
        _failureTitle = title;
        _failureGuidance = guidance;
        _failureCreditsRefunded = creditsRefunded;
        _failureMessage = message;
      });
    }
  }

  void _stopPolling() {
    _initialPollTimer?.cancel();
    _pollTimer?.cancel();
    _initialPollTimer = null;
    _pollTimer = null;
  }

  @override
  void dispose() {
    _stopPolling();
    _fakeProgressTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final failureMessage = _failureMessage;
    if (failureMessage != null) {
      return _GenerationFailureScreen(
        title: _failureTitle,
        message: failureMessage,
        guidance: _failureGuidance,
        creditsRefunded: _failureCreditsRefunded,
        creatorLabel: widget.creatorLabel,
        onBackToCreate: () => Navigator.maybePop(context),
      );
    }

    return PopScope<void>(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_confirmLeaveForHistory());
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF02050C),
        body: Stack(
          children: [
            const Positioned.fill(child: _LoadingGlow()),
            SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    key: const Key('creatingVideoHeader'),
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                    child: _Header(onBack: _confirmLeaveForHistory),
                  ),
                  Expanded(
                    child: CustomScrollView(
                      key: const PageStorageKey('creatingVideoScroll'),
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                            20,
                            14,
                            20,
                            18 + MediaQuery.paddingOf(context).bottom,
                          ),
                          sliver: SliverList.list(
                            children: [
                              _Artwork(
                                sourceImagePath: widget.sourceImagePath,
                                sourceImageUrl: widget.generation.imageUrl,
                              ),
                              const SizedBox(height: 20),
                              const _GeneratingTitle(),
                              const SizedBox(height: 8),
                              const Text(
                                "We're turning your idea into a cinematic result.\n"
                                'This may take a few moments.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Color(0xFFB4B1BD),
                                  fontSize: 14,
                                  height: 1.45,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _ProgressPercent(progress: _displayProgress),
                              const SizedBox(height: 8),
                              _NeonProgressBar(progress: _displayProgress),
                              const SizedBox(height: 18),
                              _GenerationSteps(
                                currentStepIndex: _currentStepIndex,
                                totalSteps:
                                    _generationProgress?.totalSteps ?? 10,
                              ),
                              const SizedBox(height: 18),
                              const _BackgroundTip(),
                              const SizedBox(height: 18),
                              _ContinueButton(onTap: _continueInBackground),
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: _confirmLeaveForHistory,
                                child: const Text(
                                  'Cancel',
                                  style: TextStyle(
                                    color: Color(0xFFC68AED),
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Request ${widget.generation.requestId}',
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF85818F),
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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

  void _continueInBackground() {
    _leaveForHistory();
  }

  Future<void> _confirmLeaveForHistory() async {
    if (!mounted || _leaveDialogOpen || _leavingForHistory) return;
    _leaveDialogOpen = true;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: const Color(0xD9000000),
      builder: (_) => const _LeaveCreatingVideoDialog(),
    );
    _leaveDialogOpen = false;
    if (confirmed == true && mounted) _leaveForHistory();
  }

  void _leaveForHistory() {
    if (!mounted || _leavingForHistory) return;
    _leavingForHistory = true;
    _allowPop = true;
    final navigator = Navigator.of(context);
    final currentRoute = ModalRoute.of(context);
    if (widget.openedFromHistory &&
        currentRoute != null &&
        navigator.canPop()) {
      navigator.removeRoute(currentRoute);
      return;
    }

    final builder =
        widget.historyDestinationBuilder ??
        (_) => const GenerationHistoryScreen();
    final route = MaterialPageRoute<void>(builder: builder);
    if (navigator.canPop()) {
      navigator.pushAndRemoveUntil(route, (route) => route.isFirst);
    } else {
      navigator.pushReplacement(route);
    }
  }
}

class _LeaveCreatingVideoDialog extends StatelessWidget {
  const _LeaveCreatingVideoDialog();

  @override
  Widget build(BuildContext context) => Dialog(
    key: const Key('leaveCreatingVideoDialog'),
    backgroundColor: Colors.transparent,
    insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Container(
        decoration: BoxDecoration(
          gradient: VideoFormStyle.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: VideoFormStyle.border, width: 0.6),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/images/gen_video/clock.png',
                width: 58,
                height: 58,
                excludeFromSemantics: true,
              ),
              const SizedBox(height: 16),
              Text(
                'Leave this screen?',
                textAlign: TextAlign.center,
                style: VideoFormStyle.serif(25),
              ),
              const SizedBox(height: 10),
              const Text(
                'Your video will keep generating in the background. You can check its progress in Generation History.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: VideoFormStyle.secondary,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 22),
              LayoutBuilder(
                builder: (context, constraints) {
                  final stay = OutlinedButton(
                    key: const Key('keepWaitingForVideo'),
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: VideoFormStyle.secondary,
                      side: const BorderSide(
                        color: VideoFormStyle.border,
                        width: 0.7,
                      ),
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                    ),
                    child: const Text(
                      'Keep waiting',
                      textAlign: TextAlign.center,
                    ),
                  );
                  final leave = _CreatingActionButton(
                    buttonKey: const Key('leaveForGenerationHistory'),
                    label: 'Go to History',
                    onTap: () => Navigator.pop(context, true),
                  );
                  if (constraints.maxWidth < 300 ||
                      MediaQuery.textScalerOf(context).scale(14) > 17) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [stay, const SizedBox(height: 10), leave],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: stay),
                      const SizedBox(width: 10),
                      Expanded(child: leave),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _LoadingGlow extends StatelessWidget {
  const _LoadingGlow();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.35),
          radius: 0.8,
          colors: [Color(0x332A1749), Color(0xFF02050C)],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 44,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text('Creating Video', style: VideoFormStyle.serif(23)),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            key: const Key('creatingVideoBack'),
            tooltip: 'Back',
            onPressed: onBack,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 44, height: 44),
            icon: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: VideoFormStyle.surface,
                border: Border.all(color: VideoFormStyle.border, width: 0.6),
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: VideoFormStyle.accent,
                size: 23,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _Artwork extends StatefulWidget {
  const _Artwork({required this.sourceImagePath, required this.sourceImageUrl});

  final String? sourceImagePath;
  final String sourceImageUrl;

  @override
  State<_Artwork> createState() => _ArtworkState();
}

class _ArtworkState extends State<_Artwork>
    with SingleTickerProviderStateMixin {
  late final AnimationController _effectController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _effectController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: _effectController,
        builder: (context, _) {
          final pulse = 0.08 + (_effectController.value * 0.10);
          return Container(
            key: const Key('creatingArtworkFrame'),
            width: 250,
            height: 224,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFEC5FB6), Color(0xFF5366DE)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFB76ADD).withValues(alpha: pulse),
                  blurRadius: 22 + (_effectController.value * 10),
                  spreadRadius: 0,
                ),
                BoxShadow(
                  color: const Color(0xFF4664DF).withValues(alpha: pulse * 0.7),
                  blurRadius: 18 + (_effectController.value * 8),
                ),
              ],
            ),
            padding: const EdgeInsets.all(0.8),
            child: _ProcessingArtwork(
              sourceImagePath: widget.sourceImagePath,
              sourceImageUrl: widget.sourceImageUrl,
              scanPosition: _effectController.value,
            ),
          );
        },
      ),
    );
  }
}

class _ProcessingArtwork extends StatelessWidget {
  const _ProcessingArtwork({
    required this.sourceImagePath,
    required this.sourceImageUrl,
    required this.scanPosition,
  });

  final String? sourceImagePath;
  final String sourceImageUrl;
  final double scanPosition;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(19),
      child: ColoredBox(
        color: const Color(0xFF0B101D),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _sourceImage(),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  radius: 0.85,
                  colors: [Color(0x11000000), Color(0x8A02050C)],
                  stops: [0.42, 1],
                ),
              ),
            ),
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(19),
                child: RepaintBoundary(
                  child: ColorFiltered(
                    colorFilter: const ColorFilter.mode(
                      VideoFormStyle.accent,
                      BlendMode.srcIn,
                    ),
                    child: Lottie.asset(
                      'assets/lotties/loadingImage.lottie',
                      key: const Key('creatingImageLottie'),
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                      repeat: true,
                      frameRate: FrameRate.max,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment(0, -0.92 + (scanPosition * 1.84)),
              child: Container(
                key: const Key('creatingImageScanLine'),
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 13),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Color(0xFFEC5FB6),
                      Color(0xFF5366DE),
                      Colors.transparent,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(color: Color(0x66A850CF), blurRadius: 12),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sourceImage() {
    final path = sourceImagePath;
    if (path != null && path.isNotEmpty) {
      return Image.file(
        File(path),
        key: const Key('creatingSourceImage'),
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, _, _) => _defaultArtwork(),
      );
    }

    final url = sourceImageUrl.trim();
    if (url.isEmpty) return _defaultArtwork();
    return Image.network(
      url,
      key: const Key('creatingSourceImage'),
      fit: BoxFit.cover,
      filterQuality: FilterQuality.high,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return const ColoredBox(
          key: Key('creatingNetworkImageLoading'),
          color: Color(0xFF0B101D),
        );
      },
      errorBuilder: (_, _, _) => _defaultArtwork(),
    );
  }

  Widget _defaultArtwork() {
    final bounce = math.sin(scanPosition * math.pi);
    final sway = math.sin(scanPosition * math.pi * 2);
    return Transform.translate(
      key: const Key('creatingDefaultArtworkBounce'),
      offset: Offset(0, -5 * bounce),
      child: Transform.rotate(
        angle: 0.012 * sway,
        child: Transform.scale(
          scale: 1.04 + (0.025 * bounce),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Image.asset(
              'assets/images/create_video.png',
              key: const Key('creatingDefaultArtwork'),
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ),
        ),
      ),
    );
  }
}

class _GeneratingTitle extends StatelessWidget {
  const _GeneratingTitle();

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      style: VideoFormStyle.serif(27),
      children: const [
        TextSpan(text: 'Generating '),
        TextSpan(
          text: 'your video...',
          style: TextStyle(color: VideoFormStyle.accent),
        ),
      ],
    ),
    textAlign: TextAlign.center,
  );
}

class _ProgressPercent extends StatelessWidget {
  const _ProgressPercent({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) => ShaderMask(
    blendMode: BlendMode.srcIn,
    shaderCallback: const LinearGradient(
      colors: [VideoFormStyle.pink, VideoFormStyle.accent],
    ).createShader,
    child: Text(
      '${(progress * 100).round()}%',
      textAlign: TextAlign.center,
      style: VideoFormStyle.serif(32),
    ),
  );
}

class _NeonProgressBar extends StatelessWidget {
  const _NeonProgressBar({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Video generation progress',
    value: '${(progress * 100).round()}%',
    child: Container(
      key: const Key('creatingProgressTrack'),
      height: 8,
      decoration: BoxDecoration(
        color: const Color(0xFF202235),
        borderRadius: BorderRadius.circular(8),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => Align(
          alignment: Alignment.centerLeft,
          child: Container(
            key: const Key('creatingProgressFill'),
            width: constraints.maxWidth * progress.clamp(0.0, 1.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              gradient: VideoFormStyle.gradient,
              boxShadow: const [
                BoxShadow(color: Color(0x33935ACF), blurRadius: 8),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _GenerationSteps extends StatelessWidget {
  const _GenerationSteps({
    required this.currentStepIndex,
    required this.totalSteps,
  });

  final int currentStepIndex;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    final safeTotal = totalSteps.clamp(1, _fakeStepLabels.length);
    final safeCurrent = currentStepIndex.clamp(0, safeTotal - 1);
    final maxStart = (safeTotal - 4).clamp(0, safeTotal);
    final startIndex = (safeCurrent - 2).clamp(0, maxStart);
    final endIndex = (startIndex + 4).clamp(0, safeTotal);
    return Column(
      children: [
        for (var index = startIndex; index < endIndex; index++) ...[
          _StepTile(
            index: index,
            totalSteps: safeTotal,
            label: index == safeTotal - 1
                ? 'Finalizing output'
                : _fakeStepLabels[index],
            state: index < safeCurrent
                ? _StepState.completed
                : index == safeCurrent
                ? _StepState.active
                : _StepState.pending,
          ),
          if (index != endIndex - 1) const SizedBox(height: 7),
        ],
      ],
    );
  }
}

const _fakeStepLabels = <String>[
  'Uploading source image',
  'Validating input quality',
  'Analyzing composition',
  'Preparing visual assets',
  'Understanding your prompt',
  'Planning camera movement',
  'Building the motion path',
  'Generating key frames',
  'Creating scene depth',
  'Animating the subject',
  'Blending frame transitions',
  'Stabilizing movement',
  'Rendering background details',
  'Rendering foreground details',
  'Enhancing facial details',
  'Improving textures',
  'Refining lighting',
  'Balancing colors',
  'Reducing visual artifacts',
  'Upscaling frame quality',
  'Synchronizing motion',
  'Applying cinematic effects',
  'Composing final frames',
  'Encoding video stream',
  'Optimizing playback',
  'Preparing video preview',
  'Running final quality check',
  'Finalizing output',
];

enum _StepState { completed, active, pending }

class _StepTile extends StatelessWidget {
  const _StepTile({
    required this.index,
    required this.totalSteps,
    required this.label,
    required this.state,
  });
  final int index;
  final int totalSteps;
  final String label;
  final _StepState state;

  @override
  Widget build(BuildContext context) {
    final active = state == _StepState.active;
    final completed = state == _StepState.completed;
    final status = completed
        ? 'Completed'
        : active
        ? 'In progress'
        : 'Pending';
    final statusColor = completed || active
        ? VideoFormStyle.accent
        : VideoFormStyle.muted;
    final statusText = Text(
      status,
      style: TextStyle(color: statusColor, fontSize: 11, height: 1.3),
    );
    final title = Text(
      '${index + 1}/$totalSteps  $label',
      style: TextStyle(
        color: active || completed ? Colors.white : VideoFormStyle.secondary,
        fontSize: 13,
        height: 1.4,
      ),
    );
    return Container(
      key: ValueKey('creatingStep-$index'),
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        gradient: VideoFormStyle.surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: active ? const Color(0xFF8D68AE) : const Color(0xFF343743),
          width: 0.6,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stackStatus =
              constraints.maxWidth < 290 ||
              MediaQuery.textScalerOf(context).scale(13) > 17;
          return Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: active || completed
                      ? const Color(0xFF211E36)
                      : const Color(0xFF121725),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: completed
                    ? const Icon(
                        Icons.check_rounded,
                        color: VideoFormStyle.accent,
                        size: 20,
                      )
                    : active
                    ? const Padding(
                        padding: EdgeInsets.all(8),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: VideoFormStyle.accent,
                        ),
                      )
                    : Center(
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: VideoFormStyle.muted,
                            fontSize: 12,
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    title,
                    if (stackStatus) ...[const SizedBox(height: 3), statusText],
                  ],
                ),
              ),
              if (!stackStatus) ...[const SizedBox(width: 10), statusText],
            ],
          );
        },
      ),
    );
  }
}

class _BackgroundTip extends StatelessWidget {
  const _BackgroundTip();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      gradient: VideoFormStyle.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFF343743), width: 0.6),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.notifications_none_rounded,
          color: VideoFormStyle.accent,
          size: 24,
        ),
        SizedBox(width: 12),
        Expanded(
          child: Text.rich(
            TextSpan(
              style: TextStyle(
                color: VideoFormStyle.secondary,
                fontSize: 12,
                height: 1.5,
              ),
              children: [
                TextSpan(
                  text: 'Keep creating while you wait\n',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                TextSpan(
                  text:
                      'You can continue in the background and check progress in Generation History.',
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _ContinueButton extends StatelessWidget {
  const _ContinueButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => _CreatingActionButton(
    buttonKey: const Key('continueCreatingInBackground'),
    label: 'Continue in Background',
    icon: Icons.arrow_forward_rounded,
    onTap: onTap,
  );
}

class _CreatingActionButton extends StatelessWidget {
  const _CreatingActionButton({
    required this.buttonKey,
    required this.label,
    required this.onTap,
    this.icon,
  });
  final Key buttonKey;
  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 52),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(14),
      gradient: VideoFormStyle.gradient,
      border: Border.all(color: const Color(0xFFAA91C5), width: 0.6),
    ),
    child: Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: buttonKey,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                  ),
                ),
              ),
              if (icon != null) ...[
                const SizedBox(width: 12),
                Icon(icon, color: Colors.white, size: 22),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

class _GenerationFailureScreen extends StatelessWidget {
  const _GenerationFailureScreen({
    required this.title,
    required this.message,
    required this.guidance,
    required this.creditsRefunded,
    required this.creatorLabel,
    required this.onBackToCreate,
  });
  final String title;
  final String message;
  final String? guidance;
  final bool creditsRefunded;
  final String creatorLabel;
  final VoidCallback onBackToCreate;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: VideoFormStyle.background,
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: CustomScrollView(
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                  child: Column(
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          tooltip: 'Back',
                          onPressed: onBackToCreate,
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFF0B101D),
                            side: const BorderSide(
                              color: VideoFormStyle.border,
                              width: 0.6,
                            ),
                          ),
                          icon: const Icon(
                            Icons.arrow_back_rounded,
                            color: VideoFormStyle.accent,
                            size: 24,
                          ),
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(height: 24),
                      Container(
                        width: 92,
                        height: 92,
                        decoration: BoxDecoration(
                          color: const Color(0xFF211E36),
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(
                            color: const Color(0xFF67507E),
                            width: 0.7,
                          ),
                        ),
                        child: const Icon(
                          Icons.error_outline_rounded,
                          color: VideoFormStyle.accent,
                          size: 48,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: VideoFormStyle.serif(29),
                      ),
                      const SizedBox(height: 13),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: VideoFormStyle.secondary,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                      if (creditsRefunded) ...[
                        const SizedBox(height: 12),
                        const Text(
                          'Your credits have been refunded.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF8CC9B2),
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Text(
                        guidance ??
                            'Return to $creatorLabel and try again with another prompt.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: VideoFormStyle.muted,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 32),
                      const Spacer(),
                      _FailureBackButton(
                        creatorLabel: creatorLabel,
                        onTap: onBackToCreate,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _FailureBackButton extends StatelessWidget {
  const _FailureBackButton({required this.creatorLabel, required this.onTap});
  final String creatorLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => _CreatingActionButton(
    buttonKey: const Key('backToImageToVideo'),
    label: 'Back to $creatorLabel',
    icon: Icons.arrow_back_rounded,
    onTap: onTap,
  );
}

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
        backgroundColor: const Color(0xFF030208),
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
                              const SizedBox(height: 8),
                              const _GeneratingTitle(),
                              const SizedBox(height: 8),
                              const Text(
                                "We're turning your idea into a cinematic result.\n"
                                'This may take a few moments.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Color(0xFFC5BFC9),
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
                                    color: Color(0xFFFF52B1),
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
                                  color: Color(0xFF655E69),
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
  Widget build(BuildContext context) {
    return Dialog(
      key: const Key('leaveCreatingVideoDialog'),
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF271020), Color(0xFF100A13)],
          ),
          border: Border.all(color: const Color(0xFF963466)),
          boxShadow: const [
            BoxShadow(color: Color(0x66FF2CAC), blurRadius: 28),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFF2EAC).withValues(alpha: 0.12),
                border: Border.all(color: const Color(0xFFFF42B3)),
                boxShadow: const [
                  BoxShadow(color: Color(0x66FF28AB), blurRadius: 18),
                ],
              ),
              child: const Icon(
                Icons.hourglass_top_rounded,
                color: Color(0xFFFF58B9),
                size: 31,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Leave this screen?',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 21,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your video will keep generating in the background. '
              'You can check its progress in Generation History.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFFC6BEC9),
                fontSize: 13,
                height: 1.42,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const Key('keepWaitingForVideo'),
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFF6B3A5C)),
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: const Text('Keep waiting'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    key: const Key('leaveForGenerationHistory'),
                    onPressed: () => Navigator.pop(context, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFF3D9D),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      shadowColor: const Color(0xFFFF28A9),
                      elevation: 6,
                    ),
                    child: const Text(
                      'Go to History',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
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
          colors: [Color(0x4215002B), Color(0xFF030208)],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              key: const Key('creatingVideoBack'),
              onPressed: onBack,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 40, height: 38),
              icon: const Icon(Icons.arrow_back_rounded, size: 30),
              color: Colors.white,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 48),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'Creating Video',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
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
          final pulse = 0.28 + (_effectController.value * 0.32);
          return Container(
            width: 270,
            height: 250,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFF1BB6), Color(0xFFFF9B2D)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF20B0).withValues(alpha: pulse),
                  blurRadius: 22 + (_effectController.value * 10),
                  spreadRadius: 1 + (_effectController.value * 2),
                ),
                BoxShadow(
                  color: const Color(0xFFFF8A27).withValues(alpha: pulse * 0.7),
                  blurRadius: 18 + (_effectController.value * 8),
                ),
              ],
            ),
            padding: const EdgeInsets.all(1.2),
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
      borderRadius: BorderRadius.circular(29),
      child: ColoredBox(
        color: const Color(0xFF09030D),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _sourceImage(),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  radius: 0.85,
                  colors: [Color(0x11000000), Color(0x8A09030D)],
                  stops: [0.42, 1],
                ),
              ),
            ),
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(29),
                child: RepaintBoundary(
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
                      Color(0xFFFF25B4),
                      Color(0xFFFFA22C),
                      Colors.transparent,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(color: Color(0xCCFF35B1), blurRadius: 12),
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
          color: Color(0xFF16091A),
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
          child: Image.asset(
            'assets/images/create_video.png',
            key: const Key('creatingDefaultArtwork'),
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
          ),
        ),
      ),
    );
  }
}

class _GeneratingTitle extends StatelessWidget {
  const _GeneratingTitle();

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: RichText(
        text: const TextSpan(
          style: TextStyle(fontSize: 27, fontWeight: FontWeight.w800),
          children: [
            TextSpan(
              text: 'Generating ',
              style: TextStyle(color: Colors.white),
            ),
            TextSpan(
              text: 'your video...',
              style: TextStyle(color: Color(0xFFFF5374)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressPercent extends StatelessWidget {
  const _ProgressPercent({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => const LinearGradient(
        colors: [Color(0xFFFF24B5), Color(0xFFFF9B2D)],
      ).createShader(bounds),
      child: Text(
        '${(progress * 100).round()}%',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 34,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _NeonProgressBar extends StatelessWidget {
  const _NeonProgressBar({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 17,
      padding: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF8B175F)),
        color: const Color(0xFF1A0718),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => Align(
          alignment: Alignment.centerLeft,
          child: Container(
            width: constraints.maxWidth * progress,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFFF18B1),
                  Color(0xFFFF4D58),
                  Color(0xFFFFA62B),
                ],
              ),
              boxShadow: const [
                BoxShadow(color: Color(0xAAFF2AAA), blurRadius: 9),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 13),
      decoration: BoxDecoration(
        color: const Color(0xC0140817),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: active ? const Color(0xFFFF3CAF) : const Color(0xFF6D184F),
          width: active ? 1.4 : 1,
        ),
        boxShadow: active
            ? const [BoxShadow(color: Color(0x55FF21A9), blurRadius: 12)]
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: completed || active
                    ? const Color(0xFFFF42B1)
                    : const Color(0xFF794062),
                width: 1.5,
              ),
            ),
            child: completed
                ? const Icon(
                    Icons.check_rounded,
                    color: Color(0xFFFF55B7),
                    size: 22,
                  )
                : active
                ? const Padding(
                    padding: EdgeInsets.all(7),
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Color(0xFFFF952E),
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${index + 1}/$totalSteps  $label',
              style: TextStyle(
                color: state == _StepState.pending
                    ? const Color(0xFFAAA2AE)
                    : Colors.white,
                fontSize: 14,
              ),
            ),
          ),
          Text(
            status,
            style: TextStyle(
              color: completed
                  ? const Color(0xFF48D85B)
                  : active
                  ? const Color(0xFFFFA328)
                  : const Color(0xFF918A95),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _BackgroundTip extends StatelessWidget {
  const _BackgroundTip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xC0130716),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF8C1B64)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline_rounded, color: Color(0xFFFF51B5), size: 29),
          SizedBox(width: 13),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: TextStyle(
                  color: Color(0xFFC8C1CB),
                  fontSize: 13,
                  height: 1.45,
                ),
                children: [
                  TextSpan(
                    text: 'Tip: ',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(
                    text:
                        "You can continue in background\nand we’ll notify you when it’s ready.",
                  ),
                ],
              ),
            ),
          ),
          Icon(
            Icons.notifications_active_outlined,
            color: Color(0xFFFF8B36),
            size: 35,
          ),
        ],
      ),
    );
  }
}

class _ContinueButton extends StatelessWidget {
  const _ContinueButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(29),
        gradient: const LinearGradient(
          colors: [Color(0xFFFF15AC), Color(0xFFFF4F5C), Color(0xFFFFA62B)],
        ),
        boxShadow: const [BoxShadow(color: Color(0x77FF1BA8), blurRadius: 16)],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(29),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(29),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Continue in Background',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 18),
              Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 27),
            ],
          ),
        ),
      ),
    );
  }
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF030208),
      body: Stack(
        children: [
          const Positioned.fill(child: _LoadingGlow()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: onBackToCreate,
                      icon: const Icon(Icons.arrow_back_rounded, size: 30),
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: 104,
                    height: 104,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xFFFF20B4), Color(0xFFFF942F)],
                      ),
                      boxShadow: [
                        BoxShadow(color: Color(0x77FF21AA), blurRadius: 26),
                      ],
                    ),
                    padding: const EdgeInsets.all(2),
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF150819),
                      ),
                      child: Icon(
                        Icons.error_outline_rounded,
                        color: Color(0xFFFF55B2),
                        size: 58,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 29,
                      height: 1.12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.7,
                    ),
                  ),
                  const SizedBox(height: 13),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFC2BBC6),
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                  if (creditsRefunded) ...[
                    const SizedBox(height: 10),
                    const Text(
                      'Your credits have been refunded.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF63E981),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    guidance ??
                        'Return to $creatorLabel and try again with another prompt.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF8D8592),
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                  const Spacer(),
                  _FailureBackButton(
                    creatorLabel: creatorLabel,
                    onTap: onBackToCreate,
                  ),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FailureBackButton extends StatelessWidget {
  const _FailureBackButton({required this.creatorLabel, required this.onTap});

  final String creatorLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(29),
        gradient: const LinearGradient(
          colors: [Color(0xFFFF16A8), Color(0xFFFF4E5D), Color(0xFFFFA42B)],
        ),
        boxShadow: const [BoxShadow(color: Color(0x77FF1AA7), blurRadius: 16)],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(29),
        child: InkWell(
          key: const Key('backToImageToVideo'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(29),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.arrow_back_rounded,
                color: Colors.white,
                size: 25,
              ),
              const SizedBox(width: 10),
              Text(
                'Back to $creatorLabel',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

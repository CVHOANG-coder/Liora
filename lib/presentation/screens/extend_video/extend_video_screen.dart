import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../core/constants/app_features.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../data/models/generation_progress.dart';
import '../../../data/models/i2v_generation.dart';
import '../../../data/models/i2v_request_status.dart';
import '../../../data/services/generation_progress_repository.dart';
import '../../providers/profile_provider.dart';
import '../../widgets/cached_video_thumbnail.dart';
import '../../widgets/generation_failure_dialog.dart';
import '../../widgets/generation_form_exit_guard.dart';
import '../../widgets/video_form_widgets.dart';
import '../../widgets/video_library_widgets.dart';
import '../image_to_video/creating_video_screen.dart';
import '../in_app_purchase/all_plans_screen.dart';
import '../in_app_purchase/credit_purchase_navigation.dart';
import '../support/support_contact_screen.dart';

typedef ExtendVideoSubmit =
    Future<I2VGeneration> Function({
      String? requestId,
      String? videoUrl,
      required String prompt,
      bool isHd,
      int duration,
      String? seed,
    });

class _ExtensionRequest {
  const _ExtensionRequest({
    required this.prompt,
    required this.duration,
    required this.isHd,
  });
  final String prompt;
  final int duration;
  final bool isHd;
}

/// The result screen owns the optional preview player for this route.
class ExtendVideoScreen extends ConsumerStatefulWidget {
  const ExtendVideoScreen({
    super.key,
    required this.result,
    this.previewController,
    this.submit,
    this.progressRepository,
    this.statusFetcher,
  });

  final I2VRequestStatus result;
  final VideoPlayerController? previewController;
  final ExtendVideoSubmit? submit;
  final GenerationProgressRepository? progressRepository;
  final I2VStatusFetcher? statusFetcher;

  @override
  ConsumerState<ExtendVideoScreen> createState() => _ExtendVideoScreenState();
}

class _ExtendVideoScreenState extends ConsumerState<ExtendVideoScreen> {
  final _prompt = TextEditingController();
  final _promptFocus = FocusNode();
  final _exitGuardKey = GlobalKey<GenerationFormExitGuardState>();
  int _duration = 10;
  bool _isHd = false;
  bool _isSubmitting = false;
  bool _hasLeftForm = false;

  @override
  void dispose() {
    _prompt.dispose();
    _promptFocus.dispose();
    super.dispose();
  }

  Future<void> _extend([_ExtensionRequest? pendingRequest]) async {
    if (_isSubmitting || _hasLeftForm) return;
    if (pendingRequest == null && _prompt.text.trim().isEmpty) {
      _promptFocus.requestFocus();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Describe what happens next in your video.'),
        ),
      );
      return;
    }
    final request =
        pendingRequest ??
        _ExtensionRequest(
          prompt: _prompt.text.trim(),
          duration: _duration,
          isHd: _isHd,
        );
    FocusScope.of(context).unfocus();
    setState(() => _isSubmitting = true);
    try {
      final submit = widget.submit ?? ApiClient.instance.extendVideo;
      final generation = await submit(
        requestId: widget.result.requestId.isNotEmpty
            ? widget.result.requestId
            : null,
        videoUrl: widget.result.requestId.isEmpty
            ? widget.result.resultUrl
            : null,
        prompt: request.prompt,
        duration: request.duration,
        isHd: request.isHd,
      );
      if (!mounted || _hasLeftForm) return;
      ref
          .read(profileProvider.notifier)
          .updateTotalCredit(generation.remainingCredit);
      final progress = GenerationProgress.create(
        requestId: generation.requestId,
        startedAt: generation.createTime ?? DateTime.now(),
        videoDurationSeconds: generation.params.duration > 0
            ? generation.params.duration
            : request.duration,
        isHd: request.isHd,
      );
      final repository =
          widget.progressRepository ??
          const SharedPreferencesGenerationProgressRepository();
      try {
        await repository.save(progress);
      } catch (_) {
        // A local storage failure must not resubmit an accepted paid request.
      }
      if (!mounted || _hasLeftForm) return;
      _exitGuardKey.currentState?.dismissWarning();
      final player = widget.previewController;
      if (player != null) {
        try {
          await player.pause();
        } catch (_) {
          /* Preview cannot block the job. */
        }
      }
      if (!mounted || _hasLeftForm) return;
      setState(() => _isSubmitting = false);
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => CreatingVideoScreen(
            generation: generation,
            initialProgress: progress,
            progressRepository: repository,
            statusFetcher: widget.statusFetcher,
            creatorLabel: 'Extend Video',
            isExtension: true,
          ),
        ),
      );
    } catch (error) {
      if (!mounted || _hasLeftForm) return;
      _exitGuardKey.currentState?.dismissWarning();
      setState(() => _isSubmitting = false);
      final action =
          AppFeatures.commerceEnabled && isInsufficientCreditError(error)
          ? GenerationFailureAction.buyCredits
          : await GenerationFailureDialog.showForError(
              context,
              error: error,
              fallbackMessage: 'Unable to extend the video. Please try again.',
            );
      if (!mounted || _hasLeftForm) return;
      switch (action) {
        case GenerationFailureAction.buyCredits:
          final profile = ref.read(profileProvider);
          final purchased = await openCreditPurchaseDestination(
            context,
            isSubscribed: profile?.isSubscribed == true,
            isVIP: profile?.isVIP == true,
            error: error,
          );
          if (purchased && mounted && !_hasLeftForm) await _extend(request);
        case GenerationFailureAction.renewSubscription:
          await Navigator.of(
            context,
          ).push(MaterialPageRoute<void>(builder: (_) => const AllPlans()));
        case GenerationFailureAction.contactSupport:
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => SupportContactScreen(
                errorCode: error is ApiException ? error.errorCode : null,
                errorMessage: error is ApiException ? error.message : null,
              ),
            ),
          );
        case GenerationFailureAction.retry:
          await _extend(request);
        case GenerationFailureAction.editInput:
        case GenerationFailureAction.chooseImage:
          _promptFocus.requestFocus();
        case GenerationFailureAction.chooseTheme:
        case GenerationFailureAction.close:
        case null:
          break;
      }
    }
  }

  Future<void> _pickQuality() async {
    final quality = await showVideoFormOptions(
      context,
      title: 'Quality',
      options: const ['Non-HD', 'HD'],
      selected: _isHd ? 'HD' : 'Non-HD',
    );
    if (mounted && quality != null) setState(() => _isHd = quality == 'HD');
  }

  Widget _buildAction() => SizedBox(
    width: double.infinity,
    child: VideoLibraryAction(
      key: const Key('submitExtendVideo'),
      label: _isSubmitting
          ? 'Sending request…'
          : 'Extend video · ${_duration}s',
      icon: Icons.auto_awesome_rounded,
      primary: true,
      busy: _isSubmitting,
      onTap: _isSubmitting ? null : _extend,
    ),
  );

  @override
  Widget build(BuildContext context) => GenerationFormExitGuard(
    key: _exitGuardKey,
    isSubmitting: _isSubmitting,
    onLeave: () => _hasLeftForm = true,
    child: Scaffold(
      backgroundColor: VideoFormStyle.background,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: VideoFormLayout(
          title: 'Extend video',
          backKey: const Key('extendVideoBack'),
          pinAction: true,
          action: _buildAction(),
          children: [
            // Text(
            //   'Keep the story going',
            //   style: VideoFormStyle.heading(24, fontWeight: FontWeight.w800),
            // ),
            // const SizedBox(height: 7),
            // const Text(
            //   'Create a new clip that continues from the last frame of your video.',
            //   style: TextStyle(
            //     color: VideoFormStyle.secondary,
            //     fontSize: 14,
            //     height: 1.5,
            //   ),
            // ),
            // const SizedBox(height: 8),
            _SourceVideo(
              result: widget.result,
              controller: widget.previewController,
            ),
            const SizedBox(height: 16),
            const VideoPromptHeader(title: 'What happens next?'),
            const SizedBox(height: 9),
            VideoPromptBox(
              fieldKey: const Key('extendVideoPrompt'),
              controller: _prompt,
              focusNode: _promptFocus,
              readOnly: _isSubmitting,
              height: 120,
              hint: 'Describe the next scene, action, or camera movement…',
            ),
            const SizedBox(height: 18),
            const VideoPromptHeader(
              title: 'New clip duration',
              requirement: '',
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                for (final seconds in [5, 10, 15]) ...[
                  if (seconds != 5) const SizedBox(width: 8),
                  Expanded(
                    child: _DurationOption(
                      seconds: seconds,
                      selected: _duration == seconds,
                      onTap: _isSubmitting
                          ? null
                          : () => setState(() => _duration = seconds),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            VideoFormSettingRow(
              asset: 'assets/images/gen_video/HD_icon.png',
              title: 'Quality',
              value: _isHd ? 'HD' : 'Non-HD',
              onTap: _isSubmitting ? null : _pickQuality,
            ),
            // const SizedBox(height: 12),
            // const Row(
            //   crossAxisAlignment: CrossAxisAlignment.start,
            //   children: [
            //     Icon(
            //       Icons.aspect_ratio_rounded,
            //       color: VideoFormStyle.muted,
            //       size: 16,
            //     ),
            //     SizedBox(width: 8),
            //     Expanded(
            //       child: Text(
            //         'The new clip keeps your original video’s aspect ratio.',
            //         style: TextStyle(
            //           color: VideoFormStyle.muted,
            //           fontSize: 12,
            //           height: 1.5,
            //         ),
            //       ),
            //     ),
            //   ],
            // ),
            // const SizedBox(height: 10),
            const SizedBox(height: 12),
          ],
        ),
      ),
    ),
  );
}

class _SourceVideo extends StatelessWidget {
  const _SourceVideo({required this.result, required this.controller});

  final I2VRequestStatus result;
  final VideoPlayerController? controller;

  @override
  Widget build(BuildContext context) {
    final player = controller;
    return Container(
      decoration: BoxDecoration(
        gradient: VideoFormStyle.surface,
        border: Border.all(color: VideoFormStyle.border, width: .6),
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          SizedBox(
            height: 140,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: Color(0xFF201A29)),
                if (player != null)
                  Center(
                    child: AspectRatio(
                      aspectRatio: player.value.aspectRatio,
                      child: VideoPlayer(player),
                    ),
                  )
                else
                  CachedVideoThumbnail(
                    cacheKey: 'request:${result.requestId}',
                    imageUrl: result.thumbnailUrl,
                    fallbackImageUrl: result.imageUrl,
                    placeholder: const Icon(
                      Icons.movie_outlined,
                      color: VideoFormStyle.muted,
                      size: 40,
                    ),
                  ),
                if (player != null)
                  Center(
                    child: ValueListenableBuilder<VideoPlayerValue>(
                      valueListenable: player,
                      builder: (context, value, _) => IconButton.filled(
                        key: const Key('extendVideoPreviewPlay'),
                        tooltip: value.isPlaying
                            ? 'Pause preview'
                            : 'Play preview',
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xB3292431),
                        ),
                        onPressed: () =>
                            value.isPlaying ? player.pause() : player.play(),
                        icon: Icon(
                          value.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.white,
                        ),
                        iconSize: 28,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                const Icon(
                  Icons.videocam_outlined,
                  color: VideoFormStyle.accent,
                  size: 20,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Original video',
                    style: VideoFormStyle.heading(
                      15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  result.isHd ? 'HD' : 'Non-HD',
                  style: const TextStyle(
                    color: VideoFormStyle.secondary,
                    fontSize: 12,
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

class _DurationOption extends StatelessWidget {
  const _DurationOption({
    required this.seconds,
    required this.selected,
    required this.onTap,
  });

  final int seconds;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: Material(
      color: selected
          ? VideoFormStyle.accent.withValues(alpha: .16)
          : const Color(0xFF342D3E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(11),
        side: BorderSide(
          color: selected ? VideoFormStyle.accent : VideoFormStyle.border,
          width: selected ? 1 : .6,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('extendDuration$seconds'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.add_circle_outline_rounded,
                color: selected ? VideoFormStyle.accent : VideoFormStyle.muted,
                size: 19,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '${seconds}s',
                  style: VideoFormStyle.heading(
                    18,
                    fontWeight: FontWeight.w700,
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

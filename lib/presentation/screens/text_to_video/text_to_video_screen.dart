import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../data/models/generation_progress.dart';
import '../../../data/models/i2v_generation.dart';
import '../../../data/services/generation_progress_repository.dart';
import '../../providers/profile_provider.dart';
import '../../widgets/generation_failure_dialog.dart';
import '../../widgets/generation_form_exit_guard.dart';
import '../../widgets/video_form_widgets.dart';
import '../image_to_video/creating_video_screen.dart';
import '../in_app_purchase/all_plans_screen.dart';
import '../in_app_purchase/credit_purchase_navigation.dart';
import '../support/support_contact_screen.dart';

typedef TextToVideoSubmit =
    Future<I2VGeneration> Function({
      required String prompt,
      required bool isHd,
      required bool isLongTime,
    });

class _TextToVideoRequest {
  const _TextToVideoRequest({
    required this.prompt,
    required this.isHd,
    required this.isLongTime,
  });

  final String prompt;
  final bool isHd;
  final bool isLongTime;
}

class TextToVideoScreen extends ConsumerStatefulWidget {
  const TextToVideoScreen({super.key, this.submit, this.progressRepository});

  final TextToVideoSubmit? submit;
  final GenerationProgressRepository? progressRepository;

  @override
  ConsumerState<TextToVideoScreen> createState() => _TextToVideoScreenState();
}

class _TextToVideoScreenState extends ConsumerState<TextToVideoScreen> {
  final _promptController = TextEditingController();
  final _promptFocusNode = FocusNode();
  final _keyboardDismissFocusNode = FocusNode(skipTraversal: true);
  final _promptBoxKey = GlobalKey();
  String _duration = '10s';
  String _quality = 'Non-HD';
  bool _isSubmitting = false;
  bool _hasLeftForm = false;
  final _exitGuardKey = GlobalKey<GenerationFormExitGuardState>();

  @override
  void dispose() {
    _promptController.dispose();
    _promptFocusNode.dispose();
    _keyboardDismissFocusNode.dispose();
    super.dispose();
  }

  void _dismissKeyboardOutsidePrompt(PointerDownEvent event) {
    final renderObject = _promptBoxKey.currentContext?.findRenderObject();
    if (renderObject is RenderBox) {
      final localPosition = renderObject.globalToLocal(event.position);
      if (renderObject.paintBounds.contains(localPosition)) return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        FocusScope.of(context).requestFocus(_keyboardDismissFocusNode);
      }
    });
  }

  Future<void> _pickOption({
    required String title,
    required List<String> options,
    required String selected,
    required ValueChanged<String> onSelected,
  }) async {
    if (_isSubmitting) return;
    final choice = await showVideoFormOptions(
      context,
      title: title,
      options: options,
      selected: selected,
    );
    if (mounted && choice != null) onSelected(choice);
  }

  Future<void> _generate([_TextToVideoRequest? pendingRequest]) async {
    if (_isSubmitting || _hasLeftForm) return;
    final _TextToVideoRequest request;
    if (pendingRequest != null) {
      request = pendingRequest;
    } else {
      final prompt = _promptController.text.trim();
      if (prompt.isEmpty) {
        _promptFocusNode.requestFocus();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Enter a video prompt.')));
        return;
      }
      request = _TextToVideoRequest(
        prompt: prompt,
        isHd: _quality == 'HD',
        isLongTime: _duration == '10s',
      );
    }

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _isSubmitting = true);
    try {
      final submit = widget.submit ?? ApiClient.instance.generateTextToVideo;
      final generation = await submit(
        prompt: request.prompt,
        isHd: request.isHd,
        isLongTime: request.isLongTime,
      );
      if (!mounted || _hasLeftForm) return;

      final progress = GenerationProgress.create(
        requestId: generation.requestId,
        startedAt: generation.createTime ?? DateTime.now(),
        videoDurationSeconds: request.isLongTime ? 10 : 5,
        isHd: request.isHd,
      );
      final progressRepository =
          widget.progressRepository ??
          const SharedPreferencesGenerationProgressRepository();
      try {
        await progressRepository.save(progress);
      } catch (_) {
        // The submitted request remains valid if local persistence fails.
      }
      if (!mounted || _hasLeftForm) return;

      ref
          .read(profileProvider.notifier)
          .updateTotalCredit(generation.remainingCredit);
      _exitGuardKey.currentState?.dismissWarning();
      setState(() => _isSubmitting = false);
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => CreatingVideoScreen(
            generation: generation,
            initialProgress: progress,
            progressRepository: progressRepository,
            creatorLabel: 'Text to Video',
          ),
        ),
      );
    } catch (error) {
      if (!mounted || _hasLeftForm) return;
      _exitGuardKey.currentState?.dismissWarning();
      setState(() => _isSubmitting = false);
      final action = isInsufficientCreditError(error)
          ? GenerationFailureAction.buyCredits
          : await GenerationFailureDialog.showForError(
              context,
              error: error,
              fallbackMessage:
                  'Unable to generate the video. Please try again.',
            );
      if (!mounted) return;
      switch (action) {
        case GenerationFailureAction.buyCredits:
          final profile = ref.read(profileProvider);
          final purchased = await openCreditPurchaseDestination(
            context,
            isSubscribed: profile?.isSubscribed == true,
            isVIP: profile?.isVIP == true,
            error: error,
          );
          if (purchased && mounted) await _generate(request);
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
        case GenerationFailureAction.editInput:
        case GenerationFailureAction.chooseImage:
          _promptFocusNode.requestFocus();
        case GenerationFailureAction.chooseTheme:
          Navigator.maybePop(context);
        case GenerationFailureAction.retry:
          await _generate();
        case GenerationFailureAction.close:
        case null:
          break;
      }
    }
  }

  @override
  Widget build(BuildContext context) => GenerationFormExitGuard(
    key: _exitGuardKey,
    isSubmitting: _isSubmitting,
    onLeave: () => _hasLeftForm = true,
    child: Scaffold(
      backgroundColor: VideoFormStyle.background,
      body: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _dismissKeyboardOutsidePrompt,
        child: VideoFormLayout(
          title: 'Text to video',
          backKey: const Key('textToVideoBackButton'),
          children: [
            const VideoPromptHeader(),
            const SizedBox(height: 9),
            VideoPromptBox(
              key: _promptBoxKey,
              fieldKey: const Key('textToVideoPromptField'),
              controller: _promptController,
              focusNode: _promptFocusNode,
              readOnly: _isSubmitting,
              hint:
                  'Describe your scene, characters, camera motion, lighting, and mood...',
              height: 260,
            ),
            const SizedBox(height: 11),

            VideoFormSettingRow(
              asset: 'assets/images/gen_video/clock.png',
              title: 'Duration',
              value: _duration,
              onTap: _isSubmitting
                  ? null
                  : () => _pickOption(
                      title: 'Duration',
                      options: const ['5s', '10s'],
                      selected: _duration,
                      onSelected: (value) => setState(() => _duration = value),
                    ),
            ),
            const SizedBox(height: 9),
            VideoFormSettingRow(
              asset: 'assets/images/gen_video/HD_icon.png',
              title: 'Quality',
              value: _quality,
              onTap: _isSubmitting
                  ? null
                  : () => _pickOption(
                      title: 'Quality',
                      options: const ['Non-HD', 'HD'],
                      selected: _quality,
                      onSelected: (value) => setState(() => _quality = value),
                    ),
            ),
          ],
          action: VideoGenerateButton(
            buttonKey: const Key('generateTextToVideo'),
            onPressed: _generate,
            isLoading: _isSubmitting,
          ),
        ),
      ),
    ),
  );
}

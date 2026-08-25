import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../data/models/generation_progress.dart';
import '../../../data/models/i2v_generation.dart';
import '../../../data/services/generation_progress_repository.dart';
import '../../providers/profile_provider.dart';
import '../../widgets/generation_failure_dialog.dart';
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
  String _duration = '10s';
  String _quality = 'Non-HD';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _promptController.dispose();
    _promptFocusNode.dispose();
    super.dispose();
  }

  Future<void> _pickOption({
    required String title,
    required List<String> options,
    required String selected,
    required ValueChanged<String> onSelected,
  }) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF17101D),
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            ...options.map(
              (option) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(option),
                trailing: option == selected
                    ? const Icon(Icons.check_rounded, color: AppColors.accent)
                    : null,
                onTap: () => Navigator.pop(context, option),
              ),
            ),
          ],
        ),
      ),
    );
    if (choice != null) onSelected(choice);
  }

  Future<void> _generate() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) {
      _promptFocusNode.requestFocus();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter a video prompt.')));
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _isSubmitting = true);
    try {
      final submit = widget.submit ?? ApiClient.instance.generateTextToVideo;
      final isHd = _quality == 'HD';
      final videoDurationSeconds = _duration == '10s' ? 10 : 5;
      final generation = await submit(
        prompt: prompt,
        isHd: isHd,
        isLongTime: _duration == '10s',
      );
      if (!mounted) return;

      final progress = GenerationProgress.create(
        requestId: generation.requestId,
        startedAt: generation.createTime ?? DateTime.now(),
        videoDurationSeconds: videoDurationSeconds,
        isHd: isHd,
      );
      final progressRepository =
          widget.progressRepository ??
          const SharedPreferencesGenerationProgressRepository();
      try {
        await progressRepository.save(progress);
      } catch (_) {
        // The submitted request remains valid if local persistence fails.
      }
      if (!mounted) return;

      ref
          .read(profileProvider.notifier)
          .updateTotalCredit(generation.remainingCredit);
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
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      final action = await GenerationFailureDialog.showForError(
        context,
        error: error,
        fallbackMessage: 'Unable to generate the video. Please try again.',
      );
      if (!mounted) return;
      switch (action) {
        case GenerationFailureAction.buyCredits:
          await openCreditPurchaseDestination(
            context,
            isVIP: ref.read(profileProvider)?.isVIP == true,
          );
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
              sliver: SliverList.list(
                children: [
                  _Header(onBack: () => Navigator.maybePop(context)),
                  const SizedBox(height: 24),
                  const _PromptHeader(),
                  const SizedBox(height: 9),
                  _PromptBox(
                    controller: _promptController,
                    focusNode: _promptFocusNode,
                  ),
                  const SizedBox(height: 11),
                  _SettingRow(
                    asset: 'assets/images/gen_video/clock.png',
                    title: 'Duration',
                    value: _duration,
                    onTap: () => _pickOption(
                      title: 'Duration',
                      options: const ['5s', '10s'],
                      selected: _duration,
                      onSelected: (value) => setState(() => _duration = value),
                    ),
                  ),
                  const SizedBox(height: 7),
                  _SettingRow(
                    asset: 'assets/images/gen_video/HD_icon.png',
                    title: 'Quality',
                    value: _quality,
                    onTap: () => _pickOption(
                      title: 'Quality',
                      options: const ['Non-HD', 'HD'],
                      selected: _quality,
                      onSelected: (value) => setState(() => _quality = value),
                    ),
                  ),
                  const SizedBox(height: 27),
                  _GenerateButton(
                    onPressed: _isSubmitting ? null : _generate,
                    isLoading: _isSubmitting,
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

class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              key: const Key('textToVideoBackButton'),
              onPressed: onBack,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: const Icon(Icons.arrow_back_rounded, size: 28),
              color: Colors.white,
            ),
          ),
          const Text(
            'Text to video',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _PromptHeader extends StatelessWidget {
  const _PromptHeader();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Text(
          'Prompt',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        SizedBox(width: 5),
        Text(
          '(Required)',
          style: TextStyle(color: Color(0xFFFF63B5), fontSize: 15),
        ),
      ],
    );
  }
}

class _PromptBox extends StatelessWidget {
  const _PromptBox({required this.controller, required this.focusNode});

  final TextEditingController controller;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150,
      padding: const EdgeInsets.fromLTRB(12, 9, 10, 6),
      decoration: BoxDecoration(
        color: const Color(0xFF080007),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFF4FB5)),
        boxShadow: const [BoxShadow(color: Color(0x553A0039), blurRadius: 22)],
      ),
      child: Stack(
        children: [
          TextField(
            key: const Key('textToVideoPromptField'),
            controller: controller,
            focusNode: focusNode,
            maxLength: 2800,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              height: 1.4,
            ),
            decoration: const InputDecoration(
              hintText:
                  'Describe the scene, action, camera motion, lighting, and mood...',
              hintStyle: TextStyle(
                color: Color(0xFF88818E),
                fontSize: 16,
                height: 1.55,
              ),
              border: InputBorder.none,
              counterText: '',
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (_, value, _) => Text(
                '${value.text.length}/2800',
                style: const TextStyle(color: Color(0xFF8B8490), fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.asset,
    required this.title,
    required this.value,
    required this.onTap,
  });

  final String asset;
  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF10050F),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF4F1646)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: Image.asset(asset, fit: BoxFit.contain),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Color(0xFFFF5F9E),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 11),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF190C1A),
                  border: Border.all(color: const Color(0xFF552149)),
                ),
                child: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GenerateButton extends StatelessWidget {
  const _GenerateButton({required this.onPressed, required this.isLoading});

  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          colors: [Color(0xFFFF1594), Color(0xFFFF4D55), Color(0xFFFFAE25)],
        ),
        boxShadow: const [
          BoxShadow(color: Color(0xCCFF1594), blurRadius: 14, spreadRadius: 1),
          BoxShadow(
            color: Color(0x99FF8C25),
            blurRadius: 18,
            offset: Offset(4, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          key: const Key('generateTextToVideo'),
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Generate',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(width: 6),
                      Icon(
                        Icons.auto_awesome_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

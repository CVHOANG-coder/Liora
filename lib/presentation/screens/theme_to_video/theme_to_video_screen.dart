import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/device/image_access_permission.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../data/models/generation_progress.dart';
import '../../../data/models/i2v_generation.dart';
import '../../../data/services/generation_progress_repository.dart';
import '../../../data/video_categories.dart';
import '../../providers/profile_provider.dart';
import '../../widgets/generation_failure_dialog.dart';
import '../../widgets/generation_form_exit_guard.dart';
import '../../widgets/video_form_widgets.dart';
import '../image_to_video/creating_video_screen.dart';
import '../in_app_purchase/all_plans_screen.dart';
import '../in_app_purchase/credit_purchase_navigation.dart';
import '../support/support_contact_screen.dart';

typedef ThemeVideoPickImage = Future<String?> Function(ImageSource source);
typedef ThemeVideoRequestPermission =
    Future<ImageAccessPermissionResult> Function(ImageSource source);
typedef ThemeVideoSubmit =
    Future<I2VGeneration> Function({
      required String themeId,
      required String firstImagePath,
      required bool isHd,
      required bool isLongTime,
      void Function(int sent, int total)? onUploadProgress,
    });

class _ThemeToVideoRequest {
  const _ThemeToVideoRequest({
    required this.themeId,
    required this.firstImagePath,
    required this.isHd,
    required this.isLongTime,
  });

  final String themeId;
  final String firstImagePath;
  final bool isHd;
  final bool isLongTime;
}

class ThemeToVideoScreen extends ConsumerStatefulWidget {
  const ThemeToVideoScreen({
    super.key,
    required this.theme,
    this.pickImage,
    this.requestPermission,
    this.submit,
    this.progressRepository,
  });

  final VideoPost theme;
  final ThemeVideoPickImage? pickImage;
  final ThemeVideoRequestPermission? requestPermission;
  final ThemeVideoSubmit? submit;
  final GenerationProgressRepository? progressRepository;

  @override
  ConsumerState<ThemeToVideoScreen> createState() => _ThemeToVideoScreenState();
}

class _ThemeToVideoScreenState extends ConsumerState<ThemeToVideoScreen> {
  String _duration = '10s';
  String _quality = 'Non-HD';
  String? _firstImagePath;
  bool _isPickingImage = false;
  bool _isSubmitting = false;
  bool _hasLeftForm = false;
  final _exitGuardKey = GlobalKey<GenerationFormExitGuardState>();
  int _uploadAttempt = 0;
  int _uploadSentBytes = 0;
  int _uploadTotalBytes = 0;

  Future<void> _selectFrame() async {
    if (_isPickingImage || _isSubmitting) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      barrierColor: const Color(0xB802050C),
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (_) => const VideoImageSourceSheet(isFrame: true),
    );
    if (!mounted || source == null) return;

    setState(() => _isPickingImage = true);
    try {
      final requester =
          widget.requestPermission ?? ImageAccessPermission.request;
      final permission = await requester(source);
      if (!mounted) return;
      if (permission == ImageAccessPermissionResult.settingsRequired) {
        await _showPermissionSettingsDialog(source);
        return;
      }
      if (permission == ImageAccessPermissionResult.denied) {
        _showPermissionDeniedMessage(source);
        return;
      }

      final imagePath = await _pickImage(source);
      if (!mounted || imagePath == null || imagePath.isEmpty) return;
      setState(() => _firstImagePath = imagePath);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            source == ImageSource.camera
                ? 'Unable to open the camera. Please try again.'
                : 'Unable to open the photo library. Please try again.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isPickingImage = false);
    }
  }

  Future<String?> _pickImage(ImageSource source) async {
    final picker = widget.pickImage;
    if (picker != null) return picker(source);
    return (await ImagePicker().pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1920,
      maxHeight: 1920,
      requestFullMetadata: false,
    ))?.path;
  }

  void _showPermissionDeniedMessage(ImageSource source) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          source == ImageSource.camera
              ? 'Camera permission is required to take a photo.'
              : 'Photo access is required to select an image.',
        ),
      ),
    );
  }

  Future<void> _showPermissionSettingsDialog(ImageSource source) async {
    final isCamera = source == ImageSource.camera;
    final shouldOpenSettings = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: VideoFormStyle.background,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        icon: Container(
          width: 54,
          height: 54,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [Color(0xFFEC5FB6), Color(0xFFA850CF)],
            ),
          ),
          child: Icon(
            isCamera ? Icons.photo_camera_rounded : Icons.photo_library_rounded,
            color: Colors.white,
          ),
        ),
        title: const Text('Permission Required'),
        content: Text(
          isCamera
              ? 'Enable Camera permission in Settings to take a photo for your video.'
              : 'Enable Photos permission in Settings to select an image for your video.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: VideoFormStyle.secondary, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not Now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: VideoFormStyle.accent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
    if (shouldOpenSettings == true) {
      await ImageAccessPermission.openSettings();
    }
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

  Future<void> _generate([_ThemeToVideoRequest? pendingRequest]) async {
    if (_isSubmitting || _hasLeftForm) return;
    final _ThemeToVideoRequest request;
    if (pendingRequest != null) {
      request = pendingRequest;
    } else {
      final firstImagePath = _firstImagePath;
      if (firstImagePath == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select the first frame.')),
        );
        await _selectFrame();
        return;
      }
      final themeId = widget.theme.themeKey.isNotEmpty
          ? widget.theme.themeKey
          : widget.theme.id;
      if (themeId.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Theme ID not found.')));
        return;
      }
      request = _ThemeToVideoRequest(
        themeId: themeId,
        firstImagePath: firstImagePath,
        isHd: _quality == 'HD',
        isLongTime: _duration == '10s',
      );
    }

    final attempt = ++_uploadAttempt;
    setState(() {
      _isSubmitting = true;
      _uploadSentBytes = 0;
      _uploadTotalBytes = 0;
    });
    try {
      final submit = widget.submit ?? ApiClient.instance.generateThemeVideo;
      final generation = await submit(
        themeId: request.themeId,
        firstImagePath: request.firstImagePath,
        isHd: request.isHd,
        isLongTime: request.isLongTime,
        onUploadProgress: (sent, total) {
          if (!mounted ||
              _hasLeftForm ||
              !_isSubmitting ||
              attempt != _uploadAttempt) {
            return;
          }
          setState(() {
            _uploadSentBytes = sent;
            _uploadTotalBytes = total;
          });
        },
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
            creatorLabel: 'Theme to Video',
            sourceImagePath: request.firstImagePath,
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
        case GenerationFailureAction.chooseImage:
        case GenerationFailureAction.editInput:
          await _selectFrame();
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
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: VideoFormLayout(
          title: 'Theme to video',
          backKey: const Key('themeToVideoBackButton'),
          children: [
            _ThemeBadge(theme: widget.theme),
            const SizedBox(height: 18),

            VideoImageCard(
              key: const Key('firstFrameCard'),
              label: 'First frame',
              requirement: 'Required',
              imagePath: _firstImagePath,
              onTap: _selectFrame,
              onRemove: _isSubmitting
                  ? null
                  : () => setState(() => _firstImagePath = null),
              isLoading: _isPickingImage,
              isSubmitting: _isSubmitting,
              uploadSentBytes: _uploadSentBytes,
              uploadTotalBytes: _uploadTotalBytes,
            ),
            const SizedBox(height: 16),

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
            buttonKey: const Key('generateThemeVideo'),
            onPressed: _generate,
            isLoading: _isSubmitting,
          ),
        ),
      ),
    ),
  );
}

class _ThemeBadge extends StatelessWidget {
  const _ThemeBadge({required this.theme});
  final VideoPost theme;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      gradient: VideoFormStyle.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: VideoFormStyle.border, width: 0.6),
    ),
    child: Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFF211E36),
            borderRadius: BorderRadius.circular(11),
          ),
          child: const Icon(
            Icons.auto_awesome_rounded,
            color: VideoFormStyle.accent,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Selected theme',
                style: TextStyle(color: VideoFormStyle.secondary, fontSize: 11),
              ),
              const SizedBox(height: 4),
              Text(theme.description, style: VideoFormStyle.serif(18)),
            ],
          ),
        ),
      ],
    ),
  );
}

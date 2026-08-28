import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/device/image_access_permission.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../data/models/generation_progress.dart';
import '../../../data/models/i2v_generation.dart';
import '../../../data/services/generation_progress_repository.dart';
import '../../providers/profile_provider.dart';
import '../../widgets/generation_failure_dialog.dart';
import '../../widgets/generation_form_exit_guard.dart';
import '../../widgets/video_form_widgets.dart';
import '../in_app_purchase/all_plans_screen.dart';
import '../in_app_purchase/credit_purchase_navigation.dart';
import '../support/support_contact_screen.dart';
import 'creating_video_screen.dart';

typedef ImageToVideoPickImage = Future<String?> Function();
typedef ImageToVideoPickImageFromSource =
    Future<String?> Function(ImageSource source);
typedef ImageToVideoRequestPermission =
    Future<ImageAccessPermissionResult> Function(ImageSource source);
typedef ImageToVideoSubmit =
    Future<I2VGeneration> Function({
      required String imagePath,
      required String prompt,
      required bool isHd,
      required bool isLongTime,
      void Function(int sent, int total)? onUploadProgress,
    });

class _ImageToVideoRequest {
  const _ImageToVideoRequest({
    required this.imagePath,
    required this.prompt,
    required this.isHd,
    required this.isLongTime,
  });

  final String imagePath;
  final String prompt;
  final bool isHd;
  final bool isLongTime;
}

class ImageToVideoScreen extends ConsumerStatefulWidget {
  const ImageToVideoScreen({
    super.key,
    this.pickImage,
    this.pickImageFromSource,
    this.requestPermission,
    this.submit,
    this.progressRepository,
  });

  /// Kept for compatibility with callers that provide a gallery-only picker.
  final ImageToVideoPickImage? pickImage;
  final ImageToVideoPickImageFromSource? pickImageFromSource;
  final ImageToVideoRequestPermission? requestPermission;
  final ImageToVideoSubmit? submit;
  final GenerationProgressRepository? progressRepository;

  @override
  ConsumerState<ImageToVideoScreen> createState() => _ImageToVideoScreenState();
}

class _ImageToVideoScreenState extends ConsumerState<ImageToVideoScreen> {
  final _promptController = TextEditingController();
  final _promptFocusNode = FocusNode();
  final _keyboardDismissFocusNode = FocusNode(skipTraversal: true);
  final _promptBoxKey = GlobalKey();
  String _duration = '10s';
  String _quality = 'Non-HD';
  String? _selectedImagePath;
  bool _isPickingImage = false;
  bool _isSubmitting = false;
  bool _hasLeftForm = false;
  final _exitGuardKey = GlobalKey<GenerationFormExitGuardState>();
  int _uploadAttempt = 0;
  int _uploadSentBytes = 0;
  int _uploadTotalBytes = 0;

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

  Future<void> _showImagePicker() async {
    if (_isPickingImage || _isSubmitting) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      barrierColor: const Color(0xB802050C),
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (_) => const VideoImageSourceSheet(),
    );
    if (!mounted || source == null) return;

    setState(() => _isPickingImage = true);
    try {
      final permissionRequester =
          widget.requestPermission ?? ImageAccessPermission.request;
      final permission = await permissionRequester(source);
      if (!mounted) return;
      if (permission == ImageAccessPermissionResult.settingsRequired) {
        await _showPermissionSettingsDialog(source);
        return;
      }
      if (permission == ImageAccessPermissionResult.denied) {
        _showPermissionDeniedMessage(source);
        return;
      }

      final imagePath = await _pickImageFrom(source);
      if (!mounted || imagePath == null || imagePath.isEmpty) return;
      setState(() => _selectedImagePath = imagePath);
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

  Future<String?> _pickImageFrom(ImageSource source) async {
    final sourcePicker = widget.pickImageFromSource;
    if (sourcePicker != null) return sourcePicker(source);
    final legacyPicker = widget.pickImage;
    if (legacyPicker != null) return legacyPicker();
    return (await ImagePicker().pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1920,
      maxHeight: 1920,
      requestFullMetadata: false,
    ))?.path;
  }

  void _showPermissionDeniedMessage(ImageSource source) {
    final isCamera = source == ImageSource.camera;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isCamera
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

  Future<void> _generate([_ImageToVideoRequest? pendingRequest]) async {
    if (_isSubmitting || _hasLeftForm) return;
    final _ImageToVideoRequest request;
    if (pendingRequest != null) {
      request = pendingRequest;
    } else {
      final imagePath = _selectedImagePath;
      if (imagePath == null) {
        await _showImagePicker();
        return;
      }
      final prompt = _promptController.text.trim();
      if (prompt.isEmpty) {
        _promptFocusNode.requestFocus();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Describe the motion for your video.')),
        );
        return;
      }
      request = _ImageToVideoRequest(
        imagePath: imagePath,
        prompt: prompt,
        isHd: _quality == 'HD',
        isLongTime: _duration == '10s',
      );
    }
    FocusManager.instance.primaryFocus?.unfocus();
    final attempt = ++_uploadAttempt;
    setState(() {
      _isSubmitting = true;
      _uploadSentBytes = 0;
      _uploadTotalBytes = 0;
    });
    try {
      final submit = widget.submit ?? ApiClient.instance.generateImageToVideo;
      final generation = await submit(
        imagePath: request.imagePath,
        prompt: request.prompt,
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
        // Keep the submitted request alive even if local persistence fails.
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
            sourceImagePath: request.imagePath,
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
          await _showImagePicker();
        case GenerationFailureAction.editInput:
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
          title: 'Image to video',
          backKey: const Key('imageToVideoBackButton'),
          children: [
            VideoImageCard(
              key: const Key('imageToVideoImageCard'),

              imagePath: _selectedImagePath,
              onTap: _showImagePicker,
              onRemove: _isSubmitting
                  ? null
                  : () => setState(() => _selectedImagePath = null),
              isLoading: _isPickingImage,
              isSubmitting: _isSubmitting,
              uploadSentBytes: _uploadSentBytes,
              uploadTotalBytes: _uploadTotalBytes,
            ),
            const SizedBox(height: 16),

            const VideoPromptHeader(),
            const SizedBox(height: 9),
            VideoPromptBox(
              key: _promptBoxKey,
              fieldKey: const Key('imageToVideoPromptField'),
              controller: _promptController,
              focusNode: _promptFocusNode,
              readOnly: _isSubmitting,
              hint:
                  'Describe the movement, camera motion, lighting, and mood...',
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
            buttonKey: const Key('generateImageVideo'),
            onPressed: _generate,
            isLoading: _isSubmitting,
          ),
        ),
      ),
    ),
  );
}

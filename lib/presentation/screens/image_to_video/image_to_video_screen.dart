import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/device/image_access_permission.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../data/models/generation_progress.dart';
import '../../../data/models/i2v_generation.dart';
import '../../../data/services/generation_progress_repository.dart';
import '../../providers/profile_provider.dart';
import '../../widgets/generation_failure_dialog.dart';
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
    });

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
  String _duration = '10s';
  String _quality = 'Non-HD';
  String? _selectedImagePath;
  bool _isPickingImage = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _promptController.dispose();
    _promptFocusNode.dispose();
    super.dispose();
  }

  Future<void> _showImagePicker() async {
    if (_isPickingImage || _isSubmitting) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ImageSourceSheet(),
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
      imageQuality: 95,
      maxWidth: 4096,
      maxHeight: 4096,
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
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        icon: Container(
          width: 54,
          height: 54,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [Color(0xFFFF3FAE), Color(0xFFFF783E)],
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
          style: const TextStyle(color: AppColors.textSecondary, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not Now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF409E),
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
    final imagePath = _selectedImagePath;
    if (imagePath == null) {
      await _showImagePicker();
      return;
    }
    if (_promptController.text.trim().isEmpty) {
      _promptFocusNode.requestFocus();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Describe the motion for your video.')),
      );
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _isSubmitting = true);
    try {
      final submit = widget.submit ?? ApiClient.instance.generateImageToVideo;
      final isHd = _quality == 'HD';
      final videoDurationSeconds = _duration == '10s' ? 10 : 5;
      final generation = await submit(
        imagePath: imagePath,
        prompt: _promptController.text.trim(),
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
        // Keep the submitted request alive even if local persistence fails.
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
            sourceImagePath: imagePath,
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
                  _UploadCard(
                    imagePath: _selectedImagePath,
                    onTap: _showImagePicker,
                    onRemove: _selectedImagePath == null
                        ? null
                        : () => setState(() => _selectedImagePath = null),
                    isLoading: _isPickingImage,
                  ),
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
                  // Motion style is hidden until the API supports this field.
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
              onPressed: onBack,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: const Icon(Icons.arrow_back_rounded, size: 28),
              color: Colors.white,
            ),
          ),
          const Text(
            'Image to video',
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

class _UploadCard extends StatelessWidget {
  const _UploadCard({
    required this.imagePath,
    required this.onTap,
    required this.onRemove,
    required this.isLoading,
  });

  final String? imagePath;
  final VoidCallback onTap;
  final VoidCallback? onRemove;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return _NeonDashedBorder(
      borderRadius: 16,
      child: Material(
        color: const Color(0xFF090009),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 256,
            child: Stack(
              children: [
                if (imagePath != null)
                  Positioned.fill(
                    child: Image.file(
                      File(imagePath!),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                if (imagePath == null) ...[
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: const RadialGradient(
                          center: Alignment(0, -0.1),
                          radius: 0.78,
                          colors: [Color(0x733D002C), Colors.transparent],
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const _UploadIcon(),
                        const SizedBox(height: 15),
                        const Text(
                          'Select image',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Choose from library or take a photo',
                          style: TextStyle(
                            color: Color(0xFFB0AAB4),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 45),
                        const Text(
                          'JPEG, PNG, WebP • up to 20 MB',
                          style: TextStyle(
                            color: Color(0xFF817984),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  const Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Color(0xD9000000)],
                          stops: [0.48, 1],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 14,
                    right: 14,
                    bottom: 14,
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [Color(0xFFFF3DAA), Color(0xFFFF783E)],
                            ),
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            size: 20,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Image selected',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Tap image to replace',
                                style: TextStyle(
                                  color: Color(0xFFBBB5BE),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          key: const Key('removeSelectedImage'),
                          tooltip: 'Remove image',
                          onPressed: onRemove,
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xCC211E2D),
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.close_rounded, size: 20),
                        ),
                      ],
                    ),
                  ),
                ],
                if (isLoading)
                  const Positioned.fill(
                    child: ColoredBox(
                      color: Color(0x99000000),
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Color(0xFFFF50AE),
                        ),
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
}

class _UploadIcon extends StatelessWidget {
  const _UploadIcon();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 78,
      height: 78,
      child: Image.asset(
        'assets/images/gen_video/add_image_icon.png',
        fit: BoxFit.contain,
      ),
    );
  }
}

class _ImageSourceSheet extends StatelessWidget {
  const _ImageSourceSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: Color(0xFF3A2038))),
      ),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'Add an image',
            style: TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Choose how you want to add the first frame.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _ImageSourceOption(
                  key: const Key('galleryImageSource'),
                  icon: Icons.photo_library_rounded,
                  title: 'Photo library',
                  subtitle: 'Choose an existing image',
                  colors: const [Color(0xFFFF3FAA), Color(0xFFE14FE9)],
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ImageSourceOption(
                  key: const Key('cameraImageSource'),
                  icon: Icons.photo_camera_rounded,
                  title: 'Camera',
                  subtitle: 'Take a new photo',
                  colors: const [Color(0xFFFF6B52), Color(0xFFFFA22F)],
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 14,
                color: Color(0xFF898391),
              ),
              SizedBox(width: 5),
              Flexible(
                child: Text(
                  'Your device controls access before opening photos or camera.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF898391), fontSize: 10.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ImageSourceOption extends StatelessWidget {
  const _ImageSourceOption({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.colors,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF211825),
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 154),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF432840)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: colors),
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: colors.first.withValues(alpha: 0.3),
                      blurRadius: 15,
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 25),
              ),
              const SizedBox(height: 15),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 2,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NeonDashedBorder extends StatelessWidget {
  const _NeonDashedBorder({required this.child, required this.borderRadius});

  final Widget child;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedGradientPainter(borderRadius: borderRadius),
      child: Padding(
        padding: const EdgeInsets.all(1),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: child,
        ),
      ),
    );
  }
}

class _DashedGradientPainter extends CustomPainter {
  _DashedGradientPainter({required this.borderRadius});

  final double borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(0.75),
      Radius.circular(borderRadius),
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.25
      ..shader = const LinearGradient(
        colors: [Color(0xFFFF43BA), Color(0xFFFF5A8C), Color(0xFFFFA62F)],
      ).createShader(rect);
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      const dashLength = 11.0;
      const gapLength = 7.5;
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, distance + dashLength),
          paint,
        );
        distance += dashLength + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedGradientPainter oldDelegate) => false;
}

class _PromptHeader extends StatelessWidget {
  const _PromptHeader();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
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
            ),
          ),
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
        border: Border.all(color: const Color(0xFFFF4FB5), width: 1),
        boxShadow: const [BoxShadow(color: Color(0x553A0039), blurRadius: 22)],
      ),
      child: Stack(
        children: [
          TextField(
            key: const Key('imageToVideoPromptField'),
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
                  'Describe the movement, camera motion, lighting, and mood...',
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
              _SettingIcon(asset: asset),
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

class _SettingIcon extends StatelessWidget {
  const _SettingIcon({required this.asset});

  final String asset;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: Image.asset(asset, fit: BoxFit.contain),
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

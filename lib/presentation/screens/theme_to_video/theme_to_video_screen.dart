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
import '../../../data/video_categories.dart';
import '../../providers/profile_provider.dart';
import '../../widgets/generation_failure_dialog.dart';
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
    });

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

  Future<void> _selectFrame() async {
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
      imageQuality: 95,
      maxWidth: 4096,
      maxHeight: 4096,
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
    final firstImagePath = _firstImagePath;
    if (firstImagePath == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select the first frame.')));
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

    setState(() => _isSubmitting = true);
    try {
      final submit = widget.submit ?? ApiClient.instance.generateThemeVideo;
      final isHd = _quality == 'HD';
      final videoDurationSeconds = _duration == '10s' ? 10 : 5;
      final generation = await submit(
        themeId: themeId,
        firstImagePath: firstImagePath,
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
            creatorLabel: 'Theme to Video',
            sourceImagePath: firstImagePath,
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
                  const SizedBox(height: 20),
                  _ThemeBadge(theme: widget.theme),
                  const SizedBox(height: 18),
                  _FrameCard(
                    key: const Key('firstFrameCard'),
                    label: 'First frame',
                    requirement: 'Required',
                    imagePath: _firstImagePath,
                    isLoading: _isPickingImage,
                    onTap: _selectFrame,
                    onRemove: _firstImagePath == null
                        ? null
                        : () => setState(() => _firstImagePath = null),
                  ),
                  const SizedBox(height: 18),
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
              key: const Key('themeToVideoBackButton'),
              onPressed: onBack,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: const Icon(Icons.arrow_back_rounded, size: 28),
              color: Colors.white,
            ),
          ),
          const Text(
            'Theme to video',
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

class _ThemeBadge extends StatelessWidget {
  const _ThemeBadge({required this.theme});

  final VideoPost theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF10050F),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF4F1646)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              gradient: const LinearGradient(
                colors: [Color(0xFFFF2EAA), Color(0xFFFF893A)],
              ),
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Selected theme',
                  style: TextStyle(color: Color(0xFF9E96A2), fontSize: 11),
                ),
                const SizedBox(height: 3),
                Text(
                  theme.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
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

class _FrameCard extends StatelessWidget {
  const _FrameCard({
    super.key,
    required this.label,
    required this.requirement,
    required this.imagePath,
    required this.isLoading,
    required this.onTap,
    required this.onRemove,
  });

  final String label;
  final String requirement;
  final String? imagePath;
  final bool isLoading;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              requirement,
              style: TextStyle(
                color: requirement == 'Required'
                    ? const Color(0xFFFF63B5)
                    : const Color(0xFF8F8794),
                fontSize: 10.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        AspectRatio(
          aspectRatio: 1.55,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFF3BAD), Color(0xFFFF973A)],
              ),
            ),
            padding: const EdgeInsets.all(1),
            child: Material(
              color: const Color(0xFF090009),
              borderRadius: BorderRadius.circular(15),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (imagePath != null)
                      Image.file(
                        File(imagePath!),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const _FramePlaceholder(),
                      )
                    else
                      const _FramePlaceholder(),
                    if (imagePath != null)
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Color(0xB8000000)],
                            stops: [0.55, 1],
                          ),
                        ),
                      ),
                    if (imagePath != null)
                      const Positioned(
                        left: 10,
                        bottom: 10,
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              color: Color(0xFFFF54B2),
                              size: 18,
                            ),
                            SizedBox(width: 5),
                            Text(
                              'Selected',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (onRemove != null)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: IconButton(
                          onPressed: onRemove,
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xB816101A),
                            foregroundColor: Colors.white,
                            minimumSize: const Size.square(32),
                            padding: EdgeInsets.zero,
                          ),
                          icon: const Icon(Icons.close_rounded, size: 18),
                        ),
                      ),
                    if (isLoading)
                      const ColoredBox(
                        color: Color(0x99000000),
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Color(0xFFFF50AE),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FramePlaceholder extends StatelessWidget {
  const _FramePlaceholder();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.1),
          radius: 0.85,
          colors: [Color(0x663D002C), Color(0xFF090009)],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_photo_alternate_rounded,
            color: Color(0xFFFF54B2),
            size: 42,
          ),
          SizedBox(height: 10),
          Text(
            'Add image',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 4),
          Text(
            'Library or camera',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF8F8794), fontSize: 9.5),
          ),
        ],
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
            'Add frame image',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 5),
          const Text(
            'Choose from your library or take a new photo.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _ImageSourceOption(
                  key: const Key('galleryFrameSource'),
                  icon: Icons.photo_library_rounded,
                  title: 'Photo Library',
                  colors: const [Color(0xFFFF3FAA), Color(0xFFE14FE9)],
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ImageSourceOption(
                  key: const Key('cameraFrameSource'),
                  icon: Icons.photo_camera_rounded,
                  title: 'Camera',
                  colors: const [Color(0xFFFF6B52), Color(0xFFFFA22F)],
                  onTap: () => Navigator.pop(context, ImageSource.camera),
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
    required this.colors,
    required this.onTap,
  });

  final IconData icon;
  final String title;
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
          height: 118,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF432840)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: colors),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const Spacer(),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
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
          key: const Key('generateThemeVideo'),
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

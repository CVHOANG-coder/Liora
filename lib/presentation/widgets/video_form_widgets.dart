import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'image_upload_progress_overlay.dart';
import 'video_form_style.dart';

export 'video_form_style.dart';

/// Shared presentation only: each screen owns its request and validation state.
class VideoFormLayout extends StatelessWidget {
  const VideoFormLayout({
    super.key,
    required this.title,
    required this.backKey,
    required this.children,
    required this.action,
  });

  final String title;
  final Key backKey;
  final List<Widget> children;
  final Widget action;

  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
              child: SizedBox(
                key: const Key('videoFormHeader'),
                height: 44,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 48),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(title, style: VideoFormStyle.serif(22)),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox.square(
                        dimension: 44,
                        child: IconButton(
                          key: backKey,
                          tooltip: 'Back',
                          padding: EdgeInsets.zero,
                          onPressed: () => Navigator.maybePop(context),
                          icon: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: VideoFormStyle.surface,
                              border: Border.all(
                                color: VideoFormStyle.border,
                                width: 0.6,
                              ),
                            ),
                            child: const Icon(
                              Icons.arrow_back_rounded,
                              color: VideoFormStyle.accent,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: CustomScrollView(
                key: const PageStorageKey('videoFormScroll'),
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverList.list(children: children),
                  ),
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        18,
                        20,
                        18 + MediaQuery.paddingOf(context).bottom,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          SizedBox(width: double.infinity, child: action),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class VideoPromptHeader extends StatelessWidget {
  const VideoPromptHeader({
    super.key,
    this.title = 'Prompt',
    this.requirement = '(Required)',
  });

  final String title;
  final String requirement;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 6,
    runSpacing: 4,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      Text(title, style: VideoFormStyle.serif(18)),
      Text(
        requirement,
        style: const TextStyle(
          color: VideoFormStyle.pink,
          fontSize: 12.5,
          height: 1.3,
        ),
      ),
    ],
  );
}

class VideoPromptBox extends StatelessWidget {
  const VideoPromptBox({
    super.key,
    required this.fieldKey,
    required this.controller,
    required this.focusNode,
    required this.hint,
    this.readOnly = false,
    this.height = 120,
  });

  final Key fieldKey;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final bool readOnly;
  final double height;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: focusNode,
    builder: (context, _) => Container(
      key: const Key('videoPromptSurface'),
      height:
          height +
          (MediaQuery.textScalerOf(context).scale(12) - 12).clamp(0, 30) * 3,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        gradient: VideoFormStyle.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: focusNode.hasFocus
              ? VideoFormStyle.accent
              : VideoFormStyle.border,
          width: 0.7,
        ),
      ),
      child: Column(
        children: [
          Expanded(
            child: TextField(
              key: fieldKey,
              readOnly: readOnly,
              controller: controller,
              focusNode: focusNode,
              cursorColor: VideoFormStyle.accent,
              maxLength: 2800,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.5,
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(
                  color: VideoFormStyle.muted,
                  fontSize: 14,
                  height: 1.5,
                ),
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                counterText: '',
                isCollapsed: true,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (_, value, _) => Text(
                '${value.text.characters.length}/2800',
                key: const Key('videoPromptCounter'),
                style: const TextStyle(
                  color: VideoFormStyle.muted,
                  fontSize: 10.5,
                  height: 1.2,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class VideoFormSettingRow extends StatelessWidget {
  const VideoFormSettingRow({
    super.key,
    required this.asset,
    required this.title,
    required this.value,
    required this.onTap,
  });

  final String asset;
  final String title;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Container(
    key: ValueKey('videoSetting-$title'),
    constraints: const BoxConstraints(minHeight: 52),
    decoration: BoxDecoration(
      gradient: VideoFormStyle.surface,
      borderRadius: BorderRadius.circular(11),
      border: Border.all(color: VideoFormStyle.border, width: 0.6),
    ),
    child: Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(11),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          child: Row(
            children: [
              Image.asset(
                asset,
                width: 34,
                height: 34,
                excludeFromSemantics: true,
              ),
              const SizedBox(width: 14),
              Expanded(child: Text(title, style: VideoFormStyle.serif(17))),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: VideoFormStyle.serif(16, color: VideoFormStyle.accent),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: VideoFormStyle.secondary,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class VideoGenerateButton extends StatelessWidget {
  const VideoGenerateButton({
    super.key,
    required this.buttonKey,
    required this.onPressed,
    required this.isLoading,
  });

  final Key buttonKey;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('videoGenerateSurface'),
    constraints: const BoxConstraints(minHeight: 52),
    decoration: BoxDecoration(
      gradient: VideoFormStyle.gradient,
      borderRadius: BorderRadius.circular(11),
      border: Border.all(color: const Color(0xFFAD98D5), width: 0.6),
    ),
    child: Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(11),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: buttonKey,
        onTap: isLoading ? null : onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text('Generate', style: VideoFormStyle.serif(22)),
              ),
              const SizedBox(width: 12),
              if (isLoading)
                const SizedBox.square(
                  key: Key('generateVideoLoading'),
                  dimension: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              else
                const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 21,
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class VideoImageCard extends StatelessWidget {
  const VideoImageCard({
    super.key,
    required this.imagePath,
    required this.onTap,
    required this.onRemove,
    required this.isLoading,
    required this.isSubmitting,
    required this.uploadSentBytes,
    required this.uploadTotalBytes,
    this.label,
    this.requirement = 'Required',
    this.removeKey = const Key('removeSelectedImage'),
  });

  final String? imagePath;
  final VoidCallback onTap;
  final VoidCallback? onRemove;
  final bool isLoading;
  final bool isSubmitting;
  final int uploadSentBytes;
  final int uploadTotalBytes;
  final String? label;
  final String requirement;
  final Key removeKey;

  @override
  Widget build(BuildContext context) {
    final compact = label != null;
    final height = compact ? 220.0 : 246.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          VideoPromptHeader(title: label!, requirement: requirement),
          const SizedBox(height: 9),
        ],
        CustomPaint(
          foregroundPainter: const _DashedBorderPainter(),
          child: Material(
            color: VideoFormStyle.background,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: Ink(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF151022), Color(0xFF070B17)],
                ),
              ),
              child: InkWell(
                onTap: isSubmitting ? null : onTap,
                child: Stack(
                  children: [
                    if (imagePath == null)
                      ConstrainedBox(
                        constraints: BoxConstraints(minHeight: height),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 28,
                          ),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Image.asset(
                                  'assets/images/gen_video/add_image_icon.png',
                                  width: 86,
                                  height: 86,
                                  excludeFromSemantics: true,
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  compact ? 'Add image' : 'Select image',
                                  textAlign: TextAlign.center,
                                  style: VideoFormStyle.serif(21),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  compact
                                      ? 'Library or camera'
                                      : 'Choose from library or take a photo',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: VideoFormStyle.secondary,
                                    fontSize: 12,
                                    height: 1.4,
                                  ),
                                ),
                                if (!compact) ...[
                                  const SizedBox(height: 18),
                                  const Text(
                                    'JPEG, PNG, WebP • up to 20 MB',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: VideoFormStyle.muted,
                                      fontSize: 10.5,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      )
                    else ...[
                      SizedBox(height: height, width: double.infinity),
                      Positioned.fill(
                        child: Image.file(
                          File(imagePath!),
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.broken_image_outlined,
                            color: VideoFormStyle.muted,
                            size: 40,
                          ),
                        ),
                      ),
                      if (!isSubmitting) ...[
                        const Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.transparent, Color(0xE602050C)],
                                stops: [0.4, 1],
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
                              const Icon(
                                Icons.check_circle_rounded,
                                color: VideoFormStyle.accent,
                                size: 24,
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Image selected',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    SizedBox(height: 3),
                                    Text(
                                      'Tap image to replace',
                                      style: TextStyle(
                                        color: VideoFormStyle.secondary,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                key: removeKey,
                                tooltip: 'Remove image',
                                onPressed: onRemove,
                                style: IconButton.styleFrom(
                                  backgroundColor: const Color(0xCC151725),
                                  foregroundColor: Colors.white,
                                ),
                                icon: const Icon(Icons.close_rounded, size: 20),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                    if (isSubmitting)
                      Positioned.fill(
                        child: ImageUploadProgressOverlay(
                          sentBytes: uploadSentBytes,
                          totalBytes: uploadTotalBytes,
                        ),
                      ),
                    if (isLoading)
                      const Positioned.fill(
                        child: ColoredBox(
                          color: Color(0x9902050C),
                          child: Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: VideoFormStyle.accent,
                            ),
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

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(0.5);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFBE8BC8), Color(0xFF434155)],
      ).createShader(rect);
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(12)));
    for (final metric in path.computeMetrics()) {
      for (double distance = 0; distance < metric.length; distance += 7.5) {
        canvas.drawPath(metric.extractPath(distance, distance + 4.5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) => false;
}

Future<String?> showVideoFormOptions(
  BuildContext context, {
  required String title,
  required List<String> options,
  required String selected,
}) => showModalBottomSheet<String>(
  context: context,
  useSafeArea: true,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  barrierColor: const Color(0xB802050C),
  constraints: const BoxConstraints(maxWidth: 560),
  builder: (context) => _FormSheet(
    title: title,
    children: [
      for (final option in options)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: const Color(0xFF0B101D),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: option == selected
                    ? VideoFormStyle.accent
                    : VideoFormStyle.border,
                width: 0.6,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              selected: option == selected,
              title: Text(option, style: VideoFormStyle.serif(18)),
              trailing: option == selected
                  ? const Icon(
                      Icons.check_rounded,
                      color: VideoFormStyle.accent,
                    )
                  : null,
              onTap: () => Navigator.pop(context, option),
            ),
          ),
        ),
    ],
  ),
);

class VideoImageSourceSheet extends StatelessWidget {
  const VideoImageSourceSheet({super.key, this.isFrame = false});

  final bool isFrame;

  @override
  Widget build(BuildContext context) => _FormSheet(
    title: isFrame ? 'Add frame image' : 'Add an image',
    children: [
      const Text(
        'Choose from your library or take a new photo.',
        style: TextStyle(
          color: VideoFormStyle.secondary,
          fontSize: 13,
          height: 1.4,
        ),
      ),
      const SizedBox(height: 16),
      for (final source in [ImageSource.gallery, ImageSource.camera])
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Material(
            color: const Color(0xFF0B101D),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: VideoFormStyle.border, width: 0.6),
            ),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              key: ValueKey(
                '${source.name}${isFrame ? 'Frame' : 'Image'}Source',
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 6,
              ),
              leading: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF211E36),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  source == ImageSource.gallery
                      ? Icons.photo_library_rounded
                      : Icons.photo_camera_rounded,
                  color: VideoFormStyle.accent,
                  size: 24,
                ),
              ),
              title: Text(
                source == ImageSource.gallery ? 'Photo library' : 'Camera',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                source == ImageSource.gallery
                    ? 'Choose an existing image'
                    : 'Take a new photo',
                style: const TextStyle(
                  color: VideoFormStyle.secondary,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              trailing: const Icon(
                Icons.chevron_right_rounded,
                color: VideoFormStyle.muted,
              ),
              onTap: () => Navigator.pop(context, source),
            ),
          ),
        ),
      const SizedBox(height: 4),
      const Text(
        'Your device controls access before opening photos or camera.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: VideoFormStyle.muted,
          fontSize: 10.5,
          height: 1.4,
        ),
      ),
    ],
  );
}

class _FormSheet extends StatelessWidget {
  const _FormSheet({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.85,
    ),
    child: Container(
      key: const Key('videoFormSheet'),
      decoration: const BoxDecoration(
        color: VideoFormStyle.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.fromBorderSide(
          BorderSide(color: VideoFormStyle.border, width: 0.6),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF535364),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(title, style: VideoFormStyle.serif(26)),
              const SizedBox(height: 18),
              ...children,
            ],
          ),
        ),
      ),
    ),
  );
}

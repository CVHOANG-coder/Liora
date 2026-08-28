import 'package:flutter/material.dart';

import 'video_form_style.dart';

/// Shared visual primitives for the library and the finished-video workspace.
class VideoLibraryAction extends StatelessWidget {
  const VideoLibraryAction({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.primary = false,
    this.destructive = false,
    this.busy = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool primary;
  final bool destructive;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final foreground = destructive ? const Color(0xFFE49AAA) : Colors.white;
    return Semantics(
      button: true,
      enabled: onTap != null,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        decoration: BoxDecoration(
          gradient: primary ? VideoFormStyle.gradient : VideoFormStyle.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: primary ? const Color(0xFFAD8DCD) : VideoFormStyle.border,
            width: .6,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (busy)
                    SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        color: foreground,
                        strokeWidth: 2,
                      ),
                    )
                  else
                    Icon(icon, color: foreground, size: 19),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: foreground,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class VideoLibraryTag extends StatelessWidget {
  const VideoLibraryTag(
    this.label, {
    super.key,
    this.color = VideoFormStyle.secondary,
  });
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xE60B101B),
      borderRadius: BorderRadius.circular(7),
      border: Border.all(color: color.withValues(alpha: .2), width: .5),
    ),
    child: Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: color,
        fontSize: 10,
        height: 1.2,
        fontWeight: FontWeight.w500,
      ),
    ),
  );
}

class VideoLibraryDeleteDialog extends StatelessWidget {
  const VideoLibraryDeleteDialog({
    super.key,
    required this.cancelKey,
    required this.confirmKey,
    this.prompt = '',
  });
  final Key cancelKey;
  final Key confirmKey;
  final String prompt;

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.transparent,
    insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: VideoFormStyle.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: VideoFormStyle.border, width: .7),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF271C2B),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  color: Color(0xFFE49AAA),
                  size: 26,
                ),
              ),
              const SizedBox(height: 18),
              Text('Delete video?', style: VideoFormStyle.serif(27)),
              const SizedBox(height: 10),
              const Text(
                'This video will be permanently removed from your history.',
                style: TextStyle(
                  color: VideoFormStyle.secondary,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              if (prompt.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  prompt,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: VideoFormStyle.muted,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, constraints) {
                  final cancel = VideoLibraryAction(
                    key: cancelKey,
                    label: 'Cancel',
                    icon: Icons.close_rounded,
                    onTap: () => Navigator.pop(context, false),
                  );
                  final confirm = VideoLibraryAction(
                    key: confirmKey,
                    label: 'Delete',
                    icon: Icons.delete_outline_rounded,
                    destructive: true,
                    onTap: () => Navigator.pop(context, true),
                  );
                  if (constraints.maxWidth < 280 ||
                      MediaQuery.textScalerOf(context).scale(13) > 17) {
                    return Column(
                      children: [cancel, const SizedBox(height: 10), confirm],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: cancel),
                      const SizedBox(width: 10),
                      Expanded(child: confirm),
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

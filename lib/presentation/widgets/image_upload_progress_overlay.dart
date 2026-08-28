import 'package:flutter/material.dart';

/// A compact status footer over the existing photo, without changing card size.
/// Bytes describe upload only; 100% still waits for the generation API response.
class ImageUploadProgressOverlay extends StatelessWidget {
  const ImageUploadProgressOverlay({
    super.key,
    required this.sentBytes,
    required this.totalBytes,
  });

  final int sentBytes;
  final int totalBytes;

  @override
  Widget build(BuildContext context) {
    final progress = totalBytes > 0
        ? (sentBytes / totalBytes).clamp(0.0, 1.0)
        : null;
    final uploaded = progress == 1;
    final preparing = totalBytes <= 0 && sentBytes <= 0;
    final percentage = progress == null ? null : (progress * 100).floor();
    final title = uploaded
        ? 'Image uploaded'
        : preparing
        ? 'Preparing image'
        : 'Uploading image';
    final detail = uploaded
        ? 'Submitting request'
        : totalBytes > 0
        ? '${_formatBytes(sentBytes.clamp(0, totalBytes))} / ${_formatBytes(totalBytes)}'
        : sentBytes > 0
        ? '${_formatBytes(sentBytes)} sent'
        : 'Getting ready to upload...';

    return IgnorePointer(
      child: DecoratedBox(
        key: const Key('imageUploadProgressOverlay'),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Color(0x66090009), Color(0xF2090009)],
            stops: [0.25, 0.5, 1],
          ),
        ),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      uploaded
                          ? Icons.check_circle_rounded
                          : Icons.cloud_upload_outlined,
                      color: const Color(0xFFFF63B5),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      percentage == null ? '—' : '$percentage%',
                      key: const Key('imageUploadPercentage'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFD6CDD8),
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [
                        Color(0xFFFF1594),
                        Color(0xFFFF4D55),
                        Color(0xFFFFAE25),
                      ],
                    ).createShader(bounds),
                    child: LinearProgressIndicator(
                      key: const Key('imageUploadProgressBar'),
                      value: progress,
                      minHeight: 4,
                      color: Colors.white,
                      backgroundColor: const Color(0x33FFFFFF),
                      semanticsLabel: 'Image upload',
                      semanticsValue: percentage == null
                          ? title
                          : '$percentage%',
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

String _formatBytes(int bytes) {
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '$bytes B';
}

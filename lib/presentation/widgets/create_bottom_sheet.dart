import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

enum CreateVideoMode { textToVideo, imageToVideo }

class CreateBottomSheet extends StatelessWidget {
  const CreateBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        border: Border(top: BorderSide(color: Color(0xFF5B204D))),
        boxShadow: [BoxShadow(color: Color(0x66FF2BA9), blurRadius: 28)],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(-0.8, -1),
              radius: 1.4,
              colors: [Color(0x553E113A), AppColors.surface],
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF3BAE), Color(0xFFFF8840)],
                        ),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  const _SheetHeader(),
                  const SizedBox(height: 22),
                  _CreateOption(
                    key: const Key('createTextToVideo'),
                    icon: Icons.auto_awesome_rounded,
                    title: 'Text to Video',
                    subtitle: 'Turn your description into a vivid AI video',
                    badge: 'PROMPT',
                    colors: const [Color(0xFFFF31AC), Color(0xFF9F48F5)],
                    glow: const Color(0xFFFF31AC),
                    onTap: () =>
                        Navigator.pop(context, CreateVideoMode.textToVideo),
                  ),
                  const SizedBox(height: 12),
                  _CreateOption(
                    key: const Key('createImageToVideo'),
                    icon: Icons.add_photo_alternate_rounded,
                    title: 'Image to Video',
                    subtitle: 'Bring cinematic motion to your photos',
                    badge: 'PHOTO',
                    colors: const [Color(0xFFFF4F85), Color(0xFFFF9138)],
                    glow: const Color(0xFFFF713D),
                    onTap: () =>
                        Navigator.pop(context, CreateVideoMode.imageToVideo),
                  ),
                  const SizedBox(height: 16),
                  const Center(
                    child: Text(
                      'Choose how you want to start creating',
                      style: TextStyle(color: Color(0xFF847D8A), fontSize: 11),
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

class _SheetHeader extends StatelessWidget {
  const _SheetHeader();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        _SparkIcon(),
        SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create AI video',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Your idea, moving your way.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SparkIcon extends StatelessWidget {
  const _SparkIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF35B0), Color(0xFFFF7B42)],
        ),
        boxShadow: const [BoxShadow(color: Color(0x88FF2AA9), blurRadius: 18)],
      ),
      child: const Icon(Icons.movie_filter_rounded, color: Colors.white),
    );
  }
}

class _CreateOption extends StatelessWidget {
  const _CreateOption({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.colors,
    required this.glow,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String badge;
  final List<Color> colors;
  final Color glow;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xCC211825),
      borderRadius: BorderRadius.circular(21),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 92),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(21),
            border: Border.all(color: glow.withValues(alpha: 0.38)),
          ),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: colors,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: glow.withValues(alpha: 0.4),
                      blurRadius: 16,
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 27),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 7),
                        _OptionBadge(label: badge, color: glow),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: glow.withValues(alpha: 0.12),
                  border: Border.all(color: glow.withValues(alpha: 0.45)),
                ),
                child: Icon(Icons.arrow_forward_rounded, size: 18, color: glow),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionBadge extends StatelessWidget {
  const _OptionBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

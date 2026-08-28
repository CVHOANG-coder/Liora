import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

enum CreateVideoMode { textToVideo, imageToVideo }

const _sheetBackground = Color(0xFF02050C);
const _sheetBorder = Color(0xFF343743);
const _sheetSecondary = Color(0xFFB4B1BD);
const _cardSurface = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF0B101D), Color(0xFF070C17)],
);

class CreateBottomSheet extends StatelessWidget {
  const CreateBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.88,
      ),
      child: Container(
        key: const Key('createSheetSurface'),
        decoration: const BoxDecoration(
          color: _sheetBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.fromBorderSide(
            BorderSide(color: _sheetBorder, width: 0.6),
          ),
          boxShadow: [BoxShadow(color: Color(0x40000000), blurRadius: 24)],
        ),
        clipBehavior: Clip.antiAlias,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(-0.8, -1),
              radius: 1.1,
              colors: [Color(0xFF171226), _sheetBackground],
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  key: const Key('createSheetHandle'),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF535364),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 18, 12, 18),
                  child: _SheetHeader(),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    key: const PageStorageKey('createSheetScroll'),
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _CreateOption(
                          key: const Key('createTextToVideo'),
                          asset: 'assets/images/home/text_to_video.png',
                          title: 'Text to Video',
                          subtitle:
                              'Turn your description into a vivid AI video',
                          badge: 'PROMPT',
                          accent: const Color(0xFFEC5FB6),
                          onTap: () => Navigator.pop(
                            context,
                            CreateVideoMode.textToVideo,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _CreateOption(
                          key: const Key('createImageToVideo'),
                          asset: 'assets/images/home/image_to_video.png',
                          title: 'Image to Video',
                          subtitle: 'Bring cinematic motion to your photos',
                          badge: 'PHOTO',
                          accent: const Color(0xFF9DADF0),
                          onTap: () => Navigator.pop(
                            context,
                            CreateVideoMode.imageToVideo,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Choose how you want to start creating',
                          key: Key('createSheetHint'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF858290),
                            fontSize: 11,
                            height: 1.4,
                          ),
                        ),
                      ],
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

class _SheetHeader extends StatelessWidget {
  const _SheetHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'Create AI video',
                  maxLines: 1,
                  style: TextStyle(
                    color: Color(0xFFF5F2F8),
                    fontFamily: 'Times New Roman',
                    fontFamilyFallback: ['Times', 'serif'],
                    fontSize: 30,
                    height: 1.1,
                    fontWeight: FontWeight.w400,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(height: 9),
              Container(
                width: 28,
                height: 2.5,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEC5FB6), Color(0xFF6657FF)],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Your idea, moving your way.',
                style: TextStyle(
                  color: _sheetSecondary,
                  fontSize: 12.5,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          key: const Key('createSheetCloseButton'),
          width: 44,
          height: 44,
          child: IconButton(
            tooltip: 'Close',
            padding: EdgeInsets.zero,
            onPressed: () => Navigator.pop(context),
            icon: Container(
              width: 32,
              height: 32,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: _cardSurface,
                border: Border.all(color: _sheetBorder, width: 0.6),
              ),
              child: SvgPicture.asset(
                'assets/svgs/purchase_close.svg',
                excludeFromSemantics: true,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CreateOption extends StatelessWidget {
  const _CreateOption({
    super.key,
    required this.asset,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.accent,
    required this.onTap,
  });

  final String asset;
  final String title;
  final String subtitle;
  final String badge;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey('createOptionSurface-$badge'),
      constraints: const BoxConstraints(minHeight: 96),
      decoration: BoxDecoration(
        gradient: _cardSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _sheetBorder, width: 0.6),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Image.asset(
                  asset,
                  width: 48,
                  height: 48,
                  fit: BoxFit.contain,
                  excludeFromSemantics: true,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Wrap(
                        spacing: 7,
                        runSpacing: 5,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: Color(0xFFF5F2F8),
                              fontSize: 16,
                              height: 1.2,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          _OptionBadge(label: badge, color: accent),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: _sheetSecondary,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF211E36),
                    border: Border.all(
                      color: const Color(0xFF3A354D),
                      width: 0.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_rounded,
                    size: 17,
                    color: Color(0xFFEDEAF4),
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

class _OptionBadge extends StatelessWidget {
  const _OptionBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.22), width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 8,
          height: 1.1,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

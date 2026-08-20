import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

class ImageToVideoScreen extends StatefulWidget {
  const ImageToVideoScreen({super.key});

  @override
  State<ImageToVideoScreen> createState() => _ImageToVideoScreenState();
}

class _ImageToVideoScreenState extends State<ImageToVideoScreen> {
  final _promptController = TextEditingController();
  final _promptFocusNode = FocusNode();
  String _duration = '5s';
  String _quality = 'Normal (720p)';
  String _motionStyle = 'Cinematic';
  bool _hasImage = false;

  @override
  void dispose() {
    _promptController.dispose();
    _promptFocusNode.dispose();
    super.dispose();
  }

  void _showImagePicker() {
    setState(() => _hasImage = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã chọn ảnh mẫu để xem trước')),
    );
  }

  void _randomizePrompt() {
    const prompt =
        'Slow cinematic camera push-in, gentle wind moving the subject, soft golden lighting, dreamy atmosphere';
    _promptController.text = prompt;
    setState(() {});
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

  void _generate() {
    if (!_hasImage) {
      _showImagePicker();
      return;
    }
    if (_promptController.text.trim().isEmpty) {
      _promptFocusNode.requestFocus();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hãy mô tả chuyển động cho video')),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đang chuẩn bị video của bạn...')),
    );
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
                  _UploadCard(hasImage: _hasImage, onTap: _showImagePicker),
                  const SizedBox(height: 24),
                  _PromptHeader(onRandom: _randomizePrompt),
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
                      options: const ['3s', '5s', '8s', '10s'],
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
                      options: const ['Normal (720p)', 'High (1080p)'],
                      selected: _quality,
                      onSelected: (value) => setState(() => _quality = value),
                    ),
                  ),
                  const SizedBox(height: 7),
                  _SettingRow(
                    asset: 'assets/images/gen_video/style_video.png',
                    title: 'Motion style',
                    value: _motionStyle,
                    onTap: () => _pickOption(
                      title: 'Motion style',
                      options: const [
                        'Cinematic',
                        'Dynamic',
                        'Subtle',
                        'Dreamy',
                      ],
                      selected: _motionStyle,
                      onSelected: (value) =>
                          setState(() => _motionStyle = value),
                    ),
                  ),
                  const SizedBox(height: 27),
                  _GenerateButton(onPressed: _generate),
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
  const _UploadCard({required this.hasImage, required this.onTap});

  final bool hasImage;
  final VoidCallback onTap;

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
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: RadialGradient(
                        center: const Alignment(0, -0.1),
                        radius: 0.78,
                        colors: [
                          const Color(0xFF3D002C).withValues(alpha: 0.45),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _UploadIcon(hasImage: hasImage),
                      const SizedBox(height: 15),
                      Text(
                        hasImage ? 'Image selected' : 'Select image',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        hasImage
                            ? 'Tap to replace photo'
                            : 'Tap to upload photo or artwork',
                        style: const TextStyle(
                          color: Color(0xFFB0AAB4),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 45),
                      const Text(
                        'JPG, PNG • up to 10MB',
                        style: TextStyle(
                          color: Color(0xFF817984),
                          fontSize: 11,
                        ),
                      ),
                    ],
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
  const _UploadIcon({required this.hasImage});

  final bool hasImage;

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
  const _PromptHeader({required this.onRandom});

  final VoidCallback onRandom;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text(
          'Prompt',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 5),
        const Text(
          '(Required)',
          style: TextStyle(color: Color(0xFFFF63B5), fontSize: 15),
        ),
        const Spacer(),
        _GradientOutlineButton(
          icon: Icons.refresh_rounded,
          label: 'Random',
          onTap: onRandom,
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
                  'Describe the movement, camera motion,\nlighting, and mood...',
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

class _GradientOutlineButton extends StatelessWidget {
  const _GradientOutlineButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _OutlineGradientPainter(borderRadius: 15),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: const Color(0xFFFF4D9C), size: 18),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFFFF4D9C),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
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

class _OutlineGradientPainter extends CustomPainter {
  _OutlineGradientPainter({required this.borderRadius});
  final double borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..shader = const LinearGradient(
        colors: [Color(0xFFFF39B5), Color(0xFFFFA522)],
      ).createShader(rect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(1), Radius.circular(borderRadius)),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _OutlineGradientPainter oldDelegate) => false;
}

class _GenerateButton extends StatelessWidget {
  const _GenerateButton({required this.onPressed});

  final VoidCallback onPressed;

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
          child: const Center(
            child: Row(
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
                Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

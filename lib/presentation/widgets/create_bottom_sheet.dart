import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

class CreateBottomSheet extends StatelessWidget {
  const CreateBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
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
          const SizedBox(height: 24),
          Text(
            'Bạn muốn tạo gì?',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 6),
          Text(
            'Chọn một định dạng để bắt đầu ý tưởng mới.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 22),
          _CreateOption(
            icon: Icons.movie_creation_outlined,
            title: 'Video',
            subtitle: 'Tạo video từ prompt hoặc hình ảnh',
            colors: const [AppColors.primary, AppColors.primaryDark],
            onTap: () => Navigator.pop(context, 'video'),
          ),
          const SizedBox(height: 12),
          _CreateOption(
            icon: Icons.auto_awesome_outlined,
            title: 'Hình ảnh',
            subtitle: 'Biến mô tả thành hình ảnh nổi bật',
            colors: const [AppColors.accent, Color(0xFFE259A9)],
            onTap: () => Navigator.pop(context, 'hình ảnh'),
          ),
          const SizedBox(height: 12),
          _CreateOption(
            icon: Icons.dashboard_customize_outlined,
            title: 'Từ mẫu',
            subtitle: 'Bắt đầu nhanh với mẫu có sẵn',
            colors: const [Color(0xFF61D6C3), Color(0xFF329F95)],
            onTap: () => Navigator.pop(context, 'từ mẫu'),
          ),
        ],
      ),
    );
  }
}

class _CreateOption extends StatelessWidget {
  const _CreateOption({
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
      color: AppColors.surfaceLight,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: colors),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

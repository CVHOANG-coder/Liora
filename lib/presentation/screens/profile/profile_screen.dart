import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/constants/app_colors.dart';
import '../in_app_purchase/in_app_purchase_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.85),
          radius: 1.15,
          colors: [Color(0x1E401449), AppColors.background],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = 10.0;

            return CustomScrollView(
              key: const PageStorageKey('profileScroll'),
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    12,
                    horizontalPadding,
                    116,
                  ),
                  sliver: SliverList.list(
                    children: const [
                      _AccountCard(),
                      SizedBox(height: 26),
                      _UpgradeCard(),
                      SizedBox(height: 19),
                      _ProfileMenu(),
                      SizedBox(height: 17),
                      _SupportMenu(),
                      SizedBox(height: 3),
                      Center(
                        child: Text(
                          'V 2.18.0',
                          style: TextStyle(
                            color: Color(0xFF77737F),
                            fontSize: 14,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 17),
      decoration: BoxDecoration(
        color: const Color(0x66130E1A),
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: const Color(0xFF5A234E)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x16000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 118,
                height: 118,
                padding: const EdgeInsets.all(1),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFF69D2), Color(0xFFFF7B2F)],
                  ),
                  boxShadow: [
                    BoxShadow(color: Color(0xAAFF1E9D), blurRadius: 17),
                    BoxShadow(color: Color(0x66FF813F), blurRadius: 20),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/profile/avatar_default.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(child: _AccountDetails()),
              const Icon(
                Icons.chevron_right_rounded,
                size: 34,
                color: Color(0xFFD5D2DB),
              ),
            ],
          ),
          const SizedBox(height: 17),
          const _StatsRow(),
        ],
      ),
    );
  }
}

class _AccountDetails extends StatelessWidget {
  const _AccountDetails();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Luna Noir',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          '@lunavelora',
          style: TextStyle(color: Color(0xFFB3ADBA), fontSize: 16),
        ),
        const SizedBox(height: 15),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.accent, width: 1.2),
            boxShadow: const [
              BoxShadow(color: Color(0x88FF18AF), blurRadius: 12),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ProIcon(color: AppColors.accent, size: 19),
              SizedBox(width: 6),
              Text(
                '17+ Pro',
                style: TextStyle(
                  color: AppColors.accent,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(
          child: _StatCard(
            icon: Icons.play_circle_outline_rounded,
            value: '12',
            label: 'videos',
          ),
        ),
        SizedBox(width: 14),
        Expanded(
          child: _StatCard(
            icon: Icons.star_border_rounded,
            value: '4',
            label: 'styles saved',
          ),
        ),
        SizedBox(width: 14),
        Expanded(
          child: _StatCard(
            icon: Icons.workspace_premium_outlined,
            value: 'Pro',
            label: 'active',
            warm: true,
            proIcon: true,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    this.warm = false,
    this.proIcon = false,
  });

  final IconData icon;
  final String value;
  final String label;
  final bool warm;
  final bool proIcon;

  @override
  Widget build(BuildContext context) {
    final color = warm ? const Color(0xFFFF8576) : const Color(0xFFFF4CAC);
    return Container(
      height: 86,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: const Color(0x321D1523),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF45253E)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.09),
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.13), blurRadius: 14),
              ],
            ),
            child: proIcon
                ? _ProIcon(color: color, size: 20, outline: true)
                : Icon(icon, color: color, size: 25),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFBDB6C1),
                    fontSize: 11,
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

class _UpgradeCard extends StatelessWidget {
  const _UpgradeCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 208,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF27091E), Color(0xFF100913), Color(0xFF261109)],
        ),
        border: Border.all(color: const Color(0xFFFF3BAE), width: 1.2),
        boxShadow: const [
          BoxShadow(color: Color(0x88FF1C9D), blurRadius: 18),
          BoxShadow(color: Color(0x55FF8A34), blurRadius: 22),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -9,
            top: 2,
            width: 195,
            height: 120,
            child: Image.asset(
              'assets/images/profile/vip_banner.png',
              fit: BoxFit.contain,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 15, 18, 11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _UpgradeTitle(),
                const SizedBox(height: 8),
                const _Benefit(text: 'Unlock 100+ AI styles'),
                const SizedBox(height: 4),
                const _Benefit(text: 'Create unlimited clips'),
                const SizedBox(height: 4),
                const _Benefit(text: 'Generate with AI Chat'),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const InAppPurchaseScreen(),
                    ),
                  ),
                  child: Container(
                    height: 42,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(32),
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF159C), Color(0xFFFF7E35)],
                      ),
                      boxShadow: const [
                        BoxShadow(color: Color(0xAAFF168F), blurRadius: 15),
                      ],
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Upgrade Now',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(width: 8),
                        _ProIcon(color: Colors.white, size: 20),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                const Center(
                  child: Text(
                    'Yearly 799.000đ  •  Cancel anytime',
                    style: TextStyle(color: Color(0xFFBDB1BD), fontSize: 10),
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

class _UpgradeTitle extends StatelessWidget {
  const _UpgradeTitle();

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: const TextSpan(
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 21,
          fontWeight: FontWeight.w800,
        ),
        children: [
          TextSpan(text: 'Get Velora '),
          TextSpan(
            text: 'Pro',
            style: TextStyle(color: Color(0xFFFF765C)),
          ),
        ],
      ),
    );
  }
}

class _Benefit extends StatelessWidget {
  const _Benefit({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.check_circle_rounded,
          color: Color(0xFFFF4CA9),
          size: 12,
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(color: Color(0xFFECE7EE), fontSize: 11),
        ),
      ],
    );
  }
}

class _ProIcon extends StatelessWidget {
  const _ProIcon({
    required this.color,
    required this.size,
    this.outline = false,
  });

  final Color color;
  final double size;
  final bool outline;

  @override
  Widget build(BuildContext context) {
    final visualSize = outline ? size : size;

    return SizedBox.square(
      dimension: size,
      child: Center(
        child: SizedBox.square(
          dimension: visualSize,
          child: SvgPicture.asset(
            outline ? 'assets/svgs/pro_outline.svg' : 'assets/svgs/pro.svg',
            fit: BoxFit.contain,
            colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
          ),
        ),
      ),
    );
  }
}

class _ProfileMenu extends StatelessWidget {
  const _ProfileMenu();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _FeatureTile(
          icon: Icons.chat_bubble_outline_rounded,
          title: 'AI Chat',
          subtitle: 'Tạo ý tưởng, viết prompt, phát triển kịch bản',
          action: 'Open',
        ),
        SizedBox(height: 7),
        _FeatureTile(
          icon: Icons.folder_copy_outlined,
          title: 'Packs',
          subtitle: 'Bộ style, preset và concept dựng sẵn',
        ),
        SizedBox(height: 7),
        _FeatureTile(
          icon: Icons.person_search_outlined,
          title: 'Creations',
          subtitle: 'Ảnh AI, chân dung, cover, thumbnail',
        ),
        SizedBox(height: 7),
        _FeatureTile(
          icon: Icons.video_library_outlined,
          title: 'Video',
          subtitle: 'Các clip đã tạo và mẫu yêu thích',
        ),
        SizedBox(height: 7),
        _FeatureTile(
          icon: Icons.settings_outlined,
          title: 'Settings',
          subtitle: 'Ngôn ngữ, dữ liệu, trợ giúp',
        ),
      ],
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? action;

  @override
  Widget build(BuildContext context) {
    final warm = title == 'Creations';
    final color = warm ? const Color(0xFFFF7B69) : const Color(0xFFE94DC3);
    return Container(
      height: 86,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0x541A1421),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF38243B)),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.08),
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.18), blurRadius: 18),
              ],
            ),
            child: Icon(icon, color: color, size: 34),
          ),
          const SizedBox(width: 17),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFAAA3B1),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (action != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0x331F0F2A),
                borderRadius: BorderRadius.circular(19),
                border: Border.all(color: const Color(0xFF653061)),
              ),
              child: Text(
                action!,
                style: const TextStyle(
                  color: AppColors.accent,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFFD0CBD4),
              size: 31,
            ),
        ],
      ),
    );
  }
}

class _SupportMenu extends StatelessWidget {
  const _SupportMenu();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0x3D16131C),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF302A36)),
      ),
      child: const Column(
        children: [
          _SupportTile(icon: Icons.help_outline_rounded, title: 'Help Center'),
          Divider(
            height: 1,
            indent: 16,
            endIndent: 0,
            color: Color(0x332F2936),
          ),
          _SupportTile(icon: Icons.shield_outlined, title: 'About & Privacy'),
        ],
      ),
    );
  }
}

class _SupportTile extends StatelessWidget {
  const _SupportTile({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 68,
      child: Row(
        children: [
          const SizedBox(width: 39),
          Icon(icon, color: const Color(0xFFD6D2D9), size: 27),
          const SizedBox(width: 28),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(color: Color(0xFFE4DFE8), fontSize: 17),
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: Color(0xFFD0CBD4),
            size: 31,
          ),
          const SizedBox(width: 14),
        ],
      ),
    );
  }
}

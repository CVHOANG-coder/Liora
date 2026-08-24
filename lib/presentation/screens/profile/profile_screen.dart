import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/models/user_profile.dart';
import '../../providers/profile_provider.dart';
import '../in_app_purchase/in_app_purchase_screen.dart';
import '../generation_history/generation_history_screen.dart';
import '../settings/settings_screen.dart';
import '../support/app_web_view_screen.dart';

final appVersionProvider = FutureProvider<String>((ref) async {
  final packageInfo = await PackageInfo.fromPlatform();
  return packageInfo.version.trim();
});

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final creditBalance = profile?.totalCredit ?? 0;
    final appVersion = ref.watch(appVersionProvider);

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
                    children: [
                      _AccountCard(profile: profile),
                      const SizedBox(height: 26),
                      _UpgradeCard(balance: creditBalance),
                      const SizedBox(height: 19),
                      const _ProfileMenu(),
                      const SizedBox(height: 17),
                      const _SupportMenu(),
                      const SizedBox(height: 3),
                      _AppVersionLabel(version: appVersion),
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

class _AppVersionLabel extends StatelessWidget {
  const _AppVersionLabel({required this.version});

  final AsyncValue<String> version;

  @override
  Widget build(BuildContext context) {
    final label = version.when(
      data: (value) => value.isEmpty ? 'V --' : 'V $value',
      loading: () => 'V ...',
      error: (_, _) => 'V --',
    );
    return Center(
      child: Text(
        label,
        key: const Key('profileAppVersion'),
        style: const TextStyle(
          color: Color(0xFF77737F),
          fontSize: 14,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.profile});

  final UserProfile? profile;

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
              Expanded(child: _AccountDetails(profile: profile)),
              const Icon(
                Icons.chevron_right_rounded,
                size: 34,
                color: Color(0xFFD5D2DB),
              ),
            ],
          ),
          const SizedBox(height: 17),
          _StatsRow(profile: profile),
        ],
      ),
    );
  }
}

class _AccountDetails extends StatelessWidget {
  const _AccountDetails({required this.profile});

  final UserProfile? profile;

  @override
  Widget build(BuildContext context) {
    final displayName = _profileDisplayName(profile);
    final identifier = _profileIdentifier(profile);
    final isPro = _hasProAccess(profile);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          identifier,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Color(0xFFB3ADBA), fontSize: 16),
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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isPro)
                const _ProIcon(color: AppColors.accent, size: 19)
              else
                const Icon(
                  Icons.person_outline_rounded,
                  color: AppColors.accent,
                  size: 19,
                ),
              const SizedBox(width: 6),
              Text(
                isPro ? 'Pro' : 'Free',
                style: const TextStyle(
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
  const _StatsRow({required this.profile});

  final UserProfile? profile;

  @override
  Widget build(BuildContext context) {
    final isPro = _hasProAccess(profile);
    final accountStatus = _profileAccountStatus(profile);

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.play_circle_outline_rounded,
            value: '${profile?.generationCount ?? 0}',
            label: 'videos',
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _StatCard(
            icon: Icons.today_rounded,
            value: '${profile?.todayGenerationCount ?? 0}',
            label: 'today',
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _StatCard(
            icon: Icons.workspace_premium_outlined,
            value: isPro ? 'Pro' : 'Free',
            label: accountStatus,
            warm: isPro,
            proIcon: isPro,
          ),
        ),
      ],
    );
  }
}

String _profileDisplayName(UserProfile? profile) {
  final username = profile?.username?.trim() ?? '';
  if (username.isNotEmpty) return username;

  final userCode = profile?.userCode.trim() ?? '';
  if (userCode.isNotEmpty) return userCode;

  final email = profile?.email.trim() ?? '';
  if (email.isNotEmpty) return email.split('@').first;
  return 'Nostalia User';
}

String _profileIdentifier(UserProfile? profile) {
  final email = profile?.email.trim() ?? '';
  if (email.isNotEmpty) return email;

  final userCode = profile?.userCode.trim() ?? '';
  if (userCode.isNotEmpty) return 'ID: $userCode';
  return 'Profile unavailable';
}

bool _hasProAccess(UserProfile? profile) {
  return profile?.isSubscribed == true || profile?.isVip == true;
}

String _profileAccountStatus(UserProfile? profile) {
  if (profile == null) return 'offline';
  if (profile.isBanned) return 'banned';
  if (profile.isActive) return 'active';

  final status = profile.userStatus.trim().toLowerCase();
  return status.isEmpty ? 'inactive' : status;
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
  const _UpgradeCard({required this.balance});

  final int balance;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 166,
      padding: const EdgeInsets.all(1.2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFFFF20B3), Color(0xFFFF704B), Color(0xFFFFA12B)],
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x66FF1AA5), blurRadius: 18),
          BoxShadow(
            color: Color(0x44FF832C),
            blurRadius: 20,
            offset: Offset(4, 1),
          ),
        ],
      ),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(23),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF21091D), Color(0xFF0C0810), Color(0xFF1E0D0A)],
          ),
        ),
        child: Stack(
          children: [
            const Positioned(
              right: -40,
              top: -38,
              width: 190,
              height: 155,
              child: Opacity(
                opacity: 0.28,
                child: Image(
                  image: AssetImage(
                    'assets/images/in_app_purchase/balance_coin.png',
                  ),
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 13),
              child: Column(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Image.asset(
                          'assets/images/in_app_purchase/balance_coin.png',
                          width: 82,
                          height: 72,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(
                                    Icons.account_balance_wallet_rounded,
                                    color: Color(0xFFFF55B8),
                                    size: 18,
                                  ),
                                  SizedBox(width: 7),
                                  Text(
                                    'Credit Balance',
                                    style: TextStyle(
                                      color: Color(0xFFE7E1E9),
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    ShaderMask(
                                      blendMode: BlendMode.srcIn,
                                      shaderCallback: (bounds) =>
                                          const LinearGradient(
                                            colors: [
                                              Color(0xFFFF35B2),
                                              Color(0xFFFF8536),
                                            ],
                                          ).createShader(bounds),
                                      child: Text(
                                        _formatCredits(balance),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 32,
                                          height: 1,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.6,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 7),
                                    const Padding(
                                      padding: EdgeInsets.only(bottom: 3),
                                      child: Text(
                                        'credits',
                                        style: TextStyle(
                                          color: Color(0xFFBEB6C1),
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  _BuyMoreCreditsButton(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const BuyCredits()),
                    ),
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

class _BuyMoreCreditsButton extends StatelessWidget {
  const _BuyMoreCreditsButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('buyMoreCreditsButton'),
      height: 44,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(23),
        gradient: const LinearGradient(
          colors: [Color(0xFFFF159F), Color(0xFFFF5D5B), Color(0xFFFF982F)],
        ),
        boxShadow: const [BoxShadow(color: Color(0x77FF168F), blurRadius: 13)],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(23),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image(
                image: AssetImage('assets/images/in_app_purchase/coin3.png'),
                width: 27,
                height: 27,
              ),
              SizedBox(width: 9),
              Text(
                'Buy More Credits',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(width: 7),
              Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 21),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatCredits(int value) {
  final digits = value.clamp(0, 999999999).toString();
  final buffer = StringBuffer();

  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) buffer.write(',');
    buffer.write(digits[index]);
  }

  return buffer.toString();
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
      children: [
        _FeatureTile(
          key: const Key('videoHistoryRow'),
          icon: Icons.video_library_outlined,
          title: 'Video',
          subtitle: 'History of your generated videos',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const GenerationHistoryScreen(),
            ),
          ),
        ),
        const SizedBox(height: 7),
        _FeatureTile(
          key: const Key('settingsRow'),
          icon: Icons.settings_outlined,
          title: 'Settings',
          subtitle: 'Language, data, and help',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
          ),
        ),
      ],
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFFE94DC3);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
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
                    BoxShadow(
                      color: color.withValues(alpha: 0.18),
                      blurRadius: 18,
                    ),
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
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFFD0CBD4),
                size: 31,
              ),
            ],
          ),
        ),
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
      child: Column(
        children: [
          _SupportTile(
            icon: Icons.help_outline_rounded,
            title: 'Help Center',
            onTap: () => AppWebViewScreen.open(context, AppWebPage.support),
          ),
        ],
      ),
    );
  }
}

class _SupportTile extends StatelessWidget {
  const _SupportTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 68,
          child: Row(
            children: [
              const SizedBox(width: 39),
              Icon(icon, color: const Color(0xFFD6D2D9), size: 27),
              const SizedBox(width: 28),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFFE4DFE8),
                    fontSize: 17,
                  ),
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
        ),
      ),
    );
  }
}

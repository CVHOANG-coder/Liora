import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:package_info_plus/package_info_plus.dart';

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

    return ColoredBox(
      color: const Color(0xFF02050C),
      child: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Keep the reference proportions on phones, without enlarging
            // every element indefinitely on wider screens.
            final scale = (constraints.maxWidth / 393).clamp(0.8, 1.3);
            return Column(
              children: [
                _ProfileHeader(scale: scale),
                Expanded(
                  child: CustomScrollView(
                    key: const PageStorageKey('profileScroll'),
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          14 * scale,
                          2 * scale,
                          14 * scale,
                          MediaQuery.paddingOf(context).bottom + 24,
                        ),
                        sliver: SliverList.list(
                          children: [
                            _AccountCard(profile: profile, scale: scale),
                            SizedBox(height: 10 * scale),
                            _UpgradeCard(balance: creditBalance, scale: scale),
                            SizedBox(height: 9 * scale),
                            _ProfileMenu(scale: scale),
                            const SizedBox(height: 24),
                            _AppVersionLabel(version: appVersion),
                          ],
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

const _profileSurface = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF0B101D), Color(0xFF070C17)],
);

const _profileIconGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFE49CEE), Color(0xFFB640F1)],
);

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const Key('profileHeader'),
      padding: EdgeInsets.fromLTRB(
        20 * scale,
        18 * scale,
        20 * scale,
        10 * scale,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Profile',
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Times New Roman',
                    fontFamilyFallback: const ['Times', 'serif'],
                    fontSize: 32 * scale,
                    height: 1.1,
                    fontWeight: FontWeight.w400,
                    letterSpacing: -0.8 * scale,
                  ),
                ),
                SizedBox(height: 11 * scale),
                Container(
                  width: 26 * scale,
                  height: 2.5 * scale,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFEC5FB6), Color(0xFF6657FF)],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.only(top: 3 * scale),
            child: Semantics(
              label: 'Notifications, unread',
              child: Stack(
                children: [
                  SvgPicture.asset(
                    'assets/svgs/profile_notification.svg',
                    width: 28 * scale,
                    height: 28 * scale,
                    excludeFromSemantics: true,
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 9 * scale,
                      height: 9 * scale,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF7567A),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
  const _AccountCard({required this.profile, required this.scale});

  final UserProfile? profile;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 9 * scale),
          child: Row(
            children: [
              Container(
                key: const Key('profileAvatar'),
                width: 118 * scale,
                height: 118 * scale,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF202332),
                  border: Border.all(
                    color: const Color(0xFF888793),
                    width: 1.3,
                  ),
                ),
                foregroundDecoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF888793),
                    width: 1.3,
                  ),
                ),
                child: ClipOval(
                  child: Transform.scale(
                    // Hide the neon ring baked into the shared Home avatar.
                    scale: 1.08,
                    child: ColorFiltered(
                      colorFilter: const ColorFilter.matrix([
                        0.60,
                        0.20,
                        0.10,
                        0,
                        0,
                        0.15,
                        0.75,
                        0.10,
                        0,
                        0,
                        0.15,
                        0.15,
                        0.70,
                        0,
                        0,
                        0,
                        0,
                        0,
                        1,
                        0,
                      ]),
                      child: Image.asset(
                        'assets/images/profile/avatar_default.png',
                        fit: BoxFit.cover,
                        excludeFromSemantics: true,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 15 * scale),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 145 * scale),
                    child: _AccountDetails(profile: profile, scale: scale),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 12 * scale),
        _StatsRow(profile: profile, scale: scale),
      ],
    );
  }
}

class _AccountDetails extends StatelessWidget {
  const _AccountDetails({required this.profile, required this.scale});

  final UserProfile? profile;
  final double scale;

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
          style: TextStyle(
            color: Colors.white,
            fontSize: 22 * scale,
            height: 1.15,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.4 * scale,
          ),
        ),
        SizedBox(height: 8 * scale),
        Text(
          identifier,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: const Color(0xFF62616F),
            fontSize: 13 * scale,
            height: 1.2,
          ),
        ),
        SizedBox(height: 11 * scale),
        Container(
          key: const Key('profilePlanBadge'),
          padding: EdgeInsets.symmetric(
            horizontal: 11 * scale,
            vertical: 6 * scale,
          ),
          decoration: BoxDecoration(
            gradient: _profileSurface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFF44414F), width: 0.6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ProIcon(size: 16 * scale),
              SizedBox(width: 10 * scale),
              Text(
                isPro ? 'Pro' : 'Free',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13 * scale,
                  height: 1.1,
                  fontWeight: FontWeight.w400,
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
  const _StatsRow({required this.profile, required this.scale});

  final UserProfile? profile;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final isPro = _hasProAccess(profile);
    final accountStatus = _profileAccountStatus(profile);

    return Container(
      key: const Key('profileStats'),
      height: 89 * scale,
      padding: EdgeInsets.symmetric(
        horizontal: 15 * scale,
        vertical: 16 * scale,
      ),
      decoration: BoxDecoration(
        gradient: _profileSurface,
        borderRadius: BorderRadius.circular(14 * scale),
        border: Border.all(color: const Color(0xFF343743), width: 0.6),
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
              asset: 'assets/svgs/profile_video.svg',
              value: '${profile?.generationCount ?? 0}',
              label: 'Videos',
              scale: scale,
            ),
          ),
          _StatDivider(scale: scale),
          Expanded(
            child: _StatCard(
              asset: 'assets/svgs/profile_calendar.svg',
              value: '${profile?.todayGenerationCount ?? 0}',
              label: 'Today',
              scale: scale,
            ),
          ),
          _StatDivider(scale: scale),
          Expanded(
            child: Semantics(
              key: const Key('profileAccountStatus'),
              value: 'Account status: $accountStatus',
              child: _StatCard(
                asset: 'assets/svgs/profile_plan.svg',
                value: isPro ? 'Pro' : 'Free',
                label: 'Active Plan',
                scale: scale,
                isPlan: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider({required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 0.6,
      height: double.infinity,
      margin: EdgeInsets.symmetric(horizontal: 8 * scale),
      color: const Color(0xFF262A39),
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
  return 'Liora User';
}

String _profileIdentifier(UserProfile? profile) {
  final email = profile?.email.trim() ?? '';
  if (email.isNotEmpty) return email;

  final userCode = profile?.userCode.trim() ?? '';
  if (userCode.isNotEmpty) return 'ID: $userCode';
  return 'Profile unavailable';
}

bool _hasProAccess(UserProfile? profile) {
  return profile?.isSubscribed == true || profile?.isVIP == true;
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
    required this.asset,
    required this.value,
    required this.label,
    required this.scale,
    this.isPlan = false,
  });

  final String asset;
  final String value;
  final String label;
  final double scale;
  final bool isPlan;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42 * scale,
          height: 42 * scale,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF252139), Color(0xFF17172B)],
            ),
            borderRadius: BorderRadius.circular(10 * scale),
            border: Border.all(color: const Color(0xFF3A304C), width: 0.5),
          ),
          child: ShaderMask(
            shaderCallback: _profileIconGradient.createShader,
            blendMode: BlendMode.srcIn,
            child: Center(
              child: SvgPicture.asset(
                asset,
                width: 25 * scale,
                height: 25 * scale,
                excludeFromSemantics: true,
              ),
            ),
          ),
        ),
        SizedBox(width: 12 * scale),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  maxLines: 1,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: (isPlan ? 16 : 18) * scale,
                    fontWeight: FontWeight.w400,
                    height: 1.1,
                  ),
                ),
              ),
              SizedBox(height: 7 * scale),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    color: const Color(0xFFB4B1BD),
                    fontSize: 10 * scale,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _UpgradeCard extends StatelessWidget {
  const _UpgradeCard({required this.balance, required this.scale});

  final int balance;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('profileCreditCard'),
      height: 152 * scale,
      padding: const EdgeInsets.all(0.6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14 * scale),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFAE72B4), Color(0xFF343343), Color(0xFF1A2232)],
        ),
      ),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14 * scale - 0.6),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF241A33), Color(0xFF090E1B), Color(0xFF070C16)],
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) => Stack(
            children: [
              Positioned(
                left: 9 * scale,
                top: 12 * scale,
                bottom: 8 * scale,
                width: constraints.maxWidth * 0.42,
                child: Image.asset(
                  'assets/images/profile/balance_credit.png',
                  fit: BoxFit.contain,
                  alignment: Alignment.bottomCenter,
                  excludeFromSemantics: true,
                ),
              ),
              Positioned(
                left: constraints.maxWidth * 0.475,
                right: 16 * scale,
                top: 24 * scale,
                bottom: 16 * scale,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(left: 4 * scale),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'CREDIT BALANCE',
                          style: TextStyle(
                            color: const Color(0xFFB15AF7),
                            fontSize: 10 * scale,
                            height: 1.2,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0.5 * scale,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 14 * scale),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        children: [
                          Image.asset(
                            'assets/images/profile/icon_credit_balance.png',
                            width: 40 * scale,
                            height: 28 * scale,
                            fit: BoxFit.contain,
                            excludeFromSemantics: true,
                          ),
                          SizedBox(width: 7 * scale),
                          Text(
                            _formatCredits(balance),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 32 * scale,
                              height: 1,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          SizedBox(width: 6 * scale),
                          Text(
                            'credits',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14 * scale,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    _BuyMoreCreditsButton(
                      scale: scale,
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
      ),
    );
  }
}

class _BuyMoreCreditsButton extends StatelessWidget {
  const _BuyMoreCreditsButton({required this.onTap, required this.scale});

  final VoidCallback onTap;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('buyMoreCreditsButton'),
      height: 39 * scale,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10 * scale),
        border: Border.all(color: const Color(0xFF8C5ACF), width: 0.5),
        gradient: const LinearGradient(
          colors: [Color(0xFFB846B9), Color(0xFF5033CB), Color(0xFF2155E6)],
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10 * scale),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16 * scale),
            child: Row(
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Buy More Credits',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13 * scale,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8 * scale),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 18 * scale,
                ),
              ],
            ),
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
  const _ProIcon({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: _profileIconGradient.createShader,
      blendMode: BlendMode.srcIn,
      child: SvgPicture.asset(
        'assets/svgs/pro.svg',
        width: size,
        height: size,
        colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
        excludeFromSemantics: true,
      ),
    );
  }
}

class _ProfileMenu extends StatelessWidget {
  const _ProfileMenu({required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _FeatureTile(
            key: const Key('videoHistoryRow'),
            asset: 'assets/images/profile/video_icon.png',
            title: 'VIDEO',
            subtitle: 'History of your\ngenerated videos',
            scale: scale,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const GenerationHistoryScreen(),
              ),
            ),
          ),
        ),
        SizedBox(width: 7 * scale),
        Expanded(
          child: _FeatureTile(
            key: const Key('settingsRow'),
            asset: 'assets/images/profile/setting_icon.png',
            title: 'SETTINGS',
            subtitle: 'Customize your\nexperience',
            scale: scale,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            ),
          ),
        ),
        SizedBox(width: 7 * scale),
        Expanded(
          child: _FeatureTile(
            key: const Key('helpCenterRow'),
            asset: 'assets/images/profile/help_icon.png',
            title: 'HELP CENTER',
            subtitle: 'Get assistance\nand support',
            scale: scale,
            onTap: () => AppWebViewScreen.open(context, AppWebPage.support),
          ),
        ),
      ],
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.asset,
    required this.scale,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String asset;
  final double scale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 134 * scale,
      decoration: BoxDecoration(
        gradient: _profileSurface,
        borderRadius: BorderRadius.circular(14 * scale),
        border: Border.all(color: const Color(0xFF343743), width: 0.6),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14 * scale),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            children: [
              Positioned(
                left: 12 * scale,
                right: 10 * scale,
                top: 16 * scale,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        title,
                        maxLines: 1,
                        style: TextStyle(
                          color: const Color(0xFFB052F5),
                          fontSize: 10 * scale,
                          height: 1.2,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    SizedBox(height: 6 * scale),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: const Color(0xFFB4B1BD),
                        fontSize: 10 * scale,
                        height: 1.4,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                right: 12 * scale,
                bottom: 7 * scale,
                width: 64 * scale,
                height: 63 * scale,
                child: Image.asset(
                  asset,
                  fit: BoxFit.contain,
                  excludeFromSemantics: true,
                ),
              ),
              Positioned(
                left: 11 * scale,
                bottom: 15 * scale,
                child: Container(
                  width: 22 * scale,
                  height: 22 * scale,
                  decoration: const BoxDecoration(
                    color: Color(0xFF211E36),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white,
                    size: 17 * scale,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

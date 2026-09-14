import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/constants/app_features.dart';
import '../../../core/network/api_client.dart';
import '../../../data/models/generation_history.dart';
import '../../../data/models/i2v_request_status.dart';
import '../../../data/models/user_profile.dart';
import '../../providers/profile_provider.dart';
import '../../widgets/cached_video_thumbnail.dart';
import '../../widgets/video_form_style.dart';
import '../generation_history/generation_history_screen.dart';
import '../image_to_video/image_to_video_screen.dart';
import '../in_app_purchase/free_trial_screen.dart';
import '../in_app_purchase/in_app_purchase_screen.dart';
import '../settings/settings_screen.dart';

final profileVideoHistoryProvider = FutureProvider<GenerationHistoryPage>(
  (ref) => ApiClient.instance.fetchGenerationHistory(page: 1, limit: 6),
);

final appVersionProvider = FutureProvider<String>((ref) async {
  final packageInfo = await PackageInfo.fromPlatform();
  return packageInfo.version.trim();
});

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final videoHistory = ref.watch(profileVideoHistoryProvider);

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
                            if (AppFeatures.commerceEnabled) ...[
                              SizedBox(height: 10 * scale),
                              _UpgradeCard(profile: profile, scale: scale),
                            ],
                            SizedBox(height: 14 * scale),
                            _ProfileVideoHistory(
                              history: videoHistory,
                              scale: scale,
                              onRefresh: () =>
                                  ref.invalidate(profileVideoHistoryProvider),
                            ),
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
            child: IconButton(
              key: const Key('profileSettingsButton'),
              tooltip: 'Settings',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
              ),
              icon: Icon(
                Icons.settings_outlined,
                color: const Color(0xFFD88AF0),
                size: 28 * scale,
              ),
            ),
          ),
        ],
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
        if (AppFeatures.commerceEnabled) ...[
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
  return profile?.isSubscribed == true;
}

class _UpgradeCard extends StatelessWidget {
  const _UpgradeCard({required this.profile, required this.scale});

  final UserProfile? profile;
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
                            _formatCredits(profile?.totalCredit ?? 0),
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
                    _CreditActionButton(
                      scale: scale,
                      label: profile?.isSubscribed == true
                          ? 'Buy More Credits'
                          : 'Upgrade to Pro',
                      onTap: profile?.isSubscribed == true
                          ? () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const BuyCredits(),
                              ),
                            )
                          : () => FreeTrialScreen.open(context),
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

class _CreditActionButton extends StatelessWidget {
  const _CreditActionButton({
    required this.label,
    required this.onTap,
    required this.scale,
  });

  final String label;
  final VoidCallback onTap;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('profileCreditActionButton'),
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
                      label,
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

class _ProfileVideoHistory extends StatelessWidget {
  const _ProfileVideoHistory({
    required this.history,
    required this.scale,
    required this.onRefresh,
  });

  final AsyncValue<GenerationHistoryPage> history;
  final double scale;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('profileVideoHistory'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'History videos',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Times New Roman',
                  fontSize: 25 * scale,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            IconButton(
              key: const Key('refreshProfileVideos'),
              tooltip: 'Refresh videos',
              onPressed: onRefresh,
              icon: Icon(
                Icons.refresh_rounded,
                color: VideoFormStyle.accent,
                size: 21 * scale,
              ),
            ),
            TextButton(
              key: const Key('viewAllProfileVideos'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const GenerationHistoryScreen(),
                ),
              ),
              child: const Text('View all'),
            ),
          ],
        ),
        SizedBox(height: 8 * scale),
        history.when(
          loading: () => const SizedBox(
            height: 150,
            child: Center(
              child: CircularProgressIndicator(
                color: VideoFormStyle.accent,
                strokeWidth: 2,
              ),
            ),
          ),
          error: (_, _) => _ProfileVideoMessage(
            message: 'Unable to load your videos.',
            actionLabel: 'Try again',
            onTap: onRefresh,
          ),
          data: (page) {
            final requests = page.requests.take(6).toList(growable: false);
            if (requests.isEmpty) {
              return _EmptyProfileVideos(
                onCreate: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ImageToVideoScreen(),
                  ),
                ),
              );
            }
            return GridView.builder(
              key: const Key('profileVideoGrid'),
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10 * scale,
                crossAxisSpacing: 10 * scale,
                childAspectRatio: 0.82,
              ),
              itemCount: requests.length,
              itemBuilder: (context, index) => _ProfileVideoCard(
                request: requests[index],
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const GenerationHistoryScreen(),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _ProfileVideoMessage extends StatelessWidget {
  const _ProfileVideoMessage({
    required this.message,
    this.actionLabel,
    this.onTap,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
    decoration: BoxDecoration(
      gradient: _profileSurface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFF343743), width: 0.6),
    ),
    child: Column(
      children: [
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: VideoFormStyle.secondary, fontSize: 13),
        ),
        if (actionLabel != null) ...[
          const SizedBox(height: 8),
          TextButton(onPressed: onTap, child: Text(actionLabel!)),
        ],
      ],
    ),
  );
}

class _EmptyProfileVideos extends StatelessWidget {
  const _EmptyProfileVideos({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('emptyProfileVideos'),
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
    decoration: BoxDecoration(
      gradient: _profileSurface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFF343743), width: 0.6),
    ),
    child: Column(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: const Color(0xFF211E36),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF5B4776), width: 0.7),
          ),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Image.asset(
              'assets/images/profile/video_icon.png',
              key: const Key('emptyProfileVideoIcon'),
              fit: BoxFit.contain,
              excludeFromSemantics: true,
            ),
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Your generated videos will appear here.',
          textAlign: TextAlign.center,
          style: TextStyle(color: VideoFormStyle.secondary, fontSize: 13),
        ),
        const SizedBox(height: 16),
        Container(
          constraints: const BoxConstraints(minHeight: 44),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFB846B9), Color(0xFF5033CB), Color(0xFF2155E6)],
            ),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: const Key('createImageVideoFromProfile'),
              onTap: onCreate,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_rounded, color: Colors.white, size: 19),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Create Video Now',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
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
    ),
  );
}

class _ProfileVideoCard extends StatelessWidget {
  const _ProfileVideoCard({required this.request, required this.onTap});

  final I2VRequestStatus request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final previewUrl = request.thumbnailUrl.isNotEmpty
        ? request.thumbnailUrl
        : request.imageUrl;
    final title = request.prompt.trim().isEmpty
        ? 'Untitled video'
        : request.prompt.trim();
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('profileVideo_${request.requestId}'),
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: _profileSurface,
            border: Border.all(color: const Color(0xFF343743), width: 0.6),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedVideoThumbnail(
                      cacheKey: request.requestId,
                      imageUrl: previewUrl,
                      fallbackImageUrl: request.imageUrl,
                      videoUrl: request.isCompleted ? request.resultUrl : '',
                    ),
                    if (request.isCompleted)
                      const Center(
                        child: Icon(
                          Icons.play_circle_fill_rounded,
                          color: Colors.white,
                          size: 34,
                        ),
                      ),
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xD90B101B),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text(
                          request.requestStatus.value.replaceAll('_', ' '),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
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

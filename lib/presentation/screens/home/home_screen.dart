import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/constants/app_features.dart';
import '../../../data/video_categories.dart';
import '../../providers/home_subscription_plan_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/cached_video_thumbnail.dart';
import '../image_to_video/image_to_video_screen.dart';
import '../in_app_purchase/all_plans_screen.dart';
import '../in_app_purchase/free_trial_screen.dart';
import '../in_app_purchase/in_app_purchase_screen.dart';
import '../profile/profile_screen.dart';
import '../text_to_video/text_to_video_screen.dart';
import '../video_detail/video_detail_screen.dart';

const _themeCardAspectRatio = 9 / 16;

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key, this.onProfilePressed});

  final VoidCallback? onProfilePressed;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final planStatus = AppFeatures.commerceEnabled
        ? ref.watch(homeSubscriptionPlanProvider).value ??
              homeSubscriptionPlanFromProfile(profile)
        : HomeSubscriptionPlan.none;
    final planAction = switch (planStatus) {
      HomeSubscriptionPlan.weekly => _HomePlanAction.upgrade,
      HomeSubscriptionPlan.yearly => _HomePlanAction.credit,
      HomeSubscriptionPlan.none => _HomePlanAction.pro,
    };
    final categories = ref.watch(themeCategoriesProvider);

    return ColoredBox(
      color: Colors.black,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              key: const Key('homeHeader'),
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: _HomeHeader(
                showPlanAction: AppFeatures.commerceEnabled,
                planAction: planAction,
                creditBalance: profile?.totalCredit ?? 0,
                onAvatarPressed:
                    widget.onProfilePressed ??
                    () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ProfileScreen(),
                      ),
                    ),
                onCreditPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const BuyCredits()),
                ),
                onProPressed: () {
                  if (planStatus == HomeSubscriptionPlan.none &&
                      profile?.isVIP != true) {
                    FreeTrialScreen.open(context);
                    return;
                  }
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const AllPlans()),
                  );
                },
              ),
            ),
            Expanded(
              child: CustomScrollView(
                key: const PageStorageKey('homeScroll'),
                physics: const BouncingScrollPhysics(),
                // Offscreen animated previews must not keep decoding frames.
                scrollCacheExtent: const ScrollCacheExtent.pixels(0),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        children: const [
                          _HeroBanner(),
                          SizedBox(height: 2),
                          _FeatureCards(),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 118),
                    sliver: _VideoCategories(
                      categories: categories,
                      onRetry: () => ref.invalidate(themeCategoriesProvider),
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

enum _HomePlanAction { pro, upgrade, credit }

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.showPlanAction,
    required this.planAction,
    required this.creditBalance,
    required this.onAvatarPressed,
    required this.onCreditPressed,
    required this.onProPressed,
  });

  final bool showPlanAction;
  final _HomePlanAction planAction;
  final int creditBalance;
  final VoidCallback onAvatarPressed;
  final VoidCallback onCreditPressed;
  final VoidCallback onProPressed;

  @override
  Widget build(BuildContext context) {
    final label = switch (planAction) {
      _HomePlanAction.pro => 'Pro',
      _HomePlanAction.upgrade => 'Upgrade',
      _HomePlanAction.credit => 'Pro',
    };
    final semanticsLabel = switch (planAction) {
      _HomePlanAction.pro => 'View Pro offer',
      _HomePlanAction.upgrade => 'Upgrade to Yearly Pro',
      _HomePlanAction.credit => 'View Pro plan',
    };
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: const Key('homeAvatarButton'),
              onTap: onAvatarPressed,
              child: SizedBox(
                key: const Key('homeAvatar'),
                width: 40,
                height: 40,
                child: Image.asset(
                  'assets/images/profile/avatar_default.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(right: 12),
                child: _Brand(),
              ),
            ),
          ),
          if (showPlanAction) ...[
            _HomeCreditButton(balance: creditBalance, onTap: onCreditPressed),
            const SizedBox(width: 8),
            Semantics(
              button: true,
              enabled: true,
              label: semanticsLabel,
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFDA4A9A),
                      Color(0xFF7D45C5),
                      Color(0xFF315BD9),
                    ],
                  ),
                  border: Border.all(color: const Color(0xFFCF9BE7), width: .7),
                  boxShadow: const [
                    BoxShadow(color: Color(0x66B947B1), blurRadius: 14),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(22),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    key: const Key('homeProButton'),
                    onTap: onProPressed,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SvgPicture.asset(
                            'assets/svgs/pro.svg',
                            width: 19,
                            height: 19,
                            colorFilter: const ColorFilter.mode(
                              Colors.white,
                              BlendMode.srcIn,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HomeCreditButton extends StatelessWidget {
  const _HomeCreditButton({required this.balance, required this.onTap});

  final int balance;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFF111521),
    borderRadius: BorderRadius.circular(22),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      key: const Key('homeCreditButton'),
      onTap: onTap,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFF423653), width: .7),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/in_app_purchase/credit.png',
              width: 22,
              height: 22,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 4),
            Text(
              _formatHomeCredits(balance),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

String _formatHomeCredits(int value) {
  final digits = value.clamp(0, 999999999).toString();
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) buffer.write(',');
    buffer.write(digits[index]);
  }
  return buffer.toString();
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const Key('homeBrand'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/images/home/lola_logo.png',
          width: 28,
          height: 28,
          fit: BoxFit.contain,
        ),
        const SizedBox(width: 6),
        const Text(
          'Liora',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
          ),
        ),
      ],
    );
  }
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 174,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            right: -12,
            top: 0,
            width: 270,
            height: 202,
            child: Image.asset(
              'assets/images/home/bg_banner_home.png',
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
          ),
          const Positioned(left: 8, top: 32, child: _HeroCopy()),
        ],
      ),
    );
  }
}

class _HeroCopy extends StatelessWidget {
  const _HeroCopy();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(
          width: 1,
          height: 1,
          child: Opacity(
            opacity: 0,
            child: Text('Create AI short films', style: TextStyle(fontSize: 0)),
          ),
        ),
        const Text(
          'Create AI',
          style: TextStyle(
            color: Color(0xFFF8F6F8),
            fontFamily: 'serif',
            fontSize: 35,
            height: 0.98,
            fontWeight: FontWeight.w700,
            letterSpacing: -1.5,
          ),
        ),
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFFFF71AD), Color(0xFF9B75FF)],
          ).createShader(bounds),
          child: const Text(
            'short films',
            style: TextStyle(
              fontFamily: 'serif',
              fontSize: 35,
              height: 1.05,
              fontWeight: FontWeight.w700,
              letterSpacing: -1.5,
            ),
          ),
        ),
        const SizedBox(height: 22),
        const Text(
          'Image to Video, \nmade to go viral.',
          style: TextStyle(
            color: Color(0xFFBDB8C1),
            fontSize: 16,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class _FeatureCards extends StatelessWidget {
  const _FeatureCards();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(
          child: _FeatureCard(
            title: 'Image to Video',
            subtitle: 'Animate photos\nand characters',
            asset: 'assets/images/home/image_to_video.png',
            backgroundAsset: 'assets/images/home/image_to_video_bg.png',
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: _FeatureCard(
            title: 'Text to Video',
            subtitle: 'Turn ideas into\nAI short videos',
            asset: 'assets/images/home/text_to_video.png',
            backgroundAsset: 'assets/images/home/text_to_video_bg.png',
          ),
        ),
      ],
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.title,
    required this.subtitle,
    required this.asset,
    required this.backgroundAsset,
  });

  final String title;
  final String subtitle;
  final String asset;
  final String backgroundAsset;

  @override
  Widget build(BuildContext context) {
    final card = AspectRatio(
      aspectRatio: 1.36,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(19),
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(backgroundAsset, fit: BoxFit.cover),
            ),
            Positioned(
              left: 13,
              top: 14,
              width: 40,
              height: 40,
              child: Image.asset(asset, fit: BoxFit.contain),
            ),
            Positioned(
              left: 13,
              right: 13,
              bottom: 14,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            color: Color(0xFFBBB5BE),
                            fontSize: 11.5,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 5),
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF121421).withValues(alpha: 0.78),
                      border: Border.all(color: const Color(0xFF5A5576)),
                    ),
                    child: const Icon(Icons.arrow_forward_rounded, size: 21),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    final isTextToVideo = title == 'Text to Video';
    final isImageToVideo = title == 'Image to Video';
    if (!isTextToVideo && !isImageToVideo) return card;
    return GestureDetector(
      key: Key(isTextToVideo ? 'homeTextToVideoCard' : 'homeImageToVideoCard'),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => isTextToVideo
              ? const TextToVideoScreen()
              : const ImageToVideoScreen(),
        ),
      ),
      child: card,
    );
  }
}

class _VideoCategories extends StatelessWidget {
  const _VideoCategories({required this.categories, required this.onRetry});

  final AsyncValue<List<VideoCategory>> categories;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return categories.when(
      loading: () => const SliverToBoxAdapter(child: _CategoriesLoading()),
      error: (error, _) => SliverToBoxAdapter(
        child: _CategoriesError(error: error, onRetry: onRetry),
      ),
      data: (items) {
        if (items.isEmpty) {
          return const SliverToBoxAdapter(child: _CategoriesEmpty());
        }
        return SliverList.builder(
          itemCount: items.length,
          // Images request keep-alive while loading; retaining entire rows
          // would also retain their animated image stream listeners.
          addAutomaticKeepAlives: false,
          itemBuilder: (_, index) => Padding(
            key: ValueKey(items[index].id),
            padding: EdgeInsets.only(bottom: index < items.length - 1 ? 24 : 0),
            child: _VideoCategorySection(category: items[index]),
          ),
        );
      },
    );
  }
}

class _VideoCategorySection extends StatelessWidget {
  const _VideoCategorySection({required this.category});

  final VideoCategory category;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final thumbnailWidth = ((screenWidth - 44) / 2.25).clamp(126.0, 184.0);
    final thumbnailHeight = thumbnailWidth / _themeCardAspectRatio;
    final decodeWidth =
        (thumbnailWidth * MediaQuery.devicePixelRatioOf(context)).ceil().clamp(
          1,
          512,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _CategoryIcon(title: category.title),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                category.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              key: ValueKey('seeAllThemes_${category.id}'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => _CategoryThemesScreen(category: category),
                ),
              ),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFCFCCD2),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                minimumSize: const Size(0, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'See all',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF969198),
              size: 20,
            ),
          ],
        ),
        const SizedBox(height: 11),
        SizedBox(
          height: thumbnailHeight,
          child: ListView.separated(
            key: PageStorageKey('homeCategory_${category.id}'),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            scrollCacheExtent: const ScrollCacheExtent.pixels(0),
            addAutomaticKeepAlives: false,
            itemCount: category.posts.length,
            separatorBuilder: (_, _) => const SizedBox(width: 6),
            itemBuilder: (_, index) => SizedBox(
              width: thumbnailWidth,
              child: _VideoThumbnail(
                post: category.posts[index],
                index: index,
                decodeWidth: decodeWidth,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CategoryThemesScreen extends StatelessWidget {
  const _CategoryThemesScreen({required this.category});

  final VideoCategory category;

  @override
  Widget build(BuildContext context) {
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final columns = screenWidth >= 700 ? 4 : 2;
    final cardWidth = (screenWidth - 32 - (columns - 1) * 12) / columns;
    final decodeWidth = (cardWidth * pixelRatio).ceil().clamp(1, 768);
    return Scaffold(
      key: const Key('categoryThemesScreen'),
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        surfaceTintColor: Colors.transparent,
        title: Text(category.title),
      ),
      body: GridView.builder(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          24 + MediaQuery.paddingOf(context).bottom,
        ),
        physics: const BouncingScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisSpacing: 14,
          crossAxisSpacing: 12,
          childAspectRatio: _themeCardAspectRatio,
        ),
        itemCount: category.posts.length,
        itemBuilder: (context, index) => _VideoThumbnail(
          post: category.posts[index],
          index: index,
          decodeWidth: decodeWidth,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

class _CategoryIcon extends StatelessWidget {
  const _CategoryIcon({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final normalized = title.toLowerCase();
    final icon = normalized.contains('revive')
        ? Icons.history_rounded
        : normalized.contains('animate')
        ? Icons.auto_awesome_rounded
        : Icons.local_fire_department_rounded;
    final colors = normalized.contains('revive')
        ? const [Color(0xFF8276FF), Color(0xFFB97CFF)]
        : normalized.contains('animate')
        ? const [Color(0xFF6C69FF), Color(0xFFB37AFF)]
        : const [Color(0xFFE458FF), Color(0xFF965BFF)];

    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) =>
          LinearGradient(colors: colors).createShader(bounds),
      child: Icon(icon, size: 23),
    );
  }
}

class _VideoThumbnail extends StatelessWidget {
  const _VideoThumbnail({
    required this.post,
    required this.index,
    required this.decodeWidth,
    this.fit = BoxFit.cover,
  });

  final VideoPost post;
  final int index;
  final int decodeWidth;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Watch ${post.description}',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: Key('videoThumbnail_${post.id}'),
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => VideoDetailScreen(post: post),
            ),
          ),
          child: Hero(
            tag: 'video_${post.id}',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: RepaintBoundary(
                child: _PreviewBody(
                  post: post,
                  index: index,
                  decodeWidth: decodeWidth,
                  fit: fit,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PreviewBody extends StatelessWidget {
  const _PreviewBody({
    required this.post,
    required this.index,
    required this.decodeWidth,
    required this.fit,
  });

  final VideoPost post;
  final int index;
  final int decodeWidth;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    // A null-URL post is a test/offline placeholder. Keep only the first two
    // animated preview widgets per row mounted so large empty catalogs remain
    // cheap to scroll; real API posts continue to use the full preview path.
    final isOfflinePlaceholder =
        post.previewImageUrl == null &&
        post.thumbnailUrl == null &&
        post.videoUrl == null;
    if (isOfflinePlaceholder && index > 1) {
      return const _ThumbnailSkeleton();
    }
    return CachedVideoThumbnail(
      cacheKey: 'template:${post.id}',
      imageUrl: post.previewImageUrl ?? '',
      fallbackImageUrl: post.thumbnailUrl ?? '',
      videoUrl: post.videoUrl ?? '',
      fit: fit,
      maxDecodeWidth: decodeWidth,
      filterQuality: FilterQuality.low,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      placeholder: const _ThumbnailSkeleton(),
      errorWidget: const _ThumbnailError(),
    );
  }
}

class _ThumbnailSkeleton extends StatelessWidget {
  const _ThumbnailSkeleton();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF211B25), Color(0xFF39303E), Color(0xFF211B25)],
          stops: [0.25, 0.5, 0.75],
        ),
      ),
    );
  }
}

class _ThumbnailError extends StatelessWidget {
  const _ThumbnailError();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFF211B25),
      child: Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          color: Color(0xFF827987),
          size: 26,
        ),
      ),
    );
  }
}

class _CategoriesLoading extends StatelessWidget {
  const _CategoriesLoading();

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final thumbnailWidth = ((screenWidth - 44) / 2.25).clamp(126.0, 184.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(
          width: 150,
          height: 22,
          child: ClipRRect(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            child: _ThumbnailSkeleton(),
          ),
        ),
        const SizedBox(height: 11),
        SizedBox(
          height: thumbnailWidth / _themeCardAspectRatio,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 3,
            separatorBuilder: (_, _) => const SizedBox(width: 6),
            itemBuilder: (_, _) => ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(
                width: thumbnailWidth,
                child: const _ThumbnailSkeleton(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CategoriesError extends StatelessWidget {
  const _CategoriesError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF171217),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF3A2D38)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            color: Color(0xFFFF4DA6),
            size: 30,
          ),
          const SizedBox(height: 10),
          Text(
            error.toString(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFBDB8C1), fontSize: 13),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            key: const Key('retryThemesButton'),
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 19),
            label: const Text('Retry'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFFF4DA6),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoriesEmpty extends StatelessWidget {
  const _CategoriesEmpty();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Text(
        'No themes are available yet.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Color(0xFF8E8790), fontSize: 13),
      ),
    );
  }
}

/*
class _QuickCreate extends StatelessWidget {
  const _QuickCreate();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.bolt_rounded, color: Color(0xFFB45CFF), size: 24),
            SizedBox(width: 8),
            Text(
              'Quick Create',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Row(
          children: [
            Expanded(
              child: _QuickTool(
                icon: Icons.description_outlined,
                title: 'AI Script',
                subtitle: 'Write a script in\njust a few seconds',
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: _QuickTool(
                icon: Icons.mic_none_rounded,
                title: 'Voiceover',
                subtitle: 'Natural, expressive\nAI voices',
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: _QuickTool(
                icon: Icons.closed_caption_outlined,
                title: 'Subtitle',
                subtitle: 'Automatically create\nsubtitles',
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: _QuickTool(
                icon: Icons.person_off_outlined,
                title: 'Remove Background',
                subtitle: 'Remove backgrounds\nquickly and cleanly',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuickTool extends StatelessWidget {
  const _QuickTool({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 128,
      padding: const EdgeInsets.fromLTRB(5, 13, 5, 9),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF20181B), Color(0xFF0D0D11)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF40363C)),
      ),
      child: Column(
        children: [
          ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFFFF49BB), Color(0xFFFF8A5B)],
            ).createShader(bounds),
            child: Icon(icon, color: Colors.white, size: 32),
          ),
          const Spacer(),
          FittedBox(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: const TextStyle(
              color: Color(0xFFB5B0B4),
              fontSize: 9.5,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}
*/

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:video_player/video_player.dart';

import '../../../core/constants/app_features.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/video_categories.dart';
import '../../providers/home_subscription_plan_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/cached_video_thumbnail.dart';
import '../image_to_video/image_to_video_screen.dart';
import '../in_app_purchase/all_plans_screen.dart';
import '../in_app_purchase/free_trial_screen.dart';
import '../in_app_purchase/in_app_purchase_screen.dart';
import '../text_to_video/text_to_video_screen.dart';
import '../video_detail/video_detail_screen.dart';

const _themeCardAspectRatio = 2 / 3;

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _bannerVisible = true;

  bool _onHomeScroll(ScrollNotification notification) {
    if (notification.depth != 0 || notification.metrics.axis != Axis.vertical) {
      return false;
    }
    final bannerHeight =
        MediaQuery.sizeOf(context).width * .60 +
        MediaQuery.paddingOf(context).top;
    final visible = notification.metrics.pixels < bannerHeight;
    if (visible != _bannerVisible) setState(() => _bannerVisible = visible);
    return false;
  }

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

    final safeTop = MediaQuery.paddingOf(context).top;
    return ColoredBox(
      color: AppColors.background,
      child: Stack(
        children: [
          NotificationListener<ScrollNotification>(
            onNotification: _onHomeScroll,
            child: CustomScrollView(
              key: const PageStorageKey('homeScroll'),
              physics: const BouncingScrollPhysics(),
              scrollCacheExtent: const ScrollCacheExtent.pixels(0),
              slivers: [
                SliverToBoxAdapter(
                  child: _HeroBanner(isVisible: _bannerVisible),
                ),
                const SliverPadding(
                  padding: EdgeInsets.fromLTRB(14, 12, 14, 22),
                  sliver: SliverToBoxAdapter(child: _FeatureCards()),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 0, 118),
                  sliver: _VideoCategories(
                    categories: categories,
                    onRetry: () => ref.invalidate(themeCategoriesProvider),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: safeTop - 10,
            left: 14,
            right: 14,
            child: _HomeHeader(
              showPlanAction: AppFeatures.commerceEnabled,
              planAction: planAction,
              creditBalance: profile?.totalCredit ?? 0,
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
        ],
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
    required this.onCreditPressed,
    required this.onProPressed,
  });

  final bool showPlanAction;
  final _HomePlanAction planAction;
  final int creditBalance;
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
      key: const Key('homeHeader'),
      height: 48,
      child: Row(
        crossAxisAlignment: .center,
        children: [
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
                  color: AppColors.primary,
                  border: Border.all(color: const Color(0xFFCB9DFF), width: .7),
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
                            'assets/svgs/pro_2.svg',
                            width: 22,
                            height: 22,
                            // colorFilter: const ColorFilter.mode(
                            //   Colors.white,
                            //   BlendMode.srcIn,
                            // ),
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
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Buy credits, $balance credits',
    child: Container(
      key: const Key('homeCreditSurface'),
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: AppColors.primary,
        border: Border.all(color: const Color(0xFFCB9DFF), width: .7),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const Key('homeCreditButton'),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.asset(
                  'assets/svgs/diamond.svg',
                  width: 26,
                  height: 26,
                  // colorFilter: const ColorFilter.mode(
                  //   Colors.white,
                  //   BlendMode.srcIn,
                  // ),
                ),
                // Image.asset(
                //   'assets/images/in_app_purchase/credit.png',
                //   width: 32,
                //   height: 32,
                //   fit: BoxFit.contain,
                //   excludeFromSemantics: true,
                // ),
                // const SizedBox(width: 6),
                // Text(
                //   _formatHomeCredits(balance),
                //   style: const TextStyle(
                //     color: Colors.white,
                //     fontSize: 14,
                //     fontWeight: FontWeight.w700,
                //   ),
                // ),
              ],
            ),
          ),
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
    return Semantics(
      label: 'Liora',
      child: SizedBox(
        key: const Key('homeBrand'),
        width: 84,
        height: 33,
        child: Image.asset(
          'assets/images/home/liora_header_title.png',
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          excludeFromSemantics: true,
        ),
      ),
    );
  }
}

const _bannerVideos = [
  'assets/videos/home_banner/slide_1.mp4',
  'assets/videos/home_banner/slide_2.mp4',
  'assets/videos/home_banner/slide_3.mp4',
];

const _bannerPosters = [
  'assets/images/home/home_banner_poster.jpg',
  'assets/images/home/home_banner_poster_2.jpg',
  'assets/images/home/home_banner_poster_3.jpg',
];

class _HeroBanner extends StatefulWidget {
  const _HeroBanner({required this.isVisible});

  final bool isVisible;

  @override
  State<_HeroBanner> createState() => _HeroBannerState();
}

class _HeroBannerState extends State<_HeroBanner> with WidgetsBindingObserver {
  VideoPlayerController? _video;
  Timer? _retryTimer;
  int _index = 0;
  int _loadFailures = 0;
  bool _ready = false;
  bool _advancing = false;
  bool _appActive = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _appActive = _canPlayForLifecycle(WidgetsBinding.instance.lifecycleState);
    _loadVideo();
  }

  static bool _canPlayForLifecycle(AppLifecycleState? state) => switch (state) {
    AppLifecycleState.paused ||
    AppLifecycleState.hidden ||
    AppLifecycleState.detached => false,
    _ => true,
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncPlayback();
  }

  @override
  void didUpdateWidget(covariant _HeroBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isVisible != widget.isVisible) _syncPlayback();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appActive = _canPlayForLifecycle(state);
    _syncPlayback();
  }

  Future<void> _loadVideo() async {
    final controller = VideoPlayerController.asset(_bannerVideos[_index]);
    _video = controller;
    controller.addListener(_onVideoValue);
    try {
      await controller.initialize();
      await controller.setLooping(false);
      await controller.setVolume(0);
      if (!mounted || _video != controller) return;
      _loadFailures = 0;
      _retryTimer?.cancel();
      _retryTimer = null;
      setState(() => _ready = true);
      await _syncPlayback();
    } catch (error) {
      if (_video != controller) return;
      controller.removeListener(_onVideoValue);
      _video = null;
      try {
        await controller.dispose();
      } catch (_) {
        // The poster is still available if native player cleanup fails.
      }
      debugPrint(
        'Home banner video could not load ${_bannerVideos[_index]}: $error',
      );
      if (mounted && _loadFailures < 2) {
        _loadFailures += 1;
        _retryTimer = Timer(Duration(seconds: _loadFailures), () {
          if (mounted && _video == null) _loadVideo();
        });
      }
    }
  }

  Future<void> _syncPlayback() async {
    final controller = _video;
    if (!_ready || controller == null) return;
    final shouldPlay =
        widget.isVisible && TickerMode.valuesOf(context).enabled && _appActive;
    try {
      if (!shouldPlay) {
        if (controller.value.isPlaying) await controller.pause();
        return;
      }
      if (controller.value.isPlaying) return;
      // The texture needs one frame to attach after initialization or a tab switch.
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted ||
          _video != controller ||
          !widget.isVisible ||
          !TickerMode.valuesOf(context).enabled ||
          !_appActive) {
        return;
      }
      await controller.play();
    } catch (_) {
      // A lifecycle or clip change may dispose the player during a platform call.
    }
  }

  void _onVideoValue() {
    final value = _video?.value;
    if (value == null || !mounted) return;
    if (value.isCompleted && !_advancing) {
      _advancing = true;
      scheduleMicrotask(_advanceVideo);
      return;
    }
  }

  Future<void> _advanceVideo() async {
    final previous = _video;
    setState(() {
      _index = (_index + 1) % _bannerVideos.length;
      _ready = false;
      _video = null;
    });
    if (previous != null) {
      previous.removeListener(_onVideoValue);
      try {
        await previous.dispose();
      } catch (_) {
        // A failed platform cleanup should not stop the remaining clips.
      }
    }
    if (!mounted) return;
    _advancing = false;
    _loadVideo();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _retryTimer?.cancel();
    _video?.removeListener(_onVideoValue);
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQuery.paddingOf(context).top;
    final height = MediaQuery.sizeOf(context).width * .60 + safeTop;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
      child: SizedBox(
        key: const Key('homeVideoBanner'),
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(_bannerPosters[_index], fit: BoxFit.cover),
            if (_ready && _video != null)
              FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _video!.value.size.width,
                  height: _video!.value.size.height,
                  child: VideoPlayer(_video!),
                ),
              ),
            const ColoredBox(color: Color(0x330E0B18)),
            Positioned(
              right: 18,
              bottom: 20,
              child: Semantics(
                button: true,
                label: 'Create Video Now',
                child: Material(
                  key: const Key('homeBannerCreateButton'),
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ImageToVideoScreen(),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: ShaderMask(
                        blendMode: BlendMode.srcIn,
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [
                            Color(0xFFC444A5),
                            Color(0xFF7A43CB),
                            Color(0xFF2668CC),
                          ],
                        ).createShader(bounds),
                        child: const Text(
                          'Create Video Now',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 12,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _bannerVideos.length,
                  (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: index == _index ? Colors.white : Colors.white54,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
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
            asset: 'assets/images/home/image_to_video.png',
            backgroundAsset: 'assets/images/home/image_to_video_bg.png',
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: _FeatureCard(
            title: 'Text to Video',
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
    required this.asset,
    required this.backgroundAsset,
  });

  final String title;
  final String asset;
  final String backgroundAsset;

  @override
  Widget build(BuildContext context) {
    final isTextToVideo = title == 'Text to Video';
    final textScale = MediaQuery.textScalerOf(context).scale(16) / 16;
    return LayoutBuilder(
      builder: (context, constraints) {
        final displayTitle = textScale > 1.35
            ? title.replaceAll(' ', '\n')
            : constraints.maxWidth < 155
            ? title.replaceFirst(' to ', ' to\n')
            : title;
        final cardHeight = math
            .max(
              (constraints.maxWidth / 1.25).clamp(144.0, 160.0),
              144 + math.max(0, textScale - 1) * 150,
            )
            .toDouble();
        return Semantics(
          button: true,
          label: title,
          child: GestureDetector(
            key: Key(
              isTextToVideo ? 'homeTextToVideoCard' : 'homeImageToVideoCard',
            ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => isTextToVideo
                    ? const TextToVideoScreen()
                    : const ImageToVideoScreen(),
              ),
            ),
            child: SizedBox(
              height: cardHeight,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(19),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColorFiltered(
                      colorFilter: const ColorFilter.matrix([
                        1.5,
                        0,
                        0,
                        0,
                        18,
                        0,
                        1.5,
                        0,
                        0,
                        18,
                        0,
                        0,
                        1.5,
                        0,
                        18,
                        0,
                        0,
                        0,
                        1,
                        0,
                      ]),
                      // These assets include a dark frame; crop it so the
                      // artwork reaches the rounded edges of the card.
                      child: Transform.scale(
                        scale: 1.15,
                        child: Image.asset(backgroundAsset, fit: BoxFit.cover),
                      ),
                    ),
                    Positioned(
                      left: 13,
                      top: 13,
                      width: 64,
                      height: 64,
                      child: Image.asset(asset, fit: BoxFit.contain),
                    ),
                    Positioned(
                      top: 14,
                      right: 13,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xCC171B2B),
                          border: Border.all(color: const Color(0xFF666B82)),
                        ),
                        child: const Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 19,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 13,
                      right: 13,
                      bottom: 14,
                      child: Text(
                        displayTitle,
                        softWrap: true,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          height: 1.12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
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
    final thumbnailWidth = (screenWidth * .26).clamp(108.0, 172.0);
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
                  fontSize: 20,
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
                foregroundColor: AppColors.textSecondary,
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
              color: AppColors.textSecondary,
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
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, index) => SizedBox(
              width: thumbnailWidth,
              child: _VideoThumbnail(
                post: category.posts[index],
                index: index,
                decodeWidth: decodeWidth,
                fit: BoxFit.cover,
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
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
    return Icon(icon, size: 25, color: AppColors.primary);
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
              child: Stack(
                fit: StackFit.expand,
                children: [
                  RepaintBoundary(
                    child: _PreviewBody(
                      post: post,
                      index: index,
                      decodeWidth: decodeWidth,
                      fit: fit,
                    ),
                  ),
                  const Positioned(
                    left: 10,
                    bottom: 10,
                    child: CircleAvatar(
                      radius: 13,
                      backgroundColor: Color(0xCC211B2A),
                      child: Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 19,
                      ),
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
            color: Color(0xFFD181A9),
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
              foregroundColor: const Color(0xFFD181A9),
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
            Icon(Icons.bolt_rounded, color: Color(0xFFAF88D1), size: 24),
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
          colors: [Color(0xFF40364C), Color(0xFF342D3E)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF40363C)),
      ),
      child: Column(
        children: [
          ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFFD17FB2), Color(0xFFD19C87)],
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

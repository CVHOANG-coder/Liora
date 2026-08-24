import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../data/video_categories.dart';
import '../../providers/profile_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/trial_offer_dialog.dart';
import '../image_to_video/image_to_video_screen.dart';
import '../in_app_purchase/all_plans_screen.dart';
import '../text_to_video/text_to_video_screen.dart';
import '../video_detail/video_detail_screen.dart';

const _assetRoot = 'assets/images/templates';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final isSubscribed = ref.watch(
      profileProvider.select((profile) => profile?.isSubscribed ?? false),
    );
    final categories = ref.watch(themeCategoriesProvider);

    return ColoredBox(
      color: Colors.black,
      child: SafeArea(
        bottom: false,
        child: CustomScrollView(
          key: const PageStorageKey('homeScroll'),
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 118),
              sliver: SliverList.list(
                children: [
                  _HomeHeader(
                    isSubscribed: isSubscribed,
                    onProPressed: () {
                      if (!isSubscribed) {
                        TrialOfferDialog.show(context);
                        return;
                      }
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const AllPlans(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 30),
                  _Headline(),
                  const SizedBox(height: 24),
                  _FeatureCards(),
                  const SizedBox(height: 26),
                  _VideoCategories(
                    categories: categories,
                    onRetry: () => ref.invalidate(themeCategoriesProvider),
                  ),
                  // Quick Create is temporarily hidden.
                  // const SizedBox(height: 26),
                  // _QuickCreate(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.isSubscribed, required this.onProPressed});

  final bool isSubscribed;
  final VoidCallback onProPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: Semantics(
              button: true,
              enabled: true,
              label: isSubscribed ? 'Open Pro plan' : 'View Pro offer',
              child: Material(
                color: const Color(0xFF150A13),
                borderRadius: BorderRadius.circular(20),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  key: const Key('homeProButton'),
                  onTap: onProPressed,
                  child: Container(
                    height: 34,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFFF42B5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SvgPicture.asset(
                          'assets/svgs/pro.svg',
                          width: 18,
                          height: 18,
                          fit: BoxFit.contain,
                          colorFilter: const ColorFilter.mode(
                            Color(0xFFFF48C3),
                            BlendMode.srcIn,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Pro',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
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
        ),
        const _Brand(),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.notifications_none_rounded, size: 28),
                  Positioned(
                    right: 1,
                    top: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF4149),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Container(
                width: 38,
                height: 38,
                padding: const EdgeInsets.all(1.5),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFFFF48C3), Color(0xFFFF6A3D)],
                  ),
                ),
                child: const CircleAvatar(
                  backgroundColor: Color(0xFF18131A),
                  backgroundImage: AssetImage('$_assetRoot/moody-light.jpg'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/images/home/N_logo.png',
          width: 32,
          height: 32,
          fit: BoxFit.contain,
        ),
        const SizedBox(width: 5),
        const Text(
          'Nostalia',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
          ),
        ),
      ],
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Colors.white,
              Colors.white,
              Color(0xFFFF46B8),
              Color(0xFFFF603E),
            ],
            stops: [0, 0.57, 0.76, 1],
          ).createShader(bounds),
          child: const Text(
            'Create AI short films',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 29,
              height: 1.12,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Cinematic, personalized, made to go viral.',
          style: TextStyle(color: Color(0xFFBDB8C1), fontSize: 16),
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
            title: 'Text to Video',
            subtitle: 'Turn ideas into\nAI short videos',
            asset: 'assets/images/home/text_to_video.png',
            glow: Color(0xFFFF20AF),
            background: [Color(0xFF400027), Color(0xFF100009)],
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: _FeatureCard(
            title: 'Image to Video',
            subtitle: 'Animate photos\nand characters',
            asset: 'assets/images/home/image_to_video.png',
            glow: Color(0xFFFF5B39),
            background: [Color(0xFF48110F), Color(0xFF120504)],
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
    required this.glow,
    required this.background,
  });

  final String title;
  final String subtitle;
  final String asset;
  final Color glow;
  final List<Color> background;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      height: 158,
      padding: const EdgeInsets.fromLTRB(13, 14, 13, 13),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: background,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: glow, width: 1.15),
        boxShadow: [
          BoxShadow(
            color: glow.withValues(alpha: 0.32),
            blurRadius: 18,
            spreadRadius: -4,
          ),
          BoxShadow(
            color: glow.withValues(alpha: 0.16),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Center(
              child: Image.asset(
                asset,
                width: 165,
                height: 120,
                fit: BoxFit.contain,
              ),
            ),
          ),
          Row(
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
                    const SizedBox(height: 5),
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
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: glow.withValues(alpha: 0.2),
                  border: Border.all(color: glow),
                ),
                child: const Icon(Icons.arrow_forward_rounded, size: 21),
              ),
            ],
          ),
        ],
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
      loading: () => const _CategoriesLoading(),
      error: (error, _) => _CategoriesError(error: error, onRetry: onRetry),
      data: (items) {
        if (items.isEmpty) return const _CategoriesEmpty();
        return Column(
          children: [
            for (var index = 0; index < items.length; index++) ...[
              _VideoCategorySection(category: items[index]),
              if (index != items.length - 1) const SizedBox(height: 24),
            ],
          ],
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
    final thumbnailWidth = (screenWidth - 48) / 3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.play_circle_fill_rounded,
              color: Color(0xFFFF4DA6),
              size: 21,
            ),
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
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF969198),
              size: 20,
            ),
          ],
        ),
        const SizedBox(height: 11),
        SizedBox(
          height: thumbnailWidth * 1.34,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: category.posts.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, index) => SizedBox(
              width: thumbnailWidth,
              child: _VideoThumbnail(post: category.posts[index]),
            ),
          ),
        ),
      ],
    );
  }
}

class _VideoThumbnail extends StatelessWidget {
  const _VideoThumbnail({required this.post});

  final VideoPost post;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Watch ${post.description}',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(15),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: Key('videoThumbnail_${post.id}'),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => VideoDetailScreen(post: post),
            ),
          ),
          child: Hero(
            tag: 'video_${post.id}',
            child: Image.network(
              post.thumbnailUrl!,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) =>
                  progress == null ? child : const _ThumbnailSkeleton(),
              errorBuilder: (_, _, _) => const _ThumbnailError(),
            ),
          ),
        ),
      ),
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
    final thumbnailWidth = (screenWidth - 48) / 3;

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
          height: thumbnailWidth * 1.34,
          child: Row(
            children: [
              for (var index = 0; index < 3; index++) ...[
                SizedBox(
                  width: thumbnailWidth,
                  child: const _ThumbnailSkeleton(),
                ),
                if (index != 2) const SizedBox(width: 8),
              ],
            ],
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

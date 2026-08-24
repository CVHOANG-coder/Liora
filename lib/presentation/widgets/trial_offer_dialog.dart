import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/package_provider.dart';
import '../providers/profile_provider.dart';
import '../screens/in_app_purchase/all_plans_screen.dart';

class TrialOfferDialog extends ConsumerWidget {
  const TrialOfferDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black,
      useSafeArea: false,
      builder: (_) => const TrialOfferDialog(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final weeklyPackage = ref
        .watch(packageCatalogProvider)
        ?.forPlatform(profile?.platform)
        ?.weeklySubscription;
    final weeklyPrice = weeklyPackage == null
        ? 'VND 210,000'
        : '\$${weeklyPackage.price.toStringAsFixed(2)}';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: Material(
        color: const Color(0xFF050208),
        child: Stack(
          children: [
            const Positioned.fill(child: _ScreenBackground()),
            SafeArea(
              bottom: false,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      9,
                      20,
                      15 + MediaQuery.paddingOf(context).bottom,
                    ),
                    sliver: SliverList.list(
                      children: [
                        _Hero(onClose: () => Navigator.maybePop(context)),
                        const SizedBox(height: 4),
                        const _Title(),
                        const SizedBox(height: 9),
                        const Text(
                          'Try premium video tools free for 3 days,\n'
                          'then continue only if you love it.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFFBBB4C0),
                            fontSize: 14.5,
                            height: 1.42,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 15),
                        const _TrialTimeline(),
                        const SizedBox(height: 15),
                        _PriceOffer(price: weeklyPrice),
                        const SizedBox(height: 13),
                        _PrimaryButton(
                          key: const Key('trialClaimButton'),
                          onTap: () => _openAllPlans(context),
                        ),
                        const SizedBox(height: 11),
                        _ViewPlansButton(onTap: () => _openAllPlans(context)),
                        const SizedBox(height: 15),
                        const _LegalFooter(),
                      ],
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

  void _openAllPlans(BuildContext context) {
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.push(MaterialPageRoute(builder: (_) => const AllPlans()));
  }
}

class _ScreenBackground extends StatelessWidget {
  const _ScreenBackground();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0.1, -0.4),
          radius: 1.08,
          colors: [Color(0x441A0624), Color(0xFF050208)],
          stops: [0, 0.95],
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 132,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            top: -4,
            bottom: -1,
            left: 65,
            right: 33,
            child: Image.asset(
              'assets/images/in_app_purchase/free_trailer_banner.png',
              fit: BoxFit.contain,
            ),
          ),
          Align(
            alignment: Alignment.topLeft,
            child: _CloseButton(onTap: onClose),
          ),
        ],
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('trialLaterButton'),
      width: 41,
      height: 41,
      padding: const EdgeInsets.all(1.2),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF20B4), Color(0xFFFF734C)],
        ),
        boxShadow: [BoxShadow(color: Color(0x88FF1DAB), blurRadius: 13)],
      ),
      child: Material(
        color: const Color(0xFF0B0710),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          'How your',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 31,
            height: 1,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.7,
          ),
        ),
        const SizedBox(height: 3),
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFFFF22BF), Color(0xFFFF7C45)],
          ).createShader(bounds),
          child: const Text(
            'free trial works',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 31,
              height: 1,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.75,
            ),
          ),
        ),
      ],
    );
  }
}

class _TrialTimeline extends StatelessWidget {
  const _TrialTimeline();

  static const _steps = [
    _StepData(
      number: 1,
      asset: 'assets/images/in_app_purchase/today_free_trailer.png',
      title: 'Today',
      description: 'Unlock premium video tools\nand start creating instantly.',
    ),
    _StepData(
      number: 2,
      asset: 'assets/images/in_app_purchase/day2_free_trailer.png',
      title: 'In 2 days',
      description: "We’ll remind you before\nyour free trial ends.",
    ),
    _StepData(
      number: 3,
      asset: 'assets/images/in_app_purchase/day3_free_trailer.png',
      title: 'In 3 days',
      description:
          'Your Pro subscription starts\nunless cancelled before then.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: 26.5,
          top: 42,
          bottom: 42,
          width: 2,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFF1CB9), Color(0xFFFFA22E)],
              ),
              boxShadow: const [
                BoxShadow(color: Color(0xAAFF27AC), blurRadius: 8),
              ],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Column(
          children: [
            for (var index = 0; index < _steps.length; index++) ...[
              _TimelineStep(data: _steps[index]),
              if (index != _steps.length - 1) const SizedBox(height: 9),
            ],
          ],
        ),
      ],
    );
  }
}

class _StepData {
  const _StepData({
    required this.number,
    required this.asset,
    required this.title,
    required this.description,
  });

  final int number;
  final String asset;
  final String title;
  final String description;
}

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({required this.data});

  final _StepData data;

  @override
  Widget build(BuildContext context) {
    final last = data.number == 3;
    return SizedBox(
      height: 82,
      child: Row(
        children: [
          SizedBox(
            width: 55,
            child: Center(
              child: Container(
                width: 35,
                height: 35,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF0A0710),
                  border: Border.all(
                    color: last
                        ? const Color(0xFFFF912D)
                        : const Color(0xFFFF31BB),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: last
                          ? const Color(0x99FF792E)
                          : const Color(0x99FF21B4),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    '${data.number}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13),
              decoration: BoxDecoration(
                color: const Color(0xC7110817),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFB32183)),
              ),
              child: Row(
                children: [
                  Image.asset(data.asset, width: 61, height: 61),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            height: 1,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          data.description,
                          maxLines: 2,
                          style: const TextStyle(
                            color: Color(0xFFB7AFBA),
                            fontSize: 12.5,
                            height: 1.32,
                          ),
                        ),
                      ],
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

class _PriceOffer extends StatelessWidget {
  const _PriceOffer({required this.price});

  final String price;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 109,
      padding: const EdgeInsets.all(1.1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(17),
        gradient: const LinearGradient(
          colors: [Color(0xFFFF21BA), Color(0xFFFF8143)],
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xEE100817),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 105,
              child: Image.asset(
                'assets/images/in_app_purchase/discount_free_trailer.png',
                fit: BoxFit.contain,
              ),
            ),
            Container(
              width: 1,
              height: 76,
              margin: const EdgeInsets.symmetric(horizontal: 13),
              color: const Color(0xFF762459),
            ),
            Expanded(child: _PriceCopy(price: price)),
          ],
        ),
      ),
    );
  }
}

class _PriceCopy extends StatelessWidget {
  const _PriceCopy({required this.price});

  final String price;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Free trial for 3 days',
          style: TextStyle(
            color: Color(0xFFFF50B7),
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: RichText(
            maxLines: 1,
            text: TextSpan(
              children: [
                TextSpan(
                  text: price,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 31,
                    height: 1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const TextSpan(
                  text: '/week',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0x75220C20),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: const Color(0xFF65214D)),
          ),
          child: const FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.local_offer_rounded,
                  color: Color(0xFFFF9A26),
                  size: 14,
                ),
                SizedBox(width: 7),
                Text(
                  '50% OFF for a limited time',
                  maxLines: 1,
                  style: TextStyle(
                    color: Color(0xFFFF8A39),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 55,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFFFF14AC), Color(0xFFFF535D), Color(0xFFFFA43A)],
        ),
        boxShadow: const [BoxShadow(color: Color(0x77FF1AA7), blurRadius: 14)],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/images/in_app_purchase/coin3.png',
                    width: 36,
                    height: 36,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Start my 3-day free trial',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17.5,
                      fontWeight: FontWeight.w700,
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

class _ViewPlansButton extends StatelessWidget {
  const _ViewPlansButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('viewAllPlansButton'),
      height: 43,
      padding: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFFFF21BC), Color(0xFFFF6C63)],
        ),
      ),
      child: Material(
        color: const Color(0xFF09050E),
        borderRadius: BorderRadius.circular(23),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: const Center(
            child: Text(
              'View all plans',
              style: TextStyle(
                color: Color(0xFFFF44B5),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LegalFooter extends StatelessWidget {
  const _LegalFooter();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      color: Color(0xFFAFA8B3),
      fontSize: 12,
      fontWeight: FontWeight.w400,
    );

    return const FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Privacy', style: style),
          _FooterDot(),
          Text('Restore Purchase', style: style),
          _FooterDot(),
          Text('Terms of Service', style: style),
        ],
      ),
    );
  }
}

class _FooterDot extends StatelessWidget {
  const _FooterDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 4,
      height: 4,
      margin: const EdgeInsets.symmetric(horizontal: 11),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFFF31AF),
      ),
    );
  }
}

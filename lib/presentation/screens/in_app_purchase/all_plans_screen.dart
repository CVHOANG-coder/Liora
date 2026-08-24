import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../../core/network/api_exception.dart';
import '../../../data/models/package_catalog.dart';
import '../../../data/models/user_profile.dart';
import '../../providers/package_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/purchase_provider.dart';
import '../../widgets/generation_failure_dialog.dart';
import '../support/app_web_view_screen.dart';
import '../support/support_contact_screen.dart';
import 'in_app_purchase_screen.dart';

enum ProPlanStatus { none, weekly, yearly }

ProPlanStatus resolveProPlanStatus(UserProfile? profile) {
  if (profile == null || !profile.isSubscribed) return ProPlanStatus.none;

  final startedAt = profile.subscriptionTime;
  final endsAt = profile.subscriptionEndTime;
  if (startedAt == null || endsAt == null || !endsAt.isAfter(startedAt)) {
    return ProPlanStatus.weekly;
  }

  final subscriptionDays = endsAt.difference(startedAt).inHours / 24;
  return subscriptionDays >= 300 ? ProPlanStatus.yearly : ProPlanStatus.weekly;
}

String _formatSubscriptionEnd(DateTime? value) {
  if (value == null) return '--/--/----';
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  return '$day/$month/${value.year}';
}

class _PlanPrices {
  const _PlanPrices({
    required this.weekly,
    required this.yearly,
    required this.savingsPercent,
    required this.weeklySavings,
  });

  factory _PlanPrices.fromPackages(
    PlatformPackages? packages,
    Map<String, ProductDetails> storeProducts,
  ) {
    final weeklyPackage = packages?.weeklySubscription;
    final yearlyPackage = packages?.yearlySubscription;
    if (weeklyPackage == null || yearlyPackage == null) {
      return const _PlanPrices(
        weekly: 'VND 210,000/week',
        yearly: 'VND 25,000/week',
        savingsPercent: 88,
        weeklySavings: 'VND 185,000',
      );
    }

    final yearlyPerWeek = yearlyPackage.price / 52;
    final savings = (weeklyPackage.price - yearlyPerWeek).clamp(
      0,
      weeklyPackage.price,
    );
    final savingsPercent = weeklyPackage.price <= 0
        ? 0
        : ((savings / weeklyPackage.price) * 100).round();

    final storeWeekly = storeProducts[weeklyPackage.productId]?.price;
    final storeYearly = storeProducts[yearlyPackage.productId]?.price;
    return _PlanPrices(
      weekly:
          '${storeWeekly ?? '\$${weeklyPackage.price.toStringAsFixed(2)}'}/week',
      yearly:
          '${storeYearly ?? '\$${yearlyPackage.price.toStringAsFixed(2)}'}/year',
      savingsPercent: savingsPercent,
      weeklySavings: '\$${savings.toStringAsFixed(2)}',
    );
  }

  final String weekly;
  final String yearly;
  final int savingsPercent;
  final String weeklySavings;
}

class AllPlans extends ConsumerStatefulWidget {
  const AllPlans({super.key});

  @override
  ConsumerState<AllPlans> createState() => _AllPlansState();
}

class _AllPlansState extends ConsumerState<AllPlans> {
  int _selectedPlan = 0;
  bool _muted = true;
  AppPackage? _lastAttemptedPackage;
  bool _lastAttemptWasReplacement = false;

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final purchaseState = ref.watch(purchaseControllerProvider);
    ref.listen<PurchaseState>(purchaseControllerProvider, _onPurchaseState);
    final activePlan = resolveProPlanStatus(profile);
    final activeUntil = _formatSubscriptionEnd(profile?.subscriptionEndTime);
    final platformPackages = ref
        .watch(packageCatalogProvider)
        ?.forPlatform(profile?.platform);
    final prices = _PlanPrices.fromPackages(
      platformPackages,
      purchaseState.products,
    );

    return Scaffold(
      backgroundColor: const Color(0xFF030208),
      body: Stack(
        children: [
          const Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 455,
            child: _HeroBackground(),
          ),
          SafeArea(
            bottom: false,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    18,
                    12,
                    18,
                    18 + MediaQuery.paddingOf(context).bottom,
                  ),
                  sliver: SliverList.list(
                    children: _buildContent(
                      activePlan,
                      activeUntil,
                      prices,
                      purchaseState,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildContent(
    ProPlanStatus activePlan,
    String activeUntil,
    _PlanPrices prices,
    PurchaseState purchaseState,
  ) {
    return [
      _TopActions(
        muted: _muted,
        leadingIcon: activePlan == ProPlanStatus.yearly
            ? Icons.arrow_back_rounded
            : Icons.close_rounded,
        onClose: () => Navigator.maybePop(context),
        onSoundTap: () => setState(() => _muted = !_muted),
      ),
      const SizedBox(height: 147),
      const _NostaliaLogo(),
      const SizedBox(height: 10),
      if (activePlan == ProPlanStatus.none)
        ..._availablePlanContent(prices, purchaseState),
      if (activePlan == ProPlanStatus.weekly)
        ..._weeklyPlanContent(prices, purchaseState),
      if (activePlan == ProPlanStatus.yearly)
        ..._yearlyPlanContent(activeUntil, purchaseState),
    ];
  }

  List<Widget> _availablePlanContent(
    _PlanPrices prices,
    PurchaseState purchaseState,
  ) {
    return [
      const Text(
        'Ready to go PRO?',
        style: TextStyle(
          color: Colors.white,
          fontSize: 37,
          height: 1,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.1,
        ),
      ),
      const SizedBox(height: 9),
      const Text(
        'Create unlimited AI videos. Cancel anytime.',
        style: TextStyle(
          color: Color(0xFFD4D0D5),
          fontSize: 16,
          height: 1.25,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
      ),
      const SizedBox(height: 7),
      _DescriptionRow(onBuyCredits: _openBuyCredits),
      const SizedBox(height: 16),
      const _CreatorBanner(),
      const SizedBox(height: 15),
      _PlanCard(
        title: 'Yearly Pro',
        price: prices.yearly,
        caption: 'Billed annually',
        selected: _selectedPlan == 0,
        popular: true,
        onTap: () => setState(() => _selectedPlan = 0),
      ),
      const SizedBox(height: 13),
      _PlanCard(
        title: 'Weekly Pro',
        price: prices.weekly,
        selected: _selectedPlan == 1,
        onTap: () => setState(() => _selectedPlan = 1),
      ),
      const SizedBox(height: 21),
      _SubscribeButton(
        busy: purchaseState.isBusy,
        onTap: purchaseState.isBusy ? null : _subscribe,
      ),
      const SizedBox(height: 14),
      _LegalFooter(onRestore: purchaseState.isBusy ? null : _restore),
    ];
  }

  List<Widget> _weeklyPlanContent(
    _PlanPrices prices,
    PurchaseState purchaseState,
  ) {
    return [
      _WeeklyIntro(onBuyCredits: _openBuyCredits),
      const SizedBox(height: 15),
      const _WeeklyMemberBanner(),
      const SizedBox(height: 14),
      _OwnedPlanCard(
        title: 'Weekly Pro',
        price: prices.weekly,
        caption: 'Renews weekly',
        label: 'CURRENT PLAN',
        selected: true,
      ),
      const SizedBox(height: 13),
      _OwnedPlanCard(
        title: 'Yearly Pro',
        price: prices.yearly,
        caption: 'Billed annually',
        label: 'SAVE MORE',
        selected: false,
        bestValue: true,
      ),
      const SizedBox(height: 12),
      _SavingsBanner(prices: prices),
      const SizedBox(height: 20),
      _WideGradientButton(
        label: purchaseState.isBusy ? 'Processing...' : 'Upgrade to Yearly',
        busy: purchaseState.isBusy,
        onTap: purchaseState.isBusy ? null : _upgradeToYearly,
      ),
      const SizedBox(height: 11),
      _KeepPlanButton(onTap: () => Navigator.maybePop(context)),
      const SizedBox(height: 12),
      _LegalFooter(onRestore: purchaseState.isBusy ? null : _restore),
    ];
  }

  List<Widget> _yearlyPlanContent(
    String activeUntil,
    PurchaseState purchaseState,
  ) {
    return [
      _YearlyIntro(activeUntil: activeUntil),
      const SizedBox(height: 13),
      _BalanceCard(onBuyCredits: _openBuyCredits),
      const SizedBox(height: 13),
      const _GiftProCard(),
      const SizedBox(height: 20),
      _WideGradientButton(label: 'Explore PRO Tools', onTap: _exploreProTools),
      const SizedBox(height: 15),
      _LegalFooter(onRestore: purchaseState.isBusy ? null : _restore),
    ];
  }

  void _openBuyCredits() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const BuyCredits()));
  }

  void _subscribe() {
    final profile = ref.read(profileProvider);
    final packages = ref
        .read(packageCatalogProvider)
        ?.forPlatform(profile?.platform);
    final package = _selectedPlan == 0
        ? packages?.yearlySubscription
        : packages?.weeklySubscription;
    _buySubscription(package);
  }

  void _upgradeToYearly() {
    final profile = ref.read(profileProvider);
    final package = ref
        .read(packageCatalogProvider)
        ?.forPlatform(profile?.platform)
        ?.yearlySubscription;
    _buySubscription(package, replaceExisting: true);
  }

  void _buySubscription(AppPackage? package, {bool replaceExisting = false}) {
    if (package == null || package.productId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Subscription plans are unavailable.')),
      );
      return;
    }
    _lastAttemptedPackage = package;
    _lastAttemptWasReplacement = replaceExisting;
    ref
        .read(purchaseControllerProvider.notifier)
        .buy(
          productId: package.productId,
          consumable: false,
          replaceExistingSubscription: replaceExisting,
        );
  }

  void _restore() {
    ref.read(purchaseControllerProvider.notifier).restore();
  }

  void _onPurchaseState(PurchaseState? previous, PurchaseState next) async {
    final shouldNotify = switch (next.status) {
      PurchaseFlowStatus.success ||
      PurchaseFlowStatus.error ||
      PurchaseFlowStatus.canceled => true,
      PurchaseFlowStatus.ready =>
        previous?.status == PurchaseFlowStatus.restoring,
      _ => false,
    };
    if (!shouldNotify || next.message == null || !mounted) return;
    if (next.status == PurchaseFlowStatus.error) {
      final error = ApiException(
        message: next.message!,
        errorCode: next.errorCode,
      );
      final action = await GenerationFailureDialog.showForPurchaseError(
        context,
        error: error,
        fallbackMessage:
            'We could not complete your subscription purchase. Please try again.',
      );
      if (!mounted) return;
      switch (action) {
        case GenerationFailureAction.retry:
        case GenerationFailureAction.renewSubscription:
          _buySubscription(
            _lastAttemptedPackage,
            replaceExisting: _lastAttemptWasReplacement,
          );
        case GenerationFailureAction.buyCredits:
          await Navigator.of(
            context,
          ).push(MaterialPageRoute<void>(builder: (_) => const BuyCredits()));
        case GenerationFailureAction.contactSupport:
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => SupportContactScreen(
                errorCode: next.errorCode,
                errorMessage: next.message,
              ),
            ),
          );
        case GenerationFailureAction.chooseImage:
        case GenerationFailureAction.editInput:
        case GenerationFailureAction.chooseTheme:
        case GenerationFailureAction.close:
        case null:
          break;
      }
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(next.message!)));
  }

  void _exploreProTools() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Premium creation tools are ready to use')),
    );
  }
}

class _HeroBackground extends StatelessWidget {
  const _HeroBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/images/in_app_purchase/all_plans_hero.png',
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x00030208),
                Color(0x19030208),
                Color(0xD9030208),
                Color(0xFF030208),
              ],
              stops: [0, 0.52, 0.82, 1],
            ),
          ),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color(0x28030208), Color(0x00030208)],
            ),
          ),
        ),
      ],
    );
  }
}

class _TopActions extends StatelessWidget {
  const _TopActions({
    required this.muted,
    required this.leadingIcon,
    required this.onClose,
    required this.onSoundTap,
  });

  final bool muted;
  final IconData leadingIcon;
  final VoidCallback onClose;
  final VoidCallback onSoundTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _RoundActionButton(
          semanticsLabel: 'Close',
          icon: leadingIcon,
          onTap: onClose,
        ),
        _RoundActionButton(
          semanticsLabel: muted ? 'Turn sound on' : 'Mute sound',
          icon: muted ? Icons.volume_off_outlined : Icons.volume_up_outlined,
          onTap: onSoundTap,
        ),
      ],
    );
  }
}

class _RoundActionButton extends StatelessWidget {
  const _RoundActionButton({
    required this.semanticsLabel,
    required this.icon,
    required this.onTap,
  });

  final String semanticsLabel;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 45,
      height: 45,
      padding: const EdgeInsets.all(1),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF2BAB), Color(0xFF6A275B)],
        ),
        boxShadow: [BoxShadow(color: Color(0x78FF1EA7), blurRadius: 13)],
      ),
      child: Material(
        color: const Color(0xC90A0710),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Semantics(
            button: true,
            label: semanticsLabel,
            child: Icon(icon, color: Colors.white, size: 27),
          ),
        ),
      ),
    );
  }
}

class _NostaliaLogo extends StatelessWidget {
  const _NostaliaLogo();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFF9537), Color(0xFFFF13C1)],
          ).createShader(bounds),
          child: const Icon(Icons.play_arrow_rounded, size: 31),
        ),
        const SizedBox(width: 2),
        const Text(
          'Nostalia ',
          style: TextStyle(
            color: Color(0xFFFF35BC),
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFFFF7548), Color(0xFFFFB22E)],
          ).createShader(bounds),
          child: const Text(
            'Pro',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _DescriptionRow extends StatelessWidget {
  const _DescriptionRow({required this.onBuyCredits});

  final VoidCallback onBuyCredits;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Expanded(
          child: Text(
            'Unlock Nostalia Pro for premium styles, faster generation, '
            'watermark-free export, and bonus crown coins or extra credits.',
            style: TextStyle(
              color: Color(0xFFCAC5CC),
              fontSize: 14,
              height: 1.42,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        const SizedBox(width: 8),
        _BuyCreditsButton(onTap: onBuyCredits),
      ],
    );
  }
}

class _BuyCreditsButton extends StatelessWidget {
  const _BuyCreditsButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 137,
      height: 43,
      padding: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          colors: [Color(0xFFFF4EA7), Color(0xFFFFA122)],
        ),
        boxShadow: const [BoxShadow(color: Color(0x88FF1E9A), blurRadius: 13)],
      ),
      child: Material(
        color: const Color(0xFFD71978),
        borderRadius: BorderRadius.circular(13),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/images/in_app_purchase/coin3.png',
                    width: 27,
                    height: 27,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Buy Credits',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 3),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white,
                    size: 21,
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

class _CreatorBanner extends StatelessWidget {
  const _CreatorBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 47,
      padding: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFFFF26B6), Color(0xFFFF8D31)],
        ),
        boxShadow: const [BoxShadow(color: Color(0x55FF1EA5), blurRadius: 11)],
      ),
      child: Container(
        padding: const EdgeInsets.only(left: 7, right: 13),
        decoration: BoxDecoration(
          color: const Color(0xF20A0610),
          borderRadius: BorderRadius.circular(23),
        ),
        child: Row(
          children: [
            Container(
              width: 39,
              height: 39,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF16091A),
                border: Border.all(color: const Color(0xFFFF2BB5)),
                boxShadow: const [
                  BoxShadow(color: Color(0x72FF1DAE), blurRadius: 9),
                ],
              ),
              child: const Icon(
                Icons.trending_up_rounded,
                color: Color(0xFFFF29C4),
                size: 28,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: RichText(
                  maxLines: 1,
                  text: const TextSpan(
                    style: TextStyle(
                      color: Color(0xFFD6D0D8),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w400,
                    ),
                    children: [
                      TextSpan(text: 'Over '),
                      TextSpan(
                        text: '12,541',
                        style: TextStyle(
                          color: Color(0xFFFF2BB2),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      TextSpan(text: ' creators joined the '),
                      TextSpan(
                        text: 'Yearly Pro',
                        style: TextStyle(
                          color: Color(0xFFFFB32E),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextSpan(text: ' plan today!'),
                    ],
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

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.price,
    required this.selected,
    required this.onTap,
    this.caption,
    this.popular = false,
  });

  final String title;
  final String price;
  final String? caption;
  final bool selected;
  final bool popular;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final height = selected ? 105.0 : 88.0;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: height,
          padding: EdgeInsets.all(selected ? 1.25 : 1),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            color: selected ? null : const Color(0xFF6B235D),
            gradient: selected
                ? const LinearGradient(
                    colors: [Color(0xFFFF23B3), Color(0xFFFF9A24)],
                  )
                : null,
            boxShadow: selected
                ? const [
                    BoxShadow(color: Color(0x77FF22A9), blurRadius: 15),
                    BoxShadow(
                      color: Color(0x55FF8B22),
                      blurRadius: 12,
                      offset: Offset(4, 0),
                    ),
                  ]
                : null,
          ),
          child: Material(
            color: const Color(0xEF08050D),
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: Row(
                  children: [
                    _PlanRadio(selected: selected),
                    const SizedBox(width: 14),
                    Expanded(
                      flex: 4,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          title,
                          maxLines: 1,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 21,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.35,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 5,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          ShaderMask(
                            blendMode: BlendMode.srcIn,
                            shaderCallback: (bounds) => LinearGradient(
                              colors: selected
                                  ? const [Color(0xFFFF20C1), Color(0xFFFF6944)]
                                  : const [Colors.white, Colors.white],
                            ).createShader(bounds),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Text(
                                price,
                                maxLines: 1,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.25,
                                ),
                              ),
                            ),
                          ),
                          if (caption != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              caption!,
                              style: const TextStyle(
                                color: Color(0xFFBDB6C0),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (popular)
          const Positioned(right: 0, top: -1, child: _PopularBadge()),
      ],
    );
  }
}

class _PlanRadio extends StatelessWidget {
  const _PlanRadio({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 31,
      height: 31,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? const Color(0xFF5B1737) : Colors.transparent,
        border: Border.all(
          color: const Color(0xFFFF27AE),
          width: selected ? 1.4 : 1,
        ),
        boxShadow: selected
            ? const [BoxShadow(color: Color(0xAAFF2B9F), blurRadius: 12)]
            : null,
      ),
      child: selected
          ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
          : null,
    );
  }
}

class _PopularBadge extends StatelessWidget {
  const _PopularBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 6),
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(16),
          bottomLeft: Radius.circular(17),
        ),
        gradient: LinearGradient(
          colors: [Color(0xFFFF1BBD), Color(0xFFFF9A22)],
        ),
      ),
      child: const Text(
        'MOST POPULAR',
        style: TextStyle(
          color: Colors.white,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.15,
        ),
      ),
    );
  }
}

class _SubscribeButton extends StatelessWidget {
  const _SubscribeButton({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 67,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFF12C6),
            Color(0xFFFF2C92),
            Color(0xFFFF712F),
            Color(0xFFFFB000),
          ],
        ),
        border: Border.all(color: const Color(0xFFFFB83F)),
        boxShadow: const [
          BoxShadow(color: Color(0x99FF1CA8), blurRadius: 18),
          BoxShadow(
            color: Color(0x66FF8A17),
            blurRadius: 14,
            offset: Offset(5, 0),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (busy) ...[
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Text(
                    busy ? 'Processing...' : 'Start My Subscription',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(width: 22),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 29,
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

class _WeeklyIntro extends StatelessWidget {
  const _WeeklyIntro({required this.onBuyCredits});

  final VoidCallback onBuyCredits;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "You're on PRO",
          style: TextStyle(
            color: Colors.white,
            fontSize: 37,
            height: 1,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.1,
          ),
        ),
        const SizedBox(height: 11),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Expanded(
              child: Text(
                'Current plan: Weekly Pro. Upgrade to Yearly and save more '
                'on your subscription.',
                style: TextStyle(
                  color: Color(0xFFC9C3CB),
                  fontSize: 14.5,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 8),
            _BuyCreditsButton(onTap: onBuyCredits),
          ],
        ),
      ],
    );
  }
}

class _WeeklyMemberBanner extends StatelessWidget {
  const _WeeklyMemberBanner();

  @override
  Widget build(BuildContext context) {
    return _OutlinedDarkCard(
      height: 48,
      radius: 24,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF16091A),
              border: Border.all(color: const Color(0xFFFF29B3)),
              boxShadow: const [
                BoxShadow(color: Color(0x77FF22AD), blurRadius: 10),
              ],
            ),
            child: const Icon(
              Icons.groups_rounded,
              color: Color(0xFFFF45B5),
              size: 27,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: RichText(
                maxLines: 1,
                text: const TextSpan(
                  style: TextStyle(color: Color(0xFFD2CCD5), fontSize: 13.5),
                  children: [
                    TextSpan(text: "You're among "),
                    TextSpan(
                      text: '12,541',
                      style: TextStyle(
                        color: Color(0xFFFF22B8),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    TextSpan(text: ' creators using '),
                    TextSpan(
                      text: 'Weekly Pro',
                      style: TextStyle(
                        color: Color(0xFFFFA825),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextSpan(text: '!'),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OwnedPlanCard extends StatelessWidget {
  const _OwnedPlanCard({
    required this.title,
    required this.price,
    required this.caption,
    required this.label,
    required this.selected,
    this.bestValue = false,
  });

  final String title;
  final String price;
  final String caption;
  final String label;
  final bool selected;
  final bool bestValue;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _OutlinedDarkCard(
          height: 91,
          radius: 17,
          strongGlow: true,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: Row(
              children: [
                _PlanRadio(selected: selected),
                const SizedBox(width: 14),
                Expanded(
                  flex: 4,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          title,
                          maxLines: 1,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 21,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: bestValue
                                ? const Color(0xFFFF8B22)
                                : const Color(0xFFFF2AAE),
                          ),
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            color: bestValue
                                ? const Color(0xFFFF8B3D)
                                : const Color(0xFFFF50B8),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 5,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      ShaderMask(
                        blendMode: BlendMode.srcIn,
                        shaderCallback: (bounds) => LinearGradient(
                          colors: bestValue
                              ? const [Color(0xFFFF20BE), Color(0xFFFF773A)]
                              : const [Colors.white, Colors.white],
                        ).createShader(bounds),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            price,
                            maxLines: 1,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        caption,
                        style: const TextStyle(
                          color: Color(0xFFBFB8C2),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (bestValue)
          const Positioned(
            right: 0,
            top: 0,
            child: _CornerBadge(label: 'BEST VALUE'),
          ),
      ],
    );
  }
}

class _SavingsBanner extends StatelessWidget {
  const _SavingsBanner({required this.prices});

  final _PlanPrices prices;

  @override
  Widget build(BuildContext context) {
    return _OutlinedDarkCard(
      height: 55,
      radius: 15,
      child: Row(
        children: [
          Container(
            width: 39,
            height: 39,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF18091A),
              border: Border.all(color: const Color(0xFFFF2AAB)),
            ),
            child: const Icon(
              Icons.local_offer_outlined,
              color: Color(0xFFFF35B7),
              size: 23,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(
                    color: Color(0xFFC7C0CA),
                    fontSize: 13,
                    height: 1.5,
                  ),
                  children: [
                    const TextSpan(text: 'Switch to Yearly Pro and '),
                    TextSpan(
                      text: 'save ${prices.savingsPercent}%\n',
                      style: const TextStyle(
                        color: Color(0xFFFFA423),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextSpan(
                      text:
                          "That’s ${prices.weeklySavings}/week less compared "
                          'to Weekly Pro.',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _YearlyIntro extends StatelessWidget {
  const _YearlyIntro({required this.activeUntil});

  final String activeUntil;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "You're PRO! 👑",
          style: TextStyle(
            color: Colors.white,
            fontSize: 37,
            height: 1,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.1,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Enjoy unlimited AI videos and all premium features.',
          style: TextStyle(
            color: Color(0xFFD4CFD6),
            fontSize: 14.5,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 190,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _ProBenefit(
                      icon: Icons.all_inclusive_rounded,
                      text: 'Unlimited AI video generation',
                    ),
                    _ProBenefit(
                      icon: Icons.bolt_rounded,
                      text: 'Faster generation & priority processing',
                    ),
                    _ProBenefit(
                      icon: Icons.water_drop_outlined,
                      text: 'Watermark-free export',
                    ),
                    _ProBenefit(
                      icon: Icons.workspace_premium_rounded,
                      text: 'Bonus crown coins every month',
                    ),
                    _ProBenefit(
                      icon: Icons.auto_awesome_rounded,
                      text: 'All premium styles & templates',
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 139,
                child: Column(
                  children: [
                    Expanded(
                      child: Image.asset(
                        'assets/images/in_app_purchase/yearly_pro.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Active until $activeUntil',
                      maxLines: 1,
                      style: const TextStyle(
                        color: Color(0xFFD3CDD5),
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProBenefit extends StatelessWidget {
  const _ProBenefit({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: const Color(0xFF260A25),
            border: Border.all(color: const Color(0xFF5D1452)),
          ),
          child: Icon(icon, color: const Color(0xFFFF56BA), size: 19),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            style: const TextStyle(
              color: Color(0xFFE3DEE5),
              fontSize: 11.5,
              height: 1.18,
            ),
          ),
        ),
      ],
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.onBuyCredits});

  final VoidCallback onBuyCredits;

  @override
  Widget build(BuildContext context) {
    return _OutlinedDarkCard(
      height: 82,
      radius: 17,
      child: Row(
        children: [
          Image.asset(
            'assets/images/in_app_purchase/balance_coin.png',
            width: 71,
            height: 65,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 9),
          const Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Balance',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '2,350',
                          style: TextStyle(
                            color: Color(0xFFFF5A69),
                            fontSize: 25,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextSpan(
                          text: ' credits',
                          style: TextStyle(
                            color: Color(0xFFCEC7D0),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          _BuyCreditsButton(onTap: onBuyCredits),
        ],
      ),
    );
  }
}

class _GiftProCard extends StatelessWidget {
  const _GiftProCard();

  @override
  Widget build(BuildContext context) {
    return _OutlinedDarkCard(
      height: 88,
      radius: 17,
      child: Row(
        children: [
          Image.asset(
            'assets/images/in_app_purchase/gift_vip.png',
            width: 72,
            height: 72,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Give PRO, Get More',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Share Nostalia Pro with your friends\nand get extra credits!',
                  maxLines: 2,
                  style: TextStyle(
                    color: Color(0xFFBDB6C0),
                    fontSize: 12.5,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: Color(0xFFFF33AF),
            size: 29,
          ),
        ],
      ),
    );
  }
}

class _OutlinedDarkCard extends StatelessWidget {
  const _OutlinedDarkCard({
    required this.height,
    required this.radius,
    required this.child,
    this.strongGlow = false,
  });

  final double height;
  final double radius;
  final Widget child;
  final bool strongGlow;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: const LinearGradient(
          colors: [Color(0xFFFF24B4), Color(0xFFFF713E)],
        ),
        boxShadow: strongGlow
            ? const [BoxShadow(color: Color(0x66FF20AA), blurRadius: 13)]
            : null,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11),
        decoration: BoxDecoration(
          color: const Color(0xF20B0710),
          borderRadius: BorderRadius.circular(radius - 1),
        ),
        child: child,
      ),
    );
  }
}

class _CornerBadge extends StatelessWidget {
  const _CornerBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 6),
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(16),
          bottomLeft: Radius.circular(16),
        ),
        gradient: LinearGradient(
          colors: [Color(0xFFFF1DBB), Color(0xFFFF9A22)],
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _WideGradientButton extends StatelessWidget {
  const _WideGradientButton({
    required this.label,
    required this.onTap,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 66,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(23),
        gradient: const LinearGradient(
          colors: [Color(0xFFFF10C3), Color(0xFFFF365F), Color(0xFFFFAF09)],
        ),
        boxShadow: const [BoxShadow(color: Color(0x88FF1CAB), blurRadius: 17)],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(23),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (busy) ...[
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 30),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 28,
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

class _KeepPlanButton extends StatelessWidget {
  const _KeepPlanButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton.icon(
        onPressed: onTap,
        iconAlignment: IconAlignment.end,
        icon: const Icon(Icons.chevron_right_rounded, size: 20),
        label: const Text('Keep Weekly Plan'),
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFFC9C2CB),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}

class _LegalFooter extends StatelessWidget {
  const _LegalFooter({required this.onRestore});

  final VoidCallback? onRestore;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      color: Color(0xFFDDD8E0),
      fontSize: 12.5,
      fontWeight: FontWeight.w400,
    );

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const _LegalWebLink(
            label: 'Privacy',
            page: AppWebPage.privacy,
            style: style,
          ),
          const _LegalDivider(),
          TextButton(
            onPressed: onRestore,
            style: TextButton.styleFrom(
              foregroundColor: style.color,
              textStyle: style,
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Restore Purchase'),
          ),
          const _LegalDivider(),
          const _LegalWebLink(
            label: 'Terms of Service',
            page: AppWebPage.terms,
            style: style,
          ),
        ],
      ),
    );
  }
}

class _LegalWebLink extends StatelessWidget {
  const _LegalWebLink({
    required this.label,
    required this.page,
    required this.style,
  });

  final String label;
  final AppWebPage page;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => AppWebViewScreen.open(context, page),
      style: TextButton.styleFrom(
        foregroundColor: style.color,
        textStyle: style,
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(label),
    );
  }
}

class _LegalDivider extends StatelessWidget {
  const _LegalDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 14,
      margin: const EdgeInsets.symmetric(horizontal: 9),
      color: const Color(0xFFFF28A7),
    );
  }
}

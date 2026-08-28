import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../../core/network/api_exception.dart';
import '../../../data/models/package_catalog.dart';
import '../../../data/models/user_profile.dart';
import '../../providers/package_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/purchase_provider.dart';
import '../../widgets/generation_failure_dialog.dart';
import '../../widgets/video_form_widgets.dart';
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
    final yearlyPackage = packages?.regularYearlySubscription;
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

    final storeWeekly = recurringSubscriptionPrice(
      storeProducts[weeklyPackage.productId],
    );
    final storeYearly = recurringSubscriptionPrice(
      storeProducts[yearlyPackage.productId],
    );
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
  const AllPlans({super.key, this.returnPurchaseResult = false});

  final bool returnPurchaseResult;

  @override
  ConsumerState<AllPlans> createState() => _AllPlansState();
}

class _AllPlansState extends ConsumerState<AllPlans> {
  int _selectedPlan = 0;
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
      backgroundColor: VideoFormStyle.background,
      body: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 12,
            height: MediaQuery.sizeOf(context).width * 1.15,
            child: const _HeroBackground(),
          ),
          SafeArea(
            bottom: false,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    activePlan == ProPlanStatus.none ? 24 : 18,
                    2,
                    activePlan == ProPlanStatus.none ? 24 : 18,
                    12 + MediaQuery.paddingOf(context).bottom,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _buildContent(
                        activePlan,
                        activeUntil,
                        prices,
                        purchaseState,
                        isVIP: profile?.isVIP == true,
                      ),
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
    PurchaseState purchaseState, {
    required bool isVIP,
  }) {
    return [
      _TopActions(
        leadingIcon: activePlan == ProPlanStatus.yearly
            ? Icons.arrow_back_rounded
            : Icons.close_rounded,
        onClose: () => Navigator.maybePop(context),
      ),
      const SizedBox(height: 12),
      const Align(
        alignment: Alignment.centerLeft,
        child: Padding(padding: EdgeInsets.only(left: 2), child: _LioraLogo()),
      ),
      const SizedBox(height: 8),
      if (activePlan == ProPlanStatus.none)
        ..._availablePlanContent(prices, purchaseState, isVIP: isVIP),
      if (activePlan == ProPlanStatus.weekly)
        ..._weeklyPlanContent(prices, purchaseState),
      if (activePlan == ProPlanStatus.yearly)
        ..._yearlyPlanContent(activeUntil, purchaseState),
    ];
  }

  List<Widget> _availablePlanContent(
    _PlanPrices prices,
    PurchaseState purchaseState, {
    required bool isVIP,
  }) {
    // Distribute spare height on tall phones, while compact screens can scroll.
    final media = MediaQuery.of(context);
    final extraSpace = (media.size.height - media.padding.vertical - 665).clamp(
      0.0,
      240.0,
    );
    return [
      const _ProHeadline(),
      SizedBox(height: 9 + extraSpace * .25),
      const Text(
        'Create unlimited AI videos.\nCancel anytime.',
        style: TextStyle(
          color: VideoFormStyle.secondary,
          fontSize: 12,
          fontWeight: FontWeight.w400,
          height: 1.45,
        ),
      ),
      SizedBox(height: 10 + extraSpace * .1),
      _BenefitsWithBuyCredits(onBuyCredits: _openBuyCredits),
      SizedBox(height: 11 + extraSpace * .15),
      const _CreatorBanner(),
      SizedBox(height: 8 + extraSpace * .1),
      _PlanCard(
        title: 'Yearly Pro',
        price: prices.yearly,
        caption: 'Billed annually',
        selected: _selectedPlan == 0,
        popular: true,
        onTap: () => setState(() => _selectedPlan = 0),
      ),
      if (!isVIP) ...[
        SizedBox(height: 8 + extraSpace * .1),
        _PlanCard(
          title: 'Weekly Pro',
          price: prices.weekly,
          selected: _selectedPlan == 1,
          onTap: () => setState(() => _selectedPlan = 1),
        ),
      ],
      SizedBox(height: 15 + extraSpace * .15),
      _SubscribeButton(
        busy: purchaseState.isBusy,
        onTap: purchaseState.isBusy ? null : _subscribe,
      ),
      SizedBox(height: 12 + extraSpace * .15),
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
        key: const Key('yearlyUpgradePlanCard'),
        title: 'Yearly Pro',
        price: prices.yearly,
        caption: 'Billed annually',
        label: 'SAVE MORE',
        selected: true,
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

  Future<void> _openBuyCredits() async {
    final purchased = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) =>
            BuyCredits(returnPurchaseResult: widget.returnPurchaseResult),
      ),
    );
    if (purchased == true && mounted && widget.returnPurchaseResult) {
      Navigator.of(context).pop(true);
    }
  }

  void _subscribe() {
    final profile = ref.read(profileProvider);
    final packages = ref
        .read(packageCatalogProvider)
        ?.forPlatform(profile?.platform);
    final package = profile?.isVIP == true || _selectedPlan == 0
        ? packages?.regularYearlySubscription
        : packages?.weeklySubscription;
    _buySubscription(package);
  }

  void _upgradeToYearly() {
    final profile = ref.read(profileProvider);
    final package = ref
        .read(packageCatalogProvider)
        ?.forPlatform(profile?.platform)
        ?.regularYearlySubscription;
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
          await _openBuyCredits();
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
    if (next.status == PurchaseFlowStatus.success &&
        widget.returnPurchaseResult &&
        _lastAttemptedPackage != null) {
      final messenger = ScaffoldMessenger.of(context);
      _lastAttemptedPackage = null;
      Navigator.of(context).pop(true);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(next.message!)));
      return;
    }
    if (next.status == PurchaseFlowStatus.success &&
        _lastAttemptedPackage?.durationDays != null &&
        _lastAttemptedPackage!.durationDays >= 300) {
      final messenger = ScaffoldMessenger.of(context);
      _lastAttemptedPackage = null;
      Navigator.of(context).popUntil((route) => route.isFirst);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(next.message!)));
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
          'assets/images/in_app_purchase/all_plans_hero_v2.png',
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
          color: const Color(0x2602050C),
          colorBlendMode: BlendMode.srcATop,
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x0002050C),
                Color(0x0002050C),
                Color(0xA602050C),
                Color(0xFF02050C),
              ],
              stops: [0, 0.55, 0.85, 1],
            ),
          ),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color(0xB302050C), Color(0x0002050C)],
              stops: [0, .65],
            ),
          ),
        ),
      ],
    );
  }
}

class _TopActions extends StatelessWidget {
  const _TopActions({required this.leadingIcon, required this.onClose});

  final IconData leadingIcon;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _RoundActionButton(
          key: const Key('allPlansCloseButton'),
          semanticsLabel: 'Close',
          icon: leadingIcon,
          onTap: onClose,
        ),
      ],
    );
  }
}

class _RoundActionButton extends StatelessWidget {
  const _RoundActionButton({
    super.key,
    required this.semanticsLabel,
    required this.icon,
    required this.onTap,
  });

  final String semanticsLabel;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 32,
      child: Material(
        color: const Color(0xFF0C111D),
        shape: const CircleBorder(
          side: BorderSide(color: Color(0xFF2C303E), width: .6),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Semantics(
            button: true,
            label: semanticsLabel,
            child: icon == Icons.close_rounded
                ? Padding(
                    padding: const EdgeInsets.all(9),
                    child: SvgPicture.asset('assets/svgs/purchase_close.svg'),
                  )
                : Icon(icon, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }
}

class _LioraLogo extends StatelessWidget {
  const _LioraLogo();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset('assets/images/home/lola_logo.png', width: 21, height: 21),
        const SizedBox(width: 6),
        const Text(
          'Liora ',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Text(
          'Pro',
          style: TextStyle(
            color: VideoFormStyle.pink,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ProHeadline extends StatelessWidget {
  const _ProHeadline();

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Ready to go PRO?',
    header: true,
    child: ExcludeSemantics(
      child: Text.rich(
        TextSpan(
          children: [
            const TextSpan(text: 'Ready to\ngo '),
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFFDE639D), Color(0xFF8A79DD)],
                ).createShader(bounds),
                child: Text(
                  'PRO?',
                  style: VideoFormStyle.serif(44).copyWith(height: .97),
                ),
              ),
            ),
          ],
        ),
        key: const Key('allPlansHeadline'),
        style: VideoFormStyle.serif(44).copyWith(height: .97),
      ),
    ),
  );
}

class _BenefitsList extends StatelessWidget {
  const _BenefitsList();

  static const _items = [
    ('plan_infinity', 'Unlimited AI video generation'),
    ('plan_rocket', 'Faster generation & priority queue'),
    ('plan_shield', 'Watermark-free exports'),
    ('plan_gift', 'Bonus credits every month'),
  ];

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (var index = 0; index < _items.length; index++)
        Padding(
          padding: EdgeInsets.only(bottom: index == _items.length - 1 ? 0 : 5),
          child: Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  gradient: VideoFormStyle.surface,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: const Color(0xFF2C303E), width: .5),
                ),
                child: ShaderMask(
                  blendMode: BlendMode.srcIn,
                  shaderCallback: (bounds) => const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [VideoFormStyle.pink, Color(0xFF9970D8)],
                  ).createShader(bounds),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: SvgPicture.asset(
                      'assets/svgs/${_items[index].$1}.svg',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Flexible(
                child: Text(
                  _items[index].$2,
                  style: const TextStyle(
                    color: Color(0xFFCECAD4),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w400,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
    ],
  );
}

class _BenefitsWithBuyCredits extends StatelessWidget {
  const _BenefitsWithBuyCredits({required this.onBuyCredits});

  final VoidCallback onBuyCredits;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      // Reserve a separate row when text scaling would collide with the CTA.
      final stacked =
          constraints.maxWidth < 330 ||
          MediaQuery.textScalerOf(context).scale(10) > 12;
      if (stacked) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _BenefitsList(),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: _BuyCreditsButton(onTap: onBuyCredits),
            ),
          ],
        );
      }
      return Stack(
        children: [
          const Padding(
            padding: EdgeInsets.only(right: 133),
            child: _BenefitsList(),
          ),
          Positioned(
            right: 0,
            bottom: 5,
            child: _BuyCreditsButton(onTap: onBuyCredits),
          ),
        ],
      );
    },
  );
}

class _BuyCreditsButton extends StatelessWidget {
  const _BuyCreditsButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('allPlansBuyCredits'),
    width: 131,
    constraints: const BoxConstraints(minHeight: 40),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      gradient: VideoFormStyle.surface,
      border: Border.all(color: const Color(0xFF765B9A), width: .5),
    ),
    child: Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          child: Row(
            children: [
              Image.asset(
                'assets/images/in_app_purchase/credit.png',
                width: 29,
                height: 25,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Buy Credits',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Colors.white,
                size: 17,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _CreatorBanner extends StatelessWidget {
  const _CreatorBanner();

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('allPlansCreatorBanner'),
    constraints: const BoxConstraints(minHeight: 52),
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(11),
      gradient: VideoFormStyle.surface,
      border: Border.all(color: VideoFormStyle.border, width: .5),
    ),
    child: Row(
      children: [
        SvgPicture.asset(
          'assets/svgs/plan_creators.svg',
          width: 48,
          height: 34,
        ),
        const SizedBox(width: 15),
        const Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: 'Over '),
                TextSpan(
                  text: '12,541',
                  style: TextStyle(
                    color: VideoFormStyle.pink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextSpan(text: ' creators joined the\n'),
                TextSpan(
                  text: 'Yearly Pro',
                  style: TextStyle(
                    color: Color(0xFFAA69D5),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextSpan(
                  text: ' plan ',
                  style: TextStyle(color: VideoFormStyle.pink),
                ),
                TextSpan(text: 'today!'),
              ],
            ),
            style: TextStyle(
              color: Color(0xFFCECAD4),
              fontSize: 11.5,
              fontWeight: FontWeight.w400,
              height: 1.45,
            ),
          ),
        ),
      ],
    ),
  );
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
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: Container(
      key: Key(popular ? 'allPlansYearlyCard' : 'allPlansWeeklyCard'),
      padding: const EdgeInsets.all(.5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(11),
        color: selected ? null : VideoFormStyle.border,
        gradient: selected
            ? const LinearGradient(
                colors: [VideoFormStyle.pink, Color(0xFF5266D8)],
              )
            : null,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: VideoFormStyle.surface,
          borderRadius: BorderRadius.circular(10.5),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(10.5),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final largeText =
                    MediaQuery.textScalerOf(context).scale(14) > 18;
                final priceLabel = Text(
                  price,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                );
                final pricing = Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (selected)
                      ShaderMask(
                        blendMode: BlendMode.srcIn,
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [VideoFormStyle.pink, Color(0xFF9B76DD)],
                        ).createShader(bounds),
                        child: priceLabel,
                      )
                    else
                      priceLabel,
                    if (caption != null) ...[
                      const SizedBox(height: 5),
                      Text(
                        caption!,
                        style: const TextStyle(
                          color: VideoFormStyle.secondary,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w400,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                );
                final identity = Row(
                  children: [
                    _PlanRadio(selected: selected),
                    const SizedBox(width: 17),
                    SvgPicture.asset(
                      popular
                          ? 'assets/svgs/plan_crown.svg'
                          : 'assets/svgs/plan_calendar.svg',
                      width: 24,
                      height: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ],
                );
                return ConstrainedBox(
                  constraints: BoxConstraints(minHeight: popular ? 91 : 54),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 13,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (popular) ...[
                          const Align(
                            alignment: Alignment.centerRight,
                            child: _PopularBadge(),
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (largeText || constraints.maxWidth < 310) ...[
                          identity,
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerRight,
                            child: pricing,
                          ),
                        ] else
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 11, child: identity),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 10,
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: pricing,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
}

class _PlanRadio extends StatelessWidget {
  const _PlanRadio({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) => Container(
    width: 28,
    height: 28,
    padding: const EdgeInsets.all(.8),
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: selected
          ? const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [VideoFormStyle.pink, Color(0xFFAA6BD5)],
            )
          : null,
      color: selected ? null : const Color(0xFF737784),
    ),
    child: DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xFF0A0E19),
        shape: BoxShape.circle,
      ),
      child: selected
          ? const Icon(Icons.check_rounded, color: Colors.white, size: 19)
          : null,
    ),
  );
}

class _PopularBadge extends StatelessWidget {
  const _PopularBadge();

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('allPlansPopularBadge'),
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(8),
      gradient: const LinearGradient(
        colors: [Color(0xFFBE589F), Color(0xFF424BBA)],
      ),
      border: Border.all(color: const Color(0xFF9671BD), width: .4),
    ),
    child: const Text(
      'MOST POPULAR',
      style: TextStyle(
        color: Colors.white,
        fontSize: 7.5,
        fontWeight: FontWeight.w500,
        letterSpacing: .9,
        height: 1.2,
      ),
    ),
  );
}

class _SubscribeButton extends StatelessWidget {
  const _SubscribeButton({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onTap != null,
    child: Container(
      key: const Key('allPlansSubscribeButton'),
      constraints: const BoxConstraints(minHeight: 46),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          colors: [Color(0xFFD34E8C), Color(0xFF703AA7), Color(0xFF2B40A2)],
        ),
        border: Border.all(color: const Color(0xFF8D79C3), width: .4),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            child: Row(
              children: [
                const SizedBox(width: 32),
                Expanded(
                  child: Text(
                    busy ? 'Processing...' : 'Start My Subscription',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 32,
                  height: 32,
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: const Color(0x3E9AAAF3),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0x4EAAB9F5),
                      width: .5,
                    ),
                  ),
                  child: busy
                      ? const CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: Colors.white,
                        )
                      : SvgPicture.asset('assets/svgs/plan_send.svg'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
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
                'Upgrade to Yearly and save more on your subscription.',
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
                      text: 'PRO',
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
    super.key,
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
                          'with your current plan.',
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
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
      decoration: BoxDecoration(
        gradient: VideoFormStyle.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: VideoFormStyle.border, width: .7),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'YOUR LOLA PRO PLAN',
            style: TextStyle(
              color: VideoFormStyle.accent,
              fontSize: 10,
              letterSpacing: 1.7,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 7),
          Text("You're PRO! 👑", style: VideoFormStyle.serif(35)),
          const SizedBox(height: 8),
          const Text(
            'Enjoy unlimited AI videos and all premium features.',
            style: TextStyle(
              color: VideoFormStyle.secondary,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final largeText = MediaQuery.textScalerOf(context).scale(12) > 16;
              const benefits = _YearlyBenefits();
              final artwork = _YearlyArtwork(activeUntil: activeUntil);
              if (constraints.maxWidth < 330 || largeText) {
                return Column(
                  children: [
                    SizedBox(height: 126, child: artwork),
                    const SizedBox(height: 14),
                    benefits,
                  ],
                );
              }
              return SizedBox(
                height: 190,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: benefits),
                    SizedBox(width: 124, child: artwork),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _YearlyBenefits extends StatelessWidget {
  const _YearlyBenefits();

  @override
  Widget build(BuildContext context) => const Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      _ProBenefit(
        icon: Icons.all_inclusive_rounded,
        text: 'Unlimited AI video generation',
      ),
      SizedBox(height: 7),
      _ProBenefit(
        icon: Icons.bolt_rounded,
        text: 'Faster generation & priority processing',
      ),
      SizedBox(height: 7),
      _ProBenefit(
        icon: Icons.water_drop_outlined,
        text: 'Watermark-free export',
      ),
      SizedBox(height: 7),
      _ProBenefit(
        icon: Icons.workspace_premium_rounded,
        text: 'Bonus crown coins every month',
      ),
      SizedBox(height: 7),
      _ProBenefit(
        icon: Icons.auto_awesome_rounded,
        text: 'All premium styles & templates',
      ),
    ],
  );
}

class _YearlyArtwork extends StatelessWidget {
  const _YearlyArtwork({required this.activeUntil});

  final String activeUntil;

  @override
  Widget build(BuildContext context) => Column(
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
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: VideoFormStyle.secondary, fontSize: 10.5),
      ),
    ],
  );
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
            color: const Color(0xFF14152B),
            border: Border.all(color: VideoFormStyle.accent),
          ),
          child: Icon(icon, color: VideoFormStyle.pink, size: 19),
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
    final compact = MediaQuery.textScalerOf(context).scale(12) > 16;
    return _OutlinedDarkCard(
      height: compact ? 166 : 82,
      radius: 17,
      child: compact
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Image.asset(
                        'assets/images/in_app_purchase/balance_coin.png',
                        width: 66,
                        height: 62,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(child: _BalanceDetails()),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: _BuyCreditsButton(onTap: onBuyCredits),
                ),
              ],
            )
          : Row(
              children: [
                Image.asset(
                  'assets/images/in_app_purchase/balance_coin.png',
                  width: 71,
                  height: 65,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 9),
                const Expanded(child: _BalanceDetails()),
                _BuyCreditsButton(onTap: onBuyCredits),
              ],
            ),
    );
  }
}

class _BalanceDetails extends StatelessWidget {
  const _BalanceDetails();

  @override
  Widget build(BuildContext context) => const Column(
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
                  color: VideoFormStyle.pink,
                  fontSize: 25,
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextSpan(
                text: ' credits',
                style: TextStyle(color: Color(0xFFCEC7D0), fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

class _GiftProCard extends StatelessWidget {
  const _GiftProCard();

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.textScalerOf(context).scale(12) > 16;
    return _OutlinedDarkCard(
      height: compact ? 170 : 88,
      radius: 17,
      child: Row(
        children: [
          Image.asset(
            'assets/images/in_app_purchase/gift_vip.png',
            width: compact ? 62 : 72,
            height: compact ? 62 : 72,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 12),
          const Expanded(child: _GiftProDetails()),
          const Icon(
            Icons.chevron_right_rounded,
            color: VideoFormStyle.pink,
            size: 29,
          ),
        ],
      ),
    );
  }
}

class _GiftProDetails extends StatelessWidget {
  const _GiftProDetails();

  @override
  Widget build(BuildContext context) => const Column(
    mainAxisAlignment: MainAxisAlignment.center,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Give PRO, Get More',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
      SizedBox(height: 4),
      Text(
        'Share Liora Pro with your friends\nand get extra credits!',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: Color(0xFFBDB6C0), fontSize: 12.5, height: 1.3),
      ),
    ],
  );
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
      padding: const EdgeInsets.all(.8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: strongGlow
            ? const LinearGradient(
                colors: [
                  VideoFormStyle.pink,
                  VideoFormStyle.accent,
                  Color(0xFF294CD7),
                ],
              )
            : const LinearGradient(
                colors: [Color(0xFF474253), Color(0xFF29263B)],
              ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11),
        decoration: BoxDecoration(
          gradient: VideoFormStyle.surface,
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
          colors: [VideoFormStyle.pink, VideoFormStyle.accent],
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
        gradient: VideoFormStyle.gradient,
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
    final style = Theme.of(context).textTheme.bodySmall!.copyWith(
      color: VideoFormStyle.secondary,
      fontSize: 9,
      fontWeight: FontWeight.w400,
    );

    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _LegalWebLink(
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
            _LegalWebLink(
              label: 'Terms of Service',
              page: AppWebPage.terms,
              style: style,
            ),
          ],
        ),
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
      width: .5,
      height: 11,
      margin: const EdgeInsets.symmetric(horizontal: 18),
      color: VideoFormStyle.secondary,
    );
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/network/api_exception.dart';
import '../../../data/models/package_catalog.dart';
import '../../../data/models/user_profile.dart';
import '../../providers/package_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/purchase_provider.dart';
import '../../widgets/generation_failure_dialog.dart';
import '../../widgets/pro_banner_video.dart';
import '../../widgets/video_form_widgets.dart';
import '../support/app_web_view_screen.dart';
import '../support/support_contact_screen.dart';
import 'in_app_purchase_screen.dart';

enum ProPlanStatus { none, weekly, yearly }

// Keep the original All Plans palette independent of the app-wide form theme.
abstract final class _AllPlansStyle {
  static const background = Color(0xFF02050C);
  static const border = Color(0xFF474253);
  static const secondary = Color(0xFFB4B1BD);
  static const accent = Color(0xFFC68AED);
  static const pink = Color(0xFFEC5FB6);
  static const surface = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0E1020), Color(0xFF070C17)],
  );
  static const gradient = LinearGradient(
    colors: [Color(0xFFCF559F), Color(0xFF8643B5), Color(0xFF294CD7)],
  );

  static TextStyle heading(
    double size, {
    FontWeight fontWeight = FontWeight.w400,
  }) => VideoFormStyle.heading(size, fontWeight: fontWeight);
}

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
    required this.yearlyPerWeek,
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
        yearly: 'VND 1,300,000/year',
        yearlyPerWeek: 'VND 25,000/week',
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
    final yearlyProduct = storeProducts[yearlyPackage.productId];
    final storeYearly = recurringSubscriptionPrice(yearlyProduct);
    return _PlanPrices(
      weekly:
          '${storeWeekly ?? '\$${weeklyPackage.price.toStringAsFixed(2)}'}/week',
      yearly:
          '${storeYearly ?? '\$${yearlyPackage.price.toStringAsFixed(2)}'}/year',
      yearlyPerWeek: _formatAnnualPricePerWeek(
        yearlyProduct,
        yearlyPackage.price,
      ),
      savingsPercent: savingsPercent,
      weeklySavings: '\$${savings.toStringAsFixed(2)}',
    );
  }

  final String weekly;
  final String yearly;
  final String yearlyPerWeek;
  final int savingsPercent;
  final String weeklySavings;
}

String _formatAnnualPricePerWeek(ProductDetails? product, double annualAmount) {
  final weeklyAmount =
      (recurringSubscriptionRawPrice(product) ?? annualAmount) / 52;
  final currencyCode = product?.currencyCode.toUpperCase();
  if (currencyCode == 'VND') return '${weeklyAmount.round()} ₫/week';
  if (currencyCode == null || currencyCode.isEmpty || currencyCode == 'USD') {
    return '\$${weeklyAmount.toStringAsFixed(2)}/week';
  }
  return '$currencyCode ${weeklyAmount.toStringAsFixed(2)}/week';
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
        ?.forPlatform(ref.watch(iapCatalogPlatformProvider));
    final prices = _PlanPrices.fromPackages(
      platformPackages,
      purchaseState.products,
    );
    final heroHeight = activePlan == ProPlanStatus.none
        ? math.max(
            (MediaQuery.sizeOf(context).width * .82).clamp(0.0, 420.0),
            MediaQuery.textScalerOf(context).scale(44) * 2 + 160,
          )
        : MediaQuery.sizeOf(context).width * 1.15;

    return Scaffold(
      backgroundColor: _AllPlansStyle.background,
      body: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 12,
            height: heroHeight,
            child: const _HeroBackground(key: Key('allPlansHeroBanner')),
          ),
          SafeArea(
            bottom: false,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    12,
                    2,
                    12,
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
                        heroHeight: heroHeight,
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
    required double heroHeight,
    required bool isVIP,
  }) {
    return [
      if (activePlan == ProPlanStatus.none)
        SizedBox(
          key: const Key('allPlansHeroArea'),
          height: (heroHeight + 100 - MediaQuery.paddingOf(context).top).clamp(
            32.0,
            double.infinity,
          ),
          child: Stack(
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: _TopActions(
                  leadingIcon: Icons.close_rounded,
                  onClose: () => Navigator.maybePop(context),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 5,
                child: Column(
                  key: const Key('allPlansHeaderActions'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _ProHeadline(),
                    const SizedBox(height: 12),
                    _BuyCreditsButton(onTap: _openBuyCredits),
                  ],
                ),
              ),
            ],
          ),
        )
      else if (activePlan == ProPlanStatus.weekly)
        SizedBox(
          key: const Key('allPlansWeeklyHeroArea'),
          height: heroHeight + 12 - MediaQuery.paddingOf(context).top,
          child: Stack(
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: _TopActions(
                  leadingIcon: Icons.close_rounded,
                  onClose: () => Navigator.maybePop(context),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _WeeklyProSummary(
                  activeUntil: activeUntil,
                  onBuyCredits: _openBuyCredits,
                ),
              ),
            ],
          ),
        )
      else ...[
        _TopActions(
          leadingIcon: Icons.arrow_back_rounded,
          onClose: () => Navigator.maybePop(context),
        ),
        const SizedBox(height: 20),
      ],
      if (activePlan == ProPlanStatus.none)
        ..._availablePlanContent(prices, purchaseState, isVIP: isVIP),
      if (activePlan == ProPlanStatus.weekly)
        ..._weeklyPlanContent(activeUntil, prices, purchaseState),
      if (activePlan == ProPlanStatus.yearly)
        ..._yearlyPlanContent(activeUntil, purchaseState),
    ];
  }

  List<Widget> _availablePlanContent(
    _PlanPrices prices,
    PurchaseState purchaseState, {
    required bool isVIP,
  }) {
    return [
      const SizedBox(height: 12),
      Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 52),
            child: _PlanCard(
              title: 'Annually',
              price: prices.yearly,
              weeklyEquivalent: prices.yearlyPerWeek,
              selected: _selectedPlan == 0,
              popular: true,
              onTap: purchaseState.isBusy ? null : () => _selectAndSubscribe(0),
            ),
          ),
          const Positioned(
            top: 0,
            left: 8,
            right: 8,
            child: Align(
              alignment: Alignment.topLeft,
              child: _CreatorTooltip(),
            ),
          ),
        ],
      ),
      if (!isVIP) ...[
        const SizedBox(height: 10),
        _PlanCard(
          title: 'Weekly',
          price: prices.weekly,
          selected: _selectedPlan == 1,
          onTap: purchaseState.isBusy ? null : () => _selectAndSubscribe(1),
        ),
      ],
      const SizedBox(height: 20),
      _SubscribeButton(
        busy: purchaseState.isBusy,
        onTap: purchaseState.isBusy
            ? null
            : () => _selectAndSubscribe(_selectedPlan),
      ),
      const SizedBox(height: 18),
      _LegalFooter(onRestore: purchaseState.isBusy ? null : _restore),
    ];
  }

  List<Widget> _weeklyPlanContent(
    String activeUntil,
    _PlanPrices prices,
    PurchaseState purchaseState,
  ) {
    final media = MediaQuery.of(context);
    final extraSpace = (media.size.height - media.padding.vertical - 538).clamp(
      0.0,
      400.0,
    );
    return [
      const SizedBox(height: 12),
      Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 52),
            child: _OwnedPlanCard(
              key: const Key('yearlyUpgradePlanCard'),
              title: 'Annually Pro',
              price: prices.yearly,
              label: 'SAVE MORE',
              selected: true,
              bestValue: true,
            ),
          ),
          const Positioned(
            top: 0,
            left: 8,
            right: 8,
            child: Align(
              alignment: Alignment.topLeft,
              child: _CreatorTooltip(
                message: "You're among 12,541 creators using PRO!",
              ),
            ),
          ),
        ],
      ),
      SizedBox(height: 8),
      _SavingsBanner(prices: prices),
      SizedBox(height: 8),
      _WideGradientButton(
        label: purchaseState.isBusy
            ? 'Processing...'
            : 'Upgrade to Annually Pro',
        busy: purchaseState.isBusy,
        onTap: purchaseState.isBusy ? null : _upgradeToYearly,
      ),
      SizedBox(height: 8),
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

  void _selectAndSubscribe(int planIndex) {
    if (ref.read(purchaseControllerProvider).isBusy) return;
    if (_selectedPlan != planIndex) {
      setState(() => _selectedPlan = planIndex);
    }
    final profile = ref.read(profileProvider);
    final packages = ref
        .read(packageCatalogProvider)
        ?.forPlatform(ref.read(iapCatalogPlatformProvider));
    final package = profile?.isVIP == true || planIndex == 0
        ? packages?.regularYearlySubscription
        : packages?.weeklySubscription;
    _buySubscription(package);
  }

  void _upgradeToYearly() {
    final package = ref
        .read(packageCatalogProvider)
        ?.forPlatform(ref.read(iapCatalogPlatformProvider))
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
  const _HeroBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ProBannerVideo(key: Key('allPlansProBannerVideo')),
        const DecoratedBox(decoration: BoxDecoration(color: Color(0x2602050C))),
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

class _ProHeadline extends StatelessWidget {
  const _ProHeadline();

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Ready to go PRO?',
    header: true,
    child: ExcludeSemantics(
      child: SizedBox(
        width: double.infinity,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
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
                      style: _AllPlansStyle.heading(
                        44,
                      ).copyWith(height: .97, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
            key: const Key('allPlansHeadline'),
            style: _AllPlansStyle.heading(
              44,
            ).copyWith(height: .97, fontWeight: FontWeight.w800),
          ),
        ),
      ),
    ),
  );
}

class _BuyCreditsButton extends StatelessWidget {
  const _BuyCreditsButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('allPlansBuyCredits'),
    width: 180,
    constraints: const BoxConstraints(minHeight: 48),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      gradient: const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [Color(0xFFC184EE), Color(0xFF9294E9)],
      ),
      border: Border.all(color: const Color(0xFFE2CCFF), width: 1.2),
      boxShadow: const [
        BoxShadow(
          color: Color(0x663C1C63),
          blurRadius: 12,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            children: [
              Image.asset(
                'assets/images/in_app_purchase/credit.png',
                width: 42,
                height: 36,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 7),
              const Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Buy Credits',
                    maxLines: 1,
                    style: TextStyle(
                      color: Color(0xFF1D102D),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF1D102D),
                size: 17,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _CreatorTooltip extends StatelessWidget {
  const _CreatorTooltip({this.message = '12,541 creators chose Annually Pro'});

  final String message;

  @override
  Widget build(BuildContext context) => Column(
    key: const Key('allPlansCreatorTooltip'),
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Color(0xFF7845B2), Color(0xFF965EC7)],
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              'assets/svgs/plan_creators.svg',
              width: 27,
              height: 23,
              colorFilter: const ColorFilter.mode(
                Colors.white,
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(width: 9),
            Flexible(
              fit: FlexFit.loose,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  message,
                  maxLines: 1,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(left: 41),
        child: CustomPaint(
          key: const Key('allPlansTooltipPointer'),
          size: const Size(14, 12),
          painter: _TooltipPointerPainter(),
        ),
      ),
    ],
  );
}

class _TooltipPointerPainter extends CustomPainter {
  const _TooltipPointerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2 + 1.2, size.height - 2)
      ..quadraticBezierTo(
        size.width / 2,
        size.height + 2,
        size.width / 2 - 1.2,
        size.height - 2,
      )
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFF804AB8));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.price,
    this.weeklyEquivalent,
    required this.selected,
    required this.onTap,
    this.popular = false,
  });

  final String title;
  final String price;
  final String? weeklyEquivalent;
  final bool selected;
  final bool popular;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    enabled: onTap != null,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        CustomPaint(
          foregroundPainter: selected ? _SelectedPlanBorderPainter() : null,
          child: Container(
            key: Key(popular ? 'allPlansYearlyCard' : 'allPlansWeeklyCard'),
            padding: const EdgeInsets.all(.5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11),
              color: selected ? null : _AllPlansStyle.border,
              gradient: selected
                  ? const LinearGradient(
                      colors: [_AllPlansStyle.pink, Color(0xFF5266D8)],
                    )
                  : null,
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: _AllPlansStyle.surface,
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
                            key: popular
                                ? const Key('allPlansYearlyAnnualPrice')
                                : null,
                            maxLines: 1,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                            ),
                          );
                          final fittedPrice = FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: priceLabel,
                          );
                          final pricing = selected
                              ? ShaderMask(
                                  blendMode: BlendMode.srcIn,
                                  shaderCallback: (bounds) =>
                                      const LinearGradient(
                                        colors: [
                                          _AllPlansStyle.pink,
                                          Color(0xFF9B76DD),
                                        ],
                                      ).createShader(bounds),
                                  child: fittedPrice,
                                )
                              : fittedPrice;
                          final identity = Row(
                            children: [
                              _PlanRadio(selected: selected),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      title,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        height: 1.2,
                                      ),
                                    ),
                                    if (weeklyEquivalent != null) ...[
                                      const SizedBox(height: 3),
                                      Text(
                                        'only $weeklyEquivalent',
                                        key: const Key(
                                          'allPlansYearlyWeeklyPrice',
                                        ),
                                        style: const TextStyle(
                                          color: _AllPlansStyle.secondary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          height: 1.2,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          );
                          return ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: popular ? 91 : 54,
                            ),
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(
                                16,
                                popular ? 16 : 13,
                                16,
                                popular ? 16 : 13,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (largeText ||
                                      constraints.maxWidth < 310) ...[
                                    identity,
                                    const SizedBox(height: 10),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: pricing,
                                    ),
                                  ] else
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(flex: 11, child: identity),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          flex: 10,
                                          child: Padding(
                                            padding: const EdgeInsets.only(
                                              top: 4,
                                            ),
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
              ],
            ),
          ),
        ),
        if (popular)
          const Positioned(
            top: -10,
            right: -4.5,
            child: IgnorePointer(child: _PopularBadge()),
          ),
      ],
    ),
  );
}

class _SelectedPlanBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const borderWidth = 2.0;
    final rect = Offset.zero & size;
    final paint = Paint()
      ..shader = const LinearGradient(
        colors: [_AllPlansStyle.pink, Color(0xFF5266D8)],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.deflate(borderWidth / 2),
        const Radius.circular(10),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
      color: selected ? AppColors.primary : const Color(0xFF737784),
    ),
    child: DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xFF0A0E19),
        shape: BoxShape.circle,
      ),
      child: selected
          ? const Center(
              child: DecoratedBox(
                key: Key('allPlansSelectedDot'),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: SizedBox(width: 12, height: 12),
              ),
            )
          : null,
    ),
  );
}

class _PopularBadge extends StatelessWidget {
  const _PopularBadge();

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('allPlansPopularBadge'),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(8),
      color: const Color(0xFFFFC857),
      border: Border.all(color: const Color(0xFFFFE7A1), width: 1),
      boxShadow: const [
        BoxShadow(
          color: Color(0x66FFC857),
          blurRadius: 12,
          offset: Offset(0, 3),
        ),
      ],
    ),
    child: const Text(
      'MOST POPULAR',
      style: TextStyle(
        color: Color(0xFF29133A),
        fontSize: 11,
        fontWeight: FontWeight.w800,
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
        color: const Color(0xFF8246B8),
        border: Border.all(color: const Color(0xFFAF78D5), width: .8),
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
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 40,
                  height: 40,
                  padding: const EdgeInsets.all(8),
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
                      : SvgPicture.asset(
                          'assets/svgs/plan_send.svg',
                          width: 20,
                          height: 20,
                          colorFilter: const ColorFilter.mode(
                            Colors.white,
                            BlendMode.srcIn,
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

class _WeeklyProSummary extends StatelessWidget {
  const _WeeklyProSummary({
    required this.activeUntil,
    required this.onBuyCredits,
  });

  final String activeUntil;
  final VoidCallback onBuyCredits;

  @override
  Widget build(BuildContext context) => Padding(
    key: const Key('weeklyProSummary'),
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: _WeeklyIntro(activeUntil: activeUntil, onBuyCredits: onBuyCredits),
  );
}

class _WeeklyIntro extends StatelessWidget {
  const _WeeklyIntro({required this.activeUntil, required this.onBuyCredits});

  final String activeUntil;
  final VoidCallback onBuyCredits;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('weeklyProIntro'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: ShaderMask(
                  blendMode: BlendMode.srcIn,
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [
                      Colors.white,
                      Color(0xFFFF7DC9),
                      _AllPlansStyle.accent,
                    ],
                  ).createShader(bounds),
                  child: Text(
                    'Weekly PRO',
                    maxLines: 1,
                    style: _AllPlansStyle.heading(
                      38,
                      fontWeight: FontWeight.w700,
                    ).copyWith(height: 1, letterSpacing: -.7),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: _AllPlansStyle.gradient,
                border: Border.all(color: const Color(0x99FFFFFF)),
              ),
              child: const Icon(
                Icons.workspace_premium_rounded,
                color: Colors.white,
                size: 23,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _BuyCreditsButton(onTap: onBuyCredits),
      ],
    );
  }
}

class _OwnedPlanCard extends StatelessWidget {
  const _OwnedPlanCard({
    super.key,
    required this.title,
    required this.price,
    required this.label,
    required this.selected,
    this.bestValue = false,
  });

  final String title;
  final String price;
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
          highlighted: true,
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
                    const TextSpan(text: 'Switch to Annually Pro and '),
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
        gradient: _AllPlansStyle.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _AllPlansStyle.border, width: .7),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("You're PRO! 👑", style: _AllPlansStyle.heading(35)),
          const SizedBox(height: 8),
          const Text(
            'Enjoy unlimited AI videos and all premium features.',
            style: TextStyle(
              color: _AllPlansStyle.secondary,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final largeText = MediaQuery.textScalerOf(context).scale(12) > 16;
              const benefits = _ProBenefits();
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

class _ProBenefits extends StatelessWidget {
  const _ProBenefits();

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
        style: const TextStyle(color: _AllPlansStyle.secondary, fontSize: 10.5),
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
            border: Border.all(color: _AllPlansStyle.accent),
          ),
          child: Icon(icon, color: _AllPlansStyle.pink, size: 19),
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
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          'Your Balance',
          maxLines: 1,
          style: TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
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
                  color: _AllPlansStyle.pink,
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
            color: _AllPlansStyle.pink,
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
    this.highlighted = false,
  });

  final double height;
  final double radius;
  final Widget child;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: EdgeInsets.all(highlighted ? 2 : .8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: highlighted
            ? const LinearGradient(
                colors: [
                  _AllPlansStyle.pink,
                  _AllPlansStyle.accent,
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
          gradient: _AllPlansStyle.surface,
          borderRadius: BorderRadius.circular(radius - (highlighted ? 2 : 1)),
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
          colors: [_AllPlansStyle.pink, _AllPlansStyle.accent],
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
        gradient: _AllPlansStyle.gradient,
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

class _LegalFooter extends StatelessWidget {
  const _LegalFooter({required this.onRestore});

  final VoidCallback? onRestore;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall!.copyWith(
      color: _AllPlansStyle.secondary,
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
              child: const Text(
                'Restore Purchase',
                style: TextStyle(fontSize: 12),
              ),
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
      child: Text(label, style: TextStyle(fontSize: 12)),
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
      color: _AllPlansStyle.secondary,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../../core/network/api_exception.dart';
import '../../../data/models/package_catalog.dart';
import '../../providers/package_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/purchase_provider.dart';
import '../../widgets/generation_failure_dialog.dart';
import '../support/app_web_view_screen.dart';
import '../support/support_contact_screen.dart';
import 'all_plans_screen.dart';
import 'in_app_purchase_screen.dart';

class YearlySaleScreen extends ConsumerStatefulWidget {
  const YearlySaleScreen({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const YearlySaleScreen()),
    );
  }

  @override
  ConsumerState<YearlySaleScreen> createState() => _YearlySaleScreenState();
}

class _YearlySaleScreenState extends ConsumerState<YearlySaleScreen> {
  bool _muted = true;
  bool _purchaseStarted = false;
  AppPackage? _lastAttemptedPackage;
  bool _lastAttemptWasReplacement = false;

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final purchaseState = ref.watch(purchaseControllerProvider);
    ref.listen<PurchaseState>(purchaseControllerProvider, _onPurchaseState);
    final packages = ref
        .watch(packageCatalogProvider)
        ?.forPlatform(profile?.platform);
    final salePackage =
        _findYearlyPackage(packages?.sales) ?? packages?.yearlySubscription;
    final pricing = _SalePricing.fromPackages(
      salePackage: salePackage,
      regularPackage: _findYearlyPackage(packages?.subscriptions),
      storeProducts: purchaseState.products,
    );

    return Scaffold(
      backgroundColor: const Color(0xFF030208),
      body: Stack(
        children: [
          const Positioned.fill(child: _SaleBackground()),
          SafeArea(
            bottom: false,
            child: CustomScrollView(
              key: const Key('yearlySaleScrollView'),
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    18,
                    10,
                    18,
                    18 + MediaQuery.paddingOf(context).bottom,
                  ),
                  sliver: SliverList.list(
                    children: [
                      _TopActions(
                        muted: _muted,
                        onClose: () => Navigator.maybePop(context),
                        onSoundTap: () => setState(() => _muted = !_muted),
                      ),
                      const SizedBox(height: 8),
                      const _SaleHero(),
                      const SizedBox(height: 10),
                      const _BenefitsCard(),
                      const SizedBox(height: 14),
                      _PriceCard(pricing: pricing),
                      const SizedBox(height: 10),
                      const _BillingNote(),
                      const SizedBox(height: 16),
                      _PrimaryButton(
                        busy: purchaseState.isBusy,
                        onTap: purchaseState.isBusy
                            ? null
                            : () => _startYearlySale(salePackage),
                      ),
                      const SizedBox(height: 8),
                      _TextLink(
                        key: const Key('yearlySaleViewAllPlansButton'),
                        label: 'View all plans',
                        icon: Icons.chevron_right_rounded,
                        onTap: _openAllPlans,
                      ),
                      const SizedBox(height: 7),
                      _BuyCreditsButton(onTap: _openBuyCredits),
                      const SizedBox(height: 15),
                      _LegalFooter(
                        onRestore: purchaseState.isBusy ? null : _restore,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _startYearlySale(AppPackage? package) {
    if (package == null || package.productId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The yearly sale is unavailable.')),
      );
      return;
    }
    final replaceExisting =
        resolveProPlanStatus(ref.read(profileProvider)) == ProPlanStatus.weekly;
    _lastAttemptedPackage = package;
    _lastAttemptWasReplacement = replaceExisting;
    _purchaseStarted = true;
    ref
        .read(purchaseControllerProvider.notifier)
        .buy(
          productId: package.productId,
          consumable: false,
          replaceExistingSubscription: replaceExisting,
        );
  }

  Future<void> _onPurchaseState(
    PurchaseState? previous,
    PurchaseState next,
  ) async {
    if (!_purchaseStarted || !mounted) return;
    final attemptedProductId = _lastAttemptedPackage?.productId;
    if (next.productId != null &&
        attemptedProductId != null &&
        next.productId != attemptedProductId) {
      return;
    }

    switch (next.status) {
      case PurchaseFlowStatus.success:
        _purchaseStarted = false;
        final message = next.message ?? 'Your Yearly Pro plan is now active.';
        final messenger = ScaffoldMessenger.of(context);
        await Navigator.maybePop(context);
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      case PurchaseFlowStatus.canceled:
        _purchaseStarted = false;
        if (next.message != null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(next.message!)));
        }
      case PurchaseFlowStatus.error:
        await _handlePurchaseError(next);
      case PurchaseFlowStatus.unavailable:
      case PurchaseFlowStatus.connecting:
      case PurchaseFlowStatus.ready:
      case PurchaseFlowStatus.launching:
      case PurchaseFlowStatus.pending:
      case PurchaseFlowStatus.verifying:
      case PurchaseFlowStatus.restoring:
        break;
    }
  }

  Future<void> _handlePurchaseError(PurchaseState state) async {
    final action = await GenerationFailureDialog.showForPurchaseError(
      context,
      error: ApiException(
        message: state.message ?? 'Unable to purchase the yearly plan.',
        errorCode: state.errorCode,
      ),
      fallbackMessage:
          'We could not complete your Yearly Pro purchase. Please try again.',
    );
    if (!mounted) return;
    switch (action) {
      case GenerationFailureAction.retry:
      case GenerationFailureAction.renewSubscription:
        final package = _lastAttemptedPackage;
        if (package != null) {
          _purchaseStarted = true;
          ref
              .read(purchaseControllerProvider.notifier)
              .buy(
                productId: package.productId,
                consumable: false,
                replaceExistingSubscription: _lastAttemptWasReplacement,
              );
        }
      case GenerationFailureAction.buyCredits:
        _purchaseStarted = false;
        await _openBuyCredits();
      case GenerationFailureAction.contactSupport:
        _purchaseStarted = false;
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => SupportContactScreen(
              errorCode: state.errorCode,
              errorMessage: state.message,
            ),
          ),
        );
      case GenerationFailureAction.chooseImage:
      case GenerationFailureAction.editInput:
      case GenerationFailureAction.chooseTheme:
      case GenerationFailureAction.close:
      case null:
        _purchaseStarted = false;
        break;
    }
  }

  void _restore() {
    ref.read(purchaseControllerProvider.notifier).restore();
  }

  Future<void> _openAllPlans() {
    return Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const AllPlans()));
  }

  Future<void> _openBuyCredits() {
    return Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const BuyCredits()));
  }
}

AppPackage? _findYearlyPackage(List<AppPackage>? packages) {
  if (packages == null) return null;
  for (final package in packages) {
    if (package.durationDays >= 300) return package;
  }
  return null;
}

class _SalePricing {
  const _SalePricing({
    required this.salePrice,
    required this.regularPrice,
    required this.weeklyPrice,
    required this.savingsPercent,
  });

  factory _SalePricing.fromPackages({
    required AppPackage? salePackage,
    required AppPackage? regularPackage,
    required Map<String, ProductDetails> storeProducts,
  }) {
    final storeSale = salePackage == null
        ? null
        : storeProducts[salePackage.productId];
    final storeRegular = regularPackage == null
        ? null
        : storeProducts[regularPackage.productId];
    final saleAmount = storeSale?.rawPrice ?? salePackage?.price ?? 29.99;
    final regularAmount =
        storeRegular?.rawPrice ?? regularPackage?.price ?? 99.99;
    final safeRegularAmount = regularAmount > saleAmount
        ? regularAmount
        : saleAmount;
    final percent = safeRegularAmount <= 0
        ? 0
        : (((safeRegularAmount - saleAmount) / safeRegularAmount) * 100)
              .round();

    return _SalePricing(
      salePrice: storeSale?.price ?? '\$${saleAmount.toStringAsFixed(2)}',
      regularPrice:
          storeRegular?.price ?? '\$${safeRegularAmount.toStringAsFixed(2)}',
      weeklyPrice: _formatWeeklyPrice(storeSale, saleAmount),
      savingsPercent: percent,
    );
  }

  final String salePrice;
  final String regularPrice;
  final String weeklyPrice;
  final int savingsPercent;
}

String _formatWeeklyPrice(ProductDetails? product, double yearlyAmount) {
  final amount = yearlyAmount / 52;
  final currencyCode = product?.currencyCode.toUpperCase();
  if (currencyCode == 'VND') {
    return '${amount.round()} ₫';
  }
  if (currencyCode == null || currencyCode.isEmpty || currencyCode == 'USD') {
    return '\$${amount.toStringAsFixed(2)}';
  }
  return '$currencyCode ${amount.toStringAsFixed(2)}';
}

class _SaleBackground extends StatelessWidget {
  const _SaleBackground();

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
              colors: [Color(0x72030208), Color(0xF2030208), Color(0xFF030208)],
              stops: [0, 0.34, 0.72],
            ),
          ),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0.75, -0.66),
              radius: 0.72,
              colors: [Color(0x423D0051), Color(0x00030208)],
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
    required this.onClose,
    required this.onSoundTap,
  });

  final bool muted;
  final VoidCallback onClose;
  final VoidCallback onSoundTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _RoundButton(
          key: const Key('yearlySaleCloseButton'),
          label: 'Close',
          icon: Icons.close_rounded,
          onTap: onClose,
        ),
        _RoundButton(
          label: muted ? 'Turn sound on' : 'Mute sound',
          icon: muted ? Icons.volume_off_outlined : Icons.volume_up_outlined,
          onTap: onSoundTap,
        ),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Container(
        width: 44,
        height: 44,
        padding: const EdgeInsets.all(1.2),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [Color(0xFFFF24B7), Color(0xFFFF8A32)],
          ),
          boxShadow: [BoxShadow(color: Color(0x88FF24AA), blurRadius: 13)],
        ),
        child: Material(
          color: const Color(0xE20B0610),
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Icon(icon, color: Colors.white, size: 27),
          ),
        ),
      ),
    );
  }
}

class _SaleHero extends StatelessWidget {
  const _SaleHero();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 280,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -28,
            top: -34,
            width: 228,
            height: 253,
            child: Image.asset(
              'assets/images/in_app_purchase/sale_yearly.png',
              fit: BoxFit.contain,
            ),
          ),
          const Positioned(left: 4, top: 13, child: _NostaliaPro()),
          const Positioned(left: 4, top: 53, child: _GradientTitle()),
          const Positioned(
            left: 4,
            right: 4,
            top: 174,
            child: Text(
              'Unlimited AI videos, premium styles, faster generation, '
              'and watermark-free export.',
              style: TextStyle(
                color: Color(0xFFD8D2DA),
                fontSize: 14,
                height: 1.42,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Positioned(
            left: 4,
            bottom: 3,
            child: Row(
              children: [
                _SaleBadge(icon: Icons.bolt_rounded, label: 'LIMITED SALE'),
                SizedBox(width: 9),
                _SaleBadge(
                  icon: Icons.workspace_premium_rounded,
                  label: 'BEST VALUE',
                  orange: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NostaliaPro extends StatelessWidget {
  const _NostaliaPro();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFFFF19BE), Color(0xFFFF9C22)],
          ).createShader(bounds),
          child: const Icon(Icons.play_arrow_rounded, size: 29),
        ),
        const SizedBox(width: 3),
        const Text(
          'Nostalia ',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        const Text(
          'Pro',
          style: TextStyle(
            color: Color(0xFFFF794A),
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _GradientTitle extends StatelessWidget {
  const _GradientTitle();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Yearly',
          style: TextStyle(
            color: Colors.white,
            fontSize: 42,
            height: 0.96,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.5,
          ),
        ),
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFFFF16BD), Color(0xFFFF9C22)],
          ).createShader(bounds),
          child: const Text(
            'Sale Pro',
            style: TextStyle(
              color: Colors.white,
              fontSize: 42,
              height: 0.96,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _SaleBadge extends StatelessWidget {
  const _SaleBadge({
    required this.icon,
    required this.label,
    this.orange = false,
  });

  final IconData icon;
  final String label;
  final bool orange;

  @override
  Widget build(BuildContext context) {
    final color = orange ? const Color(0xFFFF9C21) : const Color(0xFFFF28B1);
    return Container(
      height: 35,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xD80C0710),
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: color),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.42), blurRadius: 10),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _BenefitsCard extends StatelessWidget {
  const _BenefitsCard();

  static const _benefits = [
    (Icons.all_inclusive_rounded, 'Unlimited AI video generation'),
    (Icons.auto_awesome_rounded, 'Premium styles & templates'),
    (Icons.bolt_rounded, 'Faster generation'),
    (Icons.water_drop_outlined, 'Watermark-free export'),
    (Icons.workspace_premium_rounded, 'Monthly bonus crown coins'),
  ];

  @override
  Widget build(BuildContext context) {
    return _NeonCard(
      child: Column(
        children: [
          for (var index = 0; index < _benefits.length; index++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Row(
                children: [
                  _BenefitIcon(icon: _benefits[index].$1),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Text(
                      _benefits[index].$2,
                      style: const TextStyle(
                        color: Color(0xFFE4DFE6),
                        fontSize: 14.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (index != _benefits.length - 1)
              const Divider(height: 1, color: Color(0xFF4A173E)),
          ],
        ],
      ),
    );
  }
}

class _BenefitIcon extends StatelessWidget {
  const _BenefitIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF250B20),
        border: Border.all(color: const Color(0xFFFF28AC)),
        boxShadow: const [BoxShadow(color: Color(0x70FF24AA), blurRadius: 8)],
      ),
      child: Icon(icon, color: const Color(0xFFFF42B7), size: 20),
    );
  }
}

class _NeonCard extends StatelessWidget {
  const _NeonCard({required this.child, this.highlight = false});

  final Widget child;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(highlight ? 1.4 : 1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: highlight
              ? const [Color(0xFFFF19B9), Color(0xFFFFA01E)]
              : const [Color(0xFFB32882), Color(0xFF742256)],
        ),
        boxShadow: highlight
            ? const [BoxShadow(color: Color(0x75FF23A9), blurRadius: 16)]
            : null,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(17, 11, 17, 12),
        decoration: BoxDecoration(
          color: const Color(0xF20A0610),
          borderRadius: BorderRadius.circular(21),
        ),
        child: child,
      ),
    );
  }
}

class _PriceCard extends StatelessWidget {
  const _PriceCard({required this.pricing});

  final _SalePricing pricing;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _NeonCard(
          highlight: true,
          child: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Column(
              children: [
                const Row(
                  children: [
                    _SelectedPlanIcon(),
                    SizedBox(width: 12),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Yearly Sale Pro',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 90),
                  ],
                ),
                const SizedBox(height: 15),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${pricing.regularPrice}/year',
                        style: const TextStyle(
                          color: Color(0xFF918A95),
                          fontSize: 14,
                          decoration: TextDecoration.lineThrough,
                          decorationColor: Color(0xFFB0A8B2),
                        ),
                      ),
                      const SizedBox(width: 14),
                      ShaderMask(
                        blendMode: BlendMode.srcIn,
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [Color(0xFFFF16B7), Color(0xFFFF9E20)],
                        ).createShader(bounds),
                        child: Text(
                          pricing.salePrice,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 35,
                            height: 0.95,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const Text(
                        '/year',
                        style: TextStyle(
                          color: Color(0xFFC8C1CB),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  'Save ${pricing.savingsPercent}%',
                  style: const TextStyle(
                    color: Color(0xFFFF3EB1),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Only ${pricing.weeklyPrice}/week',
                  style: const TextStyle(
                    color: Color(0xFFBDB6C1),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 17),
                  decoration: BoxDecoration(
                    color: const Color(0xFF190B18),
                    borderRadius: BorderRadius.circular(19),
                    border: Border.all(color: const Color(0xFFFF29A8)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_month_outlined,
                        color: Color(0xFFFF37AC),
                        size: 19,
                      ),
                      SizedBox(width: 8),
                      Text(
                        '7-day free trial',
                        style: TextStyle(
                          color: Color(0xFFFF4DB6),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          right: 0,
          top: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(21),
                bottomLeft: Radius.circular(20),
              ),
              gradient: LinearGradient(
                colors: [Color(0xFFFF10BF), Color(0xFFFFA11C)],
              ),
            ),
            child: Text(
              'SAVE ${pricing.savingsPercent}%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SelectedPlanIcon extends StatelessWidget {
  const _SelectedPlanIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF43132E),
        border: Border.all(color: const Color(0xFFFF2BA9)),
        boxShadow: const [BoxShadow(color: Color(0x80FF25AA), blurRadius: 10)],
      ),
      child: const Icon(Icons.check_rounded, color: Colors.white, size: 24),
    );
  }
}

class _BillingNote extends StatelessWidget {
  const _BillingNote();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xA10C0810),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF4A2445)),
        ),
        child: const Text(
          'ⓘ  Billed annually  •  Cancel anytime',
          style: TextStyle(color: Color(0xFFC5BEC8), fontSize: 12),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('yearlySalePurchaseButton'),
      height: 66,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFF0BC5),
            Color(0xFFFF268E),
            Color(0xFFFF742B),
            Color(0xFFFFAE00),
          ],
        ),
        boxShadow: const [
          BoxShadow(color: Color(0xA0FF1AA8), blurRadius: 20),
          BoxShadow(
            color: Color(0x66FF8E18),
            blurRadius: 14,
            offset: Offset(5, 0),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(25),
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
                      width: 21,
                      height: 21,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.3,
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Text(
                    busy ? 'Processing...' : 'Start 7-Day Free Trial',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (!busy) ...[
                    const SizedBox(width: 18),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 27,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TextLink extends StatelessWidget {
  const _TextLink({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton.icon(
        onPressed: onTap,
        iconAlignment: IconAlignment.end,
        icon: Icon(icon, color: const Color(0xFFFF42AD)),
        label: Text(
          label,
          style: const TextStyle(
            color: Color(0xFFFF42AD),
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _BuyCreditsButton extends StatelessWidget {
  const _BuyCreditsButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('yearlySaleBuyCreditsButton'),
      height: 51,
      padding: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(27),
        gradient: const LinearGradient(
          colors: [Color(0xFFFF31AD), Color(0xFF7E2C65)],
        ),
      ),
      child: Material(
        color: const Color(0xED0A0610),
        borderRadius: BorderRadius.circular(26),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.toll_outlined, color: Color(0xFFFF55B7), size: 25),
              SizedBox(width: 11),
              Text(
                'Buy more credits',
                style: TextStyle(
                  color: Color(0xFFD88BB8),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(width: 13),
              Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFFD88BB8),
                size: 24,
              ),
            ],
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
    const style = TextStyle(color: Color(0xFFB8B0BC), fontSize: 12);
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
              minimumSize: Size.zero,
              padding: EdgeInsets.zero,
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
      color: const Color(0xFFFF2AAB),
    );
  }
}

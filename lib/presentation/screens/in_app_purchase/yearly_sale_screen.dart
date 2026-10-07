import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../../core/network/api_exception.dart';
import '../../../data/models/package_catalog.dart';
import '../../providers/package_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/purchase_provider.dart';
import '../../widgets/generation_failure_dialog.dart';
import '../../widgets/pro_banner_video.dart';
import '../../widgets/video_form_style.dart';
import '../support/app_web_view_screen.dart';
import '../support/support_contact_screen.dart';
import 'all_plans_screen.dart';
import 'in_app_purchase_screen.dart';

double _saleScale(BuildContext context) =>
    (MediaQuery.sizeOf(context).width / 393).clamp(0.82, 1.15);

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
  bool _purchaseStarted = false;
  AppPackage? _lastAttemptedPackage;
  bool _lastAttemptWasReplacement = false;

  @override
  Widget build(BuildContext context) {
    final purchaseState = ref.watch(purchaseControllerProvider);
    ref.listen<PurchaseState>(purchaseControllerProvider, _onPurchaseState);
    final packages = ref
        .watch(packageCatalogProvider)
        ?.forPlatform(ref.watch(iapCatalogPlatformProvider));
    final salePackage =
        _findYearlyPackage(packages?.sales) ?? packages?.yearlySubscription;
    final pricing = _SalePricing.fromPackages(
      salePackage: salePackage,
      regularPackage: _findYearlyPackage(packages?.subscriptions),
      storeProducts: purchaseState.products,
    );
    final scale = _saleScale(context);

    return Scaffold(
      backgroundColor: VideoFormStyle.background,
      body: Stack(
        children: [
          const Positioned.fill(child: _SaleBackground()),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: CustomScrollView(
                  key: const Key('yearlySaleScrollView'),
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        12 * scale,
                        6 * scale,
                        12 * scale,
                        12 * scale,
                      ),
                      sliver: SliverFillRemaining(
                        hasScrollBody: false,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _TopActions(
                              onClose: () => Navigator.maybePop(context),
                            ),
                            const Spacer(),
                            Column(
                              key: const Key('yearlySaleBottomContent'),
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SizedBox(height: 4 * scale),
                                const _SaleHero(),
                                SizedBox(height: 7 * scale),
                                const _BenefitsCard(),
                                SizedBox(height: 9 * scale),
                                _PriceCard(pricing: pricing),
                                SizedBox(height: 7 * scale),
                                SizedBox(height: 10 * scale),
                                _PrimaryButton(
                                  busy: purchaseState.isBusy,
                                  onTap: purchaseState.isBusy
                                      ? null
                                      : () => _startYearlySale(salePackage),
                                ),
                                SizedBox(height: 7 * scale),
                                _BuyCreditsButton(onTap: _openBuyCredits),
                                SizedBox(height: 2 * scale),
                                _TextLink(
                                  key: const Key(
                                    'yearlySaleViewAllPlansButton',
                                  ),
                                  label: 'View all plans',
                                  icon: Icons.chevron_right_rounded,
                                  onTap: _openAllPlans,
                                ),
                                SizedBox(height: 5 * scale),
                                _LegalFooter(
                                  onRestore: purchaseState.isBusy
                                      ? null
                                      : _restore,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
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

  void _startYearlySale(AppPackage? package) {
    if (package == null || package.productId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The annual sale is unavailable.')),
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
        final message = next.message ?? 'Your Annually Pro plan is now active.';
        final messenger = ScaffoldMessenger.of(context);
        Navigator.of(context).popUntil((route) => route.isFirst);
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
        message: state.message ?? 'Unable to purchase the annual plan.',
        errorCode: state.errorCode,
      ),
      fallbackMessage:
          'We could not complete your Annually Pro purchase. Please try again.',
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
    final saleAmount =
        recurringSubscriptionRawPrice(storeSale) ?? salePackage?.price ?? 29.99;
    final regularAmount =
        recurringSubscriptionRawPrice(storeRegular) ??
        regularPackage?.price ??
        99.99;
    final safeRegularAmount = regularAmount > saleAmount
        ? regularAmount
        : saleAmount;
    final percent = safeRegularAmount <= 0
        ? 0
        : (((safeRegularAmount - saleAmount) / safeRegularAmount) * 100)
              .round();

    return _SalePricing(
      salePrice:
          recurringSubscriptionPrice(storeSale) ??
          '\$${saleAmount.toStringAsFixed(2)}',
      regularPrice:
          recurringSubscriptionPrice(storeRegular) ??
          '\$${safeRegularAmount.toStringAsFixed(2)}',
      savingsPercent: percent,
    );
  }

  final String salePrice;
  final String regularPrice;
  final int savingsPercent;
}

class _SaleBackground extends StatelessWidget {
  const _SaleBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: (MediaQuery.sizeOf(context).width * .82).clamp(0.0, 420.0),
          child: const ProBannerVideo(key: Key('yearlySaleProBannerVideo')),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x72252335), Color(0xF2252335), Color(0xFF292431)],
              stops: [0, 0.34, 0.72],
            ),
          ),
        ),
      ],
    );
  }
}

class _TopActions extends StatelessWidget {
  const _TopActions({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _RoundButton(
          key: const Key('yearlySaleCloseButton'),
          label: 'Close',
          icon: Icons.close_rounded,
          onTap: onClose,
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
    final scale = _saleScale(context);
    return Semantics(
      button: true,
      label: label,
      child: Container(
        width: 40 * scale,
        height: 40 * scale,
        padding: const EdgeInsets.all(1.2),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: VideoFormStyle.gradient,
        ),
        child: Material(
          color: const Color(0xE2312E42),
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Icon(icon, color: Colors.white, size: 23 * scale),
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
    final scale = _saleScale(context);
    return SizedBox(
      height: 153 * scale,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: 0,
            top: -5 * scale,
            width: 138 * scale,
            height: 153 * scale,
            child: Image.asset(
              'assets/images/in_app_purchase/sale_yearly.png',
              fit: BoxFit.contain,
            ),
          ),
          Positioned(left: 4, top: 34 * scale, child: const _GradientTitle()),
        ],
      ),
    );
  }
}

class _GradientTitle extends StatelessWidget {
  const _GradientTitle();

  @override
  Widget build(BuildContext context) {
    final scale = _saleScale(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Annually',
          style: TextStyle(
            color: Colors.white,
            fontSize: 34 * scale,
            height: 0.96,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.1,
          ),
        ),
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => const LinearGradient(
            colors: [VideoFormStyle.pink, VideoFormStyle.accent],
          ).createShader(bounds),
          child: Text(
            'Sale Pro',
            style: TextStyle(
              color: Colors.white,
              fontSize: 34 * scale,
              height: 0.96,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.1,
            ),
          ),
        ),
      ],
    );
  }
}

class _BenefitsCard extends StatelessWidget {
  const _BenefitsCard();

  static const _benefits = [
    (Icons.all_inclusive_rounded, 'Unlimited AI videos'),
    (Icons.auto_awesome_rounded, 'Premium styles and faster generation'),
    (Icons.water_drop_outlined, 'Export without a watermark'),
  ];

  @override
  Widget build(BuildContext context) {
    final scale = _saleScale(context);
    return _OutlinedCard(
      child: Column(
        children: [
          for (var index = 0; index < _benefits.length; index++) ...[
            Padding(
              padding: EdgeInsets.symmetric(vertical: 3.5 * scale),
              child: Row(
                children: [
                  _BenefitIcon(icon: _benefits[index].$1),
                  SizedBox(width: 10 * scale),
                  Expanded(
                    child: Text(
                      _benefits[index].$2,
                      style: TextStyle(
                        color: const Color(0xFFE4DFE6),
                        fontSize: 12.5 * scale,
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
    final scale = _saleScale(context);
    return Container(
      width: 29 * scale,
      height: 29 * scale,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF14152B),
        border: Border.all(color: VideoFormStyle.accent),
      ),
      child: Icon(icon, color: const Color(0xFFD17CB1), size: 16 * scale),
    );
  }
}

class _OutlinedCard extends StatelessWidget {
  const _OutlinedCard({required this.child, this.highlight = false});

  final Widget child;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(highlight ? 1.1 : .8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: highlight ? const Color(0xFF9366AA) : const Color(0xFF474253),
      ),
      child: Container(
        padding: EdgeInsets.fromLTRB(
          14 * _saleScale(context),
          8 * _saleScale(context),
          14 * _saleScale(context),
          9 * _saleScale(context),
        ),
        decoration: BoxDecoration(
          gradient: VideoFormStyle.surface,
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
    final scale = _saleScale(context);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _OutlinedCard(
          highlight: true,
          child: Padding(
            padding: EdgeInsets.only(top: 3 * scale),
            child: Column(
              children: [
                Row(
                  children: [
                    const _SelectedPlanIcon(),
                    SizedBox(width: 9 * scale),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: const Text(
                          'Annually Sale Pro',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 82 * scale),
                  ],
                ),
                SizedBox(height: 10 * scale),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${pricing.regularPrice}/year',
                        style: TextStyle(
                          color: const Color(0xFF918A95),
                          fontSize: 11.5 * scale,
                          decoration: TextDecoration.lineThrough,
                          decorationColor: const Color(0xFFB0A8B2),
                        ),
                      ),
                      SizedBox(width: 11 * scale),
                      ShaderMask(
                        blendMode: BlendMode.srcIn,
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [VideoFormStyle.pink, VideoFormStyle.accent],
                        ).createShader(bounds),
                        child: Text(
                          pricing.salePrice,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 29 * scale,
                            height: 0.95,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Text(
                        '/year',
                        style: TextStyle(
                          color: const Color(0xFFC8C1CB),
                          fontSize: 11 * scale,
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
            padding: EdgeInsets.symmetric(
              horizontal: 12 * scale,
              vertical: 6 * scale,
            ),
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(21),
                bottomLeft: Radius.circular(20),
              ),
              gradient: LinearGradient(
                colors: [VideoFormStyle.pink, VideoFormStyle.accent],
              ),
            ),
            child: Text(
              'SAVE ${pricing.savingsPercent}%',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10 * scale,
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
    final scale = _saleScale(context);
    return Container(
      width: 32 * scale,
      height: 32 * scale,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF171531),
        border: Border.all(color: VideoFormStyle.pink),
      ),
      child: Icon(Icons.check_rounded, color: Colors.white, size: 20 * scale),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scale = _saleScale(context);
    return Container(
      key: const Key('yearlySalePurchaseButton'),
      constraints: BoxConstraints(minHeight: (54 * scale).clamp(50, 62)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13 * scale),
        gradient: VideoFormStyle.gradient,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(13 * scale),
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
                    busy ? 'Processing...' : 'Upgrade to Annual',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16 * scale,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (!busy) ...[
                    SizedBox(width: 12 * scale),
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 22 * scale,
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
    final scale = _saleScale(context);
    return Center(
      child: TextButton.icon(
        onPressed: onTap,
        iconAlignment: IconAlignment.end,
        icon: Icon(icon, color: const Color(0xFFD17CAC), size: 19 * scale),
        label: Text(
          label,
          style: TextStyle(
            color: const Color(0xFFD17CAC),
            fontSize: 13 * scale,
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
    final scale = _saleScale(context);
    return Container(
      key: const Key('yearlySaleBuyCreditsButton'),
      constraints: BoxConstraints(minHeight: (58 * scale).clamp(54, 66)),
      padding: const EdgeInsets.all(1.1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13 * scale),
        gradient: const LinearGradient(
          colors: [
            VideoFormStyle.pink,
            VideoFormStyle.accent,
            Color(0xFF8690D1),
          ],
        ),
      ),
      child: Material(
        color: const Color(0xF2312E42),
        borderRadius: BorderRadius.circular(12 * scale),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 13 * scale,
              vertical: 7 * scale,
            ),
            child: Row(
              children: [
                Image.asset(
                  'assets/images/in_app_purchase/credit.png',
                  width: 42 * scale,
                  height: 36 * scale,
                  fit: BoxFit.contain,
                  excludeFromSemantics: true,
                ),
                SizedBox(width: 10 * scale),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Buy more credits',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15 * scale,
                          height: 1.15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 29 * scale,
                  height: 29 * scale,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: VideoFormStyle.gradient,
                  ),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white,
                    size: 20 * scale,
                  ),
                ),
              ],
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
    final style = TextStyle(
      color: const Color(0xFFB8B0BC),
      fontSize: 9 * _saleScale(context),
    );
    return FittedBox(
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
              minimumSize: Size.zero,
              padding: EdgeInsets.zero,
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
      color: VideoFormStyle.accent,
    );
  }
}

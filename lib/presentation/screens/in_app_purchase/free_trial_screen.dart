import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

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

const _trialBackground = Color(0xFF02050E);
const _trialSurface = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF101321), Color(0xFF080D19)],
);
const _trialAccent = LinearGradient(
  colors: [Color(0xFFEC4F94), Color(0xFFA850CF), Color(0xFF4E62E3)],
);

double _trialScale(BuildContext context) =>
    (MediaQuery.sizeOf(context).width / 393).clamp(0.8, 1.3);

class FreeTrialScreen extends ConsumerStatefulWidget {
  const FreeTrialScreen({super.key, this.returnPurchaseResult = false});

  final bool returnPurchaseResult;

  static Future<bool?> open(
    BuildContext context, {
    bool returnPurchaseResult = false,
  }) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) =>
            FreeTrialScreen(returnPurchaseResult: returnPurchaseResult),
      ),
    );
  }

  @override
  ConsumerState<FreeTrialScreen> createState() => _FreeTrialScreenState();
}

class _FreeTrialScreenState extends ConsumerState<FreeTrialScreen> {
  AppPackage? _lastAttemptedPackage;
  bool _purchaseStarted = false;

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final purchaseState = ref.watch(purchaseControllerProvider);
    ref.listen<PurchaseState>(purchaseControllerProvider, _onPurchaseState);
    final weeklyPackage = ref
        .watch(packageCatalogProvider)
        ?.forPlatform(profile?.platform)
        ?.weeklySubscription;
    final storePrice = weeklyPackage == null
        ? null
        : recurringSubscriptionPrice(
            purchaseState.products[weeklyPackage.productId],
          );
    final weeklyPrice =
        storePrice ??
        (weeklyPackage == null
            ? 'VND 210,000'
            : '\$${weeklyPackage.price.toStringAsFixed(2)}');
    final scale = _trialScale(context);

    return Scaffold(
      backgroundColor: _trialBackground,
      body: Stack(
        children: [
          const Positioned.fill(child: _ScreenBackground()),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: CustomScrollView(
                  key: const PageStorageKey('freeTrialScroll'),
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        30 * scale,
                        0,
                        30 * scale,
                        4 * scale,
                      ),
                      sliver: SliverList.list(
                        children: [
                          const _Hero(),
                          const _Title(),
                          SizedBox(height: 7 * scale),
                          Text(
                            'Try premium video tools free for 3 days,\n'
                            'then continue only if you love it.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: const Color(0xFFAAA6B6),
                              fontSize: 12.5 * scale,
                              height: 1.35,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          SizedBox(height: 12 * scale),
                          Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10 * scale,
                            ),
                            child: const _TrialTimeline(),
                          ),
                          SizedBox(height: 8 * scale),
                          _PriceOffer(
                            price: weeklyPrice,
                            onTap: () => _openBuyCredits(context),
                          ),
                          SizedBox(height: 8 * scale),
                          _PrimaryButton(
                            key: const Key('trialClaimButton'),
                            busy: purchaseState.isBusy,
                            onTap: purchaseState.isBusy
                                ? null
                                : () => _startWeeklyTrial(weeklyPackage),
                          ),
                          SizedBox(height: 7 * scale),
                          _ViewPlansButton(onTap: () => _openAllPlans(context)),
                          SizedBox(height: 5 * scale),
                          _LegalFooter(
                            restoring:
                                purchaseState.status ==
                                PurchaseFlowStatus.restoring,
                            onRestore: purchaseState.isBusy
                                ? null
                                : _restorePurchases,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 2 * scale,
            left: 12 * scale,
            child: _CloseButton(onTap: () => Navigator.maybePop(context)),
          ),
        ],
      ),
    );
  }

  Future<void> _restorePurchases() async {
    await ref.read(purchaseControllerProvider.notifier).restore();
    if (!mounted) return;
    final message = ref.read(purchaseControllerProvider).message;
    if (message != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _startWeeklyTrial(AppPackage? package) {
    if (package == null || package.productId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The weekly plan is unavailable.')),
      );
      return;
    }
    _lastAttemptedPackage = package;
    _purchaseStarted = true;
    ref
        .read(purchaseControllerProvider.notifier)
        .buy(productId: package.productId, consumable: false);
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
        final message = next.message ?? 'Your free trial has started.';
        final messenger = ScaffoldMessenger.of(context);
        await Navigator.maybePop(context, true);
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
    final error = ApiException(
      message: state.message ?? 'Unable to start the free trial.',
      errorCode: state.errorCode,
    );
    final action = await GenerationFailureDialog.showForPurchaseError(
      context,
      error: error,
      fallbackMessage: 'We could not start your free trial. Please try again.',
    );
    if (!mounted) return;
    switch (action) {
      case GenerationFailureAction.retry:
      case GenerationFailureAction.renewSubscription:
        _startWeeklyTrial(_lastAttemptedPackage);
      case GenerationFailureAction.buyCredits:
        _purchaseStarted = false;
        await _openBuyCredits(context);
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

  Future<void> _openAllPlans(BuildContext context) async {
    final purchased = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) =>
            AllPlans(returnPurchaseResult: widget.returnPurchaseResult),
      ),
    );
    if (purchased == true && mounted && widget.returnPurchaseResult) {
      Navigator.of(this.context).pop(true);
    }
  }

  Future<void> _openBuyCredits(BuildContext context) async {
    final purchased = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) =>
            BuyCredits(returnPurchaseResult: widget.returnPurchaseResult),
      ),
    );
    if (purchased == true && mounted && widget.returnPurchaseResult) {
      Navigator.of(this.context).pop(true);
    }
  }
}

class _ScreenBackground extends StatelessWidget {
  const _ScreenBackground();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0.35, -0.85),
          radius: 0.9,
          colors: [Color(0xFF171331), Color(0xFF070B1D), _trialBackground],
          stops: [0, 0.4, 1],
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    final scale = _trialScale(context);
    return SizedBox(
      key: const Key('trialHero'),
      height: 130 * scale,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            top: -12 * scale,
            bottom: -5 * scale,
            left: 42 * scale,
            right: 9 * scale,
            child: Image.asset(
              'assets/images/in_app_purchase/free_trailer_icon_banner.png',
              fit: BoxFit.contain,
              excludeFromSemantics: true,
            ),
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
    final scale = _trialScale(context);
    return SizedBox(
      key: const Key('trialLaterButton'),
      width: 44,
      height: 44,
      child: IconButton(
        onPressed: onTap,
        tooltip: 'Close',
        padding: EdgeInsets.zero,
        icon: Container(
          width: 33 * scale,
          height: 33 * scale,
          padding: const EdgeInsets.all(0.6),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF8D82DA), Color(0xFFE1C9D5), Color(0xFFD16D54)],
            ),
          ),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF080C15),
            ),
            child: Center(
              child: SvgPicture.asset(
                'assets/svgs/purchase_close.svg',
                width: 23 * scale,
                height: 23 * scale,
                excludeFromSemantics: true,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title();

  @override
  Widget build(BuildContext context) {
    final scale = _trialScale(context);
    return Column(
      key: const Key('trialTitle'),
      children: [
        Text(
          'How your',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Times New Roman',
            fontSize: 34 * scale,
            height: 1,
            fontWeight: FontWeight.w400,
            letterSpacing: -0.7,
          ),
        ),
        SizedBox(height: 2 * scale),
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: _trialAccent.createShader,
          child: Text(
            'free trial works',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'Times New Roman',
              fontSize: 37 * scale,
              height: 1,
              fontWeight: FontWeight.w400,
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
      description: 'We’ll remind you before\nyour free trial ends.',
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
  Widget build(BuildContext context) => Column(
    key: const Key('trialTimeline'),
    children: [for (final step in _steps) _TimelineStep(data: step)],
  );
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
    final scale = _trialScale(context);
    final last = data.number == 3;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 32 * scale,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                if (!last)
                  Positioned(
                    top: 20 * scale,
                    bottom: -20 * scale,
                    width: scale,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFF9960DC), Color(0xFFEB4F9B)],
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.only(top: 5 * scale),
                  child: Container(
                    key: ValueKey('trialStepNumber-${data.number}'),
                    width: 30 * scale,
                    height: 30 * scale,
                    padding: const EdgeInsets.all(0.7),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFFE3CADF),
                          const Color(0xFFC984B9),
                          last
                              ? const Color(0xFFD5725E)
                              : const Color(0xFF9472BF),
                        ],
                      ),
                    ),
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF080C16),
                      ),
                      child: Center(
                        child: Text(
                          '${data.number}',
                          style: TextStyle(
                            color: const Color(0xFFF4F2FA),
                            fontSize: 16 * scale,
                            height: 1,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 14 * scale),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 5 * scale),
              child: Container(
                key: ValueKey('trialStepCard-${data.number}'),
                constraints: BoxConstraints(minHeight: 65 * scale),
                padding: EdgeInsets.symmetric(
                  horizontal: 12 * scale,
                  vertical: 7 * scale,
                ),
                decoration: BoxDecoration(
                  gradient: _trialSurface,
                  borderRadius: BorderRadius.circular(11 * scale),
                  border: Border.all(
                    color: const Color(0xFF3C3D4E),
                    width: 0.6,
                  ),
                ),
                child: Row(
                  children: [
                    Image.asset(
                      data.asset,
                      width: 50 * scale,
                      height: 50 * scale,
                      excludeFromSemantics: true,
                    ),
                    SizedBox(width: 14 * scale),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data.title,
                            style: TextStyle(
                              color: const Color(0xFFF3F1F9),
                              fontSize: 15 * scale,
                              height: 1.15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 4 * scale),
                          Text(
                            data.description,
                            style: TextStyle(
                              color: const Color(0xFFAAA6B7),
                              fontSize: 10.5 * scale,
                              height: 1.35,
                            ),
                          ),
                        ],
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
}

class _PriceOffer extends StatelessWidget {
  const _PriceOffer({required this.price, required this.onTap});

  final String price;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scale = _trialScale(context);
    return Semantics(
      button: true,
      label: 'View credit packages',
      child: Container(
        key: const Key('trialOfferSurface'),
        constraints: BoxConstraints(minHeight: 88 * scale),
        padding: const EdgeInsets.all(0.6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(11 * scale),
          gradient: _trialAccent,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(11 * scale - 0.6),
          clipBehavior: Clip.antiAlias,
          child: Ink(
            decoration: const BoxDecoration(gradient: _trialSurface),
            child: InkWell(
              key: const Key('trialPriceOffer'),
              onTap: onTap,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 8 * scale,
                  vertical: 7 * scale,
                ),
                child: Row(
                  children: [
                    Image.asset(
                      'assets/images/in_app_purchase/discount_free_trailer.png',
                      width: 111 * scale,
                      height: 72 * scale,
                      fit: BoxFit.contain,
                      excludeFromSemantics: true,
                    ),
                    Container(
                      width: 0.7,
                      height: 62 * scale,
                      margin: EdgeInsets.symmetric(horizontal: 10 * scale),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFFD16B99), Color(0xFF7042AE)],
                        ),
                      ),
                    ),
                    Expanded(child: _PriceCopy(price: price)),
                  ],
                ),
              ),
            ),
          ),
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
    final scale = _trialScale(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _GradientTint(
          child: Text(
            'Free trial for 3 days',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11 * scale,
              height: 1.25,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        SizedBox(height: 4 * scale),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text.rich(
            key: const Key('trialWeeklyPrice'),
            TextSpan(
              text: price,
              children: [
                TextSpan(
                  text: ' /week',
                  style: TextStyle(
                    fontSize: 9.5 * scale,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
            maxLines: 1,
            style: TextStyle(
              color: const Color(0xFFF3F1FB),
              fontSize: 22 * scale,
              height: 1.1,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        SizedBox(height: 5 * scale),
        Container(
          key: const Key('trialDiscountBadge'),
          padding: const EdgeInsets.all(0.5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12 * scale),
            gradient: _trialAccent,
          ),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: 7 * scale,
              vertical: 3 * scale,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12 * scale - 0.5),
              color: const Color(0xFF0E1120),
            ),
            child: _GradientTint(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.local_offer_rounded,
                      color: Colors.white,
                      size: 11 * scale,
                    ),
                    SizedBox(width: 5 * scale),
                    Text(
                      '50% OFF for a limited time',
                      maxLines: 1,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9.5 * scale,
                        height: 1.2,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GradientTint extends StatelessWidget {
  const _GradientTint({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ShaderMask(
    blendMode: BlendMode.srcIn,
    shaderCallback: _trialAccent.createShader,
    child: child,
  );
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({super.key, required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scale = _trialScale(context);
    return Container(
      key: const Key('trialClaimSurface'),
      constraints: BoxConstraints(minHeight: (38 * scale).clamp(44, 54)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12 * scale),
        gradient: const LinearGradient(
          colors: [Color(0xFFDF458D), Color(0xFF9044AD), Color(0xFF3553D2)],
        ),
        boxShadow: const [BoxShadow(color: Color(0x26C83C93), blurRadius: 14)],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12 * scale),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 14 * scale,
              vertical: 7 * scale,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (busy)
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                else
                  Image.asset(
                    'assets/images/in_app_purchase/credit.png',
                    width: 28 * scale,
                    height: 24 * scale,
                    excludeFromSemantics: true,
                  ),
                SizedBox(width: 12 * scale),
                Flexible(
                  child: Text(
                    busy ? 'Processing...' : 'Start my 3-day free trial',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12.5 * scale,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                    ),
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

class _ViewPlansButton extends StatelessWidget {
  const _ViewPlansButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scale = _trialScale(context);
    return Container(
      key: const Key('viewAllPlansButton'),
      constraints: BoxConstraints(minHeight: (35 * scale).clamp(44, 50)),
      padding: const EdgeInsets.all(0.6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(11 * scale),
        gradient: _trialAccent,
      ),
      child: Material(
        color: _trialBackground,
        borderRadius: BorderRadius.circular(11 * scale - 0.6),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 12 * scale,
              vertical: 9 * scale,
            ),
            child: Center(
              child: _GradientTint(
                child: Text(
                  'View all plans',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13 * scale,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LegalFooter extends StatelessWidget {
  const _LegalFooter({required this.restoring, required this.onRestore});

  final bool restoring;
  final VoidCallback? onRestore;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: const Color(0xFF9995A5),
      fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
      fontSize: 9 * _trialScale(context),
      fontWeight: FontWeight.w400,
    );

    return FittedBox(
      key: const Key('trialLegalFooter'),
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          _LegalWebLink(
            label: 'Privacy',
            page: AppWebPage.privacy,
            style: style,
          ),
          const _FooterDivider(),
          TextButton(
            key: const Key('trialRestoreButton'),
            onPressed: onRestore,
            style: _legalButtonStyle(style),
            child: Text(restoring ? 'Restoring...' : 'Restore Purchase'),
          ),
          const _FooterDivider(),
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

ButtonStyle _legalButtonStyle(TextStyle style) => TextButton.styleFrom(
  foregroundColor: style.color,
  textStyle: style,
  padding: EdgeInsets.zero,
  minimumSize: const Size(0, 28),
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
);

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
  Widget build(BuildContext context) => TextButton(
    onPressed: () => AppWebViewScreen.open(context, page),
    style: _legalButtonStyle(style),
    child: Text(label),
  );
}

class _FooterDivider extends StatelessWidget {
  const _FooterDivider();

  @override
  Widget build(BuildContext context) => Container(
    width: 0.6,
    height: 10,
    margin: const EdgeInsets.symmetric(horizontal: 18),
    color: const Color(0xFF8C8798),
  );
}

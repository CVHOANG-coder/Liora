import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../data/models/package_catalog.dart';
import '../../providers/package_provider.dart';
import '../../providers/purchase_provider.dart';
import '../../widgets/generation_failure_dialog.dart';
import '../support/app_web_view_screen.dart';
import '../support/support_contact_screen.dart';
import 'all_plans_screen.dart';
import 'in_app_purchase_screen.dart';

const _background = Color(0xFF02050E);
const _accent = LinearGradient(
  colors: [Color(0xFFEF50AC), Color(0xFFAD62EC), Color(0xFF586DFF)],
);
const _assetRoot = 'assets/images/in_app_purchase/';

class WeeklySaleScreen extends ConsumerStatefulWidget {
  const WeeklySaleScreen({super.key, this.returnPurchaseResult = false});
  final bool returnPurchaseResult;

  static Future<bool?> open(
    BuildContext context, {
    bool returnPurchaseResult = false,
  }) => Navigator.of(context).push<bool>(
    MaterialPageRoute<bool>(
      builder: (_) =>
          WeeklySaleScreen(returnPurchaseResult: returnPurchaseResult),
    ),
  );

  @override
  ConsumerState<WeeklySaleScreen> createState() => _WeeklySaleScreenState();
}

class _WeeklySaleScreenState extends ConsumerState<WeeklySaleScreen>
    with SingleTickerProviderStateMixin {
  AppPackage? _lastAttemptedPackage;
  bool _purchaseStarted = false;
  late final AnimationController _entrance;
  late final List<Animation<double>> _reveals;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    );
    _reveals = List.generate(
      10,
      (index) => _entrance.drive(
        CurveTween(
          curve: Interval(
            index * 0.09,
            (index * 0.09 + 0.19).clamp(0, 1),
            curve: Curves.easeOutCubic,
          ),
        ),
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _entrance.value = 1;
    } else if (_entrance.isDismissed) {
      _entrance.forward();
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  Widget _reveal(int index, Widget child) =>
      _SaleReveal(progress: _reveals[index], child: child);

  @override
  Widget build(BuildContext context) {
    final purchase = ref.watch(purchaseControllerProvider);
    ref.listen<PurchaseState>(purchaseControllerProvider, _onPurchaseState);
    final packages = ref
        .watch(packageCatalogProvider)
        ?.forPlatform(ref.watch(iapCatalogPlatformProvider));
    final sale = packages?.weeklyBonusSubscription;
    final price = sale == null
        ? '—'
        : purchase.products[sale.productId]?.price ??
              '\$${sale.price.toStringAsFixed(2)}';
    final scale = (MediaQuery.sizeOf(context).width.clamp(0, 560) / 393).clamp(
      0.8,
      1.3,
    );
    Widget gap(double height) => SizedBox(height: height * scale);
    Text text(
      String value,
      double size, {
      Color color = Colors.white,
      FontWeight weight = FontWeight.w700,
    }) => Text(
      value,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontFamily: 'Nunito',
        fontSize: size * scale,
        height: 1.15,
        fontWeight: weight,
        color: color,
      ),
    );
    return Scaffold(
      backgroundColor: _background,
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.2, -0.9),
                  radius: 1.1,
                  colors: [Color(0xFF191333), Color(0xFF080B1C), _background],
                  stops: [0, 0.45, 1],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: CustomScrollView(
                  key: const Key('weeklySaleScroll'),
                  slivers: [
                    SliverPadding(
                      padding: EdgeInsets.symmetric(horizontal: 13 * scale),
                      sliver: SliverList.list(
                        children: [
                          gap(4),
                          _reveal(
                            0,
                            SizedBox(
                              height: 142 * scale,
                              child: Image.asset(
                                '${_assetRoot}free_trailer_icon_banner.png',
                                fit: BoxFit.contain,
                                excludeFromSemantics: true,
                              ),
                            ),
                          ),
                          _reveal(
                            1,
                            Center(
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 14 * scale,
                                  vertical: 4 * scale,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(
                                    10 * scale,
                                  ),
                                  border: Border.all(
                                    color: const Color(0xFFF8E3FF),
                                  ),
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFE6A4F6),
                                      Color(0xFFC5C2FF),
                                    ],
                                  ),
                                ),
                                child: text(
                                  'FIRST PURCHASE ONLY',
                                  11,
                                  color: const Color(0xFF170D30),
                                  weight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                          gap(5),
                          // text('Your first week,', 31, weight: FontWeight.w800),
                          _reveal(
                            2,
                            Center(
                              child: Text.rich(
                                TextSpan(
                                  text: 'a little more ',
                                  children: [
                                    WidgetSpan(
                                      alignment: PlaceholderAlignment.baseline,
                                      baseline: TextBaseline.alphabetic,
                                      child: ShaderMask(
                                        shaderCallback: _accent.createShader,
                                        child: text(
                                          'PRO.',
                                          31,
                                          weight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'Nunito',
                                  fontSize: 31 * scale,
                                  height: 1.15,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                          gap(12),
                          _reveal(
                            3,
                            _OfferPulse(
                              entrance: _entrance,
                              child: _SaleFrame(
                                key: const Key('weeklySalePriceCard'),
                                borderWidth: 1.5,
                                radius: 15 * scale,
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                    vertical: 8 * scale,
                                    horizontal: 12 * scale,
                                  ),
                                  child: Column(
                                    children: [
                                      text(
                                        'WEEKLY PRO',
                                        20,
                                        color: const Color(0xFFEAC5F8),
                                        weight: FontWeight.w900,
                                      ),
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          price,
                                          key: const Key('weeklySalePrice'),
                                          style: TextStyle(
                                            fontFamily: 'Nunito',
                                            color: Colors.white,
                                            fontSize: 72 * scale,
                                            height: 0.98,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                      text(
                                        'for your first week',
                                        20,
                                        color: const Color(0xFFEAC5F8),
                                        weight: FontWeight.w800,
                                      ),
                                      // gap(7),
                                      // text(
                                      //   'Intro price available once per account.',
                                      //   12.5,
                                      //   color: const Color(0xFFC2BDD1),
                                      //   weight: FontWeight.w400,
                                      // ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          gap(9),
                          _reveal(
                            4,
                            _Benefit(
                              asset: 'today_free_trailer.png',
                              label: 'Unlock premium video tools',
                              scale: scale,
                            ),
                          ),
                          gap(8),
                          _reveal(
                            5,
                            _Benefit(
                              asset: 'day3_free_trailer.png',
                              label: 'Create more with PRO',
                              scale: scale,
                            ),
                          ),
                          gap(10),
                          _reveal(
                            6,
                            _SaleFrame(
                              radius: 12 * scale,
                              child: InkWell(
                                key: const Key('weeklySaleCreditsButton'),
                                borderRadius: BorderRadius.circular(12 * scale),
                                onTap: () => _openBuyCredits(context),
                                child: Padding(
                                  padding: EdgeInsets.all(9 * scale),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: Image.asset(
                                          '${_assetRoot}discount_free_trailer.png',
                                          height: 65 * scale,
                                          fit: BoxFit.contain,
                                          excludeFromSemantics: true,
                                        ),
                                      ),
                                      Container(
                                        width: 0.7,
                                        height: 62 * scale,
                                        margin: EdgeInsets.symmetric(
                                          horizontal: 10 * scale,
                                        ),
                                        color: const Color(0xFFB46EBF),
                                      ),
                                      Expanded(
                                        flex: 6,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            text(
                                              '50% OFF extra credits',
                                              17,
                                              weight: FontWeight.w800,
                                            ),
                                            gap(3),
                                            Text(
                                              'When your Weekly PRO plan is active.',
                                              style: TextStyle(
                                                fontSize: 11.5 * scale,
                                                color: const Color(0xFFC2BDD1),
                                                height: 1.25,
                                              ),
                                            ),
                                            gap(7),
                                            Container(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 9 * scale,
                                                vertical: 3 * scale,
                                              ),
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                                border: Border.all(
                                                  color: const Color(
                                                    0xFFED71CB,
                                                  ),
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.local_offer_rounded,
                                                    size: 12 * scale,
                                                    color: const Color(
                                                      0xFFF5E0FF,
                                                    ),
                                                  ),
                                                  SizedBox(width: 5 * scale),
                                                  Flexible(
                                                    child: text(
                                                      'Buy Credits',
                                                      12.5,
                                                    ),
                                                  ),
                                                  Icon(
                                                    Icons.chevron_right_rounded,
                                                    size: 18 * scale,
                                                    color: Colors.white,
                                                  ),
                                                ],
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
                          ),
                          gap(14),
                          _reveal(
                            7,
                            SizedBox(
                              height: 49 * scale,
                              child: FilledButton(
                                key: const Key('weeklySalePurchaseButton'),
                                onPressed: purchase.isBusy
                                    ? null
                                    : () => _startWeeklySale(sale),
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFFA64FF2),
                                  disabledBackgroundColor: const Color(
                                    0xFF7038A3,
                                  ),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      13 * scale,
                                    ),
                                  ),
                                ),
                                child: purchase.isBusy
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: text(
                                          'Get Weekly PRO for $price',
                                          19,
                                          weight: FontWeight.w800,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                          gap(6),

                          _reveal(
                            8,
                            _SaleFrame(
                              radius: 12 * scale,
                              child: TextButton(
                                key: const Key('weeklySalePlansButton'),
                                onPressed: () => _openAllPlans(context),
                                style: TextButton.styleFrom(
                                  minimumSize: Size.fromHeight(42 * scale),
                                  foregroundColor: Colors.white,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Flexible(child: text('View All Plans', 16)),
                                    SizedBox(width: 8 * scale),
                                    const Icon(Icons.chevron_right_rounded),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // gap(11),
                          // text(
                          //   'First week only. Then renews at ${renewal == null ? 'the regular weekly price' : '$renewal/week'}.\nCancel anytime.',
                          //   11.5,
                          //   color: const Color(0xFFC2BDD1),
                          //   weight: FontWeight.w400,
                          // ),
                          gap(5),
                          _reveal(
                            9,
                            Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children:
                                  [
                                        TextButton(
                                          onPressed: () =>
                                              AppWebViewScreen.open(
                                                context,
                                                AppWebPage.privacy,
                                              ),
                                          child: const Text('Privacy'),
                                        ),
                                        const Text(
                                          '|',
                                          style: TextStyle(
                                            color: Color(0xFF9995A5),
                                          ),
                                        ),
                                        TextButton(
                                          key: const Key(
                                            'weeklySaleRestoreButton',
                                          ),
                                          onPressed: purchase.isBusy
                                              ? null
                                              : _restorePurchases,
                                          child: Text(
                                            purchase.status ==
                                                    PurchaseFlowStatus.restoring
                                                ? 'Restoring...'
                                                : 'Restore Purchase',
                                          ),
                                        ),
                                        const Text(
                                          '|',
                                          style: TextStyle(
                                            color: Color(0xFF9995A5),
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              AppWebViewScreen.open(
                                                context,
                                                AppWebPage.terms,
                                              ),
                                          child: const Text('Terms of Service'),
                                        ),
                                      ]
                                      .map(
                                        (child) => DefaultTextStyle.merge(
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontFamily: 'Nunito',
                                            color: Color(0xFF9995A5),
                                          ),
                                          child: TextButtonTheme(
                                            data: TextButtonThemeData(
                                              style: TextButton.styleFrom(
                                                foregroundColor: const Color(
                                                  0xFF9995A5,
                                                ),
                                                textStyle: const TextStyle(
                                                  fontSize: 11,
                                                  fontFamily: 'Nunito',
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                    ),
                                                minimumSize: const Size(0, 44),
                                              ),
                                            ),
                                            child: child,
                                          ),
                                        ),
                                      )
                                      .toList(),
                            ),
                          ),
                          gap(3),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top,
            left: 11 * scale,
            child: IconButton(
              key: const Key('weeklySaleCloseButton'),
              tooltip: 'Close',
              onPressed: () => Navigator.maybePop(context),
              icon: Container(
                width: 33 * scale,
                height: 33 * scale,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE7C1F2)),
                  color: const Color(0xFF080B16),
                ),
                child: Icon(
                  Icons.close_rounded,
                  size: 28 * scale,
                  color: Colors.white,
                ),
              ),
            ),
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

  void _startWeeklySale(AppPackage? package) {
    if (package == null || package.productId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The weekly sale is currently unavailable.'),
        ),
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
        final message = next.message ?? 'Your Weekly Pro plan is now active.';
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
      message: state.message ?? 'Unable to purchase the weekly offer.',
      errorCode: state.errorCode,
    );
    final action = await GenerationFailureDialog.showForPurchaseError(
      context,
      error: error,
      fallbackMessage: 'We could not complete your purchase. Please try again.',
    );
    if (!mounted) return;
    switch (action) {
      case GenerationFailureAction.retry:
      case GenerationFailureAction.renewSubscription:
        _startWeeklySale(_lastAttemptedPackage);
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

class _SaleReveal extends StatelessWidget {
  const _SaleReveal({required this.progress, required this.child});
  final Animation<double> progress;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: progress,
    child: child,
    builder: (context, child) => IgnorePointer(
      ignoring: progress.value < 1,
      child: Opacity(
        opacity: progress.value,
        child: Transform.translate(
          offset: Offset(0, (1 - progress.value) * 12),
          child: child,
        ),
      ),
    ),
  );
}

/// A seamless sinusoidal zoom with continuous velocity between cycles.
class _OfferPulse extends StatefulWidget {
  const _OfferPulse({required this.child, required this.entrance});

  final Animation<double> entrance;

  final Widget child;

  @override
  State<_OfferPulse> createState() => _OfferPulseState();
}

class _OfferPulseState extends State<_OfferPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  bool _enabled = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _scale = _controller.drive(_SmoothPulseScale());
    widget.entrance.addStatusListener(_onEntranceStatus);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncEnabled();
  }

  void _onEntranceStatus(AnimationStatus status) => _syncEnabled();

  void _syncEnabled() {
    final enabled =
        widget.entrance.isCompleted &&
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled;
    if (_enabled == enabled) return;
    _enabled = enabled;
    if (enabled) {
      _controller.repeat();
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    widget.entrance.removeStatusListener(_onEntranceStatus);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(
    key: const Key('weeklySalePulse'),
    scale: _scale,
    child: widget.child,
  );
}

class _SmoothPulseScale extends Animatable<double> {
  @override
  double transform(double t) => 1 + 0.04 * math.sin(2 * math.pi * t);
}

class _SaleFrame extends StatelessWidget {
  const _SaleFrame({
    super.key,
    required this.child,
    required this.radius,
    this.borderWidth = 0.7,
  });
  final Widget child;
  final double radius;
  final double borderWidth;
  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(borderWidth),
    decoration: BoxDecoration(
      gradient: _accent,
      borderRadius: BorderRadius.circular(radius),
    ),
    child: Material(
      clipBehavior: Clip.antiAlias,
      borderRadius: BorderRadius.circular(radius - borderWidth),
      color: const Color(0xFF0C0D20),
      child: child,
    ),
  );
}

class _Benefit extends StatelessWidget {
  const _Benefit({
    required this.asset,
    required this.label,
    required this.scale,
  });
  final String asset;
  final String label;
  final double scale;
  @override
  Widget build(BuildContext context) => Container(
    constraints: BoxConstraints(minHeight: 41 * scale),
    padding: EdgeInsets.symmetric(horizontal: 15 * scale, vertical: 2 * scale),
    decoration: BoxDecoration(
      color: const Color(0xFF0D111C),
      borderRadius: BorderRadius.circular(12 * scale),
      border: Border.all(color: const Color(0xFF393B4D), width: 0.7),
    ),
    child: Row(
      children: [
        Image.asset(
          '$_assetRoot$asset',
          width: 48 * scale,
          height: 37 * scale,
          fit: BoxFit.contain,
          excludeFromSemantics: true,
        ),
        SizedBox(width: 13 * scale),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Nunito',
              color: Colors.white,
              fontSize: 14.5 * scale,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

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
import 'free_trial_screen.dart';

const _creditBackground = Color(0xFF02050C);
const _creditSurface = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF0D1020), Color(0xFF080C17)],
);
const _creditAccent = LinearGradient(
  colors: [Color(0xFFEC5FB6), Color(0xFFA850CF), Color(0xFF4561DF)],
);
const _creditBorder = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF655683), Color(0xFF292C3C), Color(0xFF242838)],
);

double _creditScale(BuildContext context) =>
    (MediaQuery.sizeOf(context).width / 393).clamp(0.8, 1.3);

class BuyCredits extends ConsumerStatefulWidget {
  const BuyCredits({super.key, this.returnPurchaseResult = false});

  final bool returnPurchaseResult;

  @override
  ConsumerState<BuyCredits> createState() => _BuyCreditsState();
}

class _BuyCreditsState extends ConsumerState<BuyCredits> {
  static const _fallbackPackages = [
    _CreditPackage(
      credits: 70,
      price: 'VND 136,000',
      productId: 'com.nostalia.ai.videogenerator.70_credits',
    ),
    _CreditPackage(
      credits: 150,
      price: 'VND 273,000',
      productId: 'com.nostalia.ai.videogenerator.150_credits',
    ),
    _CreditPackage(
      credits: 500,
      price: 'VND 682,000',
      productId: 'com.nostalia.ai.videogenerator.500_credits',
    ),
    _CreditPackage(
      credits: 1000,
      price: 'VND 1,350,000',
      productId: 'com.nostalia.ai.videogenerator.1000_credits',
      tag: _PackageTag.popular,
    ),
    _CreditPackage(
      credits: 5000,
      price: 'VND 5,250,000',
      productId: 'com.nostalia.ai.videogenerator.5000_credits',
      tag: _PackageTag.bestValue,
    ),
  ];

  int _selectedIndex = 4;
  _CreditPackage? _lastAttemptedPackage;
  bool _purchaseStarted = false;

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final purchaseState = ref.watch(purchaseControllerProvider);
    ref.listen<PurchaseState>(purchaseControllerProvider, _onPurchaseState);
    final platformPackages = ref
        .watch(packageCatalogProvider)
        ?.forPlatform(profile?.platform);
    final apiPackages = platformPackages?.creditsFor(
      isSubscribed: profile?.isSubscribed == true,
    );
    final catalogPackages = apiPackages == null || apiPackages.isEmpty
        ? _fallbackPackages
        : _creditPackagesFromApi(apiPackages);
    final packages = catalogPackages
        .map(
          (package) => package.copyWith(
            price: purchaseState.products[package.productId]?.price,
          ),
        )
        .toList(growable: false);
    final selectedIndex = _selectedIndex.clamp(0, packages.length - 1);
    final scale = _creditScale(context);

    return Scaffold(
      backgroundColor: _creditBackground,
      body: Stack(
        children: [
          const Positioned.fill(child: _ScreenGlow()),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        18 * scale,
                        4 * scale,
                        18 * scale,
                        14 * scale,
                      ),
                      child: _PurchaseHeader(
                        onClose: () => Navigator.maybePop(context),
                      ),
                    ),
                    Expanded(
                      child: CustomScrollView(
                        key: const PageStorageKey('buyCreditsScroll'),
                        physics: const BouncingScrollPhysics(),
                        slivers: [
                          SliverPadding(
                            padding: EdgeInsets.fromLTRB(
                              18 * scale,
                              4 * scale,
                              18 * scale,
                              8 * scale,
                            ),
                            sliver: SliverList.list(
                              children: [
                                for (
                                  var index = 0;
                                  index < packages.length;
                                  index++
                                ) ...[
                                  _CreditPackageTile(
                                    package: packages[index],
                                    selected: index == selectedIndex,
                                    onTap: purchaseState.isBusy
                                        ? null
                                        : () => setState(
                                            () => _selectedIndex = index,
                                          ),
                                  ),
                                  if (index != packages.length - 1)
                                    SizedBox(height: 10 * scale),
                                ],
                                if (profile?.isSubscribed != true) ...[
                                  SizedBox(height: 10 * scale),
                                  _SubscriptionBanner(
                                    onTap: () => _openSubscriptionPlans(
                                      isVIP: profile?.isVIP == true,
                                    ),
                                  ),
                                ],
                                SizedBox(height: 14 * scale),
                                _BuyButton(
                                  label: _buyButtonLabel(purchaseState),
                                  busy: purchaseState.isBusy,
                                  onTap: purchaseState.isBusy
                                      ? null
                                      : () => _buy(packages[selectedIndex]),
                                ),
                                SizedBox(height: 8 * scale),
                                _PurchaseFooter(
                                  restoring:
                                      purchaseState.status ==
                                      PurchaseFlowStatus.restoring,
                                  onRestore: purchaseState.isBusy
                                      ? null
                                      : () => ref
                                            .read(
                                              purchaseControllerProvider
                                                  .notifier,
                                            )
                                            .restore(),
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
        ],
      ),
    );
  }

  Future<void> _buy(_CreditPackage package) {
    _lastAttemptedPackage = package;
    _purchaseStarted = true;
    return ref
        .read(purchaseControllerProvider.notifier)
        .buy(productId: package.productId ?? '', consumable: true);
  }

  Future<void> _openSubscriptionPlans({required bool isVIP}) {
    if (!isVIP) return FreeTrialScreen.open(context);
    return Navigator.of(
      context,
    ).push<void>(MaterialPageRoute<void>(builder: (_) => const AllPlans()));
  }

  String _buyButtonLabel(PurchaseState state) => switch (state.status) {
    PurchaseFlowStatus.connecting => 'Connecting to Google Play...',
    PurchaseFlowStatus.launching => 'Opening Google Play...',
    PurchaseFlowStatus.pending => 'Waiting for payment...',
    PurchaseFlowStatus.verifying => 'Verifying purchase...',
    PurchaseFlowStatus.restoring => 'Restoring purchases...',
    _ => 'Buy Now',
  };

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
    final attemptedProductId = _lastAttemptedPackage?.productId;
    if (_purchaseStarted &&
        next.productId != null &&
        attemptedProductId != null &&
        next.productId != attemptedProductId) {
      return;
    }
    if (next.status == PurchaseFlowStatus.error) {
      final error = ApiException(
        message: next.message!,
        errorCode: next.errorCode,
      );
      final action = await GenerationFailureDialog.showForPurchaseError(
        context,
        error: error,
        fallbackMessage:
            'We could not complete your credit purchase. Please try again.',
      );
      if (!mounted) return;
      switch (action) {
        case GenerationFailureAction.retry:
          final package = _lastAttemptedPackage;
          if (package != null) await _buy(package);
        case GenerationFailureAction.contactSupport:
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => SupportContactScreen(
                errorCode: next.errorCode,
                errorMessage: next.message,
              ),
            ),
          );
        case GenerationFailureAction.buyCredits:
        case GenerationFailureAction.renewSubscription:
        case GenerationFailureAction.chooseImage:
        case GenerationFailureAction.editInput:
        case GenerationFailureAction.chooseTheme:
        case GenerationFailureAction.close:
        case null:
          break;
      }
      return;
    }
    if (next.status == PurchaseFlowStatus.success && _purchaseStarted) {
      _purchaseStarted = false;
      if (widget.returnPurchaseResult) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.of(context).pop(true);
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(next.message!)));
        return;
      }
    }
    if (next.status == PurchaseFlowStatus.canceled) {
      _purchaseStarted = false;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(next.message!)));
  }
}

class _ScreenGlow extends StatelessWidget {
  const _ScreenGlow();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0.25, -0.7),
          radius: 0.9,
          colors: [Color(0xFF110B1F), _creditBackground],
          stops: [0, 0.72],
        ),
      ),
    );
  }
}

class _PurchaseHeader extends StatelessWidget {
  const _PurchaseHeader({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final scale = _creditScale(context);
    return SizedBox(
      key: const Key('buyCreditsHeader'),
      height: (44 * scale).clamp(44, 58),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: _CloseButton(onTap: onClose),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 48 * scale),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'Buy Credit',
                style: TextStyle(
                  color: const Color(0xFFF4F0FB),
                  fontFamily: 'Times New Roman',
                  fontSize: 25 * scale,
                  height: 1.15,
                  fontWeight: FontWeight.w400,
                  letterSpacing: -0.3,
                ),
              ),
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
    final scale = _creditScale(context);
    return SizedBox(
      key: const Key('buyCreditsCloseButton'),
      width: 44,
      height: 44,
      child: IconButton(
        tooltip: 'Close',
        onPressed: onTap,
        padding: EdgeInsets.zero,
        icon: Container(
          width: 34 * scale,
          height: 34 * scale,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: _creditSurface,
            border: Border.all(color: const Color(0xFF343440), width: 0.6),
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
    );
  }
}

enum _PackageTag { popular, bestValue }

class _CreditPackage {
  const _CreditPackage({
    required this.credits,
    required this.price,
    this.productId,
    this.tag,
  });

  final int credits;
  final String price;
  final String? productId;
  final _PackageTag? tag;

  _CreditPackage copyWith({String? price}) => _CreditPackage(
    credits: credits,
    price: price ?? this.price,
    productId: productId,
    tag: tag,
  );
}

List<_CreditPackage> _creditPackagesFromApi(List<AppPackage> packages) {
  return packages
      .map(
        (package) => _CreditPackage(
          credits: package.credit,
          price: '\$${package.price.toStringAsFixed(2)}',
          productId: package.productId,
          tag: package.credit >= 5000
              ? _PackageTag.bestValue
              : package.credit >= 1000
              ? _PackageTag.popular
              : null,
        ),
      )
      .toList(growable: false);
}

class _CreditPackageTile extends StatelessWidget {
  const _CreditPackageTile({
    required this.package,
    required this.selected,
    required this.onTap,
  });

  final _CreditPackage package;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scale = _creditScale(context);
    final largeText = MediaQuery.textScalerOf(context).scale(18) > 22;
    final title = Text(
      '${package.credits} Credits',
      style: TextStyle(
        color: const Color(0xFFF0EDF5),
        fontFamily: 'Times New Roman',
        fontSize: 18 * scale,
        height: 1.15,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.25,
      ),
    );
    final price = Text(
      package.price,
      style: TextStyle(
        color: const Color(0xFFD3D0DC),
        fontSize: 14.5 * scale,
        height: 1.2,
        fontWeight: FontWeight.w400,
      ),
    );

    return Semantics(
      key: ValueKey('creditPackage-${package.productId ?? package.credits}'),
      button: true,
      selected: selected,
      enabled: onTap != null,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            key: ValueKey('creditPackageSurface-${package.credits}'),
            duration: const Duration(milliseconds: 180),
            constraints: BoxConstraints(minHeight: 64 * scale),
            padding: EdgeInsets.all(selected ? 0.8 : 0.6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12 * scale),
              gradient: selected ? _creditAccent : _creditBorder,
              boxShadow: selected
                  ? const [
                      BoxShadow(color: Color(0x20EC5FB6), blurRadius: 12),
                      BoxShadow(
                        color: Color(0x164561DF),
                        blurRadius: 10,
                        offset: Offset(3, 0),
                      ),
                    ]
                  : null,
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12 * scale - 0.8),
              clipBehavior: Clip.antiAlias,
              child: Ink(
                decoration: const BoxDecoration(gradient: _creditSurface),
                child: InkWell(
                  onTap: onTap,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      15 * scale,
                      (largeText ? (package.tag != null ? 26 : 16) : 10) *
                          scale,
                      15 * scale,
                      (largeText ? 16 : 10) * scale,
                    ),
                    child: Row(
                      children: [
                        Image.asset(
                          'assets/images/in_app_purchase/credit.png',
                          width: 54 * scale,
                          height: 42 * scale,
                          fit: BoxFit.contain,
                          excludeFromSemantics: true,
                        ),
                        SizedBox(width: 13 * scale),
                        if (largeText)
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                title,
                                SizedBox(height: 4 * scale),
                                price,
                              ],
                            ),
                          )
                        else ...[
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: title,
                            ),
                          ),
                          SizedBox(width: 8 * scale),
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: price,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (package.tag != null)
            Positioned(
              right: 14 * scale,
              top: -4 * scale,
              child: _PackageTagChip(tag: package.tag!),
            ),
        ],
      ),
    );
  }
}

class _PackageTagChip extends StatelessWidget {
  const _PackageTagChip({required this.tag});

  final _PackageTag tag;

  @override
  Widget build(BuildContext context) {
    final bestValue = tag == _PackageTag.bestValue;
    final scale = _creditScale(context);
    return Container(
      padding: const EdgeInsets.all(0.6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12 * scale),
        gradient: LinearGradient(
          colors: bestValue
              ? const [Color(0xFFE99CB4), Color(0xFF8570D6)]
              : const [Color(0xFF9E7CD4), Color(0xFF7964AC)],
        ),
      ),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: 10 * scale,
          vertical: 4 * scale,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(11.4 * scale),
          gradient: LinearGradient(
            colors: bestValue
                ? const [
                    Color(0xFFAC586C),
                    Color(0xFF653C88),
                    Color(0xFF292969),
                  ]
                : const [Color(0xFF2E244F), Color(0xFF211C40)],
          ),
        ),
        child: Text(
          bestValue ? 'BEST VALUE' : 'POPULAR',
          style: TextStyle(
            color: const Color(0xFFF5F0FE),
            fontSize: 8.5 * scale,
            height: 1.2,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.85,
          ),
        ),
      ),
    );
  }
}

class _SubscriptionBanner extends StatelessWidget {
  const _SubscriptionBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scale = _creditScale(context);
    return Semantics(
      button: true,
      label: 'View subscription plans and save up to 50 percent',
      child: Container(
        height: 100 * scale,
        padding: const EdgeInsets.all(0.6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12 * scale),
          gradient: const LinearGradient(
            colors: [Color(0xFF725389), Color(0xFF43376C)],
          ),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12 * scale - 0.6),
          clipBehavior: Clip.antiAlias,
          child: Ink(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF100D20), Color(0xFF070A19)],
              ),
            ),
            child: InkWell(
              key: const Key('subscriptionBanner'),
              onTap: onTap,
              child: LayoutBuilder(
                builder: (context, constraints) => Stack(
                  children: [
                    Positioned(
                      right: 14 * scale,
                      bottom: 2 * scale,
                      width: constraints.maxWidth * 0.36,
                      height: 20 * scale,
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            colors: [Color(0x664C1F9C), Color(0x00150B31)],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 19 * scale,
                      top: 11 * scale,
                      bottom: 6 * scale,
                      width: constraints.maxWidth * 0.33,
                      child: const Image(
                        image: AssetImage(
                          'assets/images/in_app_purchase/gift.png',
                        ),
                        fit: BoxFit.contain,
                        excludeFromSemantics: true,
                      ),
                    ),
                    Positioned(
                      left: 24 * scale,
                      right: constraints.maxWidth * 0.46,
                      top: 22 * scale,
                      bottom: 20 * scale,
                      child: const _SubscriptionCopy(),
                    ),
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

class _SubscriptionCopy extends StatelessWidget {
  const _SubscriptionCopy();

  @override
  Widget build(BuildContext context) {
    final scale = _creditScale(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Get Up to ',
                style: TextStyle(
                  color: const Color(0xFFE9DFF5),
                  fontFamily: 'Times New Roman',
                  fontSize: 26 * scale,
                  height: 1.1,
                  fontWeight: FontWeight.w400,
                  letterSpacing: -0.6,
                ),
              ),
              ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFFEC5F9B), Color(0xFFB557C8)],
                ).createShader(bounds),
                child: Text(
                  '50%',
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Times New Roman',
                    fontSize: 28 * scale,
                    height: 1.1,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 5 * scale),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            'off with Subscription',
            maxLines: 1,
            style: TextStyle(
              color: const Color(0xFFACA6BD),
              fontSize: 13.5 * scale,
              height: 1.3,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }
}

class _BuyButton extends StatelessWidget {
  const _BuyButton({
    required this.label,
    required this.busy,
    required this.onTap,
  });

  final String label;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scale = _creditScale(context);
    return Container(
      key: const Key('buyCreditsButton'),
      constraints: BoxConstraints(minHeight: 50 * scale),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13 * scale),
        gradient: const LinearGradient(
          colors: [Color(0xFFE85CAE), Color(0xFF9842B5), Color(0xFF415CD7)],
        ),
        border: Border.all(color: const Color(0xFFA496DD), width: 0.6),
        boxShadow: const [
          BoxShadow(color: Color(0x20B949BB), blurRadius: 16),
          BoxShadow(
            color: Color(0x164561DF),
            blurRadius: 12,
            offset: Offset(4, 0),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(13 * scale),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 12 * scale,
              vertical: 10 * scale,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
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
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: busy ? null : 'Times New Roman',
                      fontSize: (busy ? 15 : 22) * scale,
                      height: 1.2,
                      fontWeight: FontWeight.w400,
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

class _PurchaseFooter extends StatelessWidget {
  const _PurchaseFooter({required this.restoring, required this.onRestore});

  final bool restoring;
  final VoidCallback? onRestore;

  @override
  Widget build(BuildContext context) {
    final scale = _creditScale(context);
    final linkStyle = TextStyle(
      color: const Color(0xFF9893A3),
      fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
      fontSize: 10 * scale,
      fontWeight: FontWeight.w400,
    );

    return Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              _FooterWebLink(
                label: 'Privacy',
                page: AppWebPage.privacy,
                style: linkStyle,
              ),
              const _FooterDivider(),
              TextButton(
                onPressed: onRestore,
                style: TextButton.styleFrom(
                  foregroundColor: linkStyle.color,
                  textStyle: linkStyle,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 28),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(restoring ? 'Restoring...' : 'Restore Purchase'),
              ),
              const _FooterDivider(),
              _FooterWebLink(
                label: 'Terms of Service',
                page: AppWebPage.terms,
                style: linkStyle,
              ),
            ],
          ),
        ),
        SizedBox(height: 2 * scale),
        Text(
          key: const Key('buyCreditsDisclaimer'),
          'Credits are used for generating AI content.\n'
          'Purchased credits do not expire.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: const Color(0xFF827E8E),
            fontSize: 10 * scale,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class _FooterWebLink extends StatelessWidget {
  const _FooterWebLink({
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
        minimumSize: const Size(0, 28),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(label),
    );
  }
}

class _FooterDivider extends StatelessWidget {
  const _FooterDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 0.6,
      height: 13,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      color: const Color(0xFF4A4557),
    );
  }
}

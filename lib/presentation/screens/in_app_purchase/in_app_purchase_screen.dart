import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
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

    return Scaffold(
      backgroundColor: const Color(0xFF050307),
      body: Stack(
        children: [
          const Positioned.fill(child: _ScreenGlow()),
          SafeArea(
            bottom: false,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    16,
                    20,
                    18 + MediaQuery.paddingOf(context).bottom,
                  ),
                  sliver: SliverList.list(
                    children: [
                      _PurchaseHeader(
                        onClose: () => Navigator.maybePop(context),
                      ),
                      const SizedBox(height: 22),
                      for (var index = 0; index < packages.length; index++) ...[
                        _CreditPackageTile(
                          package: packages[index],
                          selected: index == selectedIndex,
                          onTap: () => setState(() => _selectedIndex = index),
                        ),
                        if (index != packages.length - 1)
                          const SizedBox(height: 12),
                      ],
                      if (profile?.isSubscribed != true) ...[
                        const SizedBox(height: 14),
                        _SubscriptionBanner(
                          onTap: () => _openSubscriptionPlans(
                            isVIP: profile?.isVIP == true,
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      _BuyButton(
                        label: _buyButtonLabel(purchaseState),
                        busy: purchaseState.isBusy,
                        onTap: purchaseState.isBusy
                            ? null
                            : () => _buy(packages[selectedIndex]),
                      ),
                      const SizedBox(height: 13),
                      _PurchaseFooter(
                        restoring:
                            purchaseState.status ==
                            PurchaseFlowStatus.restoring,
                        onRestore: purchaseState.isBusy
                            ? null
                            : () => ref
                                  .read(purchaseControllerProvider.notifier)
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
          center: Alignment(0.25, -0.66),
          radius: 1.04,
          colors: [Color(0x351D0921), Color(0xFF050307)],
          stops: [0, 0.92],
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
    return SizedBox(
      height: 49,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: _CloseButton(onTap: onClose),
          ),
          const Text(
            'Buy Credit',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
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
    return Container(
      key: const Key('buyCreditsCloseButton'),
      width: 39,
      height: 39,
      padding: const EdgeInsets.all(1.2),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF794E), Color(0xFFFF13A5)],
        ),
        boxShadow: [BoxShadow(color: Color(0x66FF169E), blurRadius: 12)],
      ),
      child: Material(
        color: Color(0xFF0A0710),
        shape: CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: const Icon(Icons.close_rounded, color: Colors.white, size: 27),
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
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 70,
          padding: EdgeInsets.all(selected ? 1.4 : 1),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: selected ? null : const Color(0xFF562046),
            gradient: selected
                ? const LinearGradient(
                    colors: [Color(0xFFFF23B2), Color(0xFFFF9535)],
                  )
                : null,
            boxShadow: selected
                ? const [
                    BoxShadow(color: Color(0x77FF219F), blurRadius: 14),
                    BoxShadow(
                      color: Color(0x55FF8A2E),
                      blurRadius: 12,
                      offset: Offset(3, 0),
                    ),
                  ]
                : null,
          ),
          child: Material(
            color: const Color(0xE60D0810),
            borderRadius: BorderRadius.circular(13),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Image.asset(
                      'assets/images/in_app_purchase/coin3.png',
                      width: 44,
                      height: 44,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        '${package.credits} Credits',
                        maxLines: 1,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.25,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      package.price,
                      maxLines: 1,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (package.tag != null)
          Positioned(
            right: 11,
            top: -7,
            child: _PackageTagChip(tag: package.tag!),
          ),
      ],
    );
  }
}

class _PackageTagChip extends StatelessWidget {
  const _PackageTagChip({required this.tag});

  final _PackageTag tag;

  @override
  Widget build(BuildContext context) {
    final bestValue = tag == _PackageTag.bestValue;
    return Container(
      padding: const EdgeInsets.all(1.1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: bestValue
              ? const [Color(0xFFFF2AAB), Color(0xFFFF9B31)]
              : const [Color(0xFFFF1EC8), Color(0xFFFF6DD6)],
        ),
        boxShadow: const [BoxShadow(color: Color(0xA5FF20BC), blurRadius: 10)],
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(11),
          gradient: LinearGradient(
            colors: bestValue
                ? const [Color(0xFFDF2575), Color(0xFFCD5030)]
                : const [Color(0xFF5A1549), Color(0xFF49143E)],
          ),
        ),
        child: Text(
          bestValue ? 'BEST VALUE' : 'POPULAR',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.25,
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
    return Semantics(
      button: true,
      label: 'View subscription plans and save up to 50 percent',
      child: Container(
        height: 126,
        padding: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          gradient: const LinearGradient(
            colors: [Color(0xFFFF1CB3), Color(0xFFFF714C)],
          ),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: const Key('subscriptionBanner'),
            onTap: onTap,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Color(0xFF100817), Color(0xFF160812)],
                ),
              ),
              child: const Stack(
                children: [
                  Positioned(
                    right: -5,
                    top: 9,
                    bottom: 3,
                    width: 142,
                    child: Image(
                      image: AssetImage(
                        'assets/images/in_app_purchase/gift.png',
                      ),
                      fit: BoxFit.contain,
                    ),
                  ),
                  Positioned(
                    left: 18,
                    right: 132,
                    top: 34,
                    child: _SubscriptionCopy(),
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

class _SubscriptionCopy extends StatelessWidget {
  const _SubscriptionCopy();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFFFF20B1), Color(0xFFFF9732)],
          ).createShader(bounds),
          child: const FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              'Get Up to 50%',
              maxLines: 1,
              style: TextStyle(
                color: Colors.white,
                fontSize: 27,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
              ),
            ),
          ),
        ),
        const SizedBox(height: 7),
        const FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            'off with Subscription',
            maxLines: 1,
            style: TextStyle(
              color: Color(0xFFC5BEC9),
              fontSize: 16,
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
    return Container(
      height: 57,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          colors: [Color(0xFFFF17A7), Color(0xFFFF9737)],
        ),
        border: Border.all(color: const Color(0xFFFFB067), width: 1.1),
        boxShadow: const [
          BoxShadow(color: Color(0x88FF1FA9), blurRadius: 16),
          BoxShadow(
            color: Color(0x55FF8A2C),
            blurRadius: 12,
            offset: Offset(4, 0),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Center(
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
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
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
    const linkStyle = TextStyle(
      color: Color(0xFFE5E0E8),
      fontSize: 12.5,
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
              const _FooterWebLink(
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
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(restoring ? 'Restoring...' : 'Restore Purchase'),
              ),
              const _FooterDivider(),
              const _FooterWebLink(
                label: 'Terms of Service',
                page: AppWebPage.terms,
                style: linkStyle,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Credits are used for generating AI content.\n'
          'Purchased credits do not expire.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: const Color(0xFF817986).withValues(alpha: 0.85),
            fontSize: 11.5,
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
        minimumSize: Size.zero,
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
      width: 1,
      height: 13,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      color: const Color(0xFFFF28A6),
    );
  }
}

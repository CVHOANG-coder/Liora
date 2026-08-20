import 'package:flutter/material.dart';

import '../screens/in_app_purchase/in_app_purchase_screen.dart';

class TrialOfferDialog extends StatelessWidget {
  const TrialOfferDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: const Color(0xE6000000),
      builder: (_) => const TrialOfferDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: const Color(0xFF0F0714),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFFF3EAE), width: 1.2),
            boxShadow: const [
              BoxShadow(color: Color(0xCCFF149C), blurRadius: 24),
              BoxShadow(color: Color(0xAAFF7E32), blurRadius: 32),
            ],
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(19, 20, 19, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0x4C5A0D50),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: const Color(0xFFFF30B1)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.card_giftcard_rounded,
                            color: Color(0xFFFF50BF),
                            size: 21,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Ưu đãi dùng thử',
                            style: TextStyle(
                              color: Color(0xFFE8DCEB),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    _CloseButton(onTap: () => Navigator.pop(context)),
                  ],
                ),
                const SizedBox(height: 20),
                const _HeroBanner(),
                const SizedBox(height: 4),
                const _OfferBenefit(
                  asset: 'assets/images/in_app_purchase/free_video.png',
                  title: '1 trailer miễn phí',
                  subtitle: 'Tạo ngay trailer 17+ bằng AI',
                ),
                const SizedBox(height: 9),
                const _OfferBenefit(
                  title: '+50 coins dùng thử',
                  subtitle: 'Dùng để mở template, style và hiệu ứng',
                  useCoin: true,
                ),
                const SizedBox(height: 9),
                const _OfferBenefit(
                  asset: 'assets/images/in_app_purchase/fire_icon.png',
                  title: 'Khám phá style hot & template viral',
                  subtitle: 'Bắt trend nhanh, tạo nội dung cuốn hút',
                ),
                const SizedBox(height: 14),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.person_outline_rounded,
                      color: Color(0xFFFF3DB2),
                      size: 25,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Ưu đãi dành cho người dùng mới',
                      style: TextStyle(color: Color(0xFFB8AEBB), fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                _ActionButton(
                  key: const Key('trialClaimButton'),
                  label: 'Nhận ngay',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const InAppPurchaseScreen(),
                      ),
                    );
                  },
                  filled: true,
                ),
                const SizedBox(height: 10),
                _ActionButton(
                  key: const Key('trialLaterButton'),
                  label: 'Để sau',
                  onTap: () => Navigator.pop(context),
                  filled: false,
                ),
              ],
            ),
          ),
        ),
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
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0x55120B18),
        border: Border.all(color: const Color(0xFFFF9B36), width: 1.2),
      ),
      child: IconButton(
        onPressed: onTap,
        padding: EdgeInsets.zero,
        icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
      ),
    );
  }
}

class _GradientTitle extends StatelessWidget {
  const _GradientTitle({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        colors: [Color(0xFFFF39B5), Color(0xFFFF8B37)],
      ).createShader(bounds),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 28,
          height: 1,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 142,
      width: double.infinity,
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 1, top: 5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tặng gói',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 25,
                      height: 1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const _GradientTitle(text: 'Free Trailer'),
                  const SizedBox(height: 11),
                  const Text(
                    'Nhận ngay 50 coins\nđể trải nghiệm',
                    style: TextStyle(
                      color: Color(0xFFCAC0CC),
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            width: 172,
            height: 142,
            child: Image.asset(
              'assets/images/in_app_purchase/free_trailer_icon_banner.png',
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }
}

class _OfferBenefit extends StatelessWidget {
  const _OfferBenefit({
    this.asset,
    required this.title,
    required this.subtitle,
    this.useCoin = false,
  });

  final String? asset;
  final String title;
  final String subtitle;
  final bool useCoin;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 66,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0x35130B1C),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF5C194F)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: asset != null
                ? Image.asset(asset!, fit: BoxFit.contain)
                : const _CoinIcon(size: 48),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFF4EEF5),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFACA2AF),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    super.key,
    required this.label,
    required this.onTap,
    required this.filled,
  });

  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 49,
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          gradient: filled
              ? const LinearGradient(
                  colors: [Color(0xFFFF129D), Color(0xFFFF9A35)],
                )
              : null,
          border: filled ? null : Border.all(color: const Color(0xFFFF2CA9)),
          color: filled ? null : const Color(0x1E26091F),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(25),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (filled) ...[
                  const _CoinIcon(size: 32),
                  const SizedBox(width: 12),
                ],
                Text(
                  label,
                  style: TextStyle(
                    color: filled ? Colors.white : const Color(0xFFFF43B4),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
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

class _CoinIcon extends StatelessWidget {
  const _CoinIcon({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/in_app_purchase/coin2.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}

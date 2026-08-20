import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

class InAppPurchaseScreen extends StatelessWidget {
  const InAppPurchaseScreen({super.key});

  static const _packages = [
    _CreditPackage(
      '4.500 credits',
      '4500 coins',
      '99,99 US\$',
      _PackageTag.best,
    ),
    _CreditPackage('2.000 credits', '2000 coins', '49,99 US\$', null),
    _CreditPackage(
      '1.000 credits',
      '1000 coins',
      '34,99 US\$',
      _PackageTag.popular,
    ),
    _CreditPackage('600 credits', '600 coins', '19,99 US\$', null),
    _CreditPackage('275 credits', '275 coins', '9,99 US\$', null),
    _CreditPackage('100 credits', '100 coins', '3,99 US\$', null),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.75),
            radius: 1.2,
            colors: [Color(0x1D4D1246), AppColors.background],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(17, 17, 17, 28),
                sliver: SliverList.list(
                  children: [
                    _PurchaseHeader(onBack: () => Navigator.maybePop(context)),
                    const SizedBox(height: 18),
                    const _BalanceCard(),
                    const SizedBox(height: 16),
                    _WatchAdsCard(onWatch: () => _showComingSoon(context)),
                    const SizedBox(height: 22),
                    const Text(
                      'Gói credits',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 23,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ..._packages.map(
                      (package) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _CreditPackageTile(
                          package: package,
                          onTap: () => _showComingSoon(context),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const _PurchaseFooter(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tính năng thanh toán sẽ sớm ra mắt')),
    );
  }
}

class _PurchaseHeader extends StatelessWidget {
  const _PurchaseHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onBack,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 42, height: 46),
          icon: const Icon(Icons.arrow_back_rounded, size: 34),
        ),
        const SizedBox(width: 8),
        const Text(
          'Nạp credits',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 25,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 10),
        const _CoinIcon(size: 30, type: 2),
      ],
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 116,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: const Color(0x4C120D18),
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: const Color(0xFF5B2456)),
      ),
      child: Row(
        children: [
          const _CoinIcon(size: 108),
          const SizedBox(width: 10),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Số dư hiện tại',
                style: TextStyle(color: Color(0xFFB7B0B9), fontSize: 16),
              ),
              SizedBox(height: 2),
              Text(
                '35',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 34,
                  height: 1,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'credits',
                style: TextStyle(color: Color(0xFFB7B0B9), fontSize: 16),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WatchAdsCard extends StatelessWidget {
  const _WatchAdsCard({required this.onWatch});

  final VoidCallback onWatch;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      decoration: BoxDecoration(
        color: const Color(0x4C100B17),
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: const Color(0xFFFF3AAF)),
        boxShadow: const [BoxShadow(color: Color(0x552D0B39), blurRadius: 22)],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0x552B0E39),
                  border: Border.all(color: const Color(0xFFFF58C4)),
                  boxShadow: const [
                    BoxShadow(color: Color(0xAAFF19B2), blurRadius: 14),
                  ],
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Color(0xFFFF65D0),
                  size: 34,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Xem quảng cáo & Nhận credits',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Xem tối đa 3 quảng cáo mỗi ngày để nhận thêm credits',
                      style: TextStyle(
                        color: Color(0xFFB6AFBB),
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF271022), Color(0xFF30131C)],
                  ),
                  border: Border.all(color: const Color(0xFFFF755F)),
                ),
                child: const Text(
                  '+9',
                  style: TextStyle(
                    color: Color(0xFFFFB2A1),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: const Color(0x321E0C2A),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF3A164E)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Đã xem 0 / 3 quảng cáo hôm nay',
                style: TextStyle(color: Color(0xFFB8B1BB), fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 17),
          SizedBox(
            height: 45,
            width: double.infinity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF149C), Color(0xFFFF9B39)],
                ),
                boxShadow: const [
                  BoxShadow(color: Color(0x883C0E8A), blurRadius: 16),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onWatch,
                  borderRadius: BorderRadius.circular(24),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _CoinIcon(size: 28, type: 2),
                      SizedBox(width: 8),
                      Text(
                        'Xem quảng cáo',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _PackageTag { best, popular }

class _CreditPackage {
  const _CreditPackage(this.credits, this.coins, this.price, this.tag);

  final String credits;
  final String coins;
  final String price;
  final _PackageTag? tag;
}

class _CreditPackageTile extends StatelessWidget {
  const _CreditPackageTile({required this.package, required this.onTap});

  final _CreditPackage package;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final highlighted = package.tag != null;
    final borderColor = package.tag == _PackageTag.best
        ? const Color(0xFFFFAD36)
        : const Color(0xFFFF3DAD);

    return Container(
      height: 84,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0x4C100B17),
        borderRadius: BorderRadius.circular(21),
        border: Border.all(
          color: highlighted ? borderColor : const Color(0xFF51204D),
          width: highlighted ? 1.4 : 1,
        ),
        boxShadow: highlighted
            ? [
                BoxShadow(
                  color: borderColor.withValues(alpha: 0.27),
                  blurRadius: 17,
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          const _CoinIcon(size: 70),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (package.tag != null) ...[
                  _PackageTagChip(tag: package.tag!),
                  const SizedBox(height: 2),
                ],
                Text(
                  package.credits,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 19,
                    height: 1.05,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  package.coins,
                  style: const TextStyle(
                    color: Color(0xFFAFA8B3),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 101,
            height: 43,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF208D), Color(0xFFFF7C4A)],
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(16),
                  child: Center(
                    child: Text(
                      package.price,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 7),
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
    final best = tag == _PackageTag.best;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: best ? const Color(0x443D2400) : const Color(0x443C0934),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        best ? '★  TỐT NHẤT' : '♦  PHỔ BIẾN',
        style: TextStyle(
          color: best ? const Color(0xFFFFC324) : const Color(0xFFFF53C4),
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _PurchaseFooter extends StatelessWidget {
  const _PurchaseFooter();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.lock_outline_rounded, color: Color(0xFFFF42B5), size: 23),
        SizedBox(width: 12),
        Text(
          'Thanh toán an toàn',
          style: TextStyle(color: Color(0xFFB0A9B3), fontSize: 14),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text('•', style: TextStyle(color: Color(0xFFB0A9B3))),
        ),
        Text(
          'Khôi phục mua hàng',
          style: TextStyle(color: Color(0xFFB0A9B3), fontSize: 14),
        ),
      ],
    );
  }
}

class _CoinIcon extends StatelessWidget {
  const _CoinIcon({required this.size, this.type = 1});

  final double size;
  final int type;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      type == 1
          ? 'assets/images/in_app_purchase/coin.png'
          : 'assets/images/in_app_purchase/coin2.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}

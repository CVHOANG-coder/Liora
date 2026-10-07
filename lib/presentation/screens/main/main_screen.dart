import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_features.dart';
import '../../../core/firebase/firebase_service.dart';
import '../../../data/models/user_profile.dart';
import '../../providers/purchase_provider.dart';
import '../../providers/profile_provider.dart';
import '../in_app_purchase/all_plans_screen.dart';
import '../in_app_purchase/free_trial_screen.dart';
import '../in_app_purchase/yearly_sale_screen.dart';
import '../home/home_screen.dart';
import '../image_to_video/image_to_video_screen.dart';
import '../profile/profile_screen.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({
    super.key,
    this.initialIndex = 0,
    this.showTrialOffer = true,
    this.notificationPermissionRequester,
  });

  final int initialIndex;
  final bool showTrialOffer;
  final NotificationPermissionRequester? notificationPermissionRequester;

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen>
    with WidgetsBindingObserver {
  late int _selectedIndex;
  late final List<Widget> _screens;
  bool _isShowingInitialOffer = false;
  bool _wasBackgrounded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _screens = [const HomeScreen(), const ProfileScreen()];
    _selectedIndex = widget.initialIndex.clamp(0, _screens.length - 1);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _showInitialOfferIfNeeded();
      if (!mounted || _selectedIndex != 0) return;
      await _requestHomeNotificationPermission();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _wasBackgrounded = true;
    } else if (state == AppLifecycleState.resumed && _wasBackgrounded) {
      _wasBackgrounded = false;
      unawaited(_showSaleOnResume());
    }
  }

  Future<void> _showSaleOnResume() async {
    if (!AppFeatures.commerceEnabled ||
        !mounted ||
        _isShowingInitialOffer ||
        _isPurchaseInProgress()) {
      return;
    }
    _isShowingInitialOffer = true;
    try {
      final profile = await ref.read(apiClientProvider).fetchProfile();
      if (!mounted) return;
      ref.read(profileProvider.notifier).setProfile(profile);
      if (_hasActiveWeeklyPlan(profile) && !_isPurchaseInProgress()) {
        await YearlySaleScreen.open(context);
      }
    } catch (_) {
      // A failed profile refresh must not show an offer for a stale plan.
    } finally {
      _isShowingInitialOffer = false;
    }
  }

  bool _isPurchaseInProgress() =>
      switch (ref.read(purchaseControllerProvider).status) {
        PurchaseFlowStatus.launching ||
        PurchaseFlowStatus.pending ||
        PurchaseFlowStatus.verifying ||
        PurchaseFlowStatus.restoring => true,
        _ => false,
      };

  Future<void> _showInitialOfferIfNeeded() async {
    if (!AppFeatures.commerceEnabled ||
        !mounted ||
        !widget.showTrialOffer ||
        _isShowingInitialOffer) {
      return;
    }
    _isShowingInitialOffer = true;
    try {
      final profile = ref.read(profileProvider);
      final activePlan = resolveProPlanStatus(profile);
      if (_hasActiveWeeklyPlan(profile)) {
        await YearlySaleScreen.open(context);
      } else if (activePlan == ProPlanStatus.none && profile?.isVIP != true) {
        await FreeTrialScreen.open(context);
      }
    } finally {
      _isShowingInitialOffer = false;
    }
  }

  bool _hasActiveWeeklyPlan(UserProfile? profile) {
    final startedAt = profile?.subscriptionTime;
    final endsAt = profile?.subscriptionEndTime;
    final now = DateTime.now();
    return profile != null &&
        profile.isSubscribed &&
        startedAt != null &&
        endsAt != null &&
        !startedAt.isAfter(now) &&
        endsAt.isAfter(now) &&
        endsAt.isAfter(startedAt) &&
        resolveProPlanStatus(profile) == ProPlanStatus.weekly;
  }

  Future<void> _requestHomeNotificationPermission() {
    final requester =
        widget.notificationPermissionRequester ??
        FirebaseService.requestNotificationPermissionOnHome;
    return requester().then<void>((_) {});
  }

  void _selectTab(int index) {
    setState(() => _selectedIndex = index);
    if (index == 0) {
      unawaited(_requestHomeNotificationPermission());
    }
  }

  void _openImageToVideo() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const ImageToVideoScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          for (var index = 0; index < _screens.length; index++)
            TickerMode(
              enabled: index == _selectedIndex,
              child: _screens[index],
            ),
        ],
      ),
      bottomNavigationBar: _BottomBar(
        currentIndex: _selectedIndex,
        onChanged: _selectTab,
        onCreate: _openImageToVideo,
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.currentIndex,
    required this.onChanged,
    required this.onCreate,
  });

  final int currentIndex;
  final ValueChanged<int> onChanged;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: SizedBox(
        height: 76,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: CustomPaint(
                key: const Key('curvedBottomBar'),
                painter: const _CurvedBottomBarPainter(),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 58,
              child: Row(
                children: [
                  Expanded(
                    child: _NavItem(
                      key: const Key('homeTab'),
                      icon: Icons.home_rounded,
                      label: 'Home',
                      selected: currentIndex == 0,
                      onTap: () => onChanged(0),
                    ),
                  ),
                  const SizedBox(width: 120),
                  Expanded(
                    child: _NavItem(
                      key: const Key('profileTab'),
                      icon: Icons.person_rounded,
                      label: 'Me',
                      selected: currentIndex == 1,
                      onTap: () => onChanged(1),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(top: 0, child: _CreateButton(onPressed: onCreate)),
          ],
        ),
      ),
    );
  }
}

class _CurvedBottomBarPainter extends CustomPainter {
  const _CurvedBottomBarPainter();

  Path _path(Size size) {
    const top = 16.0;
    const cornerRadius = 28.0;
    final center = size.width / 2;
    return Path()
      ..moveTo(cornerRadius, top)
      ..lineTo(center - 48, top)
      ..cubicTo(center - 38, top, center - 39, 30, center - 27, 40)
      ..cubicTo(center - 19, 47, center - 10, 49, center, 49)
      ..cubicTo(center + 10, 49, center + 19, 47, center + 27, 40)
      ..cubicTo(center + 39, 30, center + 38, top, center + 48, top)
      ..lineTo(size.width - cornerRadius, top)
      ..quadraticBezierTo(size.width, top, size.width, top + cornerRadius)
      ..lineTo(size.width, size.height - cornerRadius)
      ..quadraticBezierTo(
        size.width,
        size.height,
        size.width - cornerRadius,
        size.height,
      )
      ..lineTo(cornerRadius, size.height)
      ..quadraticBezierTo(0, size.height, 0, size.height - cornerRadius)
      ..lineTo(0, top + cornerRadius)
      ..quadraticBezierTo(0, top, cornerRadius, top)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = _path(size);
    canvas.drawShadow(path, const Color(0xB3000000), 14, false);

    final fill = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFA343146), Color(0xFA292639)],
      ).createShader(Offset.zero & size);
    canvas.drawPath(path, fill);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0xFF514B62),
    );
  }

  @override
  bool shouldRepaint(covariant _CurvedBottomBarPainter oldDelegate) => false;
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    super.key,
    required this.icon,
    required this.label,
    this.selected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const activeGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFA45CF4), Color(0xFFA45CF4)],
    );
    final color = selected ? null : const Color(0xFF9295A3);

    Widget applyActiveGradient(Widget child) {
      if (!selected) return child;

      return ShaderMask(
        shaderCallback: (bounds) => activeGradient.createShader(bounds),
        blendMode: BlendMode.srcIn,
        child: child,
      );
    }

    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: InkResponse(
        onTap: onTap,
        radius: 34,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            applyActiveGradient(
              Icon(icon, color: color ?? Colors.white, size: 30),
            ),
            const SizedBox(height: 1),
            applyActiveGradient(
              Text(
                label,
                style: TextStyle(
                  color: color ?? Colors.white,
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateButton extends StatelessWidget {
  const _CreateButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Create',
      child: Container(
        key: const Key('createButton'),
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFA45CF4), Color(0xFFA45CF4), Color(0xFFA45CF4)],
          ),
          border: Border.all(color: const Color(0xFFBCA9C7), width: 1.5),
        ),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: const Icon(Icons.add_rounded, size: 38, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

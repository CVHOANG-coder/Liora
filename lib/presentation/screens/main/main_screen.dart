import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_features.dart';
import '../../../core/firebase/firebase_service.dart';
import '../../providers/purchase_provider.dart';
import '../../providers/profile_provider.dart';
import '../../widgets/create_bottom_sheet.dart';
import '../in_app_purchase/all_plans_screen.dart';
import '../in_app_purchase/free_trial_screen.dart';
import '../in_app_purchase/yearly_sale_screen.dart';
import '../home/home_screen.dart';
import '../image_to_video/image_to_video_screen.dart';
import '../profile/profile_screen.dart';
import '../text_to_video/text_to_video_screen.dart';

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

class _MainScreenState extends ConsumerState<MainScreen> {
  late int _selectedIndex;
  bool _isShowingInitialOffer = false;

  static const _screens = [HomeScreen(), ProfileScreen()];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex.clamp(0, _screens.length - 1);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _showInitialOfferIfNeeded();
      if (!mounted || _selectedIndex != 0) return;
      await _requestHomeNotificationPermission();
    });
  }

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
      if (activePlan == ProPlanStatus.weekly) {
        final shouldShow = await ref
            .read(yearlySalePreferencesProvider)
            .consumeScheduledOffer();
        if (!mounted || !shouldShow) return;
        await YearlySaleScreen.open(context);
      } else if (profile?.isVIP == true) {
        return;
      } else if (!(profile?.isSubscribed ?? false)) {
        await FreeTrialScreen.open(context);
      }
    } finally {
      _isShowingInitialOffer = false;
    }
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

  Future<void> _openCreateSheet() async {
    final result = await showModalBottomSheet<CreateVideoMode>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: false,
      elevation: 0,
      constraints: const BoxConstraints(maxWidth: 560),
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0xB802050C),
      builder: (_) => const CreateBottomSheet(),
    );

    if (!mounted || result == null) return;
    switch (result) {
      case CreateVideoMode.imageToVideo:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const ImageToVideoScreen()),
        );
        return;
      case CreateVideoMode.textToVideo:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const TextToVideoScreen()),
        );
        return;
    }
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
        onCreate: _openCreateSheet,
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
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xF5121727), Color(0xF50B1020)],
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFF2D3346)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 12,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Row(
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
                const SizedBox(width: 110),
                Expanded(
                  child: _NavItem(
                    key: const Key('profileTab'),
                    icon: Icons.person_rounded,
                    label: 'Me',
                    selected: currentIndex == 1,
                    showDot: currentIndex == 1,
                    onTap: () => onChanged(1),
                  ),
                ),
              ],
            ),
            Positioned(top: 4, child: _CreateButton(onPressed: onCreate)),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool showDot;
  final VoidCallback onTap;

  const _NavItem({
    super.key,
    required this.icon,
    required this.label,
    this.selected = false,
    this.showDot = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const activeGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFEC5FB6), Color(0xFFA850CF)],
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
            if (showDot) ...[
              const SizedBox(height: 2),
              applyActiveGradient(
                Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: color ?? Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
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
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFD744C7), Color(0xFF754DEB), Color(0xFF3F86FF)],
          ),
          border: Border.all(color: const Color(0xFFB96BFF), width: 0.8),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF30A8).withValues(alpha: 0.18),
              blurRadius: 8,
              spreadRadius: 0,
            ),
            BoxShadow(
              color: const Color(0xFF4F80FF).withValues(alpha: 0.16),
              blurRadius: 8,
              offset: const Offset(2, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: const Key('createButton'),
            onTap: onPressed,
            child: const Icon(Icons.add_rounded, size: 30, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    if (!mounted || !widget.showTrialOffer || _isShowingInitialOffer) return;
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
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0xC7000000),
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
      body: IndexedStack(index: _selectedIndex, children: _screens),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: _CreateButton(onPressed: _openCreateSheet),
      bottomNavigationBar: _BottomBar(
        currentIndex: _selectedIndex,
        onChanged: _selectTab,
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.currentIndex, required this.onChanged});

  final int currentIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Container(
        height: 82,
        decoration: BoxDecoration(
          color: const Color(0xF5101015),
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: const Color(0xFF292830)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x99000000),
              blurRadius: 28,
              offset: Offset(0, 12),
            ),
          ],
        ),
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
            const SizedBox(width: 80),
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
    );
  }
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
    final color = selected ? const Color(0xFFFF4DA6) : const Color(0xFF929198);

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
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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
        width: 68,
        height: 68,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF111116),
          border: Border.all(color: const Color(0xFFFF4DB7), width: 2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF30A8).withValues(alpha: 0.72),
              blurRadius: 24,
              spreadRadius: 1,
            ),
            BoxShadow(
              color: const Color(0xFFFF763C).withValues(alpha: 0.38),
              blurRadius: 20,
              offset: const Offset(6, 5),
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
            child: const Icon(Icons.add_rounded, size: 39, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

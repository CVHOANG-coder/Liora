import 'package:flutter/material.dart';

import '../../widgets/create_bottom_sheet.dart';
import '../../widgets/trial_offer_dialog.dart';
import '../home/home_screen.dart';
import '../profile/profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  static const _screens = [HomeScreen(), ProfileScreen()];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) TrialOfferDialog.show(context);
    });
  }

  Future<void> _openCreateSheet() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: false,
      builder: (_) => const CreateBottomSheet(),
    );

    if (!mounted || result == null) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Đã chọn tạo $result')));
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
        onChanged: (index) => setState(() => _selectedIndex = index),
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
      label: 'Tạo mới',
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

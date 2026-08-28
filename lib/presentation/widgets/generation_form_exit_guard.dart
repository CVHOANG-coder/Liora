import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

class GenerationFormExitGuard extends StatefulWidget {
  const GenerationFormExitGuard({
    super.key,
    required this.isSubmitting,
    required this.onLeave,
    required this.child,
  });

  final bool isSubmitting;
  final VoidCallback onLeave;
  final Widget child;

  @override
  State<GenerationFormExitGuard> createState() =>
      GenerationFormExitGuardState();
}

class GenerationFormExitGuardState extends State<GenerationFormExitGuard> {
  DialogRoute<bool>? _warningRoute;

  /// Close only this warning before handling an API result or opening a route.
  void dismissWarning() {
    final route = _warningRoute;
    _warningRoute = null;
    if (route != null && route.isActive) {
      route.navigator?.removeRoute(route);
    }
  }

  Future<void> _confirmLeave() async {
    if (_warningRoute != null || !widget.isSubmitting) return;
    final navigator = Navigator.of(context);
    final formRoute = ModalRoute.of(context);
    final route = DialogRoute<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        key: const Key('generationExitDialog'),
        backgroundColor: AppColors.surface,
        title: const Text(
          'Leave this screen?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'Your request is still being sent. If you leave, it may still be '
          'processed and use credits.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            key: const Key('stayOnGenerationForm'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(
              'Stay',
              style: TextStyle(color: AppColors.primary),
            ),
          ),
          TextButton(
            key: const Key('leaveGenerationForm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Leave',
              style: TextStyle(color: AppColors.accent),
            ),
          ),
        ],
      ),
    );
    _warningRoute = route;
    final leave = await navigator.push<bool>(route);
    // An API result may have dismissed the warning while it was open.
    if (!mounted || _warningRoute != route) return;
    _warningRoute = null;
    if (leave == true && formRoute?.isCurrent == true) {
      widget.onLeave();
      navigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: !widget.isSubmitting,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          widget.onLeave();
        } else {
          _confirmLeave();
        }
      },
      child: widget.child,
    );
  }
}

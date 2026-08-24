import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

class NotificationPermissionDialog extends StatelessWidget {
  const NotificationPermissionDialog({super.key});

  static Future<bool> show(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          barrierColor: const Color(0xD9000000),
          builder: (_) => const NotificationPermissionDialog(),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 390),
        padding: const EdgeInsets.all(1.3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFF24B5), Color(0xFFFF5C62), Color(0xFFFF9F2B)],
          ),
          boxShadow: const [
            BoxShadow(color: Color(0x66FF1BAB), blurRadius: 25),
            BoxShadow(color: Color(0x33FF8C2A), blurRadius: 20),
          ],
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 25, 22, 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const RadialGradient(
              center: Alignment(0, -0.7),
              radius: 1.1,
              colors: [Color(0xFF251027), Color(0xFF0B060F)],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 82,
                height: 82,
                padding: const EdgeInsets.all(1.3),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFFFF24B7), Color(0xFFFF9A2E)],
                  ),
                  boxShadow: [
                    BoxShadow(color: Color(0x77FF20AA), blurRadius: 20),
                  ],
                ),
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0xFF170919),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.notifications_active_rounded,
                    color: Color(0xFFFF70B8),
                    size: 42,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Never miss your video',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 23,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.45,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Enable notifications in Settings and we’ll let you know as '
                'soon as your AI video is ready.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 22),
              Container(
                height: 54,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(27),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFFF16A8),
                      Color(0xFFFF4E5C),
                      Color(0xFFFFA42B),
                    ],
                  ),
                  boxShadow: const [
                    BoxShadow(color: Color(0x66FF1AA6), blurRadius: 15),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(27),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    key: const Key('notificationOpenSettingsButton'),
                    onTap: () => Navigator.pop(context, true),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.settings_rounded, color: Colors.white),
                        SizedBox(width: 9),
                        Text(
                          'Open Settings',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                key: const Key('notificationNotNowButton'),
                onPressed: () => Navigator.pop(context, false),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFAAA2AF),
                  minimumSize: const Size.fromHeight(42),
                ),
                child: const Text(
                  'Not Now',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

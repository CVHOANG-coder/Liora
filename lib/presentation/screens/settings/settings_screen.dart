import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/device/image_access_permission.dart';
import '../../../core/storage/playback_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.preferences});

  final PlaybackPreferences? preferences;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final PlaybackPreferences _preferences;
  bool _autoplayVideos = true;
  bool _startMuted = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _preferences = widget.preferences ?? SharedPreferencesPlaybackPreferences();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final settings = await _preferences.load();
      if (!mounted) return;
      setState(() {
        _autoplayVideos = settings.autoplayVideos;
        _startMuted = settings.startMuted;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _setAutoplay(bool value) async {
    setState(() => _autoplayVideos = value);
    try {
      await _preferences.setAutoplayVideos(value);
    } catch (_) {
      if (!mounted) return;
      setState(() => _autoplayVideos = !value);
      _showMessage('Unable to save settings.');
    }
  }

  Future<void> _setStartMuted(bool value) async {
    setState(() => _startMuted = value);
    try {
      await _preferences.setStartMuted(value);
    } catch (_) {
      if (!mounted) return;
      setState(() => _startMuted = !value);
      _showMessage('Unable to save settings.');
    }
  }

  void _clearImageCache() {
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
    _showMessage('Image cache cleared.');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showInfoDialog({
    required String title,
    required IconData icon,
    required String message,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        icon: _DialogIcon(icon: icon),
        title: Text(title, textAlign: TextAlign.center),
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            height: 1.5,
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF3DAA),
              foregroundColor: Colors.white,
            ),
            child: const Text('Got It'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xF208060B),
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        toolbarHeight: 66,
        leadingWidth: 68,
        leading: Padding(
          padding: const EdgeInsets.only(left: 14),
          child: _HeaderButton(
            key: const Key('settingsBackButton'),
            onTap: () => Navigator.maybePop(context),
          ),
        ),
        title: const Text(
          'Settings',
          style: TextStyle(
            color: Colors.white,
            fontSize: 21,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.85),
            radius: 1.05,
            colors: [Color(0x4D4B123F), AppColors.background],
          ),
        ),
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                14,
                12,
                14,
                24 + MediaQuery.paddingOf(context).bottom,
              ),
              sliver: SliverList.list(
                children: [
                  const _SettingsHero(),
                  const SizedBox(height: 24),
                  const _SectionTitle('PLAYBACK'),
                  const SizedBox(height: 9),
                  _SettingsGroup(
                    children: [
                      _SwitchSettingsTile(
                        key: const Key('autoplayVideosSetting'),
                        icon: Icons.play_circle_outline_rounded,
                        title: 'Autoplay videos',
                        subtitle: 'Play generated videos automatically',
                        value: _autoplayVideos,
                        enabled: !_isLoading,
                        onChanged: _setAutoplay,
                      ),
                      const _SettingsDivider(),
                      _SwitchSettingsTile(
                        key: const Key('startMutedSetting'),
                        icon: Icons.volume_off_outlined,
                        title: 'Start muted',
                        subtitle: 'Open videos with sound muted',
                        value: _startMuted,
                        enabled: !_isLoading,
                        onChanged: _setStartMuted,
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  const _SectionTitle('APP & DATA'),
                  const SizedBox(height: 9),
                  _SettingsGroup(
                    children: [
                      _ActionSettingsTile(
                        key: const Key('appPermissionsSetting'),
                        icon: Icons.admin_panel_settings_outlined,
                        title: 'App permissions',
                        subtitle: 'Camera, photos, and system permissions',
                        onTap: ImageAccessPermission.openSettings,
                      ),
                      const _SettingsDivider(),
                      _ActionSettingsTile(
                        key: const Key('clearImageCacheSetting'),
                        icon: Icons.cleaning_services_outlined,
                        title: 'Clear image cache',
                        subtitle: 'Remove cached images from this device',
                        onTap: _clearImageCache,
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  const _SectionTitle('LEGAL & ABOUT'),
                  const SizedBox(height: 9),
                  _SettingsGroup(
                    children: [
                      _ActionSettingsTile(
                        icon: Icons.shield_outlined,
                        title: 'Privacy',
                        subtitle: 'How the app protects your data',
                        onTap: () => _showInfoDialog(
                          title: 'Privacy',
                          icon: Icons.shield_outlined,
                          message:
                              'Photos and videos are accessed only when you '
                              'select them or grant permission. You can change '
                              'app permissions at any time in system settings.',
                        ),
                      ),
                      const _SettingsDivider(),
                      _ActionSettingsTile(
                        icon: Icons.description_outlined,
                        title: 'Terms of Service',
                        subtitle: 'Nostalia terms of use',
                        onTap: () => _showInfoDialog(
                          title: 'Terms of Service',
                          icon: Icons.description_outlined,
                          message:
                              'When using Nostalia, you are responsible for '
                              'uploaded and generated content. Do not use the '
                              'service for unlawful purposes.',
                        ),
                      ),
                      const _SettingsDivider(),
                      const _ValueSettingsTile(
                        icon: Icons.info_outline_rounded,
                        title: 'App version',
                        value: '1.0.0',
                      ),
                    ],
                  ),
                  const SizedBox(height: 26),
                  const Center(
                    child: Text(
                      'Nostalia • Create beyond imagination',
                      style: TextStyle(color: Color(0xFF77717C), fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xCC160D17),
        border: Border.all(color: const Color(0xFF6A2457)),
        boxShadow: const [BoxShadow(color: Color(0x44FF2FA8), blurRadius: 12)],
      ),
      child: IconButton(
        onPressed: onTap,
        padding: EdgeInsets.zero,
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }
}

class _SettingsHero extends StatelessWidget {
  const _SettingsHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0x99150C17),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF5A234E)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 20,
            offset: Offset(0, 9),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                colors: [Color(0xFFFF36AE), Color(0xFFFF7A42)],
              ),
              boxShadow: const [
                BoxShadow(color: Color(0x77FF2EA8), blurRadius: 18),
              ],
            ),
            child: const Icon(
              Icons.tune_rounded,
              color: Colors.white,
              size: 29,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Make Nostalia yours',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Manage video playback and app data.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.35,
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFFFF72C2),
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0x99150F19),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF3D293C)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _SwitchSettingsTile extends StatelessWidget {
  const _SwitchSettingsTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return _SettingsTileLayout(
      icon: icon,
      title: title,
      subtitle: subtitle,
      trailing: Switch.adaptive(
        value: value,
        onChanged: enabled ? onChanged : null,
        activeTrackColor: const Color(0xFFFF4DB3),
        activeThumbColor: Colors.white,
      ),
    );
  }
}

class _ActionSettingsTile extends StatelessWidget {
  const _ActionSettingsTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: _SettingsTileLayout(
          icon: icon,
          title: title,
          subtitle: subtitle,
          trailing: const Icon(
            Icons.chevron_right_rounded,
            color: Color(0xFFB9B1BD),
            size: 27,
          ),
        ),
      ),
    );
  }
}

class _ValueSettingsTile extends StatelessWidget {
  const _ValueSettingsTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return _SettingsTileLayout(
      icon: icon,
      title: title,
      trailing: Text(
        value,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SettingsTileLayout extends StatelessWidget {
  const _SettingsTileLayout({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.trailing,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 76),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(13, 10, 10, 10),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF291525),
                border: Border.all(color: const Color(0xFF552047)),
              ),
              child: Icon(icon, color: const Color(0xFFFF69BD), size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        height: 1.3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing,
          ],
        ),
      ),
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, indent: 67, color: Color(0xFF302632));
  }
}

class _DialogIcon extends StatelessWidget {
  const _DialogIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFFFF3DAA), Color(0xFFFF7941)],
        ),
      ),
      child: Icon(icon, color: Colors.white),
    );
  }
}

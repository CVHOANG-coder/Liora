import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../../../core/device/image_access_permission.dart';
import '../../../core/media/video_cache_service.dart';
import '../../../core/media/video_thumbnail_cache.dart';
import '../../../core/storage/playback_preferences.dart';
import '../support/app_web_view_screen.dart';

// Match the navy surfaces and violet icon treatment used by Profile.
const _settingsBackground = Color(0xFF02050C);
const _settingsSecondary = Color(0xFFB4B1BD);
const _settingsBorder = Color(0xFF343743);
const _settingsSurface = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF0B101D), Color(0xFF070C17)],
);
const _settingsIconGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFE49CEE), Color(0xFFB640F1)],
);

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
  bool _isClearingCache = false;

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

  Future<void> _clearMediaCache() async {
    if (_isClearingCache) return;
    setState(() => _isClearingCache = true);
    try {
      PaintingBinding.instance.imageCache
        ..clear()
        ..clearLiveImages();
      await Future.wait([
        DefaultCacheManager().emptyCache(),
        VideoCacheService.instance.clear(),
        VideoThumbnailCache.instance.clear(),
      ]);
      if (mounted) _showMessage('Image and video cache cleared.');
    } catch (_) {
      if (mounted) _showMessage('Unable to clear all cached media.');
    } finally {
      if (mounted) setState(() => _isClearingCache = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _settingsBackground,
      appBar: AppBar(
        key: const Key('settingsHeader'),
        backgroundColor: _settingsBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemNavigationBarColor: _settingsBackground,
          systemNavigationBarIconBrightness: Brightness.light,
          systemNavigationBarDividerColor: Colors.transparent,
        ),
        centerTitle: false,
        toolbarHeight: 84,
        leadingWidth: 68,
        titleSpacing: 8,
        leading: Padding(
          padding: const EdgeInsets.only(left: 14),
          child: _HeaderButton(
            key: const Key('settingsBackButton'),
            onTap: () => Navigator.maybePop(context),
          ),
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Settings',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Times New Roman',
                fontFamilyFallback: ['Times', 'serif'],
                fontSize: 32,
                height: 1.1,
                fontWeight: FontWeight.w400,
                letterSpacing: -0.8,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: 26,
              height: 2.5,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                gradient: const LinearGradient(
                  colors: [Color(0xFFEC5FB6), Color(0xFF6657FF)],
                ),
              ),
            ),
          ],
        ),
      ),
      body: ColoredBox(
        color: _settingsBackground,
        child: CustomScrollView(
          key: const PageStorageKey('settingsScroll'),
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
                    key: const Key('playbackSettingsGroup'),
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
                    key: const Key('appDataSettingsGroup'),
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
                        key: const Key('clearMediaCacheSetting'),
                        icon: Icons.cleaning_services_outlined,
                        title: 'Clear media cache',
                        subtitle: _isClearingCache
                            ? 'Clearing cached images and videos…'
                            : 'Remove cached thumbnails and videos',
                        onTap: _isClearingCache ? null : _clearMediaCache,
                        isBusy: _isClearingCache,
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  const _SectionTitle('LEGAL & ABOUT'),
                  const SizedBox(height: 9),
                  _SettingsGroup(
                    key: const Key('legalSettingsGroup'),
                    children: [
                      _ActionSettingsTile(
                        key: const Key('privacySetting'),
                        icon: Icons.shield_outlined,
                        title: 'Privacy',
                        subtitle: 'How the app protects your data',
                        onTap: () =>
                            AppWebViewScreen.open(context, AppWebPage.privacy),
                      ),
                      const _SettingsDivider(),
                      _ActionSettingsTile(
                        key: const Key('termsSetting'),
                        icon: Icons.description_outlined,
                        title: 'Terms of Service',
                        subtitle: 'Liora terms of use',
                        onTap: () =>
                            AppWebViewScreen.open(context, AppWebPage.terms),
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
                      'Liora • Create beyond imagination',
                      style: TextStyle(color: Color(0xFF777585), fontSize: 11),
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
    return Center(
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: _settingsSurface,
          border: Border.all(color: _settingsBorder, width: 0.6),
        ),
        child: IconButton(
          tooltip: 'Back',
          onPressed: onTap,
          padding: EdgeInsets.zero,
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 18,
          ),
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
      key: const Key('settingsHero'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF21172E), Color(0xFF0B101D), Color(0xFF070C17)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _settingsBorder, width: 0.6),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Make Liora yours',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    height: 1.25,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 7),
                Text(
                  'Manage video playback and app data.',
                  style: TextStyle(
                    color: _settingsSecondary,
                    fontSize: 12,
                    height: 1.4,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Image.asset(
            'assets/images/profile/setting_icon.png',
            width: 76,
            height: 76,
            fit: BoxFit.contain,
            excludeFromSemantics: true,
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
          color: Color(0xFFB052F5),
          fontSize: 11,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: _settingsSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _settingsBorder, width: 0.6),
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
      trailing: Semantics(
        label: title,
        child: Switch.adaptive(
          value: value,
          onChanged: enabled ? onChanged : null,
          activeTrackColor: const Color(0xFFA850CF),
          activeThumbColor: Colors.white,
          inactiveTrackColor: const Color(0xFF242638),
          inactiveThumbColor: const Color(0xFF9295A3),
          trackOutlineWidth: const WidgetStatePropertyAll(0.6),
          trackOutlineColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const Color(0xFFC875E1);
            }
            return const Color(0xFF454655);
          }),
        ),
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
    this.isBusy = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool isBusy;

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
          trailing: isBusy
              ? const SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: Color(0xFFB052F5),
                    semanticsLabel: 'Clearing cached media',
                  ),
                )
              : Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF211E36),
                  ),
                  child: const Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white,
                    size: 17,
                  ),
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
          color: _settingsSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w400,
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
      constraints: const BoxConstraints(minHeight: 78),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(13, 13, 12, 13),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF252139), Color(0xFF17172B)],
                ),
                border: Border.all(color: const Color(0xFF3A304C), width: 0.5),
              ),
              child: ShaderMask(
                shaderCallback: _settingsIconGradient.createShader,
                blendMode: BlendMode.srcIn,
                child: Icon(icon, color: Colors.white, size: 22),
              ),
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
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.25,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _settingsSecondary,
                        fontSize: 11,
                        height: 1.4,
                        fontWeight: FontWeight.w400,
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
    return const Divider(
      height: 0.6,
      thickness: 0.6,
      indent: 67,
      endIndent: 14,
      color: Color(0xFF262A39),
    );
  }
}

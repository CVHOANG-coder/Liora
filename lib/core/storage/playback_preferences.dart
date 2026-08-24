import 'package:shared_preferences/shared_preferences.dart';

class PlaybackSettings {
  const PlaybackSettings({
    required this.autoplayVideos,
    required this.startMuted,
  });

  final bool autoplayVideos;
  final bool startMuted;
}

abstract interface class PlaybackPreferences {
  Future<PlaybackSettings> load();

  Future<void> setAutoplayVideos(bool value);

  Future<void> setStartMuted(bool value);
}

class SharedPreferencesPlaybackPreferences implements PlaybackPreferences {
  SharedPreferencesPlaybackPreferences([this._preferences]);

  static const _autoplayKey = 'settings.autoplay_videos';
  static const _startMutedKey = 'settings.start_muted';

  SharedPreferencesAsync? _preferences;

  SharedPreferencesAsync get _store =>
      _preferences ??= SharedPreferencesAsync();

  @override
  Future<PlaybackSettings> load() async {
    return PlaybackSettings(
      autoplayVideos: await _store.getBool(_autoplayKey) ?? true,
      startMuted: await _store.getBool(_startMutedKey) ?? false,
    );
  }

  @override
  Future<void> setAutoplayVideos(bool value) =>
      _store.setBool(_autoplayKey, value);

  @override
  Future<void> setStartMuted(bool value) =>
      _store.setBool(_startMutedKey, value);
}

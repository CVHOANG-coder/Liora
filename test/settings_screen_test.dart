import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_gen/core/storage/playback_preferences.dart';
import 'package:video_gen/presentation/screens/profile/profile_screen.dart';
import 'package:video_gen/presentation/screens/settings/settings_screen.dart';

void main() {
  testWidgets('opens Settings from Profile', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: ProfileScreen())),
    );
    await tester.pump();

    final settingsRow = find.byKey(const Key('settingsRow'));
    await tester.ensureVisible(settingsRow);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: settingsRow, matching: find.byType(InkWell)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text('Make Nostalia yours'), findsOneWidget);
    expect(find.text('Autoplay videos'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('loads and saves playback preferences', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final preferences = _MemoryPlaybackPreferences(
      const PlaybackSettings(autoplayVideos: false, startMuted: true),
    );

    await tester.pumpWidget(
      MaterialApp(home: SettingsScreen(preferences: preferences)),
    );
    await tester.pumpAndSettle();

    final autoplaySwitch = find.descendant(
      of: find.byKey(const Key('autoplayVideosSetting')),
      matching: find.byType(Switch),
    );
    final mutedSwitch = find.descendant(
      of: find.byKey(const Key('startMutedSetting')),
      matching: find.byType(Switch),
    );
    expect(tester.widget<Switch>(autoplaySwitch).value, isFalse);
    expect(tester.widget<Switch>(mutedSwitch).value, isTrue);

    await tester.tap(autoplaySwitch);
    await tester.pump();
    await tester.tap(mutedSwitch);
    await tester.pump();

    expect(preferences.settings.autoplayVideos, isTrue);
    expect(preferences.settings.startMuted, isFalse);
    expect(tester.takeException(), isNull);
  });
}

class _MemoryPlaybackPreferences implements PlaybackPreferences {
  _MemoryPlaybackPreferences(this.settings);

  PlaybackSettings settings;

  @override
  Future<PlaybackSettings> load() async => settings;

  @override
  Future<void> setAutoplayVideos(bool value) async {
    settings = PlaybackSettings(
      autoplayVideos: value,
      startMuted: settings.startMuted,
    );
  }

  @override
  Future<void> setStartMuted(bool value) async {
    settings = PlaybackSettings(
      autoplayVideos: settings.autoplayVideos,
      startMuted: value,
    );
  }
}

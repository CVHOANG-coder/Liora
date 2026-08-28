import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_gen/core/storage/playback_preferences.dart';
import 'package:video_gen/presentation/screens/settings/settings_screen.dart';
import 'package:video_gen/shared/themes/app_theme.dart';

void main() {
  const previewPath = String.fromEnvironment('SETTINGS_PREVIEW_PATH');
  const sansPath = String.fromEnvironment('SETTINGS_PREVIEW_SANS');
  const serifPath = String.fromEnvironment('SETTINGS_PREVIEW_SERIF');

  setUpAll(() async {
    if (previewPath.isEmpty) return;
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    for (final family in ['Roboto', '.SF Pro Text', '.SF Pro Display']) {
      if (sansPath.isEmpty) continue;
      final loader = FontLoader(family)
        ..addFont(File(sansPath).readAsBytes().then(ByteData.sublistView));
      await loader.load();
    }
    if (serifPath.isNotEmpty) {
      final loader = FontLoader('Times New Roman')
        ..addFont(File(serifPath).readAsBytes().then(ByteData.sublistView));
      await loader.load();
    }
  });

  for (final size in [
    const Size(320, 568),
    const Size(393, 698),
    const Size(393, 852),
    const Size(430, 932),
  ]) {
    for (final textScale in [1.0, 1.5]) {
      testWidgets('Settings style and scrolling at $size, text $textScale', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.view.padding = const FakeViewPadding(top: 44, bottom: 34);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPadding);
        await tester.pumpWidget(
          RepaintBoundary(
            key: const Key('settingsPreview'),
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.dark,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(textScale)),
                child: child!,
              ),
              home: SettingsScreen(preferences: _MemoryPreferences()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
          const Color(0xFF02050C),
        );
        final title = tester.widget<Text>(find.text('Settings'));
        expect(title.style!.fontFamily, 'Times New Roman');
        expect(title.style!.fontWeight, FontWeight.w400);
        final header = tester.getRect(find.byKey(const Key('settingsHeader')));
        final back = tester.getRect(
          find.byKey(const Key('settingsBackButton')),
        );
        expect(back.width, greaterThanOrEqualTo(44));
        final hero = tester.widget<Container>(
          find.byKey(const Key('settingsHero')),
        );
        final heroDecoration = hero.decoration! as BoxDecoration;
        expect(heroDecoration.borderRadius, BorderRadius.circular(14));
        expect(heroDecoration.boxShadow, isNull);
        final artwork = find.byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.image is AssetImage &&
              (widget.image as AssetImage).assetName ==
                  'assets/images/profile/setting_icon.png',
        );
        expect(artwork, findsOneWidget);

        if (previewPath.isNotEmpty &&
            size == const Size(393, 852) &&
            textScale == 1) {
          await tester.runAsync(() async {
            await precacheImage(
              tester.widget<Image>(artwork).image,
              tester.element(find.byType(SettingsScreen)),
            );
          });
          await tester.pumpAndSettle();
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const Key('settingsPreview')),
          );
          await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 2);
            try {
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await File(previewPath).writeAsBytes(bytes!.buffer.asUint8List());
            } finally {
              image.dispose();
            }
          });
        }

        for (final group in [
          'playbackSettingsGroup',
          'appDataSettingsGroup',
          'legalSettingsGroup',
        ]) {
          final finder = find.byKey(Key(group));
          await tester.ensureVisible(finder);
          await tester.pumpAndSettle();
          final decoration =
              tester
                      .widget<Container>(
                        find
                            .descendant(
                              of: finder,
                              matching: find.byWidgetPredicate(
                                (widget) =>
                                    widget is Container &&
                                    widget.decoration is BoxDecoration &&
                                    (widget.decoration! as BoxDecoration)
                                            .borderRadius ==
                                        BorderRadius.circular(14),
                              ),
                            )
                            .first,
                      )
                      .decoration!
                  as BoxDecoration;
          expect((decoration.gradient! as LinearGradient).colors, const [
            Color(0xFF0B101D),
            Color(0xFF070C17),
          ]);
          expect(
            (decoration.border! as Border).top.color,
            const Color(0xFF343743),
          );
          expect(tester.takeException(), isNull);
        }
        await tester.ensureVisible(find.text('App version'));
        await tester.pumpAndSettle();
        expect(find.text('App version').hitTestable(), findsOneWidget);
        expect(tester.getRect(find.byKey(const Key('settingsHeader'))), header);
        expect(
          tester.getRect(find.byKey(const Key('settingsBackButton'))),
          back,
        );
        expect(
          find.byKey(const Key('settingsBackButton')).hitTestable(),
          findsOneWidget,
        );
        await tester.scrollUntilVisible(
          find.byKey(const Key('autoplayVideosSetting')),
          -200,
          scrollable: find.descendant(
            of: find.byKey(const PageStorageKey('settingsScroll')),
            matching: find.byType(Scrollable),
          ),
        );
        await tester.pumpAndSettle();
        final autoplay = tester.widget<Switch>(
          find.descendant(
            of: find.byKey(const Key('autoplayVideosSetting')),
            matching: find.byType(Switch),
          ),
        );
        expect(autoplay.activeTrackColor, const Color(0xFFA850CF));
        expect(autoplay.inactiveTrackColor, const Color(0xFF242638));
        expect(autoplay.onChanged, isNotNull);
        expect(tester.takeException(), isNull);
      });
    }
  }
}

class _MemoryPreferences implements PlaybackPreferences {
  PlaybackSettings settings = const PlaybackSettings(
    autoplayVideos: true,
    startMuted: false,
  );

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

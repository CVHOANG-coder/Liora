import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_gen/data/video_categories.dart';
import 'package:video_gen/presentation/screens/image_to_video/image_to_video_screen.dart';
import 'package:video_gen/presentation/screens/text_to_video/text_to_video_screen.dart';
import 'package:video_gen/presentation/screens/theme_to_video/theme_to_video_screen.dart';
import 'package:video_gen/presentation/widgets/video_form_widgets.dart';
import 'package:video_gen/shared/themes/app_theme.dart';

const _previewDirectory = String.fromEnvironment('FORM_PREVIEW_DIR');
const _sansPath = String.fromEnvironment('FORM_PREVIEW_SANS');
const _serifPath = String.fromEnvironment('FORM_PREVIEW_SERIF');

const _theme = VideoPost(
  id: 'dance',
  themeKey: 'dance',
  thumbnailUrl: '',
  videoUrl: null,
  description: 'Mad dance',
);

void main() {
  setUpAll(() async {
    if (_previewDirectory.isEmpty) return;
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    for (final family in ['Roboto', '.SF Pro Text', '.SF Pro Display']) {
      if (_sansPath.isEmpty) continue;
      final loader = FontLoader(family)
        ..addFont(File(_sansPath).readAsBytes().then(ByteData.sublistView));
      await loader.load();
    }
    if (_serifPath.isNotEmpty) {
      final loader = FontLoader('Times New Roman')
        ..addFont(File(_serifPath).readAsBytes().then(ByteData.sublistView));
      await loader.load();
    }
  });

  for (final form in ['image', 'text', 'theme']) {
    for (final size in [
      const Size(320, 568),
      const Size(393, 852),
      const Size(430, 932),
      const Size(568, 320),
    ]) {
      for (final scale in [1.0, 1.5, 2.0]) {
        testWidgets('$form layout at $size with text $scale', (tester) async {
          _setView(tester, size);
          await _pumpForm(tester, form, scale: scale);
          expect(tester.takeException(), isNull);
          expect(
            tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
            VideoFormStyle.background,
          );
          final header = tester.getRect(
            find.byKey(const Key('videoFormHeader')),
          );
          expect(header.top, greaterThanOrEqualTo(44));
          final title = tester.widget<Text>(
            find.text('${_title(form)} to video'),
          );
          expect(title.style!.fontFamily, 'Times New Roman');

          if (_previewDirectory.isNotEmpty &&
              size == const Size(393, 852) &&
              scale == 1) {
            await _capture(tester, form);
          }

          await _scrollTo(
            tester,
            find.byKey(const Key('videoSetting-Duration')),
          );
          await tester.tap(find.text('10s'));
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('videoFormSheet')), findsOneWidget);
          expect(tester.takeException(), isNull);
          await _scrollTo(tester, find.text('5s'), sheet: true);
          await tester.tap(find.text('5s'));
          await tester.pumpAndSettle();
          expect(find.text('5s'), findsOneWidget);

          await _scrollTo(
            tester,
            find.byKey(const Key('videoSetting-Quality')),
          );
          await tester.tap(find.text('Non-HD'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await _scrollTo(tester, find.text('HD'), sheet: true);
          await tester.tap(find.text('HD'));
          await tester.pumpAndSettle();
          expect(find.text('HD'), findsOneWidget);

          await _scrollTo(
            tester,
            find.byKey(const Key('videoGenerateSurface')),
          );
          final button = tester.getRect(
            find.byKey(const Key('videoGenerateSurface')),
          );
          expect(button.bottom, lessThanOrEqualTo(size.height - 34 + 0.1));
          final decoration =
              tester
                      .widget<Container>(
                        find.byKey(const Key('videoGenerateSurface')),
                      )
                      .decoration!
                  as BoxDecoration;
          expect(decoration.gradient, VideoFormStyle.gradient);
          // The back control stays available even after scrolling the form.
          expect(
            tester.getRect(find.byKey(const Key('videoFormHeader'))),
            header,
          );
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  for (final form in ['image', 'text']) {
    testWidgets('$form prompt counter and keyboard keep controls reachable', (
      tester,
    ) async {
      _setView(tester, const Size(320, 568));
      await _pumpForm(tester, form);
      final field = find.byKey(Key('${form}ToVideoPromptField'));
      await _scrollTo(tester, field);
      await tester.enterText(field, 'A cinematic scene');
      await tester.pump();
      expect(find.text('17/2800'), findsOneWidget);
      expect(tester.widget<TextField>(field).maxLength, 2800);
      final prompt = tester.widget<TextField>(field);
      tester.view.viewInsets = const FakeViewPadding(bottom: 230);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      await _scrollTo(tester, find.byKey(const Key('videoGenerateSurface')));
      expect(
        tester.getRect(find.byKey(const Key('videoGenerateSurface'))).bottom,
        lessThanOrEqualTo(338.1),
      );
      expect(prompt.controller!.text, 'A cinematic scene');
      expect(tester.takeException(), isNull);
    });
  }

  for (final form in ['image', 'theme']) {
    testWidgets('$form source sheet fits large text and landscape', (
      tester,
    ) async {
      _setView(tester, const Size(568, 320));
      await _pumpForm(tester, form, scale: 2);
      final card = find.byKey(
        Key(form == 'image' ? 'imageToVideoImageCard' : 'firstFrameCard'),
      );
      await _scrollTo(tester, card);
      final scroll = find.byKey(const PageStorageKey('videoFormScroll'));
      final visibleCard = tester
          .getRect(card)
          .intersect(tester.getRect(scroll));
      await tester.tapAt(visibleCard.center);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('videoFormSheet')), findsOneWidget);
      expect(tester.takeException(), isNull);
      final source = find.byKey(
        Key(form == 'image' ? 'cameraImageSource' : 'cameraFrameSource'),
      );
      await _scrollTo(tester, source, sheet: true);
      expect(source.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

String _title(String form) => switch (form) {
  'image' => 'Image',
  'text' => 'Text',
  _ => 'Theme',
};

void _setView(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 44, bottom: 34);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPadding);
}

Future<void> _pumpForm(
  WidgetTester tester,
  String form, {
  double scale = 1,
}) async {
  final theme = _previewDirectory.isEmpty
      ? AppTheme.dark
      : AppTheme.dark.copyWith(
          textTheme: AppTheme.dark.textTheme.apply(fontFamily: 'Roboto'),
        );
  await tester.pumpWidget(
    RepaintBoundary(
      key: const Key('formPreview'),
      child: ProviderScope(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: theme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: switch (form) {
            'image' => const ImageToVideoScreen(),
            'text' => const TextToVideoScreen(),
            _ => const ThemeToVideoScreen(theme: _theme),
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _scrollTo(
  WidgetTester tester,
  Finder target, {
  bool sheet = false,
}) async {
  final scrollable = find
      .descendant(
        of: find.byKey(
          sheet
              ? const Key('videoFormSheet')
              : const PageStorageKey('videoFormScroll'),
        ),
        matching: find.byType(Scrollable),
      )
      .first;
  // Scroll from the gutter so the prompt's own scroll view cannot consume it.
  for (var i = 0; target.evaluate().isEmpty && i < 40; i++) {
    final rect = tester.getRect(scrollable);
    await tester.dragFrom(
      Offset(rect.left + 2, rect.center.dy),
      const Offset(0, -100),
    );
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

Future<void> _capture(WidgetTester tester, String name) async {
  final context = tester.element(find.byType(VideoFormLayout));
  await tester.runAsync(() async {
    for (final asset in ['add_image_icon.png', 'clock.png', 'HD_icon.png']) {
      await precacheImage(
        AssetImage('assets/images/gen_video/$asset'),
        context,
      );
    }
  });
  await tester.pumpAndSettle();
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('formPreview')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        '$_previewDirectory/$name-form-preview.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

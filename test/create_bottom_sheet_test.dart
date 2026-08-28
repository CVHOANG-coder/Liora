import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_gen/core/firebase/firebase_service.dart';
import 'package:video_gen/data/video_categories.dart';
import 'package:video_gen/presentation/providers/theme_provider.dart';
import 'package:video_gen/presentation/screens/main/main_screen.dart';
import 'package:video_gen/presentation/screens/image_to_video/image_to_video_screen.dart';
import 'package:video_gen/presentation/screens/text_to_video/text_to_video_screen.dart';
import 'package:video_gen/presentation/widgets/create_bottom_sheet.dart';
import 'package:video_gen/shared/themes/app_theme.dart';

const _previewPath = String.fromEnvironment('CREATE_SHEET_PREVIEW_PATH');
const _sansPath = String.fromEnvironment('CREATE_SHEET_PREVIEW_SANS');
const _serifPath = String.fromEnvironment('CREATE_SHEET_PREVIEW_SERIF');

void main() {
  setUpAll(() async {
    if (_previewPath.isEmpty) return;
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    if (_sansPath.isNotEmpty) {
      for (final family in ['Roboto', '.SF Pro Text', '.SF Pro Display']) {
        final loader = FontLoader(family)
          ..addFont(File(_sansPath).readAsBytes().then(ByteData.sublistView));
        await loader.load();
      }
    }
    if (_serifPath.isNotEmpty) {
      final loader = FontLoader('Times New Roman')
        ..addFont(File(_serifPath).readAsBytes().then(ByteData.sublistView));
      await loader.load();
    }
  });

  for (final size in [
    const Size(320, 568),
    const Size(393, 852),
    const Size(430, 932),
    const Size(568, 320),
  ]) {
    for (final textScale in [1.0, 1.5, 2.0]) {
      testWidgets('Create sheet layout at $size, text $textScale', (
        tester,
      ) async {
        _configureView(tester, size);
        final previousShadows = debugDisableShadows;
        try {
          if (_previewPath.isNotEmpty) debugDisableShadows = false;
          await tester.pumpWidget(
            MaterialApp(
              theme: _theme,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(textScale)),
                child: child!,
              ),
              home: _SheetHarness(),
            ),
          );
          await tester.tap(find.text('Open create'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final surface =
              tester
                      .widget<Container>(
                        find.byKey(const Key('createSheetSurface')),
                      )
                      .decoration!
                  as BoxDecoration;
          expect(surface.color, const Color(0xFF02050C));
          expect(
            (surface.border! as Border).top.color,
            const Color(0xFF343743),
          );
          expect(
            surface.borderRadius,
            const BorderRadius.vertical(top: Radius.circular(28)),
          );
          final title = tester.widget<Text>(find.text('Create AI video'));
          expect(title.style!.fontFamily, 'Times New Roman');
          expect(title.style!.fontWeight, FontWeight.w400);
          final close = tester.getRect(
            find.byKey(const Key('createSheetCloseButton')),
          );
          expect(close.width, closeTo(44, 0.001));
          expect(close.height, closeTo(44, 0.001));

          if (_previewPath.isNotEmpty &&
              size == const Size(393, 852) &&
              textScale == 1) {
            await tester.runAsync(() async {
              final context = tester.element(find.byType(CreateBottomSheet));
              for (final name in ['text_to_video', 'image_to_video']) {
                await precacheImage(
                  AssetImage('assets/images/home/$name.png'),
                  context,
                );
              }
            });
            await tester.pumpAndSettle();
            final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(const Key('createSheetPreview')),
            );
            await tester.runAsync(() async {
              final image = await boundary.toImage(pixelRatio: 2);
              try {
                final bytes = await image.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                await File(
                  _previewPath,
                ).writeAsBytes(bytes!.buffer.asUint8List());
              } finally {
                image.dispose();
              }
            });
          }

          for (final option in [
            (key: 'createTextToVideo', badge: 'PROMPT', asset: 'text_to_video'),
            (
              key: 'createImageToVideo',
              badge: 'PHOTO',
              asset: 'image_to_video',
            ),
          ]) {
            final finder = find.byKey(Key(option.key));
            await tester.ensureVisible(finder);
            await tester.pumpAndSettle();
            final card =
                tester
                        .widget<Container>(
                          find.byKey(
                            ValueKey('createOptionSurface-${option.badge}'),
                          ),
                        )
                        .decoration!
                    as BoxDecoration;
            expect((card.gradient! as LinearGradient).colors, const [
              Color(0xFF0B101D),
              Color(0xFF070C17),
            ]);
            expect(card.borderRadius, BorderRadius.circular(14));
            expect(card.boxShadow, isNull);
            expect(
              find.descendant(
                of: finder,
                matching: find.byWidgetPredicate(
                  (widget) =>
                      widget is Image &&
                      widget.image is AssetImage &&
                      (widget.image as AssetImage).assetName ==
                          'assets/images/home/${option.asset}.png',
                ),
              ),
              findsOneWidget,
            );
            expect(tester.takeException(), isNull);
          }
          await tester.ensureVisible(find.byKey(const Key('createSheetHint')));
          await tester.pumpAndSettle();
          expect(
            find.byKey(const Key('createSheetHint')).hitTestable(),
            findsOneWidget,
          );
          expect(
            tester.getRect(find.byKey(const Key('createSheetCloseButton'))),
            close,
          );
          await tester.tap(find.byKey(const Key('createSheetCloseButton')));
          await tester.pumpAndSettle();
          expect(find.byType(CreateBottomSheet), findsNothing);
          expect(tester.takeException(), isNull);
        } finally {
          debugDisableShadows = previousShadows;
        }
      });
    }
  }

  for (final tab in [0, 1]) {
    for (final option in [
      (key: 'createTextToVideo', screen: TextToVideoScreen),
      (key: 'createImageToVideo', screen: ImageToVideoScreen),
    ]) {
      testWidgets('tab $tab opens ${option.key} through the shared sheet', (
        tester,
      ) async {
        _configureView(tester, const Size(393, 852));
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              themeCategoriesProvider.overrideWith(
                (_) async => const <VideoCategory>[],
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.dark,
              home: MainScreen(
                initialIndex: tab,
                showTrialOffer: false,
                notificationPermissionRequester: () async =>
                    NotificationPermissionFlowResult.granted,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('createButton')));
        await tester.pumpAndSettle();
        expect(find.byType(CreateBottomSheet), findsOneWidget);
        await tester.ensureVisible(find.byKey(Key(option.key)));
        await tester.tap(find.byKey(Key(option.key)));
        await tester.pumpAndSettle();
        expect(find.byType(CreateBottomSheet), findsNothing);
        expect(find.byType(option.screen), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('barrier and swipe still dismiss without selecting a mode', (
    tester,
  ) async {
    _configureView(tester, const Size(393, 852));
    CreateVideoMode? result = CreateVideoMode.textToVideo;
    final harness = _SheetHarness(onResult: (value) => result = value);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.dark, home: harness));
    await tester.tap(find.text('Open create'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(12, 55));
    await tester.pumpAndSettle();
    expect(find.byType(CreateBottomSheet), findsNothing);
    expect(result, isNull);
    result = CreateVideoMode.imageToVideo;
    await tester.tap(find.text('Open create'));
    await tester.pumpAndSettle();
    await tester.fling(
      find.byKey(const Key('createSheetHandle')),
      const Offset(0, 450),
      1000,
    );
    await tester.pumpAndSettle();
    expect(find.byType(CreateBottomSheet), findsNothing);
    expect(result, isNull);
    expect(tester.takeException(), isNull);
  });
}

ThemeData get _theme => _previewPath.isEmpty
    ? AppTheme.dark
    : AppTheme.dark.copyWith(
        textTheme: AppTheme.dark.textTheme.apply(fontFamily: 'Roboto'),
      );

void _configureView(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 44, bottom: 34);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPadding);
}

class _SheetHarness extends StatelessWidget {
  const _SheetHarness({this.onResult});

  final ValueChanged<CreateVideoMode?>? onResult;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(
        onPressed: () async {
          final result = await showModalBottomSheet<CreateVideoMode>(
            context: context,
            useSafeArea: true,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => const RepaintBoundary(
              key: Key('createSheetPreview'),
              child: CreateBottomSheet(),
            ),
          );
          onResult?.call(result);
        },
        child: const Text('Open create'),
      ),
    ),
  );
}

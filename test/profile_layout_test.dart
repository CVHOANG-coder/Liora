import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_gen/core/constants/app_features.dart';
import 'package:video_gen/data/models/user_profile.dart';
import 'package:video_gen/data/video_categories.dart';
import 'package:video_gen/presentation/providers/profile_provider.dart';
import 'package:video_gen/presentation/providers/theme_provider.dart';
import 'package:video_gen/presentation/screens/main/main_screen.dart';
import 'package:video_gen/presentation/screens/profile/profile_screen.dart';
import 'package:video_gen/shared/themes/app_theme.dart';

void main() {
  const previewPath = String.fromEnvironment('PROFILE_PREVIEW_PATH');
  const sansPath = String.fromEnvironment('PROFILE_PREVIEW_SANS');
  const serifPath = String.fromEnvironment('PROFILE_PREVIEW_SERIF');

  // Optional local preview uses real fonts; regular CI tests need no host fonts.
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
    testWidgets(
      'Profile reference layout and navigation remain usable at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.view.padding = const FakeViewPadding(top: 24, bottom: 0);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPadding);

        final container = ProviderContainer(
          overrides: [
            appVersionProvider.overrideWith((ref) async => '1.0.0'),
            themeCategoriesProvider.overrideWith(
              (ref) async => const <VideoCategory>[],
            ),
          ],
        );
        addTearDown(container.dispose);
        container
            .read(profileProvider.notifier)
            .setProfile(
              UserProfile.fromJson({
                'user_code': 'GIPAU6JAQS1N6ABCDEFGHIJ',
                'total_credit': 5,
                'is_actived': true,
              }),
            );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: RepaintBoundary(
              key: const Key('profilePreview'),
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: AppTheme.dark,
                home: const MainScreen(initialIndex: 1, showTrialOffer: false),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        final scale = size.width / 393;
        expect(
          tester.getSize(find.byKey(const Key('profileAvatar'))).width,
          closeTo(118 * scale, 0.01),
        );
        final stats = tester.getRect(find.byKey(const Key('profileStats')));
        final menu = tester.getRect(find.byKey(const Key('videoHistoryRow')));
        expect(stats.left, closeTo(14 * scale, 0.01));
        expect(stats.height, closeTo(89 * scale, 0.01));
        if (AppFeatures.commerceEnabled) {
          final credit = tester.getRect(
            find.byKey(const Key('profileCreditCard')),
          );
          expect(credit.top - stats.bottom, closeTo(10 * scale, 0.01));
          expect(credit.height, closeTo(152 * scale, 0.01));
          expect(menu.top - credit.bottom, closeTo(9 * scale, 0.01));
        } else {
          expect(find.byKey(const Key('profileCreditCard')), findsNothing);
          expect(menu.top - stats.bottom, closeTo(9 * scale, 0.01));
        }
        expect(menu.height, closeTo(134 * scale, 0.01));
        expect(
          find.text('Buy More Credits'),
          AppFeatures.commerceEnabled ? findsOneWidget : findsNothing,
        );
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Image &&
                widget.image is AssetImage &&
                (widget.image as AssetImage).assetName ==
                    'assets/images/profile/help_icon.png',
          ),
          AppFeatures.externalLinksEnabled ? findsOneWidget : findsNothing,
        );
        if (AppFeatures.commerceEnabled) {
          final badge = tester.widget<Container>(
            find.byKey(const Key('profilePlanBadge')),
          );
          expect((badge.decoration! as BoxDecoration).boxShadow, isNull);
        } else {
          expect(find.byKey(const Key('profilePlanBadge')), findsNothing);
        }

        if (previewPath.isNotEmpty && size == const Size(393, 698)) {
          await tester.runAsync(() async {
            final context = tester.element(find.byType(ProfileScreen));
            for (final image in tester.widgetList<Image>(find.byType(Image))) {
              await precacheImage(image.image, context);
            }
          });
          await tester.pumpAndSettle();
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const Key('profilePreview')),
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

        final header = tester.getRect(find.byKey(const Key('profileHeader')));
        await tester.drag(
          find.byKey(const PageStorageKey('profileScroll')),
          const Offset(0, -500),
        );
        await tester.pumpAndSettle();
        expect(tester.getRect(find.byKey(const Key('profileHeader'))), header);
        expect(find.byKey(const Key('profileAppVersion')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_gen/data/video_categories.dart';
import 'package:video_gen/presentation/providers/theme_provider.dart';
import 'package:video_gen/presentation/screens/home/home_screen.dart';
import 'package:video_gen/presentation/screens/theme_to_video/theme_to_video_screen.dart';
import 'package:video_gen/presentation/screens/video_detail/video_detail_screen.dart';

void main() {
  const post = VideoPost(
    id: 'preview-post',
    thumbnailUrl: 'https://example.com/preview.jpg',
    previewWebpUrl: 'https://example.com/preview.webp',
    videoUrl: null,
    description: 'Cinematic portrait',
  );

  testWidgets('shows the selected video template details and interactions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: VideoDetailScreen(post: post)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cinematic portrait'), findsOneWidget);
    expect(find.text('Use AI Template ✨'), findsOneWidget);
    expect(find.text('@VideoGen AI'), findsNothing);
    expect(find.text('Filter: Viral dances'), findsNothing);
    expect(find.text('00:24'), findsNothing);
    expect(find.text('1 clip'), findsNothing);
    expect(find.text('2 uses'), findsNothing);
    expect(find.bySemanticsLabel('Turn sound on'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.bySemanticsLabel('Turn sound on'));
    await tester.pump();

    expect(find.bySemanticsLabel('Mute'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens video details when a Home thumbnail is tapped', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          themeCategoriesProvider.overrideWith(
            (ref) async => const <VideoCategory>[
              VideoCategory(
                id: 'viral-dances',
                title: 'Viral dances',
                posts: <VideoPost>[post],
              ),
            ],
          ),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final thumbnail = find.byKey(const Key('videoThumbnail_preview-post'));
    expect(thumbnail, findsOneWidget);

    await tester.ensureVisible(thumbnail);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(thumbnail);
    await tester.pumpAndSettle();

    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pump();

    expect(find.byType(VideoDetailScreen), findsOneWidget);
    expect(find.text('Use AI Template ✨'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('use template opens Theme to Video with the selected theme', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: VideoDetailScreen(post: post)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('useVideoTemplateButton')));
    await tester.pumpAndSettle();

    expect(find.byType(ThemeToVideoScreen), findsOneWidget);
    expect(find.text('Theme to video'), findsOneWidget);
    expect(find.text('Cinematic portrait'), findsOneWidget);
    expect(find.text('Prompt'), findsNothing);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_gen/main.dart';

void main() {
  testWidgets('navigates between home and profile', (tester) async {
    await tester.pumpWidget(const VideoGenApp());
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('trialLaterButton')));
    await tester.tap(find.byKey(const Key('trialLaterButton')));
    await tester.pumpAndSettle();

    expect(find.text('Tạo phim ngắn AI 17+'), findsOneWidget);
    expect(find.text('Me'), findsOneWidget);

    await tester.tap(find.byKey(const Key('profileTab')));
    await tester.pumpAndSettle();

    expect(find.text('Luna Noir'), findsOneWidget);
    expect(find.text('@lunavelora'), findsOneWidget);
  });

  testWidgets('center add button opens create sheet', (tester) async {
    await tester.pumpWidget(const VideoGenApp());
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('trialLaterButton')));
    await tester.tap(find.byKey(const Key('trialLaterButton')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('createButton')));
    await tester.pumpAndSettle();

    expect(find.text('Bạn muốn tạo gì?'), findsOneWidget);
    expect(find.text('Video'), findsOneWidget);
    expect(find.text('Hình ảnh'), findsOneWidget);
    expect(find.text('Từ mẫu'), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_gen/presentation/screens/in_app_purchase/all_plans_screen.dart';
import 'package:video_gen/presentation/widgets/trial_offer_dialog.dart';

void main() {
  testWidgets('shows the free-trial timeline and opens all plans', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => TrialOfferDialog.show(context),
              child: const Text('Open trial'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open trial'));
    await tester.pumpAndSettle();

    expect(find.text('How your'), findsOneWidget);
    expect(find.text('free trial works'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('In 2 days'), findsOneWidget);
    expect(find.text('In 3 days'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final viewPlans = find.byKey(const Key('viewAllPlansButton'));
    await tester.ensureVisible(viewPlans);
    await tester.pumpAndSettle();
    await tester.tap(viewPlans);
    await tester.pumpAndSettle();

    expect(find.byType(AllPlans), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

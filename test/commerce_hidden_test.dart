import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_gen/core/constants/app_features.dart';
import 'package:video_gen/core/firebase/firebase_service.dart';
import 'package:video_gen/core/network/api_exception.dart';
import 'package:video_gen/data/video_categories.dart';
import 'package:video_gen/main.dart';
import 'package:video_gen/presentation/providers/purchase_provider.dart';
import 'package:video_gen/presentation/providers/theme_provider.dart';
import 'package:video_gen/presentation/screens/in_app_purchase/all_plans_screen.dart';
import 'package:video_gen/presentation/screens/in_app_purchase/free_trial_screen.dart';
import 'package:video_gen/presentation/screens/in_app_purchase/in_app_purchase_screen.dart';
import 'package:video_gen/presentation/screens/main/main_screen.dart';
import 'package:video_gen/presentation/screens/profile/profile_screen.dart';
import 'package:video_gen/presentation/screens/settings/settings_screen.dart';
import 'package:video_gen/presentation/screens/support/support_contact_screen.dart';
import 'package:video_gen/presentation/widgets/generation_failure_dialog.dart';

void main() {
  test('commerce is enabled by default in the current build', () {
    expect(AppFeatures.commerceEnabled, isTrue);
  });

  test('onboarding is enabled by default in the current build', () {
    expect(AppFeatures.onboardingEnabled, isTrue);
  });

  test('Privacy, Terms, and Help links are enabled by default', () {
    expect(AppFeatures.externalLinksEnabled, isTrue);
  });

  testWidgets('purchase, credit, and plan entry points are visible', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer(
      overrides: [
        appVersionProvider.overrideWith((ref) async => '1.0.0'),
        themeCategoriesProvider.overrideWith(
          (ref) async => const <VideoCategory>[],
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: MainScreen(
            showTrialOffer: false,
            notificationPermissionRequester: () async =>
                NotificationPermissionFlowResult.denied,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('homeProButton')), findsOneWidget);
    expect(find.byType(FreeTrialScreen), findsNothing);
    expect(find.byType(AllPlans), findsNothing);
    expect(find.byType(BuyCredits), findsNothing);

    await tester.tap(find.byKey(const Key('profileTab')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('profilePlanBadge')), findsOneWidget);
    expect(find.byKey(const Key('profileCreditCard')), findsOneWidget);
    expect(find.byKey(const Key('buyMoreCreditsButton')), findsOneWidget);
    expect(find.text('Active Plan'), findsOneWidget);
    expect(find.byKey(const Key('helpCenterRow')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('buyMoreCreditsButton')));
    await tester.tap(find.byKey(const Key('buyMoreCreditsButton')));
    await tester.pumpAndSettle();
    expect(find.byType(BuyCredits), findsOneWidget);

    Navigator.of(tester.element(find.byType(BuyCredits))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('settingsRow')));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.byKey(const Key('privacySetting')), findsOneWidget);
    expect(find.byKey(const Key('termsSetting')), findsOneWidget);
    expect(find.text('Privacy'), findsOneWidget);
    expect(find.text('Terms of Service'), findsOneWidget);
    expect(find.text('LEGAL & ABOUT'), findsOneWidget);
  });

  testWidgets('support screen exposes the Support Center link', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              key: const Key('openSupportScreen'),
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => const SupportContactScreen(),
                ),
              ),
              child: const Text('Open internal support'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('openSupportScreen')));
    await tester.pumpAndSettle();
    expect(find.byType(SupportContactScreen), findsOneWidget);
    expect(find.text('Open Support Center'), findsOneWidget);
  });

  testWidgets(
    'Privacy, Terms, and Help UI is visible when external links are enabled',
    (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: ProfileScreen())),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('helpCenterRow')), findsOneWidget);

      await tester.tap(find.byKey(const Key('settingsRow')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('privacySetting')), findsOneWidget);
      expect(find.byKey(const Key('termsSetting')), findsOneWidget);

      await tester.pumpWidget(const MaterialApp(home: SupportContactScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Open Support Center'), findsOneWidget);
    },
    skip: !AppFeatures.externalLinksEnabled,
  );

  testWidgets('non-Google Play builds do not initialize the purchase gateway', (
    tester,
  ) async {
    var gatewayCreated = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          googlePlayPlatformProvider.overrideWith((ref) => false),
          purchaseGatewayProvider.overrideWith((ref) {
            gatewayCreated = true;
            throw StateError('Purchase gateway must not be created.');
          }),
        ],
        child: const VideoGenApp(home: SizedBox.shrink()),
      ),
    );
    await tester.pump();

    expect(gatewayCreated, isFalse);
    expect(tester.takeException(), isNull);
  });

  test('credit and subscription errors expose purchase actions', () {
    const expectedActions = {
      ApiErrorCode.insufficientCredit: GenerationFailureAction.buyCredits,
      ApiErrorCode.subscriptionExpired:
          GenerationFailureAction.renewSubscription,
    };
    for (final entry in expectedActions.entries) {
      final presentation = resolveApiErrorPresentation(
        ApiException(message: 'Server commerce message', errorCode: entry.key),
        fallbackMessage: 'Unable to generate.',
      );

      expect(presentation.primaryAction, entry.value);
    }
  });
}

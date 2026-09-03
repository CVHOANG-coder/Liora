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
import 'package:video_gen/presentation/screens/support/app_web_view_screen.dart';
import 'package:video_gen/presentation/screens/support/support_contact_screen.dart';
import 'package:video_gen/presentation/widgets/generation_failure_dialog.dart';

void main() {
  test('commerce is disabled by default in the current build', () {
    expect(AppFeatures.commerceEnabled, isFalse);
  });

  test('onboarding is disabled by default in the current build', () {
    expect(AppFeatures.onboardingEnabled, isFalse);
  });

  test('Privacy, Terms, and Help links are disabled by default', () {
    expect(AppFeatures.externalLinksEnabled, isFalse);
  });

  testWidgets('purchase, credit, and plan entry points are hidden', (
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
            notificationPermissionRequester: () async =>
                NotificationPermissionFlowResult.denied,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('homeProButton')), findsNothing);
    expect(find.byType(FreeTrialScreen), findsNothing);
    expect(find.byType(AllPlans), findsNothing);
    expect(find.byType(BuyCredits), findsNothing);

    await tester.tap(find.byKey(const Key('profileTab')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('profilePlanBadge')), findsNothing);
    expect(find.byKey(const Key('profileCreditCard')), findsNothing);
    expect(find.byKey(const Key('buyMoreCreditsButton')), findsNothing);
    expect(find.text('Active Plan'), findsNothing);
    expect(find.byKey(const Key('helpCenterRow')), findsNothing);

    await tester.tap(find.byKey(const Key('settingsRow')));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.byKey(const Key('privacySetting')), findsNothing);
    expect(find.byKey(const Key('termsSetting')), findsNothing);
    expect(find.text('Privacy'), findsNothing);
    expect(find.text('Terms of Service'), findsNothing);
    expect(find.text('ABOUT'), findsOneWidget);
  });

  testWidgets('support screen and web navigator expose no external links', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Column(
              children: [
                ElevatedButton(
                  key: const Key('openBlockedPrivacy'),
                  onPressed: () =>
                      AppWebViewScreen.open(context, AppWebPage.privacy),
                  child: const Text('Attempt privacy'),
                ),
                ElevatedButton(
                  key: const Key('openSupportScreen'),
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const SupportContactScreen(),
                    ),
                  ),
                  child: const Text('Open internal support'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('openBlockedPrivacy')));
    await tester.pumpAndSettle();
    expect(find.byType(AppWebViewScreen), findsNothing);

    await tester.tap(find.byKey(const Key('openSupportScreen')));
    await tester.pumpAndSettle();
    expect(find.byType(SupportContactScreen), findsOneWidget);
    expect(find.text('Open Support Center'), findsNothing);
  });

  testWidgets(
    'Privacy, Terms, and Help UI remains available behind the feature flag',
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

  testWidgets('app does not initialize the purchase gateway', (tester) async {
    var gatewayCreated = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          purchaseGatewayProvider.overrideWith((ref) {
            gatewayCreated = true;
            throw StateError('Purchase gateway must stay disabled.');
          }),
        ],
        child: const VideoGenApp(home: SizedBox.shrink()),
      ),
    );
    await tester.pump();

    expect(gatewayCreated, isFalse);
    expect(tester.takeException(), isNull);
  });

  test('credit and subscription errors do not expose purchase actions', () {
    for (final code in [
      ApiErrorCode.insufficientCredit,
      ApiErrorCode.subscriptionExpired,
    ]) {
      final presentation = resolveApiErrorPresentation(
        ApiException(message: 'Server commerce message', errorCode: code),
        fallbackMessage: 'Unable to generate.',
      );

      expect(presentation.primaryAction, GenerationFailureAction.close);
      expect(presentation.title, 'Feature Temporarily Unavailable');
      expect(presentation.message.toLowerCase(), isNot(contains('credit')));
      expect(
        presentation.message.toLowerCase(),
        isNot(contains('subscription')),
      );
    }
  });
}

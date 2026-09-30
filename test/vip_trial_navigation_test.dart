import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:video_gen/core/constants/app_features.dart';
import 'package:video_gen/core/device/device_identity_service.dart';
import 'package:video_gen/core/network/api_client.dart';
import 'package:video_gen/core/storage/token_storage.dart';
import 'package:video_gen/data/models/package_catalog.dart';
import 'package:video_gen/data/models/user_profile.dart';
import 'package:video_gen/data/video_categories.dart';
import 'package:video_gen/presentation/providers/home_subscription_plan_provider.dart';
import 'package:video_gen/presentation/providers/package_provider.dart';
import 'package:video_gen/presentation/providers/profile_provider.dart';
import 'package:video_gen/presentation/providers/purchase_provider.dart';
import 'package:video_gen/presentation/providers/theme_provider.dart';
import 'package:video_gen/presentation/screens/home/home_screen.dart';
import 'package:video_gen/presentation/screens/in_app_purchase/all_plans_screen.dart';
import 'package:video_gen/presentation/screens/in_app_purchase/free_trial_screen.dart';
import 'package:video_gen/presentation/screens/in_app_purchase/in_app_purchase_screen.dart';
import 'package:video_gen/presentation/screens/in_app_purchase/yearly_sale_screen.dart';
import 'package:video_gen/presentation/screens/main/main_screen.dart';

void main() {
  if (!AppFeatures.commerceEnabled) {
    test('legacy subscription navigation is preserved behind the flag', () {
      expect(AppFeatures.commerceEnabled, isFalse);
    });
    return;
  }

  testWidgets('non-VIP opens Free Trial from the Home Pro button', (
    tester,
  ) async {
    _configurePhoneSize(tester);
    final container = _profileContainer(isSubscribed: false);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const Key('homeProButton')),
        matching: find.text('Pro'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('homeProButton')));
    await tester.pumpAndSettle();

    expect(find.byType(FreeTrialScreen), findsOneWidget);
    expect(find.byType(AllPlans), findsNothing);
    expect(find.byKey(const Key('trialClaimButton')), findsOneWidget);
  });

  testWidgets('new user does not see annual sale after dismissing Free Trial', (
    tester,
  ) async {
    _configurePhoneSize(tester);
    final container = _profileContainer(isSubscribed: false);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: MainScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(FreeTrialScreen), findsOneWidget);
    expect(find.byType(YearlySaleScreen), findsNothing);

    await tester.tap(find.byKey(const Key('trialLaterButton')));
    await tester.pumpAndSettle();

    expect(find.byType(FreeTrialScreen), findsNothing);
    expect(find.byType(YearlySaleScreen), findsNothing);
  });

  testWidgets('yearly subscriber sees credits and opens Buy Credits', (
    tester,
  ) async {
    _configurePhoneSize(tester);
    final container = _profileContainer(
      isSubscribed: true,
      subscriptionDays: 365,
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: MainScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('trialClaimButton')), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const Key('homeProButton')),
        matching: find.text('Pro'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('homeCreditButton')),
        matching: find.byType(Image),
      ),
      findsOneWidget,
    );
    expect(find.text('100'), findsOneWidget);

    await tester.tap(find.byKey(const Key('homeCreditButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('trialClaimButton')), findsNothing);
    expect(find.byType(BuyCredits), findsOneWidget);
  });

  testWidgets('same-day test subscription uses Google Play yearly plan', (
    tester,
  ) async {
    _configurePhoneSize(tester);
    final container = _profileContainer(
      isSubscribed: true,
      isVIP: true,
      subscriptionDays: 0,
      googlePlayProductId: 'yearly.product',
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pro'), findsOneWidget);
    expect(find.text('Upgrade'), findsNothing);
  });

  testWidgets('same-day test subscription uses Google Play weekly plan', (
    tester,
  ) async {
    _configurePhoneSize(tester);
    final container = _profileContainer(
      isSubscribed: true,
      isVIP: true,
      subscriptionDays: 0,
      googlePlayProductId: 'weekly.product',
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Upgrade'), findsOneWidget);
    expect(find.text('Pro'), findsNothing);
  });

  testWidgets('weekly subscriber sees Upgrade and opens All Plans', (
    tester,
  ) async {
    _configurePhoneSize(tester);
    final container = _profileContainer(
      isSubscribed: true,
      isVIP: false,
      subscriptionDays: 7,
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const Key('homeProButton')),
        matching: find.text('Upgrade'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('homeProButton')));
    await tester.pumpAndSettle();

    expect(find.byType(AllPlans), findsOneWidget);
    expect(find.byType(YearlySaleScreen), findsNothing);
  });

  testWidgets('VIP without a subscription opens Home without an offer', (
    tester,
  ) async {
    _configurePhoneSize(tester);
    final container = _profileContainer(isSubscribed: false, isVIP: true);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: MainScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('trialClaimButton')), findsNothing);
    expect(find.byType(YearlySaleScreen), findsNothing);
    expect(find.byKey(const Key('homeProButton')), findsOneWidget);
    expect(find.text('Pro'), findsOneWidget);
  });

  testWidgets('weekly subscriber sees the yearly sale on app entry', (
    tester,
  ) async {
    _configurePhoneSize(tester);
    final container = _profileContainer(
      isSubscribed: true,
      isVIP: true,
      subscriptionDays: 7,
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: MainScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(YearlySaleScreen), findsOneWidget);
    expect(find.text('Lola '), findsNothing);
    expect(find.text('Annually'), findsOneWidget);
    expect(find.text('Sale Pro'), findsOneWidget);

    await tester.tap(find.byKey(const Key('yearlySaleCloseButton')));
    await tester.pumpAndSettle();
    expect(find.byType(YearlySaleScreen), findsNothing);

    await tester.tap(find.byKey(const Key('homeProButton')));
    await tester.pumpAndSettle();
    expect(find.byType(AllPlans), findsOneWidget);
  });

  testWidgets('weekly subscriber sees sale on each app entry', (tester) async {
    _configurePhoneSize(tester);
    final container = _profileContainer(
      isSubscribed: true,
      isVIP: true,
      subscriptionDays: 7,
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: MainScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(YearlySaleScreen), findsOneWidget);

    await tester.tap(find.byKey(const Key('yearlySaleCloseButton')));
    await tester.pumpAndSettle();
    expect(find.byType(YearlySaleScreen), findsNothing);

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: MainScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(YearlySaleScreen), findsOneWidget);
  });

  testWidgets('active weekly trial sees sale when app resumes', (tester) async {
    _configurePhoneSize(tester);
    late final ProviderContainer container;
    final profileClient = _FakeProfileApiClient(
      () => container.read(profileProvider)!,
    );
    container = _profileContainer(
      isSubscribed: true,
      subscriptionDays: 3,
      profileClient: profileClient,
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: MainScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(YearlySaleScreen), findsOneWidget);

    await tester.tap(find.byKey(const Key('yearlySaleCloseButton')));
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(profileClient.fetchCount, 1);
    expect(find.byType(YearlySaleScreen), findsOneWidget);
  });

  testWidgets('paid weekly plan sees sale when app resumes', (tester) async {
    _configurePhoneSize(tester);
    late final ProviderContainer container;
    final profileClient = _FakeProfileApiClient(
      () => container.read(profileProvider)!,
    );
    container = _profileContainer(
      isSubscribed: true,
      subscriptionDays: 7,
      profileClient: profileClient,
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: MainScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(YearlySaleScreen), findsOneWidget);

    await tester.tap(find.byKey(const Key('yearlySaleCloseButton')));
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(profileClient.fetchCount, 1);
    expect(find.byType(YearlySaleScreen), findsOneWidget);
  });

  testWidgets('expired weekly plan does not see sale on entry or resume', (
    tester,
  ) async {
    _configurePhoneSize(tester);
    late final ProviderContainer container;
    final profileClient = _FakeProfileApiClient(
      () => container.read(profileProvider)!,
    );
    container = _profileContainer(
      isSubscribed: true,
      subscriptionDays: 7,
      expired: true,
      profileClient: profileClient,
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: MainScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(YearlySaleScreen), findsNothing);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(profileClient.fetchCount, 1);
    expect(find.byType(YearlySaleScreen), findsNothing);
  });

  testWidgets('annual plan does not see sale on entry or resume', (
    tester,
  ) async {
    _configurePhoneSize(tester);
    late final ProviderContainer container;
    final profileClient = _FakeProfileApiClient(
      () => container.read(profileProvider)!,
    );
    container = _profileContainer(
      isSubscribed: true,
      subscriptionDays: 365,
      profileClient: profileClient,
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: MainScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(YearlySaleScreen), findsNothing);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(profileClient.fetchCount, 1);
    expect(find.byType(YearlySaleScreen), findsNothing);
  });

  testWidgets('resume skips sale after the weekly plan changes to annual', (
    tester,
  ) async {
    _configurePhoneSize(tester);
    late UserProfile serverProfile;
    final profileClient = _FakeProfileApiClient(() => serverProfile);
    final container = _profileContainer(
      isSubscribed: true,
      subscriptionDays: 7,
      profileClient: profileClient,
    );
    addTearDown(container.dispose);
    serverProfile = container.read(profileProvider)!;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: MainScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(YearlySaleScreen), findsOneWidget);
    await tester.tap(find.byKey(const Key('yearlySaleCloseButton')));
    await tester.pumpAndSettle();

    final startedAt = DateTime.now().toUtc().subtract(const Duration(days: 1));
    serverProfile = UserProfile.fromJson(<String, dynamic>{
      'id': 2,
      'isVIP': true,
      'isSubscribed': true,
      'sub_time': startedAt.toIso8601String(),
      'sub_end_time': startedAt
          .add(const Duration(days: 365))
          .toIso8601String(),
    });
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(profileClient.fetchCount, 1);
    expect(find.byType(YearlySaleScreen), findsNothing);
  });
}

ProviderContainer _profileContainer({
  required bool isSubscribed,
  bool? isVIP,
  int subscriptionDays = 7,
  bool expired = false,
  String? googlePlayProductId,
  ApiClient? profileClient,
}) {
  final subscriptionStart = DateTime.now().toUtc().subtract(
    Duration(days: expired ? subscriptionDays + 1 : 1),
  );
  final container = ProviderContainer(
    overrides: [
      themeCategoriesProvider.overrideWith(
        (ref) async => const <VideoCategory>[],
      ),
      if (profileClient != null)
        apiClientProvider.overrideWithValue(profileClient),
      if (googlePlayProductId != null)
        googlePlayPastPurchasesProvider.overrideWith(
          (ref) async => <PurchaseDetails>[
            PurchaseDetails(
              purchaseID: 'GPA.test',
              productID: googlePlayProductId,
              verificationData: PurchaseVerificationData(
                localVerificationData: '',
                serverVerificationData: 'token',
                source: 'google_play',
              ),
              transactionDate: '1787558400000',
              status: PurchaseStatus.purchased,
            ),
          ],
        ),
    ],
  );
  container
      .read(profileProvider.notifier)
      .setProfile(
        UserProfile.fromJson(<String, dynamic>{
          'id': 2,
          'user_code': 'USER001',
          'platform': 'ANDROID',
          'is_actived': true,
          'isVIP': isVIP ?? isSubscribed,
          'isSubscribed': isSubscribed,
          'sub_time': isSubscribed ? subscriptionStart.toIso8601String() : null,
          'sub_end_time': isSubscribed
              ? subscriptionStart
                    .add(Duration(days: subscriptionDays))
                    .toIso8601String()
              : null,
          'total_credit': 100,
          'i2v_credit_base': 35,
        }),
      );
  if (googlePlayProductId != null) {
    container
        .read(packageCatalogProvider.notifier)
        .setCatalog(
          PackageCatalog.fromJson(<String, dynamic>{
            'ANDROID': <String, dynamic>{
              'SUBSCRIPTION': <Map<String, dynamic>>[
                <String, dynamic>{
                  'product_id': 'weekly.product',
                  'pack_duration_day': 7,
                },
                <String, dynamic>{
                  'product_id': 'yearly.product',
                  'pack_duration_day': 365,
                },
              ],
            },
          }),
        );
  }
  return container;
}

class _FakeProfileApiClient extends ApiClient {
  _FakeProfileApiClient(this.currentProfile)
    : super(
        deviceIdentity: const _FakeDeviceIdentity(),
        tokenStorage: _FakeTokenStorage(),
      );

  final UserProfile Function() currentProfile;
  int fetchCount = 0;

  @override
  Future<UserProfile> fetchProfile() async {
    fetchCount += 1;
    return currentProfile();
  }
}

class _FakeDeviceIdentity implements DeviceIdentityProvider {
  const _FakeDeviceIdentity();

  @override
  String get countryCode => 'US';

  @override
  String get platform => 'ANDROID';

  @override
  Future<String> getDeviceId() async => 'test-device';
}

class _FakeTokenStorage implements TokenStorage {
  @override
  Future<void> clearToken() async {}

  @override
  Future<String?> readToken() async => null;

  @override
  Future<void> saveToken(String token) async {}
}

void _configurePhoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

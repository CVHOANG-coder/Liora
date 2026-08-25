import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:video_gen/core/device/device_identity_service.dart';
import 'package:video_gen/core/network/api_client.dart';
import 'package:video_gen/core/network/api_exception.dart';
import 'package:video_gen/core/storage/token_storage.dart';
import 'package:video_gen/core/storage/yearly_sale_preferences.dart';
import 'package:video_gen/data/models/package_catalog.dart';
import 'package:video_gen/data/models/purchase_verification.dart';
import 'package:video_gen/data/models/user_profile.dart';
import 'package:video_gen/data/services/google_play_purchase_gateway.dart';
import 'package:video_gen/presentation/providers/package_provider.dart';
import 'package:video_gen/presentation/providers/profile_provider.dart';
import 'package:video_gen/presentation/providers/purchase_provider.dart';

void main() {
  test('refreshes profile into Riverpod after a verified purchase', () async {
    final gateway = _FakePurchaseGateway();
    final apiClient = _FakeApiClient();
    final yearlySalePreferences = _MemoryYearlySalePreferences();
    addTearDown(gateway.dispose);
    final container = ProviderContainer(
      overrides: [
        googlePlayPlatformProvider.overrideWithValue(true),
        purchaseGatewayProvider.overrideWithValue(gateway),
        apiClientProvider.overrideWithValue(apiClient),
        yearlySalePreferencesProvider.overrideWithValue(yearlySalePreferences),
      ],
    );
    addTearDown(container.dispose);

    container.read(purchaseControllerProvider);
    await _waitFor(
      () =>
          container.read(purchaseControllerProvider).status ==
          PurchaseFlowStatus.ready,
    );

    container
        .read(packageCatalogProvider.notifier)
        .setCatalog(
          PackageCatalog.fromJson(<String, dynamic>{
            'ANDROID': <String, dynamic>{
              'SUBSCRIPTION': <Map<String, dynamic>>[
                <String, dynamic>{
                  'product_id': 'weekly.pro.trial',
                  'pack_duration_day': 7,
                },
              ],
            },
          }),
        );
    await Future<void>.delayed(Duration.zero);

    final purchase = PurchaseDetails(
      purchaseID: 'GPA.1234',
      productID: 'weekly.pro.trial',
      verificationData: PurchaseVerificationData(
        localVerificationData: '',
        serverVerificationData: 'purchase-token',
        source: 'google_play',
      ),
      transactionDate: '1787558400000',
      status: PurchaseStatus.purchased,
    )..pendingCompletePurchase = true;
    gateway.emit(purchase);

    await _waitFor(
      () =>
          container.read(purchaseControllerProvider).status ==
          PurchaseFlowStatus.success,
    );

    final profile = container.read(profileProvider);
    expect(apiClient.verifyCalls, 1);
    expect(apiClient.fetchProfileCalls, 2);
    expect(gateway.completedPurchases, 1);
    expect(profile?.isVIP, isTrue);
    expect(profile?.isSubscribed, isTrue);
    expect(profile?.totalCredit, 420);
    expect(yearlySalePreferences.pending, isTrue);
  });

  test('selects an eligible free-trial offer and passes its token', () async {
    const productId = 'com.nostalia.ai.videogenerator.weekly';
    final googleProducts = GooglePlayProductDetails.fromProductDetails(
      const ProductDetailsWrapper(
        description: 'Weekly Pro subscription',
        name: 'Weekly Pro',
        productId: productId,
        productType: ProductType.subs,
        title: 'Weekly Pro',
        subscriptionOfferDetails: <SubscriptionOfferDetailsWrapper>[
          SubscriptionOfferDetailsWrapper(
            basePlanId: 'weekly-base-plan',
            offerId: 'three-day-trial',
            offerTags: <String>['free-trial'],
            offerIdToken: 'three-day-trial-token',
            pricingPhases: <PricingPhaseWrapper>[
              PricingPhaseWrapper(
                billingCycleCount: 1,
                billingPeriod: 'P3D',
                formattedPrice: r'$0.00',
                priceAmountMicros: 0,
                priceCurrencyCode: 'USD',
                recurrenceMode: RecurrenceMode.finiteRecurring,
              ),
              PricingPhaseWrapper(
                billingCycleCount: 0,
                billingPeriod: 'P1W',
                formattedPrice: r'$7.99',
                priceAmountMicros: 7990000,
                priceCurrencyCode: 'USD',
                recurrenceMode: RecurrenceMode.infiniteRecurring,
              ),
            ],
          ),
          SubscriptionOfferDetailsWrapper(
            basePlanId: 'weekly-base-plan',
            offerTags: <String>[],
            offerIdToken: 'base-plan-token',
            pricingPhases: <PricingPhaseWrapper>[
              PricingPhaseWrapper(
                billingCycleCount: 0,
                billingPeriod: 'P1W',
                formattedPrice: r'$7.99',
                priceAmountMicros: 7990000,
                priceCurrencyCode: 'USD',
                recurrenceMode: RecurrenceMode.infiniteRecurring,
              ),
            ],
          ),
        ],
      ),
    );
    final gateway = _FakePurchaseGateway(products: googleProducts);
    addTearDown(gateway.dispose);
    final container = ProviderContainer(
      overrides: [
        googlePlayPlatformProvider.overrideWithValue(true),
        purchaseGatewayProvider.overrideWithValue(gateway),
        apiClientProvider.overrideWithValue(_FakeApiClient()),
      ],
    );
    addTearDown(container.dispose);

    container.read(purchaseControllerProvider);
    await _waitFor(
      () =>
          container.read(purchaseControllerProvider).status ==
          PurchaseFlowStatus.ready,
    );
    await container
        .read(purchaseControllerProvider.notifier)
        .buy(productId: productId, consumable: false);

    final purchaseParam = gateway.lastSubscriptionParam;
    expect(purchaseParam, isA<GooglePlayPurchaseParam>());
    expect(
      (purchaseParam! as GooglePlayPurchaseParam).offerToken,
      'three-day-trial-token',
    );
    expect(
      (purchaseParam.productDetails as GooglePlayProductDetails).offerToken,
      'three-day-trial-token',
    );
    expect(recurringSubscriptionPrice(purchaseParam.productDetails), r'$7.99');
    expect(recurringSubscriptionRawPrice(purchaseParam.productDetails), 7.99);
  });

  test(
    'recovers and acknowledges an unfinished subscription on startup',
    () async {
      const productId = 'com.nostalia.ai.videogenerator.weekly';
      final unfinishedPurchase = PurchaseDetails(
        purchaseID: 'GPA.unfinished',
        productID: productId,
        verificationData: PurchaseVerificationData(
          localVerificationData: '',
          serverVerificationData: 'unfinished-purchase-token',
          source: 'google_play',
        ),
        transactionDate: '1787558400000',
        status: PurchaseStatus.purchased,
      )..pendingCompletePurchase = true;
      final gateway = _FakePurchaseGateway(
        pastPurchases: <PurchaseDetails>[unfinishedPurchase],
      );
      final apiClient = _FakeApiClient();
      addTearDown(gateway.dispose);
      final container = ProviderContainer(
        overrides: [
          googlePlayPlatformProvider.overrideWithValue(true),
          purchaseGatewayProvider.overrideWithValue(gateway),
          apiClientProvider.overrideWithValue(apiClient),
        ],
      );
      addTearDown(container.dispose);

      container.read(purchaseControllerProvider);
      await _waitFor(
        () =>
            container.read(purchaseControllerProvider).status ==
            PurchaseFlowStatus.ready,
      );
      container
          .read(packageCatalogProvider.notifier)
          .setCatalog(
            PackageCatalog.fromJson(<String, dynamic>{
              'ANDROID': <String, dynamic>{
                'SUBSCRIPTION': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'id': 1,
                    'product_id': productId,
                    'product_type': 'SUBSCRIPTION',
                    'name': 'Weekly Pro',
                    'price': 7.99,
                    'platform': 'ANDROID',
                    'description': '',
                    'credit': 200,
                    'pack_duration_day': 7,
                  },
                ],
              },
            }),
          );

      await _waitFor(
        () =>
            container.read(purchaseControllerProvider).status ==
            PurchaseFlowStatus.success,
      );

      expect(apiClient.verifyCalls, 1);
      expect(gateway.completedPurchases, 1);
      expect(
        container.read(purchaseControllerProvider).status,
        PurchaseFlowStatus.success,
      );
    },
  );

  test(
    'acknowledges a verified subscription even with a stale pending flag',
    () async {
      final gateway = _FakePurchaseGateway();
      final apiClient = _FakeApiClient();
      addTearDown(gateway.dispose);
      final container = ProviderContainer(
        overrides: [
          googlePlayPlatformProvider.overrideWithValue(true),
          purchaseGatewayProvider.overrideWithValue(gateway),
          apiClientProvider.overrideWithValue(apiClient),
        ],
      );
      addTearDown(container.dispose);

      container.read(purchaseControllerProvider);
      await _waitFor(
        () =>
            container.read(purchaseControllerProvider).status ==
            PurchaseFlowStatus.ready,
      );
      gateway.emit(
        PurchaseDetails(
          purchaseID: 'GPA.stale-flag',
          productID: 'com.nostalia.ai.videogenerator.weekly',
          verificationData: PurchaseVerificationData(
            localVerificationData: '',
            serverVerificationData: 'stale-flag-token',
            source: 'google_play',
          ),
          transactionDate: '1787558400000',
          status: PurchaseStatus.purchased,
        )..pendingCompletePurchase = false,
      );

      await _waitFor(() => gateway.completedPurchases == 1);

      expect(apiClient.verifyCalls, 1);
      expect(gateway.completedPurchases, 1);
    },
  );
}

Future<void> _waitFor(bool Function() condition) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  fail('Timed out waiting for the purchase flow.');
}

class _FakeApiClient extends ApiClient {
  _FakeApiClient()
    : super(
        deviceIdentity: const _FakeDeviceIdentity(),
        tokenStorage: _MemoryTokenStorage(),
      );

  int verifyCalls = 0;
  int fetchProfileCalls = 0;

  @override
  Future<PurchaseVerificationResponse> verifyPurchase(
    PurchaseReceipt receipt,
  ) async {
    verifyCalls += 1;
    return const PurchaseVerificationResponse(
      success: true,
      message: 'Purchase verified.',
    );
  }

  @override
  Future<UserProfile> fetchProfile() async {
    fetchProfileCalls += 1;
    if (fetchProfileCalls == 1) {
      throw const ApiException(message: 'Temporary profile refresh failure.');
    }
    return UserProfile.fromJson(<String, dynamic>{
      'id': 2,
      'platform': 'ANDROID',
      'isVIP': true,
      'isSubscribed': true,
      'total_credit': 420,
    });
  }
}

class _FakeDeviceIdentity implements DeviceIdentityProvider {
  const _FakeDeviceIdentity();

  @override
  String get countryCode => 'VN';

  @override
  String get platform => 'ANDROID';

  @override
  Future<String> getDeviceId() async => 'device-001';
}

class _MemoryTokenStorage implements TokenStorage {
  String? token;

  @override
  Future<void> clearToken() async => token = null;

  @override
  Future<String?> readToken() async => token;

  @override
  Future<void> saveToken(String token) async => this.token = token;
}

class _MemoryYearlySalePreferences implements YearlySalePreferences {
  bool pending = false;

  @override
  Future<bool> consumeScheduledOffer() async {
    final result = pending;
    pending = false;
    return result;
  }

  @override
  Future<void> scheduleAfterWeeklyPurchase() async => pending = true;
}

class _FakePurchaseGateway implements PurchaseGateway {
  _FakePurchaseGateway({
    this.products = const [],
    this.pastPurchases = const [],
  });

  final _updates = StreamController<List<PurchaseDetails>>.broadcast();
  final List<ProductDetails> products;
  final List<PurchaseDetails> pastPurchases;
  int completedPurchases = 0;
  PurchaseParam? lastSubscriptionParam;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _updates.stream;

  void emit(PurchaseDetails purchase) => _updates.add([purchase]);

  Future<void> dispose() => _updates.close();

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<ProductDetailsResponse> queryProductDetails(
    Set<String> productIds,
  ) async => ProductDetailsResponse(
    productDetails: products
        .where((product) => productIds.contains(product.id))
        .toList(growable: false),
    notFoundIDs: [],
  );

  @override
  Future<bool> buyConsumable(PurchaseParam purchaseParam) async => true;

  @override
  Future<bool> buySubscription(
    PurchaseParam purchaseParam, {
    PurchaseDetails? oldPurchase,
  }) async {
    lastSubscriptionParam = purchaseParam;
    return true;
  }

  @override
  Future<List<PurchaseDetails>> queryPastPurchases() async => pastPurchases;

  @override
  Future<void> consume(PurchaseDetails purchase) async {}

  @override
  Future<void> complete(PurchaseDetails purchase) async {
    completedPurchases += 1;
  }

  @override
  Future<void> restorePurchases() async {}
}

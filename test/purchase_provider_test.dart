import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:video_gen/core/device/device_identity_service.dart';
import 'package:video_gen/core/network/api_client.dart';
import 'package:video_gen/core/network/api_exception.dart';
import 'package:video_gen/core/storage/token_storage.dart';
import 'package:video_gen/data/models/purchase_verification.dart';
import 'package:video_gen/data/models/user_profile.dart';
import 'package:video_gen/data/services/google_play_purchase_gateway.dart';
import 'package:video_gen/presentation/providers/profile_provider.dart';
import 'package:video_gen/presentation/providers/purchase_provider.dart';

void main() {
  test('refreshes profile into Riverpod after a verified purchase', () async {
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
    expect(profile?.isVip, isTrue);
    expect(profile?.isSubscribed, isTrue);
    expect(profile?.totalCredit, 420);
  });
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

class _FakePurchaseGateway implements PurchaseGateway {
  final _updates = StreamController<List<PurchaseDetails>>.broadcast();
  int completedPurchases = 0;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _updates.stream;

  void emit(PurchaseDetails purchase) => _updates.add([purchase]);

  Future<void> dispose() => _updates.close();

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<ProductDetailsResponse> queryProductDetails(
    Set<String> productIds,
  ) async => ProductDetailsResponse(productDetails: [], notFoundIDs: []);

  @override
  Future<bool> buyConsumable(PurchaseParam purchaseParam) async => true;

  @override
  Future<bool> buySubscription(
    PurchaseParam purchaseParam, {
    PurchaseDetails? oldPurchase,
  }) async => true;

  @override
  Future<List<PurchaseDetails>> queryPastPurchases() async => [];

  @override
  Future<void> consume(PurchaseDetails purchase) async {}

  @override
  Future<void> complete(PurchaseDetails purchase) async {
    completedPurchases += 1;
  }

  @override
  Future<void> restorePurchases() async {}
}

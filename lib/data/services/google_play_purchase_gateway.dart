import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

abstract interface class PurchaseGateway {
  Stream<List<PurchaseDetails>> get purchaseStream;

  Future<bool> isAvailable();

  Future<ProductDetailsResponse> queryProductDetails(Set<String> productIds);

  Future<bool> buyConsumable(PurchaseParam purchaseParam);

  Future<bool> buySubscription(
    PurchaseParam purchaseParam, {
    PurchaseDetails? oldPurchase,
  });

  Future<List<PurchaseDetails>> queryPastPurchases();

  Future<void> consume(PurchaseDetails purchase);

  Future<void> complete(PurchaseDetails purchase);

  Future<void> restorePurchases();
}

class GooglePlayPurchaseGateway implements PurchaseGateway {
  GooglePlayPurchaseGateway({InAppPurchase? store})
    : _store = store ?? InAppPurchase.instance;

  final InAppPurchase _store;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _store.purchaseStream;

  @override
  Future<bool> isAvailable() => _store.isAvailable();

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> productIds) =>
      _store.queryProductDetails(productIds);

  @override
  Future<bool> buyConsumable(PurchaseParam purchaseParam) =>
      _store.buyConsumable(
        purchaseParam: purchaseParam,
        // The server must grant the credits before the token is consumed.
        autoConsume: false,
      );

  @override
  Future<bool> buySubscription(
    PurchaseParam purchaseParam, {
    PurchaseDetails? oldPurchase,
  }) {
    final offerToken = purchaseParam is GooglePlayPurchaseParam
        ? purchaseParam.offerToken
        : purchaseParam.productDetails is GooglePlayProductDetails
        ? (purchaseParam.productDetails as GooglePlayProductDetails).offerToken
        : null;
    final effectiveParam = oldPurchase is GooglePlayPurchaseDetails
        ? GooglePlayPurchaseParam(
            productDetails: purchaseParam.productDetails,
            applicationUserName: purchaseParam.applicationUserName,
            offerToken: offerToken,
            changeSubscriptionParam: ChangeSubscriptionParam(
              oldPurchaseDetails: oldPurchase,
              replacementMode: ReplacementMode.withTimeProration,
            ),
          )
        : purchaseParam;
    return _store.buyNonConsumable(purchaseParam: effectiveParam);
  }

  @override
  Future<List<PurchaseDetails>> queryPastPurchases() async {
    final addition = _store
        .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
    final response = await addition.queryPastPurchases();
    if (response.error case final error?) throw error;
    return response.pastPurchases;
  }

  @override
  Future<void> consume(PurchaseDetails purchase) async {
    final addition = _store
        .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
    final result = await addition.consumePurchase(purchase);
    // itemNotOwned is also safe here: a secure backend may have consumed the
    // token as part of successful verification before this client call.
    if (result.responseCode != BillingResponse.ok &&
        result.responseCode != BillingResponse.itemNotOwned) {
      throw StateError(
        'Google Play could not consume the purchase: ${result.debugMessage}',
      );
    }
  }

  @override
  Future<void> complete(PurchaseDetails purchase) =>
      _store.completePurchase(purchase);

  @override
  Future<void> restorePurchases() => _store.restorePurchases();
}

import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../data/models/package_catalog.dart';
import '../../data/models/purchase_verification.dart';
import '../../data/services/google_play_purchase_gateway.dart';
import 'package_provider.dart';
import 'profile_provider.dart';

enum PurchaseFlowStatus {
  unavailable,
  connecting,
  ready,
  launching,
  pending,
  verifying,
  restoring,
  success,
  error,
  canceled,
}

class PurchaseState {
  const PurchaseState({
    required this.status,
    this.products = const <String, ProductDetails>{},
    this.notFoundProductIds = const <String>{},
    this.message,
    this.productId,
  });

  const PurchaseState.unavailable()
    : this(status: PurchaseFlowStatus.unavailable);

  final PurchaseFlowStatus status;
  final Map<String, ProductDetails> products;
  final Set<String> notFoundProductIds;
  final String? message;
  final String? productId;

  bool get isBusy => switch (status) {
    PurchaseFlowStatus.connecting ||
    PurchaseFlowStatus.launching ||
    PurchaseFlowStatus.pending ||
    PurchaseFlowStatus.verifying ||
    PurchaseFlowStatus.restoring => true,
    _ => false,
  };

  PurchaseState copyWith({
    PurchaseFlowStatus? status,
    Map<String, ProductDetails>? products,
    Set<String>? notFoundProductIds,
    String? message,
    bool clearMessage = false,
    String? productId,
    bool clearProductId = false,
  }) {
    return PurchaseState(
      status: status ?? this.status,
      products: products ?? this.products,
      notFoundProductIds: notFoundProductIds ?? this.notFoundProductIds,
      message: clearMessage ? null : message ?? this.message,
      productId: clearProductId ? null : productId ?? this.productId,
    );
  }
}

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient.instance);

final purchaseGatewayProvider = Provider<PurchaseGateway>(
  (ref) => GooglePlayPurchaseGateway(),
);

final googlePlayPlatformProvider = Provider<bool>((ref) => Platform.isAndroid);

final purchaseControllerProvider =
    NotifierProvider<PurchaseController, PurchaseState>(PurchaseController.new);

class PurchaseController extends Notifier<PurchaseState> {
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  late PurchaseGateway _gateway;
  late ApiClient _apiClient;
  final Set<String> _consumableProductIds = <String>{};
  final Set<String> _subscriptionProductIds = <String>{};
  final Set<String> _processingPurchaseTokens = <String>{};
  bool _disposed = false;

  @override
  PurchaseState build() {
    if (!ref.watch(googlePlayPlatformProvider)) {
      return const PurchaseState.unavailable();
    }

    _gateway = ref.watch(purchaseGatewayProvider);
    _apiClient = ref.watch(apiClientProvider);
    ref.onDispose(() {
      _disposed = true;
      unawaited(_purchaseSubscription?.cancel());
    });
    ref.listen<PackageCatalog?>(packageCatalogProvider, (_, catalog) {
      if (catalog != null) unawaited(_loadCatalogProducts(catalog));
    });
    scheduleMicrotask(_initialize);
    return const PurchaseState(status: PurchaseFlowStatus.connecting);
  }

  Future<void> _initialize() async {
    _purchaseSubscription = _gateway.purchaseStream.listen(
      _onPurchaseUpdates,
      onError: (Object error) => _setError(_messageFor(error)),
    );

    try {
      final available = await _gateway.isAvailable();
      if (_disposed) return;
      if (!available) {
        state = const PurchaseState(
          status: PurchaseFlowStatus.unavailable,
          message: 'Google Play Billing is currently unavailable.',
        );
        return;
      }

      state = state.copyWith(
        status: PurchaseFlowStatus.ready,
        clearMessage: true,
      );
      final catalog = ref.read(packageCatalogProvider);
      if (catalog != null) await _loadCatalogProducts(catalog);
    } catch (error) {
      _setError(_messageFor(error));
    }
  }

  Future<void> _loadCatalogProducts(PackageCatalog catalog) async {
    final packages = catalog.forPlatform('ANDROID');
    if (packages == null) return;

    _consumableProductIds
      ..clear()
      ..addAll(
        <AppPackage>[
          ...packages.consumableNew,
          ...packages.consumableVip,
        ].map((package) => package.productId).where((id) => id.isNotEmpty),
      );
    _subscriptionProductIds
      ..clear()
      ..addAll(
        <AppPackage>[
          ...packages.subscriptions,
          ...packages.sales,
        ].map((package) => package.productId).where((id) => id.isNotEmpty),
      );
    final ids = <AppPackage>[
      ...packages.subscriptions,
      ...packages.sales,
      ...packages.consumableNew,
      ...packages.consumableVip,
    ].map((package) => package.productId).where((id) => id.isNotEmpty).toSet();
    if (ids.isEmpty) return;

    await _queryProducts(ids);
  }

  Future<void> _queryProducts(Set<String> ids) async {
    try {
      final response = await _gateway.queryProductDetails(ids);
      if (_disposed) return;
      final products = Map<String, ProductDetails>.of(state.products);
      products.addEntries(
        response.productDetails.map((product) => MapEntry(product.id, product)),
      );
      state = state.copyWith(
        status: state.isBusy ? state.status : PurchaseFlowStatus.ready,
        products: products,
        notFoundProductIds: <String>{
          ...state.notFoundProductIds,
          ...response.notFoundIDs,
        },
        message: response.error?.message,
        clearMessage: response.error == null,
      );
    } catch (error) {
      _setError(_messageFor(error));
    }
  }

  Future<void> buy({
    required String productId,
    required bool consumable,
    bool replaceExistingSubscription = false,
  }) async {
    if (productId.isEmpty) {
      _setError('This product does not have a product ID.');
      return;
    }
    if (state.status == PurchaseFlowStatus.unavailable) {
      _setError('Google Play Billing is currently unavailable.');
      return;
    }
    if (state.isBusy) return;
    if (consumable) _consumableProductIds.add(productId);

    var product = state.products[productId];
    if (product == null) {
      await _queryProducts(<String>{productId});
      product = state.products[productId];
    }
    if (product == null) {
      _setError('Product $productId was not found on Google Play.');
      return;
    }

    state = state.copyWith(
      status: PurchaseFlowStatus.launching,
      productId: productId,
      clearMessage: true,
    );
    try {
      final purchaseParam = PurchaseParam(productDetails: product);
      PurchaseDetails? oldSubscription;
      if (!consumable && replaceExistingSubscription) {
        final purchases = await _gateway.queryPastPurchases();
        for (final purchase in purchases) {
          if (_subscriptionProductIds.contains(purchase.productID) &&
              purchase.productID != productId) {
            oldSubscription = purchase;
            break;
          }
        }
      }
      final launched = consumable
          ? await _gateway.buyConsumable(purchaseParam)
          : await _gateway.buySubscription(
              purchaseParam,
              oldPurchase: oldSubscription,
            );
      if (!launched) {
        _setError('Unable to open the Google Play checkout screen.');
      }
    } catch (error) {
      _setError(_messageFor(error));
    }
  }

  Future<void> restore() async {
    if (state.isBusy) return;
    state = state.copyWith(
      status: PurchaseFlowStatus.restoring,
      clearMessage: true,
      clearProductId: true,
    );
    try {
      await _gateway.restorePurchases();
      if (!_disposed && state.status == PurchaseFlowStatus.restoring) {
        state = state.copyWith(
          status: PurchaseFlowStatus.ready,
          message: 'Previous purchases have been checked.',
        );
      }
    } catch (error) {
      _setError(_messageFor(error));
    }
  }

  Future<void> _onPurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          state = state.copyWith(
            status: PurchaseFlowStatus.pending,
            productId: purchase.productID,
            message: 'The purchase is waiting for Google Play to process it.',
          );
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _verifyAndFinish(purchase);
        case PurchaseStatus.error:
          _setError(
            purchase.error?.message ??
                'Google Play could not process the purchase.',
            productId: purchase.productID,
          );
        case PurchaseStatus.canceled:
          state = state.copyWith(
            status: PurchaseFlowStatus.canceled,
            productId: purchase.productID,
            message: 'Purchase canceled.',
          );
      }
    }
  }

  Future<void> _verifyAndFinish(PurchaseDetails purchase) async {
    final token = purchase.verificationData.serverVerificationData;
    final key = token.isEmpty
        ? '${purchase.productID}:${purchase.purchaseID}'
        : token;
    if (!_processingPurchaseTokens.add(key)) return;

    state = state.copyWith(
      status: PurchaseFlowStatus.verifying,
      productId: purchase.productID,
      clearMessage: true,
    );
    try {
      if (token.isEmpty) {
        throw const ApiException(
          message: 'Google Play did not return a purchase token.',
        );
      }
      final result = await _apiClient.verifyPurchase(
        PurchaseReceipt(
          productId: purchase.productID,
          purchaseToken: token,
          orderId: purchase.purchaseID ?? '',
        ),
      );

      final consumable = _consumableProductIds.contains(purchase.productID);
      if (consumable) {
        await _gateway.consume(purchase);
      } else if (purchase.pendingCompletePurchase) {
        await _gateway.complete(purchase);
      }

      try {
        final profile = await _apiClient.fetchProfile();
        ref.read(profileProvider.notifier).setProfile(profile);
      } catch (_) {
        // The purchase is already verified and finalized. The profile will be
        // reconciled on the next authenticated refresh if this request fails.
      }

      if (!_disposed) {
        state = state.copyWith(
          status: PurchaseFlowStatus.success,
          productId: purchase.productID,
          message: result.message.isEmpty
              ? 'Payment successful.'
              : result.message,
        );
      }
    } catch (error) {
      // Do not consume or acknowledge an invalid/unverified purchase. It can
      // be retried from the purchase stream after connectivity is restored.
      _setError(_messageFor(error), productId: purchase.productID);
    } finally {
      _processingPurchaseTokens.remove(key);
    }
  }

  void _setError(String message, {String? productId}) {
    if (_disposed) return;
    state = state.copyWith(
      status: PurchaseFlowStatus.error,
      message: message,
      productId: productId,
    );
  }

  String _messageFor(Object error) {
    if (error is ApiException) return error.message;
    if (error is IAPError) return error.message;
    return 'Unable to process the purchase. Please try again.';
  }
}

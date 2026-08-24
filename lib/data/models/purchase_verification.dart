class PurchaseReceipt {
  const PurchaseReceipt({
    required this.productId,
    required this.purchaseToken,
    required this.orderId,
  });

  final String productId;
  final String purchaseToken;
  final String orderId;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'productId': productId,
    'purchaseToken': purchaseToken,
    'orderId': orderId,
  };
}

class PurchaseVerificationResponse {
  const PurchaseVerificationResponse({
    required this.success,
    required this.message,
  });

  factory PurchaseVerificationResponse.fromJson(Map<String, dynamic> json) {
    return PurchaseVerificationResponse(
      success: json['success'] == true,
      message: json['message']?.toString() ?? '',
    );
  }

  final bool success;
  final String message;
}

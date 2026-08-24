import 'package:dio/dio.dart';

import '../../core/network/api_config.dart';
import '../../core/network/api_exception.dart';
import '../models/purchase_verification.dart';

class PurchaseVerificationService {
  PurchaseVerificationService(this._dio);

  final Dio _dio;

  Future<PurchaseVerificationResponse> verify(PurchaseReceipt receipt) async {
    try {
      final response = await _dio.post<dynamic>(
        ApiConfig.verifyPurchasePath,
        data: <String, dynamic>{'receipt': receipt.toJson()},
      );
      final body = response.data;
      if (body is! Map) {
        throw const ApiException(
          message: 'Invalid purchase verification data.',
        );
      }

      final result = PurchaseVerificationResponse.fromJson(
        Map<String, dynamic>.from(body),
      );
      if (!result.success) {
        throw ApiException(
          message: result.message.isEmpty
              ? 'Unable to verify the purchase.'
              : result.message,
          statusCode: response.statusCode,
        );
      }
      return result;
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}

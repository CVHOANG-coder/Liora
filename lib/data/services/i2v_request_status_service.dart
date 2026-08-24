import 'package:dio/dio.dart';

import '../../core/network/api_config.dart';
import '../../core/network/api_exception.dart';
import '../models/i2v_request_status.dart';

class I2VRequestStatusService {
  I2VRequestStatusService(this._dio);

  final Dio _dio;

  Future<I2VRequestStatus> fetch(String requestId) async {
    try {
      final safeRequestId = Uri.encodeComponent(requestId);
      final response = await _dio.get<dynamic>(
        '${ApiConfig.requestStatusPath}/$safeRequestId',
      );
      final body = response.data;
      if (body is! Map) {
        throw const ApiException(message: 'Invalid video status data.');
      }

      final result = I2VRequestStatusResponse.fromJson(
        Map<String, dynamic>.from(body),
      );
      if (!result.success) {
        throw ApiException(
          message: result.message.isEmpty
              ? 'Unable to check the video status.'
              : result.message,
          statusCode: response.statusCode,
        );
      }
      return result.data;
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    } on FormatException catch (error) {
      throw ApiException(message: error.message, cause: error);
    }
  }
}

import 'package:dio/dio.dart';

import '../../core/network/api_config.dart';
import '../../core/network/api_exception.dart';
import '../models/generation_history.dart';

class GenerationHistoryService {
  GenerationHistoryService(this._dio);

  final Dio _dio;

  Future<GenerationHistoryPage> fetch({
    required int page,
    int limit = 10,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        ApiConfig.generationHistoryPath,
        queryParameters: <String, dynamic>{'page': page, 'limit': limit},
      );
      final body = response.data;
      if (body is! Map) {
        throw const ApiException(message: 'Invalid video history data.');
      }

      final json = Map<String, dynamic>.from(body);
      if (json['success'] != true) {
        final message = json['message']?.toString() ?? '';
        throw ApiException(
          message: message.isEmpty ? 'Unable to load video history.' : message,
          statusCode: response.statusCode,
        );
      }
      return GenerationHistoryPage.fromJson(json);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    } on FormatException catch (error) {
      throw ApiException(message: error.message, cause: error);
    }
  }

  Future<void> deleteRequest(String requestId) async {
    try {
      final safeRequestId = Uri.encodeComponent(requestId);
      final response = await _dio.delete<dynamic>(
        '${ApiConfig.deleteGenerationRequestPath}/$safeRequestId',
      );
      final body = response.data;
      if (body is Map) {
        final json = Map<String, dynamic>.from(body);
        if (json['success'] == false) {
          final message = json['message']?.toString() ?? '';
          throw ApiException(
            message: message.isEmpty
                ? 'Unable to remove the video from history.'
                : message,
            statusCode: response.statusCode,
          );
        }
      }
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}

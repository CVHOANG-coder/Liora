import 'package:dio/dio.dart';

import '../../core/network/api_config.dart';
import '../../core/network/api_exception.dart';
import '../models/i2v_generation.dart';

class T2VGenerationService {
  T2VGenerationService(this._dio);

  final Dio _dio;

  Future<I2VGeneration> generate({
    required String prompt,
    required bool isHd,
    required bool isLongTime,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        ApiConfig.generateT2VPath,
        data: <String, dynamic>{
          'prompt': prompt,
          'is_hd': isHd,
          'is_long_time': isLongTime,
        },
      );
      final body = response.data;
      if (body is! Map) {
        throw const ApiException(message: 'Invalid video generation data.');
      }

      if (body['success'] != true) {
        throw ApiException.fromResponse(
          responseData: body,
          fallbackMessage: 'Unable to submit the video generation request.',
          statusCode: response.statusCode,
        );
      }

      final result = I2VGenerationResponse.fromJson(
        Map<String, dynamic>.from(body),
      );
      if (result.data.requestId.isEmpty) {
        throw ApiException(
          message: result.message.isEmpty
              ? 'Unable to submit the video generation request.'
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

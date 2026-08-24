import 'package:dio/dio.dart';

import '../../core/network/api_config.dart';
import '../../core/network/api_exception.dart';
import '../models/i2v_generation.dart';

class I2VGenerationService {
  I2VGenerationService(this._dio);

  final Dio _dio;

  Future<I2VGeneration> generate({
    required String imagePath,
    required String prompt,
    required bool isHd,
    required bool isLongTime,
  }) async {
    try {
      final fileName = Uri.file(imagePath).pathSegments.last;
      final formData = FormData.fromMap(<String, dynamic>{
        'source_image': await MultipartFile.fromFile(
          imagePath,
          filename: fileName,
        ),
        'prompt': prompt,
        'is_hd': isHd.toString(),
        'is_long_time': isLongTime.toString(),
      });
      final response = await _dio.post<dynamic>(
        ApiConfig.generateI2VPath,
        data: formData,
      );
      final body = response.data;
      if (body is! Map) {
        throw const ApiException(message: 'Invalid video generation data.');
      }

      if (body['success'] != true) {
        throw ApiException(
          message:
              extractApiErrorMessage(body) ??
              'Unable to submit the video generation request.',
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

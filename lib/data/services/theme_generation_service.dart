import 'package:dio/dio.dart';

import '../../core/network/api_config.dart';
import '../../core/network/api_exception.dart';
import '../models/i2v_generation.dart';

class ThemeGenerationService {
  ThemeGenerationService(this._dio);

  final Dio _dio;

  Future<I2VGeneration> generate({
    required String themeId,
    required String firstImagePath,
    required bool isHd,
    required bool isLongTime,
    ProgressCallback? onUploadProgress,
  }) async {
    try {
      final fields = <String, dynamic>{
        'theme_id': themeId,
        'source_image': await MultipartFile.fromFile(
          firstImagePath,
          filename: Uri.file(firstImagePath).pathSegments.last,
        ),
        'is_hd': isHd.toString(),
        'is_long_time': isLongTime.toString(),
      };

      final response = await _dio.post<dynamic>(
        ApiConfig.generateThemePath,
        data: FormData.fromMap(fields),
        onSendProgress: onUploadProgress,
      );
      final body = response.data;
      if (body is! Map) {
        throw const ApiException(message: 'Invalid video generation data.');
      }

      if (body['success'] != true) {
        throw ApiException.fromResponse(
          responseData: body,
          fallbackMessage: 'Unable to submit the theme video request.',
          statusCode: response.statusCode,
        );
      }

      final result = I2VGenerationResponse.fromJson(
        Map<String, dynamic>.from(body),
      );
      if (result.data.requestId.isEmpty) {
        throw ApiException(
          message: result.message.isEmpty
              ? 'Unable to submit the theme video request.'
              : result.message,
          statusCode: response.statusCode,
        );
      }
      return result.data;
    } on DioException catch (error) {
      throw ApiException.fromUploadDio(error);
    } on FormatException catch (error) {
      throw ApiException(message: error.message, cause: error);
    }
  }
}

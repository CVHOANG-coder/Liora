import 'package:dio/dio.dart';

import '../../core/network/api_config.dart';
import '../../core/network/api_exception.dart';
import '../models/i2v_generation.dart';

class ExtendVideoService {
  ExtendVideoService(this._dio);

  final Dio _dio;

  Future<I2VGeneration> generate({
    String? requestId,
    String? videoUrl,
    required String prompt,
    bool isHd = false,
    int duration = 5,
    String? seed,
  }) async {
    final sourceId = requestId?.trim() ?? '';
    final sourceUrl = videoUrl?.trim() ?? '';
    if (sourceId.isEmpty && sourceUrl.isEmpty) {
      throw const ApiException(
        message: 'Choose a completed video to extend.',
        errorCode: ApiErrorCode.videoUrlRequired,
      );
    }
    if (prompt.trim().isEmpty) {
      throw const ApiException(
        message: 'Describe what happens next.',
        errorCode: ApiErrorCode.promptRequired,
      );
    }
    if (![5, 10, 15].contains(duration)) {
      throw const ApiException(
        message: 'Choose a duration of 5, 10, or 15 seconds.',
        errorCode: ApiErrorCode.invalidDuration,
      );
    }
    try {
      final response = await _dio.post<dynamic>(
        ApiConfig.extendVideoPath,
        data: <String, dynamic>{
          if (sourceId.isNotEmpty)
            'request_id': sourceId
          else
            'video_url': sourceUrl,
          'prompt': prompt.trim(),
          'is_hd': isHd,
          'duration': duration,
          if (seed != null && seed.trim().isNotEmpty) 'seed': seed.trim(),
        },
      );
      final body = response.data;
      if (body is! Map) {
        throw const ApiException(message: 'Invalid video extension data.');
      }

      if (body['success'] != true) {
        throw ApiException.fromResponse(
          responseData: body,
          fallbackMessage: 'Unable to submit the video extension request.',
          statusCode: response.statusCode,
        );
      }

      final result = I2VGenerationResponse.fromJson(
        Map<String, dynamic>.from(body),
      );
      if (result.data.requestId.isEmpty) {
        throw ApiException(
          message: result.message.isEmpty
              ? 'Unable to submit the video extension request.'
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

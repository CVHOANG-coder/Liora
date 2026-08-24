import 'package:dio/dio.dart';

import '../../core/network/api_config.dart';
import '../../core/network/api_exception.dart';
import '../video_categories.dart';

class ThemeService {
  ThemeService(this._dio);

  final Dio _dio;

  Future<List<VideoCategory>> fetchThemes() async {
    try {
      final response = await _dio.get<dynamic>(ApiConfig.themesPath);
      final body = response.data;
      if (body is! Map) {
        throw const ApiException(message: 'Invalid theme data.');
      }

      if (body['success'] != true) {
        throw ApiException.fromResponse(
          responseData: body,
          fallbackMessage: 'Unable to load themes.',
          statusCode: response.statusCode,
        );
      }

      final result = ThemeCatalogResponse.fromJson(
        Map<String, dynamic>.from(body),
      );
      return result.categories;
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    } on FormatException catch (error) {
      throw ApiException(message: error.message, cause: error);
    }
  }
}

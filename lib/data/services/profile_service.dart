import 'package:dio/dio.dart';

import '../../core/network/api_config.dart';
import '../../core/network/api_exception.dart';
import '../models/user_profile.dart';

class ProfileService {
  ProfileService(this._dio);

  final Dio _dio;

  Future<UserProfile> fetchProfile({bool allowAuthRefresh = true}) async {
    try {
      final response = await _dio.get<dynamic>(
        ApiConfig.profilePath,
        options: Options(
          extra: <String, dynamic>{
            ApiConfig.skipAuthRefreshKey: !allowAuthRefresh,
          },
        ),
      );
      final body = response.data;
      if (body is! Map) {
        throw const ApiException(message: 'Invalid profile data.');
      }

      final result = UserProfileResponse.fromJson(
        Map<String, dynamic>.from(body),
      );
      if (!result.success) {
        throw ApiException(
          message: result.message.isEmpty
              ? 'Unable to load user information.'
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

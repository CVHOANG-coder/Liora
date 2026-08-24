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

      if (body['success'] != true) {
        throw ApiException.fromResponse(
          responseData: body,
          fallbackMessage: 'Unable to load user information.',
          statusCode: response.statusCode,
        );
      }

      final result = UserProfileResponse.fromJson(
        Map<String, dynamic>.from(body),
      );
      return result.data;
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    } on FormatException catch (error) {
      throw ApiException(message: error.message, cause: error);
    }
  }
}

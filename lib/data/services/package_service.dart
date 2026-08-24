import 'package:dio/dio.dart';

import '../../core/network/api_config.dart';
import '../../core/network/api_exception.dart';
import '../models/package_catalog.dart';

class PackageService {
  PackageService(this._dio);

  final Dio _dio;

  Future<PackageCatalog> fetchPackages() async {
    try {
      final response = await _dio.get<dynamic>(ApiConfig.packagesPath);
      final body = response.data;
      if (body is! Map) {
        throw const ApiException(message: 'Invalid package data.');
      }

      if (body['success'] != true) {
        throw ApiException.fromResponse(
          responseData: body,
          fallbackMessage: 'Unable to load package information.',
          statusCode: response.statusCode,
        );
      }

      final result = PackageCatalogResponse.fromJson(
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

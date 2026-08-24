import 'package:dio/dio.dart';

import '../../data/services/auth_session.dart';
import 'api_config.dart';

class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._dio, this._authSession);

  static const _retriedKey = 'auth_retry_completed';
  static const _requestTokenKey = 'auth_request_token';

  final Dio _dio;
  final AuthSession _authSession;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      await _authSession.initialize();
      final token = _authSession.token;
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
        options.extra[_requestTokenKey] = token;
      }
      handler.next(options);
    } catch (error, stackTrace) {
      handler.reject(
        DioException(
          requestOptions: options,
          error: error,
          stackTrace: stackTrace,
          message: 'Could not load the saved access token.',
        ),
      );
    }
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final statusCode = err.response?.statusCode;
    final request = err.requestOptions;
    final shouldRefresh =
        (statusCode == 401 || statusCode == 403) &&
        request.extra[ApiConfig.skipAuthRefreshKey] != true &&
        request.extra[_retriedKey] != true;

    if (!shouldRefresh) {
      handler.next(err);
      return;
    }

    try {
      final requestToken = request.extra[_requestTokenKey];
      final currentToken = _authSession.token;
      final refreshedToken =
          currentToken != null && currentToken != requestToken
          ? currentToken
          : (await _authSession.signIn()).token;
      request.extra[_retriedKey] = true;
      request.headers['Authorization'] = 'Bearer $refreshedToken';

      final response = await _dio.fetch<dynamic>(request);
      handler.resolve(response);
    } catch (_) {
      // Keep the original 401/403 as the public error. A later request may
      // attempt authentication again after connectivity has recovered.
      handler.next(err);
    }
  }
}

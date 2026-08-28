import 'package:dio/dio.dart';

import '../../data/services/auth_session.dart';
import 'api_config.dart';

class AuthInterceptor extends Interceptor {
  AuthInterceptor(
    this._dio,
    this._authSession, {
    this.retryMultipartUploads = false,
  });

  static const _retriedKey = 'auth_retry_completed';
  static const _requestTokenKey = 'auth_request_token';

  final Dio _dio;
  final AuthSession _authSession;
  final bool retryMultipartUploads;

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

    late final String refreshedToken;
    try {
      final requestToken = request.extra[_requestTokenKey];
      final currentToken = _authSession.token;
      refreshedToken = currentToken != null && currentToken != requestToken
          ? currentToken
          : (await _authSession.signIn()).token;
    } catch (_) {
      // Keep the original 401/403 as the public error. A later request may
      // attempt authentication again after connectivity has recovered.
      handler.next(err);
      return;
    }

    final data = request.data;
    final isMultipartRetry = retryMultipartUploads && data is FormData;
    try {
      final RequestOptions retry;
      if (isMultipartRetry) {
        retry = request.copyWith(
          // Multipart streams have already been consumed by the first POST.
          data: data.clone(),
          headers: {
            ...request.headers,
            'Authorization': 'Bearer $refreshedToken',
          },
          extra: {...request.extra, _retriedKey: true},
        );
      } else {
        // Preserve the original retry behavior for regular API calls.
        request.extra[_retriedKey] = true;
        request.headers['Authorization'] = 'Bearer $refreshedToken';
        retry = request;
      }
      final response = await _dio.fetch<dynamic>(retry);
      handler.resolve(response);
    } on DioException catch (retryError) {
      // Only uploads expose the actual retry failure. Other calls retain the
      // original 401/403, as before the upload-specific changes.
      handler.next(isMultipartRetry ? retryError : err);
    } catch (_) {
      handler.next(err);
    }
  }
}

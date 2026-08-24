import 'package:dio/dio.dart';

class ApiException implements Exception {
  const ApiException({required this.message, this.statusCode, this.cause});

  factory ApiException.fromDio(DioException exception) {
    final responseData = exception.response?.data;
    final serverMessage = extractApiErrorMessage(responseData);

    final message = switch (exception.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => 'The server connection timed out.',
      DioExceptionType.connectionError =>
        'Unable to connect to the server. Check your network connection.',
      _ when serverMessage != null && serverMessage.isNotEmpty => serverMessage,
      _ => 'An error occurred while connecting to the server.',
    };

    return ApiException(
      message: message,
      statusCode: exception.response?.statusCode,
      cause: exception,
    );
  }

  final String message;
  final int? statusCode;
  final Object? cause;

  @override
  String toString() => message;
}

String? extractApiErrorMessage(Object? responseData) {
  if (responseData is String && responseData.trim().isNotEmpty) {
    return responseData.trim();
  }
  if (responseData is! Map) return null;

  for (final key in const ['message', 'error', 'detail']) {
    final value = responseData[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
    final nested = extractApiErrorMessage(value);
    if (nested != null) return nested;
  }

  return extractApiErrorMessage(responseData['data']);
}

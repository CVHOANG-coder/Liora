import 'dart:io';

import 'package:dio/dio.dart';

class ApiException implements Exception {
  const ApiException({
    required this.message,
    this.errorCode,
    this.statusCode,
    this.cause,
    this.isUploadRequest = false,
  });

  factory ApiException.fromResponse({
    required Object? responseData,
    required String fallbackMessage,
    int? statusCode,
    Object? cause,
  }) {
    final serverMessage = extractApiErrorMessage(responseData);
    return ApiException(
      message: apiErrorDisplayMessage(
        serverMessage,
        fallbackMessage: fallbackMessage,
      ),
      errorCode: extractApiErrorCode(responseData),
      statusCode: statusCode,
      cause: cause,
    );
  }

  factory ApiException.fromDio(DioException exception) {
    final responseData = exception.response?.data;
    final serverMessage = extractApiErrorMessage(responseData);

    final message = switch (exception.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => 'The server connection timed out.',
      DioExceptionType.connectionError =>
        'Unable to connect to the server. Check your network connection.',
      _ when serverMessage != null && serverMessage.isNotEmpty =>
        apiErrorDisplayMessage(
          serverMessage,
          fallbackMessage: 'The request could not be completed.',
        ),
      _ => 'An error occurred while connecting to the server.',
    };

    return ApiException(
      message: message,
      errorCode: extractApiErrorCode(responseData),
      statusCode: exception.response?.statusCode,
      cause: exception,
    );
  }

  /// Only the image-generation services opt into upload-specific failures.
  factory ApiException.fromUploadDio(DioException exception) {
    final original = ApiException.fromDio(exception);
    final message = switch (exception.type) {
      DioExceptionType.connectionTimeout =>
        'Connecting to the server timed out. Check your network connection.',
      DioExceptionType.sendTimeout =>
        'Uploading the request timed out. Check your network connection.',
      DioExceptionType.receiveTimeout => 'The server did not respond in time.',
      _ when isConnectionInterruption(exception) =>
        'The connection was interrupted before a response was received.',
      DioExceptionType.badCertificate =>
        'A secure connection to the server could not be verified.',
      DioExceptionType.cancel => 'The request was cancelled.',
      _ => original.message,
    };
    return ApiException(
      message: message,
      errorCode: original.errorCode,
      statusCode: original.statusCode,
      cause: exception,
      isUploadRequest: true,
    );
  }

  final String message;
  final String? errorCode;
  final int? statusCode;
  final Object? cause;
  final bool isUploadRequest;

  bool hasCode(String code) => errorCode == code;

  /// A transport error does not establish whether a paid POST was accepted.
  /// In particular, Dio can wrap a dart:io reset as `unknown`, not
  /// `connectionError`. Keep the original cause for diagnostics.
  bool get isNetworkFailure {
    final error = cause;
    if (error is! DioException) return false;
    return isConnectionInterruption(error) ||
        const {
          DioExceptionType.connectionTimeout,
          DioExceptionType.sendTimeout,
          DioExceptionType.receiveTimeout,
          DioExceptionType.connectionError,
          DioExceptionType.badCertificate,
        }.contains(error.type);
  }

  @override
  String toString() => message;
}

bool isConnectionInterruption(DioException error) =>
    error.response == null &&
    (error.error is HttpException || error.error is SocketException);

abstract final class ApiErrorCode {
  static const insufficientCredit = 'INSUFFICIENT_CREDIT';
  static const subscriptionExpired = 'SUBSCRIPTION_EXPIRED';
  static const accountBanned = 'ACCOUNT_BANNED';
  static const contentPolicy = 'CONTENT_POLICY';
  static const fileTooLarge = 'FILE_TOO_LARGE';
  static const unsupportedFormat = 'UNSUPPORTED_FORMAT';
  static const promptRequired = 'PROMPT_REQUIRED';
  static const imageRequired = 'IMAGE_REQUIRED';
  static const imageUrlRequired = 'IMAGE_URL_REQUIRED';
  static const imageUrlInvalid = 'IMAGE_URL_INVALID';
  static const invalidAspectRatio = 'INVALID_ASPECT_RATIO';
  static const invalidPagination = 'INVALID_PAGINATION';
  static const themeRequired = 'THEME_REQUIRED';
  static const themeNotFound = 'THEME_NOT_FOUND';
  static const requestNotFound = 'REQUEST_NOT_FOUND';
  static const alreadyFinished = 'ALREADY_FINISHED';
  static const receiptInvalid = 'RECEIPT_INVALID';
  static const productNotFound = 'PRODUCT_NOT_FOUND';
  static const purchaseFailed = 'PURCHASE_FAILED';
  static const creditDeductionFailed = 'CREDIT_DEDUCTION_FAILED';
  static const iapDisabled = 'IAP_DISABLED';
  static const iapNotConfigured = 'IAP_NOT_CONFIGURED';
  static const uploadFailed = 'UPLOAD_FAILED';
  static const requestCreateFailed = 'REQUEST_CREATE_FAILED';
  static const submitFailed = 'SUBMIT_FAILED';
  static const userNotFound = 'USER_NOT_FOUND';
  static const internalError = 'INTERNAL_ERROR';
}

String? extractApiErrorCode(Object? responseData) {
  if (responseData is! Map) return null;

  for (final key in const ['error_code', 'errorCode']) {
    final value = responseData[key]?.toString().trim().toUpperCase();
    if (value != null && value.isNotEmpty) return value;
  }

  for (final key in const ['data', 'error', 'detail']) {
    final nested = extractApiErrorCode(responseData[key]);
    if (nested != null) return nested;
  }
  return null;
}

String apiErrorDisplayMessage(
  Object? error, {
  required String fallbackMessage,
}) {
  final rawMessage = switch (error) {
    ApiException exception => exception.message,
    String message => message,
    _ => '',
  };
  final message = rawMessage.trim();
  if (message.isEmpty || _containsNonEnglishLatin(message)) {
    return fallbackMessage;
  }
  return message;
}

bool _containsNonEnglishLatin(String value) {
  return RegExp(r'[\u00C0-\u024F\u0300-\u036F\u1E00-\u1EFF]').hasMatch(value);
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

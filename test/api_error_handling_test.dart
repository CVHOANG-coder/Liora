import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_gen/core/constants/app_features.dart';
import 'package:video_gen/core/network/api_exception.dart';
import 'package:video_gen/presentation/widgets/generation_failure_dialog.dart';

void main() {
  test('non-upload APIs retain their original error messages and retry UI', () {
    const messages = {
      DioExceptionType.connectionTimeout: 'The server connection timed out.',
      DioExceptionType.sendTimeout: 'The server connection timed out.',
      DioExceptionType.receiveTimeout: 'The server connection timed out.',
      DioExceptionType.connectionError:
          'Unable to connect to the server. Check your network connection.',
      DioExceptionType.unknown:
          'An error occurred while connecting to the server.',
      DioExceptionType.badCertificate:
          'An error occurred while connecting to the server.',
      DioExceptionType.cancel:
          'An error occurred while connecting to the server.',
    };
    for (final entry in messages.entries) {
      final cause = DioException(
        requestOptions: RequestOptions(path: '/users/gen-t2v'),
        type: entry.key,
        error: entry.key == DioExceptionType.unknown
            ? const HttpException('Connection reset by peer')
            : null,
      );
      final error = ApiException.fromDio(cause);
      expect(error.cause, same(cause));
      expect(error.isUploadRequest, isFalse);
      expect(error.message, entry.value, reason: entry.key.name);
      final presentation = resolveApiErrorPresentation(
        error,
        fallbackMessage: 'Unable to submit video.',
      );
      expect(presentation.title, 'Video Generation Failed');
      expect(presentation.primaryLabel, 'Try Again');
      expect(presentation.primaryAction, GenerationFailureAction.retry);
      expect(presentation.message, isNot(contains('Check History')));
    }
  });

  test('an unknown Dio HttpException is an unconfirmed network request', () {
    final cause = DioException(
      requestOptions: RequestOptions(path: '/users/gen-i2v'),
      error: const HttpException('Connection reset by peer'),
    );
    final error = ApiException.fromUploadDio(cause);
    expect(error.cause, same(cause));
    expect(error.isNetworkFailure, isTrue);
    expect(error.message, contains('connection was interrupted'));
    final presentation = resolveApiErrorPresentation(
      error,
      fallbackMessage: 'Unable to submit video.',
    );
    expect(presentation.title, 'Request Not Confirmed');
    expect(presentation.message, contains('Check History'));
    expect(presentation.primaryAction, GenerationFailureAction.close);
    expect(presentation.secondaryAction, isNull);
    expect(presentation.message, isNot(contains('No credits were deducted')));
  });

  test('timeout messages distinguish connection, upload and response', () {
    final messages =
        [
              DioExceptionType.connectionTimeout,
              DioExceptionType.sendTimeout,
              DioExceptionType.receiveTimeout,
            ]
            .map(
              (type) => ApiException.fromUploadDio(
                DioException(
                  requestOptions: RequestOptions(path: '/users/gen-i2v'),
                  type: type,
                ),
              ).message,
            )
            .toList();
    expect(messages[0], contains('Connecting'));
    expect(messages[1], contains('Uploading'));
    expect(messages[2], contains('did not respond'));
  });

  group('API error parsing', () {
    test('reads error_code from data and preserves the server message', () {
      final error = ApiException.fromResponse(
        responseData: <String, dynamic>{
          'success': false,
          'message': 'Have 12, need 35',
          'data': <String, dynamic>{
            'error_code': ApiErrorCode.insufficientCredit,
          },
        },
        fallbackMessage: 'Unable to generate.',
        statusCode: 400,
      );

      expect(error.errorCode, ApiErrorCode.insufficientCredit);
      expect(error.message, 'Have 12, need 35');
      expect(error.statusCode, 400);
    });

    test('reads error_code from a nested error object', () {
      expect(
        extractApiErrorCode(<String, dynamic>{
          'error': <String, dynamic>{'error_code': ApiErrorCode.contentPolicy},
        }),
        ApiErrorCode.contentPolicy,
      );
    });

    test('replaces a non-English server message with an English fallback', () {
      final error = ApiException.fromResponse(
        responseData: <String, dynamic>{
          'success': false,
          'message': 'Kh\u00F4ng th\u1EC3 x\u1EED l\u00FD y\u00EAu c\u1EA7u.',
          'data': <String, dynamic>{'error_code': ApiErrorCode.internalError},
        },
        fallbackMessage: 'Unable to process the request.',
      );

      expect(error.message, 'Unable to process the request.');
    });
  });

  group('API error presentation', () {
    test('maps every documented error code to the expected action', () {
      const expectedActions = <String, GenerationFailureAction>{
        ApiErrorCode.insufficientCredit: AppFeatures.commerceEnabled
            ? GenerationFailureAction.buyCredits
            : GenerationFailureAction.close,
        ApiErrorCode.subscriptionExpired: AppFeatures.commerceEnabled
            ? GenerationFailureAction.renewSubscription
            : GenerationFailureAction.close,
        ApiErrorCode.accountBanned: GenerationFailureAction.contactSupport,
        ApiErrorCode.contentPolicy: GenerationFailureAction.editInput,
        ApiErrorCode.fileTooLarge: GenerationFailureAction.chooseImage,
        ApiErrorCode.unsupportedFormat: GenerationFailureAction.chooseImage,
        ApiErrorCode.promptRequired: GenerationFailureAction.editInput,
        ApiErrorCode.imageRequired: GenerationFailureAction.chooseImage,
        ApiErrorCode.imageUrlRequired: GenerationFailureAction.editInput,
        ApiErrorCode.imageUrlInvalid: GenerationFailureAction.editInput,
        ApiErrorCode.invalidAspectRatio: GenerationFailureAction.editInput,
        ApiErrorCode.invalidPagination: GenerationFailureAction.retry,
        ApiErrorCode.themeRequired: GenerationFailureAction.chooseTheme,
        ApiErrorCode.themeNotFound: GenerationFailureAction.chooseTheme,
        ApiErrorCode.requestNotFound: GenerationFailureAction.close,
        ApiErrorCode.alreadyFinished: GenerationFailureAction.close,
        ApiErrorCode.receiptInvalid: GenerationFailureAction.contactSupport,
        ApiErrorCode.productNotFound: GenerationFailureAction.close,
        ApiErrorCode.purchaseFailed: GenerationFailureAction.retry,
        ApiErrorCode.creditDeductionFailed: GenerationFailureAction.retry,
        ApiErrorCode.iapDisabled: GenerationFailureAction.contactSupport,
        ApiErrorCode.iapNotConfigured: GenerationFailureAction.contactSupport,
        ApiErrorCode.uploadFailed: GenerationFailureAction.retry,
        ApiErrorCode.requestCreateFailed: GenerationFailureAction.retry,
        ApiErrorCode.submitFailed: GenerationFailureAction.retry,
        ApiErrorCode.userNotFound: GenerationFailureAction.retry,
        ApiErrorCode.internalError: GenerationFailureAction.retry,
      };

      for (final entry in expectedActions.entries) {
        final presentation = resolveApiErrorPresentation(
          ApiException(message: 'Server detail', errorCode: entry.key),
          fallbackMessage: 'Fallback',
        );
        expect(presentation.primaryAction, entry.value, reason: entry.key);
      }
    });

    test('content policy never opens the credit purchase flow', () {
      final presentation = resolveApiErrorPresentation(
        const ApiException(
          message: 'Please revise this prompt.',
          errorCode: ApiErrorCode.contentPolicy,
        ),
        fallbackMessage: 'Unable to generate.',
      );

      expect(presentation.primaryAction, GenerationFailureAction.editInput);
      expect(
        presentation.primaryAction,
        isNot(GenerationFailureAction.buyCredits),
      );
    });

    test('submit failure explains that credits were refunded', () {
      final presentation = resolveApiErrorPresentation(
        const ApiException(
          message: 'Provider rejected the job.',
          errorCode: ApiErrorCode.submitFailed,
        ),
        fallbackMessage: 'Unable to generate.',
      );

      if (AppFeatures.commerceEnabled) {
        expect(presentation.message, contains('automatically refunded'));
      } else {
        expect(presentation.message, isNot(contains('credit')));
      }
      expect(presentation.primaryAction, GenerationFailureAction.retry);
    });
  });

  group('purchase error presentation', () {
    test('maps documented purchase errors to safe actions', () {
      const expectedActions = <String, GenerationFailureAction>{
        ApiErrorCode.receiptInvalid: GenerationFailureAction.contactSupport,
        ApiErrorCode.productNotFound: GenerationFailureAction.contactSupport,
        ApiErrorCode.purchaseFailed: GenerationFailureAction.retry,
        ApiErrorCode.creditDeductionFailed: GenerationFailureAction.retry,
        ApiErrorCode.iapDisabled: GenerationFailureAction.contactSupport,
        ApiErrorCode.iapNotConfigured: GenerationFailureAction.contactSupport,
      };

      for (final entry in expectedActions.entries) {
        final presentation = resolvePurchaseErrorPresentation(
          ApiException(message: 'Purchase detail', errorCode: entry.key),
          fallbackMessage: 'Unable to complete the purchase.',
        );
        expect(presentation.primaryAction, entry.value, reason: entry.key);
        expect(presentation.visual, AppErrorVisual.purchase, reason: entry.key);
        expect(presentation.title, isNot(contains('Video Generation')));
      }
    });

    test('unknown purchase failures never use generation wording', () {
      final presentation = resolvePurchaseErrorPresentation(
        const ApiException(message: 'The checkout could not be completed.'),
        fallbackMessage: 'Unable to complete the purchase.',
      );

      expect(presentation.title, 'Purchase Failed');
      expect(presentation.primaryAction, GenerationFailureAction.retry);
      expect(presentation.message, 'The checkout could not be completed.');
    });

    test('receipt errors warn users not to buy again', () {
      final presentation = resolvePurchaseErrorPresentation(
        const ApiException(
          message: 'Receipt rejected by Google Play.',
          errorCode: ApiErrorCode.receiptInvalid,
        ),
        fallbackMessage: 'Unable to verify the purchase.',
      );

      expect(presentation.title, 'Purchase Could Not Be Verified');
      expect(presentation.message, contains('before trying to buy it again'));
      expect(
        presentation.primaryAction,
        GenerationFailureAction.contactSupport,
      );
    });

    test('unavailable Google Play does not offer a retry loop', () {
      final presentation = resolvePurchaseErrorPresentation(
        const ApiException(
          message: 'Google Play Billing is currently unavailable.',
        ),
        fallbackMessage: 'Unable to complete the purchase.',
      );

      expect(presentation.title, 'Google Play Is Unavailable');
      expect(presentation.primaryAction, GenerationFailureAction.close);
      expect(presentation.secondaryLabel, isNull);
    });
  });
}

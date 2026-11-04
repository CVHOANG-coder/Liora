import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_gen/core/network/api_exception.dart';
import 'package:video_gen/data/services/extend_video_service.dart';
import 'package:video_gen/presentation/widgets/generation_failure_dialog.dart';

void main() {
  for (final duration in [5, 10, 15]) {
    test(
      'submits JSON for a $duration second continuation using the source ID',
      () async {
        final adapter = _Adapter((options) {
          expect(options.method, 'POST');
          expect(options.path, '/users/extend-video');
          expect(options.contentType, Headers.jsonContentType);
          expect(options.data, {
            'request_id': 'source-id',
            'prompt': 'Keep walking',
            'is_hd': true,
            'duration': duration,
            'seed': '123',
          });
          return {
            'success': true,
            'data': {
              'request_id': 'extension-id',
              'extend_from': 'source-id',
              'status': 'IN_QUEUE',
              'remaining_credit': 130,
              'params': {'duration': duration, 'megapixels': 1},
              'credit_info': {
                'base_credit': 35,
                'multiplier': 4,
                'total_charged': 280,
              },
            },
          };
        });
        final service = ExtendVideoService(Dio()..httpClientAdapter = adapter);
        final result = await service.generate(
          requestId: 'source-id',
          videoUrl: 'https://video.test/ignored.mp4',
          prompt: ' Keep walking ',
          isHd: true,
          duration: duration,
          seed: ' 123 ',
        );
        expect(result.requestId, 'extension-id');
        expect(result.extendFrom, 'source-id');
        expect(result.params.duration, duration);
        expect(result.remainingCredit, 130);
        expect(result.creditInfo.totalCharged, 280);
        expect(adapter.calls, 1);
      },
    );
  }

  test('URL fallback omits optional seed and uses API defaults', () async {
    final adapter = _Adapter((options) {
      expect(options.data, {
        'video_url': 'https://video.test/original.mp4',
        'prompt': 'Continue',
        'is_hd': false,
        'duration': 5,
      });
      return {
        'success': true,
        'data': {'request_id': 'new-id'},
      };
    });
    await ExtendVideoService(Dio()..httpClientAdapter = adapter).generate(
      videoUrl: 'https://video.test/original.mp4',
      prompt: 'Continue',
      seed: ' ',
    );
  });

  test(
    'rejects missing input and unsupported durations before submitting',
    () async {
      final adapter = _Adapter((_) => throw StateError('Must not send'));
      final service = ExtendVideoService(Dio()..httpClientAdapter = adapter);
      await expectLater(
        service.generate(prompt: 'Continue'),
        throwsA(_code(ApiErrorCode.videoUrlRequired)),
      );
      await expectLater(
        service.generate(requestId: 'source', prompt: ' '),
        throwsA(_code(ApiErrorCode.promptRequired)),
      );
      await expectLater(
        service.generate(requestId: 'source', prompt: 'Continue', duration: 20),
        throwsA(_code(ApiErrorCode.invalidDuration)),
      );
      expect(adapter.calls, 0);
    },
  );

  for (final code in [
    ApiErrorCode.sourceVideoNotFound,
    ApiErrorCode.frameExtractFailed,
    ApiErrorCode.invalidDuration,
    ApiErrorCode.insufficientCredit,
  ]) {
    test('preserves nested $code errors from the API', () async {
      final service = ExtendVideoService(
        Dio()
          ..httpClientAdapter = _Adapter(
            (_) => {
              'success': false,
              'message': 'Request rejected',
              'data': {'error_code': code},
            },
          ),
      );
      await expectLater(
        service.generate(requestId: 'source', prompt: 'Continue'),
        throwsA(_code(code)),
      );
    });
  }

  for (final body in [
    <String, Object?>{'success': true, 'data': {}},
    <String, Object?>{'success': true, 'data': null},
    'invalid',
  ]) {
    test('rejects malformed successful response $body', () async {
      final service = ExtendVideoService(
        Dio()..httpClientAdapter = _Adapter((_) => body),
      );
      await expectLater(
        service.generate(requestId: 'source', prompt: 'Continue'),
        throwsA(isA<ApiException>()),
      );
    });
  }

  test('extension failures offer actions suited to their cause', () {
    for (final entry in {
      ApiErrorCode.sourceVideoNotFound: GenerationFailureAction.close,
      ApiErrorCode.videoUrlRequired: GenerationFailureAction.close,
      ApiErrorCode.frameExtractFailed: GenerationFailureAction.retry,
      ApiErrorCode.invalidDuration: GenerationFailureAction.editInput,
    }.entries) {
      final presentation = resolveApiErrorPresentation(
        ApiException(message: '', errorCode: entry.key),
        fallbackMessage: 'Unable to extend',
      );
      expect(presentation.primaryAction, entry.value);
    }
  });
}

Matcher _code(String code) =>
    isA<ApiException>().having((e) => e.errorCode, 'error code', code);

class _Adapter implements HttpClientAdapter {
  _Adapter(this.respond);
  final Object? Function(RequestOptions) respond;
  int calls = 0;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    return ResponseBody.fromString(
      jsonEncode(respond(options)),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

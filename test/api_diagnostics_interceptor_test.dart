import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_gen/core/network/api_diagnostics_interceptor.dart';

void main() {
  for (final fail in [false, true]) {
    test(
      'diagnostics terminate on ${fail ? 'reset' : 'success'} without secrets',
      () async {
        final messages = <String>[];
        final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
        dio.httpClientAdapter = _UploadAdapter(fail: fail);
        dio.interceptors.add(ApiDiagnosticsInterceptor(log: messages.add));
        addTearDown(() => dio.close(force: true));
        final progress = <(int, int)>[];
        final response = dio.post<dynamic>(
          '/users/gen-i2v?secret=query-secret',
          options: Options(headers: {'Authorization': 'Bearer token-secret'}),
          data: FormData.fromMap({
            'prompt': 'prompt-secret',
            'source_image': MultipartFile.fromBytes([
              1,
              2,
              3,
            ], filename: 'private.jpg'),
          }),
          onSendProgress: (sent, total) => progress.add((sent, total)),
        );
        if (fail) {
          await expectLater(response, throwsA(isA<DioException>()));
        } else {
          await response;
        }
        expect(messages, hasLength(3));
        expect(messages[0], contains('start POST /users/gen-i2v'));
        expect(messages[1], contains('body_sent'));
        expect(
          messages[2],
          contains(fail ? 'connection_reset_by_peer' : 'status=200'),
        );
        expect(messages[2], contains('after_body_ms='));
        expect(progress.last.$1, progress.last.$2);
        for (final secret in [
          'query-secret',
          'token-secret',
          'prompt-secret',
          'private.jpg',
        ]) {
          expect(messages.join(), isNot(contains(secret)));
        }
      },
    );
  }

  test(
    'disabled diagnostics neither log nor wrap the upload callback',
    () async {
      final messages = <String>[];
      final dio = Dio();
      dio.httpClientAdapter = _UploadAdapter();
      dio.interceptors.add(
        ApiDiagnosticsInterceptor(enabled: false, log: messages.add),
      );
      addTearDown(() => dio.close(force: true));
      final progress = <(int, int)>[];
      void onProgress(int sent, int total) => progress.add((sent, total));
      final response = await dio.post<dynamic>(
        'https://example.test/upload',
        data: 'body',
        onSendProgress: onProgress,
      );
      expect(response.requestOptions.onSendProgress, same(onProgress));
      expect(progress, isNotEmpty);
      expect(messages, isEmpty);
    },
  );

  test('a broken diagnostic sink cannot fail an upload', () async {
    final dio = Dio();
    dio.httpClientAdapter = _UploadAdapter();
    dio.interceptors.add(
      ApiDiagnosticsInterceptor(log: (_) => throw StateError('log')),
    );
    addTearDown(() => dio.close(force: true));
    final response = await dio.post<dynamic>(
      'https://example.test/upload',
      data: 'body',
    );
    expect(response.statusCode, 200);
  });
}

class _UploadAdapter implements HttpClientAdapter {
  _UploadAdapter({this.fail = false});

  final bool fail;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    await requestStream?.drain<void>();
    if (fail) throw const HttpException('Connection reset by peer');
    return ResponseBody.fromString(
      '{}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

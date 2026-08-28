import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_gen/core/network/api_exception.dart';
import 'package:video_gen/data/services/i2v_generation_service.dart';
import 'package:video_gen/data/services/theme_generation_service.dart';

// Exercise real sockets, not a mocked Dio adapter. No production endpoint,
// credentials, user photos, or generation credits are used by these tests.
void main() {
  late Directory directory;
  late File file;
  late Uint8List fileBytes;
  late HttpServer server;
  late Dio dio;
  late List<_Receipt> receipts;
  late Completer<void> received;
  late bool respond;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('multipart_transport_');
    // Transport fixture only: verify every byte without involving an image
    // decoder. Match the size of the image in the failed device request.
    fileBytes = Uint8List.fromList(
      List.generate(625325, (index) => index % 251),
    );
    file = await File('${directory.path}/source.jpg').writeAsBytes(fileBytes);
    receipts = [];
    received = Completer<void>();
    respond = true;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      try {
        final bytes = await request.fold<BytesBuilder>(
          BytesBuilder(copy: false),
          (builder, chunk) => builder..add(chunk),
        );
        receipts.add(_Receipt(request, bytes.takeBytes()));
        if (!received.isCompleted) received.complete();
        if (respond) {
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode({
              'success': true,
              'data': {'request_id': 'local-only', 'status': 'IN_QUEUE'},
            }),
          );
          await request.response.close();
        }
      } catch (error, stack) {
        if (!received.isCompleted) received.completeError(error, stack);
      }
    });
    dio = Dio(
      BaseOptions(
        baseUrl: 'http://127.0.0.1:${server.port}',
        connectTimeout: const Duration(seconds: 3),
        sendTimeout: const Duration(seconds: 3),
        receiveTimeout: const Duration(seconds: 3),
        // Same defaults as ApiClient; multipart must replace application/json.
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );
  });

  tearDown(() async {
    dio.close(force: true);
    await server.close(force: true);
    await directory.delete(recursive: true);
  });

  test(
    'I2V sends complete binary file and Unicode fields over a real socket',
    () async {
      const prompt = 'biến cô gái thành nàng tiên cá 🌊';
      final progress = <(int, int)>[];
      final result = await I2VGenerationService(dio).generate(
        imagePath: file.path,
        prompt: prompt,
        isHd: false,
        isLongTime: true,
        onUploadProgress: (sent, total) => progress.add((sent, total)),
      );
      await received.future;
      expect(result.requestId, 'local-only');
      expect(receipts, hasLength(1));
      final receipt = receipts.single;
      expect(receipt.path, '/users/gen-i2v');
      receipt.expectComplete(fileBytes);
      expect(receipt.fields, {
        'prompt': prompt,
        'is_hd': 'false',
        'is_long_time': 'true',
      });
      expect(progress.last, (receipt.body.length, receipt.body.length));
    },
  );

  test(
    'theme upload uses the same complete multipart file transport',
    () async {
      await ThemeGenerationService(dio).generate(
        firstImagePath: file.path,
        themeId: 'test-theme',
        isHd: true,
        isLongTime: false,
      );
      final receipt = receipts.single;
      expect(receipt.path, '/users/gen-theme');
      receipt.expectComplete(fileBytes);
      expect(receipt.fields, {
        'theme_id': 'test-theme',
        'is_hd': 'true',
        'is_long_time': 'false',
      });
    },
  );

  test('a second submission gets a fresh readable file stream', () async {
    final service = I2VGenerationService(dio);
    for (var attempt = 0; attempt < 2; attempt++) {
      await service.generate(
        imagePath: file.path,
        prompt: 'test',
        isHd: false,
        isLongTime: false,
      );
    }
    expect(receipts, hasLength(2));
    for (final receipt in receipts) {
      receipt.expectComplete(fileBytes);
    }
  });

  test(
    'receive timeout can happen after the receiver has the entire image',
    () async {
      respond = false;
      dio.options.receiveTimeout = const Duration(milliseconds: 150);
      await expectLater(
        I2VGenerationService(dio).generate(
          imagePath: file.path,
          prompt: 'test',
          isHd: false,
          isLongTime: true,
        ),
        throwsA(
          isA<ApiException>().having(
            (error) => (error.cause as DioException).type,
            'timeout phase',
            DioExceptionType.receiveTimeout,
          ),
        ),
      );
      await received.future.timeout(const Duration(seconds: 2));
      expect(receipts, hasLength(1));
      receipts.single.expectComplete(fileBytes);
    },
  );
}

class _Receipt {
  _Receipt(HttpRequest request, this.body)
    : path = request.uri.path,
      declaredLength = request.contentLength,
      contentType = request.headers.contentType! {
    final boundary = contentType.parameters['boundary']!;
    for (final part in latin1.decode(body).split('--$boundary')) {
      final split = part.indexOf('\r\n\r\n');
      if (split < 0) continue;
      final header = part.substring(0, split);
      final name = RegExp(r'name="([^"]+)"').firstMatch(header)?.group(1);
      final bytes = latin1.encode(part.substring(split + 4, part.length - 2));
      if (name == 'source_image') {
        files.add(bytes);
        fileContentType = RegExp(
          r'content-type: ([^\r\n]+)',
          caseSensitive: false,
        ).firstMatch(header)?.group(1);
      } else if (name != null) {
        fields[name] = utf8.decode(bytes);
      }
    }
  }

  final String path;
  final int declaredLength;
  final ContentType contentType;
  final Uint8List body;
  final Map<String, String> fields = {};
  final List<List<int>> files = [];
  String? fileContentType;

  void expectComplete(List<int> expectedFile) {
    expect(contentType.mimeType, 'multipart/form-data');
    expect(declaredLength, body.length);
    expect(
      latin1
          .decode(body)
          .endsWith('--${contentType.parameters['boundary']}--\r\n'),
      isTrue,
    );
    expect(files, hasLength(1));
    expect(files.single, orderedEquals(expectedFile));
    expect(fileContentType, 'image/jpeg');
  }
}

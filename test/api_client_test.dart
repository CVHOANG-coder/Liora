import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_gen/core/device/device_identity_service.dart';
import 'package:video_gen/core/network/api_client.dart';
import 'package:video_gen/core/network/api_diagnostics_interceptor.dart';
import 'package:video_gen/core/network/api_exception.dart';
import 'package:video_gen/core/storage/token_storage.dart';
import 'package:video_gen/data/models/purchase_verification.dart';

void main() {
  test(
    'regular APIs remain independent while an upload waits and fails',
    () async {
      final uploadStarted = Completer<void>();
      final finishUpload = Completer<void>();
      final uploadAdapter = _CallbackAdapter((options) async {
        uploadStarted.complete();
        await finishUpload.future;
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.receiveTimeout,
        );
      }, consumeRequestBody: true);
      final apiAdapter = _CallbackAdapter((options) {
        expect(options.data, isNot(isA<FormData>()));
        expect(options.onSendProgress, isNull);
        expect(options.extra, {
          if (options.path == '/users/user-status') 'skip_auth_refresh': false,
          'auth_request_token': 'refreshed-token',
        });
        expect(options.headers['Authorization'], 'Bearer refreshed-token');
        final body = switch (options.path) {
          '/users/user-status' => _profileBody(),
          '/users/gen-t2v' => _i2vBody(),
          '/users/request-status/request-001' => _requestStatusBody(),
          '/get-all-package' => {'success': true, 'data': <String, dynamic>{}},
          '/users/get-themes' => {
            'success': true,
            'data': {'categories': [], 'total': 0},
          },
          '/users/gen-history' => {
            'success': true,
            'data': {
              'requests': [],
              'pagination': {
                'page': 1,
                'limit': 10,
                'total': 0,
                'total_pages': 0,
              },
            },
          },
          '/users/verify-purchase' ||
          '/users/delete-request/request-001' => {'success': true},
          _ => throw StateError('Unexpected regular API: ${options.path}'),
        };
        return _jsonResponse(body, 200);
      });
      final authAdapter = _CallbackAdapter((options) {
        expect(options.onSendProgress, isNull);
        expect(options.extra, isEmpty);
        return _jsonResponse(_signInBody('refreshed-token'), 200);
      });
      final client = ApiClient(
        httpClient: _dioWithAdapter(apiAdapter),
        uploadClient: _dioWithAdapter(uploadAdapter),
        authClient: _dioWithAdapter(authAdapter),
        deviceIdentity: const _FakeDeviceIdentity(),
        tokenStorage: _MemoryTokenStorage('saved-token'),
      );
      final uploadFailure = expectLater(
        client.generateImageToVideo(
          imagePath: 'assets/images/create_video.png',
          prompt: 'a calm seaside',
          isHd: false,
          isLongTime: false,
        ),
        throwsA(
          isA<ApiException>().having(
            (error) => error.isUploadRequest,
            'upload context',
            isTrue,
          ),
        ),
      );
      await uploadStarted.future;
      try {
        await client.signIn();
        await Future.wait<dynamic>([
          client.fetchProfile(),
          client.fetchPackages(),
          client.fetchThemes(),
          client.fetchGenerationHistory(page: 1),
          client.fetchImageToVideoStatus('request-001'),
          client.generateTextToVideo(
            prompt: 'a calm seaside',
            isHd: false,
            isLongTime: false,
          ),
          client.verifyPurchase(
            const PurchaseReceipt(
              productId: 'credits',
              purchaseToken: 'test-receipt',
              orderId: 'test-order',
            ),
          ),
          client.deleteGenerationRequest('request-001'),
        ]);
        expect(apiAdapter.requests, hasLength(8));
        expect(authAdapter.requests, hasLength(1));
        expect(uploadAdapter.requests, hasLength(1));
      } finally {
        finishUpload.complete();
        await uploadFailure;
      }
      await client.fetchProfile();
      expect(apiAdapter.requests, hasLength(9));
    },
  );

  for (final status in [401, 403]) {
    for (final retryTimesOut in [false, true]) {
      test(
        'regular auth retry retains original $status; timeout=$retryTimesOut',
        () async {
          var attempts = 0;
          final apiAdapter = _CallbackAdapter((options) {
            attempts++;
            if (attempts == 1) {
              return _jsonResponse({'message': 'expired'}, status);
            }
            expect(options.headers['Authorization'], 'Bearer refreshed-token');
            if (retryTimesOut) {
              throw DioException(
                requestOptions: options,
                type: DioExceptionType.receiveTimeout,
              );
            }
            return _jsonResponse({'message': 'server failure'}, 500);
          });
          final authAdapter = _CallbackAdapter(
            (_) => _jsonResponse(_signInBody('refreshed-token'), 200),
          );
          final client = ApiClient(
            httpClient: _dioWithAdapter(apiAdapter),
            uploadClient: _dioWithAdapter(_CallbackAdapter(_unusedRequest)),
            authClient: _dioWithAdapter(authAdapter),
            deviceIdentity: const _FakeDeviceIdentity(),
            tokenStorage: _MemoryTokenStorage('saved-token'),
          );
          void onProgress(int sent, int total) {}
          await expectLater(
            client.dio.post<dynamic>(
              '/protected',
              data: {'value': true},
              onSendProgress: onProgress,
            ),
            throwsA(
              isA<DioException>()
                  .having(
                    (error) => error.response?.statusCode,
                    'original status',
                    status,
                  )
                  .having(
                    (error) => error.response?.data['message'],
                    'original response',
                    'expired',
                  ),
            ),
          );
          expect(apiAdapter.requests, hasLength(2));
          expect(authAdapter.requests, hasLength(1));
          expect(apiAdapter.requests.first, same(apiAdapter.requests.last));
          expect(apiAdapter.requests.last.onSendProgress, same(onProgress));
          expect(apiAdapter.requests.last.extra.keys, [
            'auth_request_token',
            'auth_retry_completed',
          ]);
        },
      );
    }
  }

  for (final status in [401, 403]) {
    test('multipart upload is rebuilt after a $status token refresh', () async {
      var attempts = 0;
      final apiAdapter = _CallbackAdapter((options) {
        attempts++;
        expect((options.data as FormData).isFinalized, isTrue);
        if (attempts == 1) {
          return _jsonResponse({'message': 'expired'}, status);
        }
        expect(options.headers['Authorization'], 'Bearer refreshed-token');
        return _jsonResponse(_i2vBody(), 200);
      }, consumeRequestBody: true);
      final authAdapter = _CallbackAdapter(
        (_) => _jsonResponse(_signInBody('refreshed-token'), 200),
      );
      final client = ApiClient(
        httpClient: _dioWithAdapter(_CallbackAdapter(_unusedRequest)),
        uploadClient: _dioWithAdapter(apiAdapter),
        authClient: _dioWithAdapter(authAdapter),
        deviceIdentity: const _FakeDeviceIdentity(),
        tokenStorage: _MemoryTokenStorage('expired-token'),
      );
      final progress = <(int, int)>[];
      final result = await client.generateImageToVideo(
        imagePath: 'assets/images/create_video.png',
        prompt: 'a calm seaside',
        isHd: false,
        isLongTime: false,
        onUploadProgress: (sent, total) => progress.add((sent, total)),
      );

      expect(result.requestId, 'request-001');
      expect(apiAdapter.requests, hasLength(2));
      expect(authAdapter.requests, hasLength(1));
      final original = apiAdapter.requests.first.data as FormData;
      final retry = apiAdapter.requests.last.data as FormData;
      expect(identical(original, retry), isFalse);
      expect(Map.fromEntries(retry.fields), Map.fromEntries(original.fields));
      expect(
        retry.files.single.value.length,
        original.files.single.value.length,
      );
      expect(progress.where((event) => event.$1 == event.$2), hasLength(2));
    });
  }

  for (final refreshFirst in [false, true]) {
    test(
      'connection reset preserves cause and is not retried; refresh=$refreshFirst',
      () async {
        var attempts = 0;
        final apiAdapter = _CallbackAdapter((options) {
          attempts++;
          if (refreshFirst && attempts == 1) {
            return _jsonResponse({'message': 'expired'}, 401);
          }
          throw const HttpException('Connection reset by peer');
        }, consumeRequestBody: true);
        final authAdapter = _CallbackAdapter(
          (_) => _jsonResponse(_signInBody('refreshed-token'), 200),
        );
        final client = ApiClient(
          httpClient: _dioWithAdapter(_CallbackAdapter(_unusedRequest)),
          uploadClient: _dioWithAdapter(apiAdapter),
          authClient: _dioWithAdapter(authAdapter),
          deviceIdentity: const _FakeDeviceIdentity(),
          tokenStorage: _MemoryTokenStorage('saved-token'),
        );
        await expectLater(
          client.generateImageToVideo(
            imagePath: 'assets/images/create_video.png',
            prompt: 'a calm seaside',
            isHd: false,
            isLongTime: false,
          ),
          throwsA(
            isA<ApiException>()
                .having(
                  (error) => error.isNetworkFailure,
                  'network failure',
                  isTrue,
                )
                .having((error) => error.statusCode, 'no HTTP response', isNull)
                .having(
                  (error) => (error.cause as DioException).error,
                  'original reset',
                  isA<HttpException>(),
                ),
          ),
        );
        expect(apiAdapter.requests, hasLength(refreshFirst ? 2 : 1));
        expect(authAdapter.requests, hasLength(refreshFirst ? 1 : 0));
      },
    );
  }

  test('only upload send timeout is five minutes; others stay one minute', () {
    final client = ApiClient(
      deviceIdentity: const _FakeDeviceIdentity(),
      tokenStorage: _MemoryTokenStorage(),
    );
    addTearDown(() => client.dio.close(force: true));
    addTearDown(() => client.uploadDio.close(force: true));

    expect(client.uploadDio, isNot(same(client.dio)));
    expect(
      client.uploadDio.httpClientAdapter,
      isNot(same(client.dio.httpClientAdapter)),
    );
    expect(
      client.dio.interceptors.whereType<ApiDiagnosticsInterceptor>(),
      isEmpty,
    );
    expect(
      client.uploadDio.interceptors.whereType<ApiDiagnosticsInterceptor>(),
      hasLength(1),
    );
    for (final dio in [client.dio, client.uploadDio]) {
      expect(dio.options.connectTimeout, const Duration(minutes: 1));
      expect(dio.options.receiveTimeout, const Duration(minutes: 1));
    }
    expect(client.dio.options.sendTimeout, const Duration(minutes: 1));
    expect(client.uploadDio.options.sendTimeout, const Duration(minutes: 5));
  });

  test(
    'sign in sends device metadata and coalesces concurrent calls',
    () async {
      final authAdapter = _CallbackAdapter((options) async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return _jsonResponse(_signInBody('token-1'), 200);
      });
      final authDio = _dioWithAdapter(authAdapter);
      final client = ApiClient(
        authClient: authDio,
        httpClient: _dioWithAdapter(_CallbackAdapter(_unusedRequest)),
        deviceIdentity: const _FakeDeviceIdentity(),
        tokenStorage: _MemoryTokenStorage(),
      );

      final users = await Future.wait([client.signIn(), client.signIn()]);

      expect(
        authDio.interceptors.whereType<ApiDiagnosticsInterceptor>(),
        isEmpty,
      );
      expect(authAdapter.requests.single.onSendProgress, isNull);
      expect(authAdapter.requests.single.extra, isEmpty);
      expect(authAdapter.requests, hasLength(1));
      expect(authAdapter.requests.single.path, '/signin');
      expect(authAdapter.requests.single.data, <String, dynamic>{
        'device_id': 'device-001',
        'platform': 'ANDROID',
        'country': 'VN',
      });
      expect(users.first.token, 'token-1');
      expect(users.last.token, 'token-1');
    },
  );

  test(
    '401 signs in again and retries the request with the new token',
    () async {
      var protectedCallCount = 0;
      final apiAdapter = _CallbackAdapter((options) {
        protectedCallCount += 1;
        if (protectedCallCount == 1) {
          return _jsonResponse(<String, dynamic>{'message': 'expired'}, 401);
        }
        expect(options.headers['Authorization'], 'Bearer refreshed-token');
        return _jsonResponse(<String, dynamic>{'result': 'ok'}, 200);
      });
      final authAdapter = _CallbackAdapter(
        (options) => _jsonResponse(_signInBody('refreshed-token'), 200),
      );
      final client = ApiClient(
        authClient: _dioWithAdapter(authAdapter),
        httpClient: _dioWithAdapter(apiAdapter),
        deviceIdentity: const _FakeDeviceIdentity(),
        tokenStorage: _MemoryTokenStorage(),
      );

      final response = await client.dio.get<dynamic>('/protected');

      expect(response.data, <String, dynamic>{'result': 'ok'});
      expect(apiAdapter.requests, hasLength(2));
      expect(authAdapter.requests, hasLength(1));
    },
  );

  test(
    'a request is retried at most once when authorization still fails',
    () async {
      final apiAdapter = _CallbackAdapter(
        (options) =>
            _jsonResponse(<String, dynamic>{'message': 'forbidden'}, 403),
      );
      final authAdapter = _CallbackAdapter(
        (options) => _jsonResponse(_signInBody('still-invalid'), 200),
      );
      final client = ApiClient(
        authClient: _dioWithAdapter(authAdapter),
        httpClient: _dioWithAdapter(apiAdapter),
        deviceIdentity: const _FakeDeviceIdentity(),
        tokenStorage: _MemoryTokenStorage(),
      );

      await expectLater(
        client.dio.get<dynamic>('/protected'),
        throwsA(isA<DioException>()),
      );

      expect(apiAdapter.requests, hasLength(2));
      expect(authAdapter.requests, hasLength(1));
    },
  );

  test('bootstrap uses a saved token when profile succeeds', () async {
    final tokenStorage = _MemoryTokenStorage('saved-token');
    final apiAdapter = _CallbackAdapter((options) {
      expect(options.path, '/users/user-status');
      expect(options.headers['Authorization'], 'Bearer saved-token');
      return _jsonResponse(_profileBody(), 200);
    });
    final authAdapter = _CallbackAdapter(_unusedRequest);
    final client = ApiClient(
      authClient: _dioWithAdapter(authAdapter),
      httpClient: _dioWithAdapter(apiAdapter),
      deviceIdentity: const _FakeDeviceIdentity(),
      tokenStorage: tokenStorage,
    );

    final profile = await client.bootstrapSession();

    expect(profile.userCode, '6YP8PZM34CDFT9RY');
    expect(profile.totalCredit, 70);
    expect(apiAdapter.requests, hasLength(1));
    expect(authAdapter.requests, isEmpty);
    expect(tokenStorage.savedTokens, isEmpty);
  });

  test(
    'bootstrap signs in and retries profile when saved token fails',
    () async {
      var profileCalls = 0;
      final tokenStorage = _MemoryTokenStorage('expired-token');
      final apiAdapter = _CallbackAdapter((options) {
        profileCalls += 1;
        if (profileCalls == 1) {
          expect(options.headers['Authorization'], 'Bearer expired-token');
          return _jsonResponse(<String, dynamic>{'message': 'expired'}, 401);
        }
        expect(options.headers['Authorization'], 'Bearer fresh-token');
        return _jsonResponse(_profileBody(), 200);
      });
      final authAdapter = _CallbackAdapter(
        (options) => _jsonResponse(_signInBody('fresh-token'), 200),
      );
      final client = ApiClient(
        authClient: _dioWithAdapter(authAdapter),
        httpClient: _dioWithAdapter(apiAdapter),
        deviceIdentity: const _FakeDeviceIdentity(),
        tokenStorage: tokenStorage,
      );

      final profile = await client.bootstrapSession();

      expect(profile.userStatus, 'NEW');
      expect(apiAdapter.requests, hasLength(2));
      expect(authAdapter.requests, hasLength(1));
      expect(tokenStorage.savedTokens, <String>['fresh-token']);
      expect(await tokenStorage.readToken(), 'fresh-token');
    },
  );

  test('fetch packages uses the catalog endpoint and parses data', () async {
    final apiAdapter = _CallbackAdapter((options) {
      expect(options.path, '/get-all-package');
      return _jsonResponse(<String, dynamic>{
        'success': true,
        'message': 'success',
        'data': <String, dynamic>{
          'ANDROID': <String, dynamic>{
            'SUBSCRIPTION': <dynamic>[],
            'SALE': <dynamic>[],
            'CONSUMABLE_VIP': <dynamic>[],
            'CONSUMABLE_NEW': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 4,
                'product_id': 'com.nostalia.ai.videogenerator.70_credits',
                'product_type': 'CONSUMABLE',
                'name': '70 Credits',
                'price': 5.19,
                'platform': 'ANDROID',
                'description': '70 credits',
                'credit': 70,
                'pack_duration_day': 0,
              },
            ],
          },
        },
      }, 200);
    });
    final client = ApiClient(
      authClient: _dioWithAdapter(_CallbackAdapter(_unusedRequest)),
      httpClient: _dioWithAdapter(apiAdapter),
      deviceIdentity: const _FakeDeviceIdentity(),
      tokenStorage: _MemoryTokenStorage(),
    );

    final catalog = await client.fetchPackages();

    expect(catalog.forPlatform('ANDROID')?.consumableNew.single.credit, 70);
    expect(apiAdapter.requests, hasLength(1));
  });

  test('verify purchase posts the Google Play receipt with auth', () async {
    final apiAdapter = _CallbackAdapter((options) {
      expect(options.path, '/users/verify-purchase');
      expect(options.method, 'POST');
      expect(options.headers['Authorization'], 'Bearer saved-token');
      expect(options.data, <String, dynamic>{
        'receipt': <String, dynamic>{
          'productId': 'com.nostalia.ai.videogenerator.500_credits',
          'purchaseToken': 'play-purchase-token',
          'orderId': 'GPA.0000-0000-0000-00000',
        },
      });
      return _jsonResponse(<String, dynamic>{
        'success': true,
        'message': 'Purchase verified',
      }, 200);
    });
    final client = ApiClient(
      authClient: _dioWithAdapter(_CallbackAdapter(_unusedRequest)),
      httpClient: _dioWithAdapter(apiAdapter),
      deviceIdentity: const _FakeDeviceIdentity(),
      tokenStorage: _MemoryTokenStorage('saved-token'),
    );

    final result = await client.verifyPurchase(
      const PurchaseReceipt(
        productId: 'com.nostalia.ai.videogenerator.500_credits',
        purchaseToken: 'play-purchase-token',
        orderId: 'GPA.0000-0000-0000-00000',
      ),
    );

    expect(result.success, isTrue);
    expect(result.message, 'Purchase verified');
    expect(apiAdapter.requests, hasLength(1));
  });

  test('fetch themes uses the authenticated themes endpoint', () async {
    final apiAdapter = _CallbackAdapter((options) {
      expect(options.path, '/users/get-themes');
      expect(options.method, 'GET');
      expect(options.headers['Authorization'], 'Bearer saved-token');
      return _jsonResponse(<String, dynamic>{
        'success': true,
        'message': 'success',
        'data': <String, dynamic>{
          'categories': <Map<String, dynamic>>[
            <String, dynamic>{
              'category_key': 'Hula_image2video_viral_dance',
              'title': 'Viral dances',
              'theme_count': 1,
              'themes': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 1,
                  'theme_key': 'hula_image2video_viral_dance__mad_dance',
                  'name': 'Mad dance',
                  'service_type': 'I2V_GENERATOR',
                  'preview_video_url': 'https://example.test/mad-dance.mp4',
                  'thumbnail_url': 'https://example.test/mad-dance.jpg',
                  'preview_webp_url': 'https://example.test/mad-dance.webp',
                  'sort_order': 1,
                },
              ],
            },
          ],
          'total': 1,
        },
      }, 200);
    });
    final client = ApiClient(
      authClient: _dioWithAdapter(_CallbackAdapter(_unusedRequest)),
      httpClient: _dioWithAdapter(apiAdapter),
      deviceIdentity: const _FakeDeviceIdentity(),
      tokenStorage: _MemoryTokenStorage('saved-token'),
    );

    final categories = await client.fetchThemes();

    expect(categories.single.title, 'Viral dances');
    expect(categories.single.posts.single.description, 'Mad dance');
    expect(
      categories.single.posts.single.previewWebpUrl,
      'https://example.test/mad-dance.webp',
    );
    expect(
      categories.single.posts.single.previewImageUrl,
      'https://example.test/mad-dance.webp',
    );
    expect(
      categories.single.posts.single.thumbnailUrl,
      'https://example.test/mad-dance.jpg',
    );
    expect(
      categories.single.posts.single.id,
      'hula_image2video_viral_dance__mad_dance',
    );
    expect(apiAdapter.requests, hasLength(1));
  });

  test('generate image to video posts authenticated multipart data', () async {
    final uploadProgress = <(int, int)>[];
    final apiAdapter = _CallbackAdapter((options) {
      expect(options.path, '/users/gen-i2v');
      expect(options.method, 'POST');
      expect(options.headers['Authorization'], 'Bearer saved-token');
      expect(options.contentType, startsWith('multipart/form-data'));
      final formData = options.data as FormData;
      expect(Map<String, String>.fromEntries(formData.fields), <String, String>{
        'prompt': 'a calm seaside',
        'is_hd': 'false',
        'is_long_time': 'false',
      });
      expect(formData.files.single.key, 'source_image');
      expect(formData.files.single.value.filename, 'create_video.png');
      return _jsonResponse(_i2vBody(), 200);
    }, consumeRequestBody: true);
    final client = ApiClient(
      authClient: _dioWithAdapter(_CallbackAdapter(_unusedRequest)),
      httpClient: _dioWithAdapter(_CallbackAdapter(_unusedRequest)),
      uploadClient: _dioWithAdapter(apiAdapter),
      deviceIdentity: const _FakeDeviceIdentity(),
      tokenStorage: _MemoryTokenStorage('saved-token'),
    );

    final generation = await client.generateImageToVideo(
      imagePath: 'assets/images/create_video.png',
      prompt: 'a calm seaside',
      isHd: false,
      isLongTime: false,
      onUploadProgress: (sent, total) => uploadProgress.add((sent, total)),
    );

    expect(generation.requestId, 'request-001');
    expect(generation.status, 'IN_QUEUE');
    expect(generation.remainingCredit, 465);
    expect(generation.creditInfo.totalCharged, 35);
    expect(uploadProgress, isNotEmpty);
    expect(uploadProgress.last.$1, greaterThan(0));
    expect(uploadProgress.last.$1, uploadProgress.last.$2);
    expect(
      uploadProgress.last.$2,
      (apiAdapter.requests.single.data as FormData).length,
    );
  });

  test('generate text to video posts authenticated JSON data', () async {
    final apiAdapter = _CallbackAdapter((options) {
      expect(options.path, '/users/gen-t2v');
      expect(options.method, 'POST');
      expect(options.headers['Authorization'], 'Bearer saved-token');
      expect(options.contentType, 'application/json');
      expect(options.onSendProgress, isNull);
      expect(options.extra.keys, ['auth_request_token']);
      expect(options.data, <String, dynamic>{
        'prompt': 'a calm seaside',
        'is_hd': true,
        'is_long_time': true,
      });
      return _jsonResponse(_i2vBody(), 200);
    });
    final client = ApiClient(
      authClient: _dioWithAdapter(_CallbackAdapter(_unusedRequest)),
      httpClient: _dioWithAdapter(apiAdapter),
      deviceIdentity: const _FakeDeviceIdentity(),
      tokenStorage: _MemoryTokenStorage('saved-token'),
    );

    final generation = await client.generateTextToVideo(
      prompt: 'a calm seaside',
      isHd: true,
      isLongTime: true,
    );

    expect(generation.requestId, 'request-001');
    expect(generation.status, 'IN_QUEUE');
    expect(generation.remainingCredit, 465);
  });

  test(
    'T2V preserves an insufficient-credit message without response data',
    () async {
      final client = ApiClient(
        authClient: _dioWithAdapter(_CallbackAdapter(_unusedRequest)),
        httpClient: _dioWithAdapter(
          _CallbackAdapter(
            (_) => _jsonResponse(<String, dynamic>{
              'success': false,
              'message': 'You need 35 credits, current balance is 0.',
              'data': null,
            }, 200),
          ),
        ),
        deviceIdentity: const _FakeDeviceIdentity(),
        tokenStorage: _MemoryTokenStorage('saved-token'),
      );

      await expectLater(
        client.generateTextToVideo(
          prompt: 'a calm seaside',
          isHd: false,
          isLongTime: false,
        ),
        throwsA(
          isA<ApiException>().having(
            (error) => error.message,
            'message',
            contains('need 35 credits'),
          ),
        ),
      );
    },
  );

  test(
    'generate theme video posts only the first frame as authenticated multipart',
    () async {
      final uploadProgress = <(int, int)>[];
      final apiAdapter = _CallbackAdapter((options) {
        expect(options.path, '/users/gen-theme');
        expect(options.method, 'POST');
        expect(options.headers['Authorization'], 'Bearer saved-token');
        expect(options.contentType, startsWith('multipart/form-data'));
        final formData = options.data as FormData;
        expect(
          Map<String, String>.fromEntries(formData.fields),
          <String, String>{
            'theme_id': 'mad_dance',
            'is_hd': 'true',
            'is_long_time': 'true',
          },
        );
        expect(formData.files.map((entry) => entry.key), <String>[
          'source_image',
        ]);
        return _jsonResponse(_themeGenerationBody(), 200);
      }, consumeRequestBody: true);
      final client = ApiClient(
        authClient: _dioWithAdapter(_CallbackAdapter(_unusedRequest)),
        httpClient: _dioWithAdapter(_CallbackAdapter(_unusedRequest)),
        uploadClient: _dioWithAdapter(apiAdapter),
        deviceIdentity: const _FakeDeviceIdentity(),
        tokenStorage: _MemoryTokenStorage('saved-token'),
      );

      final generation = await client.generateThemeVideo(
        themeId: 'mad_dance',
        firstImagePath: 'assets/images/create_video.png',
        isHd: true,
        isLongTime: true,
        onUploadProgress: (sent, total) => uploadProgress.add((sent, total)),
      );

      expect(generation.requestId, 'request-001');
      expect(generation.remainingCredit, 465);
      expect(generation.theme?.name, 'Mad dance');
      expect(generation.image2Url, endsWith('last.jpg'));
      expect(uploadProgress, isNotEmpty);
      expect(uploadProgress.last.$1, greaterThan(0));
      expect(uploadProgress.last.$1, uploadProgress.last.$2);
      expect(
        uploadProgress.last.$2,
        (apiAdapter.requests.single.data as FormData).length,
      );
    },
  );

  test(
    'theme generation preserves a nested insufficient-credit error',
    () async {
      final client = ApiClient(
        authClient: _dioWithAdapter(_CallbackAdapter(_unusedRequest)),
        httpClient: _dioWithAdapter(_CallbackAdapter(_unusedRequest)),
        uploadClient: _dioWithAdapter(
          _CallbackAdapter(
            (_) => _jsonResponse(<String, dynamic>{
              'success': false,
              'error': <String, dynamic>{
                'message': 'Not enough credits to generate this video.',
                'error_code': ApiErrorCode.insufficientCredit,
              },
              'data': null,
            }, 200),
          ),
        ),
        deviceIdentity: const _FakeDeviceIdentity(),
        tokenStorage: _MemoryTokenStorage('saved-token'),
      );

      await expectLater(
        client.generateThemeVideo(
          themeId: 'mad_dance',
          firstImagePath: 'assets/images/create_video.png',
          isHd: false,
          isLongTime: false,
        ),
        throwsA(
          isA<ApiException>().having(
            (error) => error.message,
            'message',
            contains('Not enough credits'),
          ),
        ),
      );
    },
  );

  test(
    'fetch video request status uses request id and parses result',
    () async {
      final apiAdapter = _CallbackAdapter((options) {
        expect(options.path, '/users/request-status/request-001');
        expect(options.method, 'GET');
        expect(options.headers['Authorization'], 'Bearer saved-token');
        return _jsonResponse(_requestStatusBody(), 200);
      });
      final client = ApiClient(
        authClient: _dioWithAdapter(_CallbackAdapter(_unusedRequest)),
        httpClient: _dioWithAdapter(apiAdapter),
        deviceIdentity: const _FakeDeviceIdentity(),
        tokenStorage: _MemoryTokenStorage('saved-token'),
      );

      final status = await client.fetchImageToVideoStatus('request-001');

      expect(status.isCompleted, isTrue);
      expect(status.resultUrl, endsWith('result.mp4'));
      expect(status.creditCharged, 35);
    },
  );

  test('fetch generation history sends pagination and bearer token', () async {
    final apiAdapter = _CallbackAdapter((options) {
      expect(options.path, '/users/gen-history');
      expect(options.method, 'GET');
      expect(options.queryParameters, <String, dynamic>{
        'page': 2,
        'limit': 10,
      });
      expect(options.headers['Authorization'], 'Bearer saved-token');
      return _jsonResponse(<String, dynamic>{
        'success': true,
        'message': 'success',
        'data': <String, dynamic>{
          'requests': <Map<String, dynamic>>[
            _requestStatusBody()['data']! as Map<String, dynamic>,
          ],
          'pagination': <String, dynamic>{
            'page': 2,
            'limit': 10,
            'total': 21,
            'total_pages': 3,
          },
        },
      }, 200);
    });
    final client = ApiClient(
      authClient: _dioWithAdapter(_CallbackAdapter(_unusedRequest)),
      httpClient: _dioWithAdapter(apiAdapter),
      deviceIdentity: const _FakeDeviceIdentity(),
      tokenStorage: _MemoryTokenStorage('saved-token'),
    );

    final history = await client.fetchGenerationHistory(page: 2, limit: 10);

    expect(history.requests.single.requestId, 'request-001');
    expect(history.pagination.page, 2);
    expect(history.pagination.hasMore, isTrue);
  });

  test('delete generation request sends id and bearer token', () async {
    final apiAdapter = _CallbackAdapter((options) {
      expect(options.path, '/users/delete-request/request-001');
      expect(options.method, 'DELETE');
      expect(options.headers['Authorization'], 'Bearer saved-token');
      return _jsonResponse(<String, dynamic>{
        'success': true,
        'message': 'success',
      }, 200);
    });
    final client = ApiClient(
      authClient: _dioWithAdapter(_CallbackAdapter(_unusedRequest)),
      httpClient: _dioWithAdapter(apiAdapter),
      deviceIdentity: const _FakeDeviceIdentity(),
      tokenStorage: _MemoryTokenStorage('saved-token'),
    );

    await client.deleteGenerationRequest('request-001');

    expect(apiAdapter.requests, hasLength(1));
  });
}

Dio _dioWithAdapter(HttpClientAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
  dio.httpClientAdapter = adapter;
  return dio;
}

FutureOr<ResponseBody> _unusedRequest(RequestOptions options) {
  throw StateError('Unexpected API request to ${options.path}');
}

ResponseBody _jsonResponse(Object data, int statusCode) {
  return ResponseBody.fromString(
    jsonEncode(data),
    statusCode,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
    },
  );
}

Map<String, dynamic> _signInBody(String token) => <String, dynamic>{
  'success': true,
  'message': 'success',
  'data': <String, dynamic>{
    'id': 2,
    'user_code': '6YP8PZM34CDFT9RY',
    'platform': 'ANDROID',
    'country': 'VN',
    'is_actived': true,
    'is_banned': false,
    'sub_credit_remain': 0,
    'bought_credit': 0,
    'token': token,
  },
};

Map<String, dynamic> _profileBody() => <String, dynamic>{
  'success': true,
  'message': 'success',
  'data': <String, dynamic>{
    'id': 2,
    'email': '',
    'username': null,
    'user_code': '6YP8PZM34CDFT9RY',
    'platform': 'IOS',
    'country': 'VN',
    'country_code': null,
    'is_actived': true,
    'is_banned': false,
    'sub_time': '2026-08-23T15:25:06.332Z',
    'sub_end_time': '2026-08-23T15:25:06.332Z',
    'sub_credit_remain': 0,
    'bought_credit': 0,
    'create_time': '2026-08-23T15:25:06.332Z',
    'gen_count': 0,
    'today_gen_count': 0,
    'user_status': 'NEW',
    'isVIP': false,
    'isSubscribed': false,
    'total_credit': 70,
    'i2v_credit_base': 35,
  },
};

Map<String, dynamic> _i2vBody() => <String, dynamic>{
  'success': true,
  'message': 'I2V video generation request submitted successfully',
  'data': <String, dynamic>{
    'request_id': 'request-001',
    'runpod_job_id': 'pod-001',
    'user_id': 2,
    'service_type': 'I2V_GENERATOR',
    'prompt': 'a calm seaside',
    'image_url': 'https://example.test/image.jpg',
    'status': 'IN_QUEUE',
    'create_time': '2026-08-23T16:25:36.592Z',
    'params': <String, dynamic>{
      'duration': 5,
      'megapixels': 0.5,
      'steps': 8,
      'aspect_ratio': '9:16 (Portrait Widescreen)',
      'seed': '94711889392016',
    },
    'remaining_credit': 465,
    'credit_info': <String, dynamic>{
      'base_credit': 35,
      'multiplier': 1,
      'total_charged': 35,
    },
  },
};

Map<String, dynamic> _themeGenerationBody() {
  final body = _i2vBody();
  final data = body['data']! as Map<String, dynamic>;
  data['theme'] = <String, dynamic>{'id': 1, 'name': 'Mad dance'};
  data['image2_url'] = 'https://example.test/last.jpg';
  return body;
}

Map<String, dynamic> _requestStatusBody() => <String, dynamic>{
  'success': true,
  'message': 'success',
  'data': <String, dynamic>{
    'id': 2,
    'request_id': 'request-001',
    'runpod_job_id': 'pod-001',
    'user_id': 2,
    'service_type': 'I2V_GENERATOR',
    'request_status': 'COMPLETED',
    'prompt': 'a calm seaside',
    'image_url': 'https://example.test/source.jpg',
    'thumbnail_url': '',
    'is_hd': false,
    'is_long_time': false,
    'duration': 5,
    'result_data': 'https://example.test/result.mp4',
    'error_message': '',
    'credit_charged': 35,
    'credit_refunded': false,
    'create_time': '2026-08-23T16:25:36.592Z',
    'completed_time': '2026-08-23T16:26:37.824Z',
    'last_update_time': '2026-08-23T16:26:37.824Z',
  },
};

class _FakeDeviceIdentity implements DeviceIdentityProvider {
  const _FakeDeviceIdentity();

  @override
  String get countryCode => 'VN';

  @override
  Future<String> getDeviceId() async => 'device-001';

  @override
  String get platform => 'ANDROID';
}

class _CallbackAdapter implements HttpClientAdapter {
  _CallbackAdapter(this._callback, {this.consumeRequestBody = false});

  final bool consumeRequestBody;
  final FutureOr<ResponseBody> Function(RequestOptions options) _callback;
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (consumeRequestBody) await requestStream?.drain<void>();
    return _callback(options);
  }

  @override
  void close({bool force = false}) {}
}

class _MemoryTokenStorage implements TokenStorage {
  _MemoryTokenStorage([this._token]);

  String? _token;
  final List<String> savedTokens = <String>[];

  @override
  Future<void> clearToken() async => _token = null;

  @override
  Future<String?> readToken() async => _token;

  @override
  Future<void> saveToken(String token) async {
    _token = token;
    savedTokens.add(token);
  }
}

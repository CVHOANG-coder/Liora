import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_gen/core/device/device_identity_service.dart';
import 'package:video_gen/core/network/api_client.dart';
import 'package:video_gen/core/network/api_exception.dart';
import 'package:video_gen/core/storage/token_storage.dart';
import 'package:video_gen/data/models/purchase_verification.dart';

void main() {
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
      categories.single.posts.single.id,
      'hula_image2video_viral_dance__mad_dance',
    );
    expect(apiAdapter.requests, hasLength(1));
  });

  test('generate image to video posts authenticated multipart data', () async {
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
    });
    final client = ApiClient(
      authClient: _dioWithAdapter(_CallbackAdapter(_unusedRequest)),
      httpClient: _dioWithAdapter(apiAdapter),
      deviceIdentity: const _FakeDeviceIdentity(),
      tokenStorage: _MemoryTokenStorage('saved-token'),
    );

    final generation = await client.generateImageToVideo(
      imagePath: 'assets/images/create_video.png',
      prompt: 'a calm seaside',
      isHd: false,
      isLongTime: false,
    );

    expect(generation.requestId, 'request-001');
    expect(generation.status, 'IN_QUEUE');
    expect(generation.remainingCredit, 465);
    expect(generation.creditInfo.totalCharged, 35);
  });

  test('generate text to video posts authenticated JSON data', () async {
    final apiAdapter = _CallbackAdapter((options) {
      expect(options.path, '/users/gen-t2v');
      expect(options.method, 'POST');
      expect(options.headers['Authorization'], 'Bearer saved-token');
      expect(options.contentType, 'application/json');
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
    'generate theme video posts two frames as authenticated multipart',
    () async {
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
          'source_image2',
        ]);
        return _jsonResponse(_themeGenerationBody(), 200);
      });
      final client = ApiClient(
        authClient: _dioWithAdapter(_CallbackAdapter(_unusedRequest)),
        httpClient: _dioWithAdapter(apiAdapter),
        deviceIdentity: const _FakeDeviceIdentity(),
        tokenStorage: _MemoryTokenStorage('saved-token'),
      );

      final generation = await client.generateThemeVideo(
        themeId: 'mad_dance',
        firstImagePath: 'assets/images/create_video.png',
        lastImagePath: 'assets/images/create_video.png',
        isHd: true,
        isLongTime: true,
      );

      expect(generation.requestId, 'request-001');
      expect(generation.remainingCredit, 465);
      expect(generation.theme?.name, 'Mad dance');
      expect(generation.image2Url, endsWith('last.jpg'));
    },
  );

  test('generate theme video omits the optional last frame', () async {
    final apiAdapter = _CallbackAdapter((options) {
      final formData = options.data as FormData;
      expect(formData.files.map((entry) => entry.key), <String>[
        'source_image',
      ]);
      return _jsonResponse(_i2vBody(), 200);
    });
    final client = ApiClient(
      authClient: _dioWithAdapter(_CallbackAdapter(_unusedRequest)),
      httpClient: _dioWithAdapter(apiAdapter),
      deviceIdentity: const _FakeDeviceIdentity(),
      tokenStorage: _MemoryTokenStorage('saved-token'),
    );

    await client.generateThemeVideo(
      themeId: 'mad_dance',
      firstImagePath: 'assets/images/create_video.png',
      isHd: false,
      isLongTime: false,
    );
  });

  test('theme generation preserves a nested insufficient-coin error', () async {
    final client = ApiClient(
      authClient: _dioWithAdapter(_CallbackAdapter(_unusedRequest)),
      httpClient: _dioWithAdapter(
        _CallbackAdapter(
          (_) => _jsonResponse(<String, dynamic>{
            'success': false,
            'error': <String, dynamic>{
              'message': 'Không đủ coin để tạo video.',
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
          contains('Không đủ coin'),
        ),
      ),
    );
  });

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
  _CallbackAdapter(this._callback);

  final FutureOr<ResponseBody> Function(RequestOptions options) _callback;
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
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

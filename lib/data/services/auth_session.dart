import 'package:dio/dio.dart';

import '../../core/device/device_identity_service.dart';
import '../../core/network/api_config.dart';
import '../../core/network/api_exception.dart';
import '../../core/storage/token_storage.dart';
import '../models/sign_in_response.dart';

class AuthSession {
  AuthSession(this._authDio, this._device, this._tokenStorage);

  final Dio _authDio;
  final DeviceIdentityProvider _device;
  final TokenStorage _tokenStorage;

  Future<void>? _activeInitialization;
  Future<SignInData>? _activeSignIn;
  SignInData? _currentUser;
  String? _token;
  bool _isInitialized = false;

  SignInData? get currentUser => _currentUser;
  String? get token => _token;
  bool get hasToken => _token != null && _token!.isNotEmpty;

  Future<void> initialize() {
    if (_isInitialized) return Future<void>.value();
    return _activeInitialization ??= _loadStoredToken().whenComplete(
      () => _activeInitialization = null,
    );
  }

  Future<void> _loadStoredToken() async {
    final storedToken = await _tokenStorage.readToken();
    _token = storedToken == null || storedToken.isEmpty ? null : storedToken;
    _isInitialized = true;
  }

  /// Coalesces concurrent refreshes so several 401/403 responses trigger only
  /// one call to /signin.
  Future<SignInData> signIn() => _activeSignIn ??= _performSignIn()
      .whenComplete(() => _activeSignIn = null);

  Future<SignInData> _performSignIn() async {
    try {
      await initialize();
      final response = await _authDio.post<dynamic>(
        ApiConfig.signInPath,
        data: <String, dynamic>{
          'device_id': await _device.getDeviceId(),
          'platform': _device.platform,
          'country': _device.countryCode,
        },
      );

      final body = response.data;
      if (body is! Map) {
        throw const ApiException(message: 'Invalid sign-in data.');
      }

      if (body['success'] != true) {
        throw ApiException.fromResponse(
          responseData: body,
          fallbackMessage: 'Unable to sign in on this device.',
          statusCode: response.statusCode,
        );
      }

      final result = SignInResponse.fromJson(Map<String, dynamic>.from(body));

      await _tokenStorage.saveToken(result.data.token);
      _token = result.data.token;
      _currentUser = result.data;
      return result.data;
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    } on FormatException catch (error) {
      throw ApiException(message: error.message, cause: error);
    }
  }

  Future<void> clear() async {
    await _tokenStorage.clearToken();
    _token = null;
    _currentUser = null;
    _isInitialized = true;
  }
}

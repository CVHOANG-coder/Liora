import 'package:shared_preferences/shared_preferences.dart';

abstract interface class TokenStorage {
  Future<String?> readToken();

  Future<void> saveToken(String token);

  Future<void> clearToken();
}

class SharedPreferencesTokenStorage implements TokenStorage {
  SharedPreferencesTokenStorage({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const _tokenKey = 'auth_access_token';

  final SharedPreferencesAsync _preferences;

  @override
  Future<String?> readToken() => _preferences.getString(_tokenKey);

  @override
  Future<void> saveToken(String token) =>
      _preferences.setString(_tokenKey, token);

  @override
  Future<void> clearToken() => _preferences.remove(_tokenKey);
}

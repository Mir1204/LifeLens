import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secrets stay in Android Keystore-backed encrypted storage, never SQLite.
class SecureStorageService {
  static const _storage = FlutterSecureStorage(aOptions: AndroidOptions());
  static const _tokenKey = 'backend_access_token';
  static const _refreshTokenKey = 'backend_refresh_token';

  Future<String?> token() => _storage.read(key: _tokenKey);
  Future<String?> read(String key) => _storage.read(key: key);
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
  Future<void> saveToken(String token) =>
      _storage.write(key: _tokenKey, value: token);
  Future<String?> refreshToken() => _storage.read(key: _refreshTokenKey);
  Future<void> saveRefreshToken(String token) =>
      _storage.write(key: _refreshTokenKey, value: token);
  Future<void> clearToken() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }
}

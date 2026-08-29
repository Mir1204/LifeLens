import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secrets stay in Android Keystore-backed encrypted storage, never SQLite.
class SecureStorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _tokenKey = 'backend_access_token';

  Future<String?> token() => _storage.read(key: _tokenKey);
  Future<String?> read(String key) => _storage.read(key: key);
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
  Future<void> saveToken(String token) =>
      _storage.write(key: _tokenKey, value: token);
  Future<void> clearToken() => _storage.delete(key: _tokenKey);
}

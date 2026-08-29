import 'dart:convert';
import 'dart:io';

import '../models/app_user.dart';
import 'lifelens_store.dart';
import 'local_database_service.dart';
import 'secure_storage_service.dart';

/// Accounts are authenticated by the backend. The phone retains no password.
class AuthService {
  AuthService({
    LocalDatabaseService? database,
    SecureStorageService? secureStorage,
  }) : database = database ?? LocalDatabaseService(),
       secureStorage = secureStorage ?? SecureStorageService();

  final LocalDatabaseService database;
  final SecureStorageService secureStorage;

  Future<AppUser?> currentUser() => database.signedInUser();

  Future<AppUser> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final token = await _authenticate(
      '/auth/register',
      normalizedEmail,
      password,
    );
    final user = AppUser(
      userId: _stableUserId(normalizedEmail),
      name: name.trim(),
      email: normalizedEmail,
    );
    await database.upsertUser(user: user, passwordHash: '', signedIn: true);
    await secureStorage.saveToken(token);
    return user;
  }

  Future<AppUser> login({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final token = await _authenticate('/auth/login', normalizedEmail, password);
    final row = await database.userByEmail(normalizedEmail);
    final user = AppUser(
      userId: row?['user_id'] as String? ?? _stableUserId(normalizedEmail),
      name: row?['name'] as String? ?? normalizedEmail.split('@').first,
      email: normalizedEmail,
      monthlyIncome: (row?['monthly_income'] as num?)?.toDouble(),
      monthlyBudget: (row?['monthly_budget'] as num?)?.toDouble(),
    );
    await database.upsertUser(user: user, passwordHash: '', signedIn: true);
    await secureStorage.saveToken(token);
    return user;
  }

  Future<String> _authenticate(
    String endpoint,
    String email,
    String password,
  ) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30);
    try {
      final request = await client.postUrl(
        Uri.parse('${LifeLensStore.defaultBackendUrl}$endpoint'),
      );
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({'email': email, 'password': password}));
      final response = await request.close().timeout(
        const Duration(seconds: 45),
      );
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw const AuthException(
          'Unable to authenticate. Check your details and connection.',
        );
      }
      final token =
          (jsonDecode(body) as Map<String, dynamic>)['access_token'] as String?;
      if (token == null || token.isEmpty)
        throw const AuthException(
          'Server returned an invalid sign-in response.',
        );
      return token;
    } on SocketException {
      throw const AuthException(
        'A secure internet connection is required to sign in.',
      );
    } on HttpException {
      throw const AuthException(
        'Could not contact the secure sign-in service.',
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<void> signOut() async {
    await database.signOutAll();
    await secureStorage.clearToken();
  }

  String _stableUserId(String email) {
    var hash = 0x811c9dc5;
    for (final unit in email.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return 'user_${hash.toRadixString(16).padLeft(8, '0')}';
  }
}

class AuthException implements Exception {
  const AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

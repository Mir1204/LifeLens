import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/app_user.dart';
import 'lifelens_store.dart';
import 'local_database_service.dart';
import 'prediction_api_service.dart';
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
    final tokens = await _authenticate(
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
    await _saveTokens(tokens);
    return user;
  }

  Future<AppUser> login({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final tokens = await _authenticate(
      '/auth/login',
      normalizedEmail,
      password,
    );
    final row = await database.userByEmail(normalizedEmail);
    final user = AppUser(
      userId: row?['user_id'] as String? ?? _stableUserId(normalizedEmail),
      name: row?['name'] as String? ?? normalizedEmail.split('@').first,
      email: normalizedEmail,
      monthlyIncome: (row?['monthly_income'] as num?)?.toDouble(),
      monthlyBudget: (row?['monthly_budget'] as num?)?.toDouble(),
    );
    await database.upsertUser(user: user, passwordHash: '', signedIn: true);
    await _saveTokens(tokens);
    return user;
  }

  Future<AppUser> signInWithGoogle() async {
    const webClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
    if (webClientId.isEmpty) {
      throw const AuthException(
        'Google Sign-In is not configured for this build.',
      );
    }
    GoogleSignInAccount? account;
    try {
      account = await GoogleSignIn(
        scopes: const ['email', 'profile'],
        serverClientId: webClientId,
      ).signIn();
    } on PlatformException catch (error) {
      if (error.code == 'sign_in_failed') {
        throw const AuthException(
          'Google Sign-In setup does not match this Android app. Verify the package name and SHA-1 in Google Cloud Console.',
        );
      }
      throw const AuthException(
        'Google Sign-In could not start on this device.',
      );
    }
    if (account == null)
      throw const AuthException('Google Sign-In was cancelled.');
    final authentication = await account.authentication;
    final idToken = authentication.idToken;
    if (idToken == null)
      throw const AuthException(
        'Google did not return a secure sign-in token.',
      );

    final tokens = await _authenticateGoogle(idToken);
    final row = await database.userByEmail(account.email.toLowerCase());
    final user = AppUser(
      userId: row?['user_id'] as String? ?? _stableUserId(account.email),
      name:
          row?['name'] as String? ??
          account.displayName ??
          account.email.split('@').first,
      email: account.email.toLowerCase(),
      monthlyIncome: (row?['monthly_income'] as num?)?.toDouble(),
      monthlyBudget: (row?['monthly_budget'] as num?)?.toDouble(),
    );
    await database.upsertUser(user: user, passwordHash: '', signedIn: true);
    await _saveTokens(tokens);
    return user;
  }

  Future<_AuthTokens> _authenticateGoogle(String idToken) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30);
    try {
      final request = await client.postUrl(
        Uri.parse('${LifeLensStore.defaultBackendUrl}/auth/google'),
      );
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({'id_token': idToken}));
      final response = await request.close().timeout(
        const Duration(seconds: 45),
      );
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode == HttpStatus.unauthorized) {
        throw const AuthException(
          'Google rejected this sign-in. Confirm the Web OAuth client ID is identical in the app and Render.',
        );
      }
      if (response.statusCode == HttpStatus.serviceUnavailable) {
        throw const AuthException(
          'Google verification is temporarily unavailable. Please try again shortly.',
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw const AuthException(
          'LifeLens could not complete Google Sign-In.',
        );
      }
      return _AuthTokens.fromJson(jsonDecode(body) as Map<String, dynamic>);
    } on SocketException {
      throw const AuthException(
        'Could not reach the secure LifeLens sign-in service.',
      );
    } on TimeoutException {
      throw const AuthException(
        'LifeLens sign-in timed out. Please try again.',
      );
    } on HttpException {
      throw const AuthException(
        'Could not contact the secure LifeLens sign-in service.',
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<_AuthTokens> _authenticate(
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
      return _AuthTokens.fromJson(jsonDecode(body) as Map<String, dynamic>);
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
    final refreshToken = await secureStorage.refreshToken();
    if (refreshToken != null) {
      try {
        final backendUrl =
            await database.setting('backend_url') ??
            'https://lifelens-backend-xh56.onrender.com';
        await PredictionApiService(
          baseUrl: backendUrl,
        ).revokeRefreshSession(refreshToken: refreshToken);
      } catch (_) {
        // Local credentials are still removed even if the device is offline.
      }
    }
    await database.signOutAll();
    await secureStorage.clearToken();
  }

  Future<void> _saveTokens(_AuthTokens tokens) async {
    await secureStorage.saveToken(tokens.accessToken);
    await secureStorage.saveRefreshToken(tokens.refreshToken);
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

class _AuthTokens {
  const _AuthTokens({required this.accessToken, required this.refreshToken});
  final String accessToken;
  final String refreshToken;

  factory _AuthTokens.fromJson(Map<String, dynamic> json) {
    final accessToken = json['access_token'] as String?;
    final refreshToken = json['refresh_token'] as String?;
    if (accessToken == null ||
        refreshToken == null ||
        accessToken.isEmpty ||
        refreshToken.isEmpty) {
      throw const AuthException('Server returned an invalid sign-in response.');
    }
    return _AuthTokens(accessToken: accessToken, refreshToken: refreshToken);
  }
}

class AuthException implements Exception {
  const AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

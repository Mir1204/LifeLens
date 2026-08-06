import '../models/app_user.dart';
import 'local_database_service.dart';

class AuthService {
  AuthService({LocalDatabaseService? database})
      : database = database ?? LocalDatabaseService();

  final LocalDatabaseService database;

  Future<AppUser?> currentUser() async {
    return database.signedInUser();
  }

  Future<AppUser> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final user = AppUser(
      userId: _stableUserId(normalizedEmail),
      name: name.trim(),
      email: normalizedEmail,
    );
    await database.upsertUser(
      user: user,
      passwordHash: _passwordHash(password),
      signedIn: true,
    );
    return user;
  }

  Future<AppUser> login({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final row = await database.userByEmail(normalizedEmail);

    if (row == null) {
      throw const AuthException('No account found. Create an account first.');
    }
    if (row['password_hash'] != _passwordHash(password)) {
      throw const AuthException('Email or password is incorrect.');
    }

    final user = AppUser(
      userId: row['user_id'] as String,
      name: row['name'] as String,
      email: row['email'] as String,
    );
    await database.markSignedIn(user.userId);
    return user;
  }

  Future<void> signOut() async {
    await database.signOutAll();
  }

  String _stableUserId(String email) {
    var hash = 0x811c9dc5;
    for (final unit in email.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return 'user_${hash.toRadixString(16).padLeft(8, '0')}';
  }

  String _passwordHash(String password) {
    var hash = 0x811c9dc5;
    for (final unit in password.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

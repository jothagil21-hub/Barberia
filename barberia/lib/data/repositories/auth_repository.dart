import '../../core/security/master_key.dart';
import '../../core/security/password_hasher.dart';
import '../database/database_helper.dart';
import '../database/schema.dart';
import '../models/user.dart';

class AuthRepository {
  AuthRepository({DatabaseHelper? databaseHelper})
      : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _databaseHelper;

  Future<AppUser?> authenticate({
    required String username,
    required String password,
  }) async {
    final db = await _databaseHelper.database;
    final rows = await db.query(
      'users',
      where: 'username = ?',
      whereArgs: [username.trim()],
      limit: 1,
    );

    if (rows.isEmpty) return null;

    final row = rows.first;
    final hash = row['password_hash']! as String;
    if (!PasswordHasher.verify(password, hash)) return null;

    return AppUser.fromMap(row);
  }

  Future<AppUser?> authenticatePanelUser({
    required String username,
    required String password,
  }) async {
    final user = await authenticate(username: username, password: password);
    if (user == null || !user.isPanelUser) return null;
    return user;
  }

  Future<void> upsertPanelUser({
    required String username,
    required String password,
    required String role,
    required String tenantUserId,
  }) async {
    final trimmed = username.trim();
    final db = await _databaseHelper.database;
    final now = DateTime.now().toIso8601String();
    final hash = PasswordHasher.hash(password);

    final existing = await db.query(
      'users',
      where: 'username = ?',
      whereArgs: [trimmed],
      limit: 1,
    );

    if (existing.isEmpty) {
      await db.insert('users', {
        'username': trimmed,
        'password_hash': hash,
        'role': role,
        'created_at': now,
        'password_change_count': 0,
        'tenant_user_id': tenantUserId,
        'auth_source': Schema.authSourcePanel,
      });
      return;
    }

    await db.update(
      'users',
      {
        'password_hash': hash,
        'role': role,
        'tenant_user_id': tenantUserId,
        'auth_source': Schema.authSourcePanel,
      },
      where: 'username = ?',
      whereArgs: [trimmed],
    );
  }

  Future<int> getPasswordChangeCount(int userId) async {
    final db = await _databaseHelper.database;
    final rows = await db.query(
      'users',
      columns: ['password_change_count'],
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );

    if (rows.isEmpty) return 0;
    return rows.first['password_change_count']! as int;
  }

  Future<void> changePassword({
    required int userId,
    required String currentPassword,
    required String newPassword,
    String? masterKey,
  }) async {
    final trimmedNew = newPassword.trim();
    if (trimmedNew.length < 3) {
      throw ArgumentError('La nueva contraseña debe tener al menos 3 caracteres.');
    }

    final db = await _databaseHelper.database;
    final rows = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );

    if (rows.isEmpty) {
      throw StateError('Usuario no encontrado.');
    }

    final row = rows.first;
    if (row['auth_source'] == Schema.authSourcePanel) {
      throw StateError(
        'La contraseña del panel se cambia en el servidor web, no en la app.',
      );
    }

    final hash = row['password_hash']! as String;
    if (!PasswordHasher.verify(currentPassword, hash)) {
      throw const InvalidPasswordException();
    }

    final changeCount = row['password_change_count']! as int;
    if (changeCount >= 1 && !MasterKey.isValid(masterKey)) {
      throw const MasterKeyRequiredException();
    }

    await db.update(
      'users',
      {
        'password_hash': PasswordHasher.hash(trimmedNew),
        'password_change_count': changeCount + 1,
      },
      where: 'id = ?',
      whereArgs: [userId],
    );
  }
}

class InvalidPasswordException implements Exception {
  const InvalidPasswordException();
}

class MasterKeyRequiredException implements Exception {
  const MasterKeyRequiredException();
}

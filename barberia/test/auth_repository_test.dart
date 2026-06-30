import 'package:barberia/core/security/master_key.dart';
import 'package:barberia/core/security/password_hasher.dart';
import 'package:barberia/data/repositories/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/test_database.dart';

void main() {
  late AuthRepository repository;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    final helper = await createTestDatabaseHelper();
    repository = AuthRepository(databaseHelper: helper);
  });

  test('login admin con contraseña correcta', () async {
    final user = await repository.authenticate(
      username: 'admin',
      password: '123',
    );

    expect(user, isNotNull);
    expect(user!.username, 'admin');
    expect(user.role, 'admin');
  });

  test('login rechaza contraseña incorrecta', () async {
    final user = await repository.authenticate(
      username: 'admin',
      password: 'wrong',
    );

    expect(user, isNull);
  });

  test('PasswordHasher no almacena la clave en texto plano', () {
    final hash = PasswordHasher.hash('123');
    expect(hash, isNot('123'));
    expect(PasswordHasher.verify('123', hash), isTrue);
    expect(PasswordHasher.verify('456', hash), isFalse);
  });

  test('primer cambio de contraseña sin clave maestra', () async {
    final user = await repository.authenticate(
      username: 'admin',
      password: '123',
    );
    expect(user, isNotNull);

    await repository.changePassword(
      userId: user!.id,
      currentPassword: '123',
      newPassword: 'abc',
    );

    final updated = await repository.authenticate(
      username: 'admin',
      password: 'abc',
    );
    expect(updated, isNotNull);

    final count = await repository.getPasswordChangeCount(user.id);
    expect(count, 1);
  });

  test('segundo cambio rechaza sin clave maestra', () async {
    final user = await repository.authenticate(
      username: 'admin',
      password: '123',
    );
    expect(user, isNotNull);

    await repository.changePassword(
      userId: user!.id,
      currentPassword: '123',
      newPassword: 'abc',
    );

    expect(
      () => repository.changePassword(
        userId: user.id,
        currentPassword: 'abc',
        newPassword: 'xyz',
      ),
      throwsA(isA<MasterKeyRequiredException>()),
    );
  });

  test('segundo cambio acepta clave maestra válida', () async {
    final user = await repository.authenticate(
      username: 'admin',
      password: '123',
    );
    expect(user, isNotNull);

    await repository.changePassword(
      userId: user!.id,
      currentPassword: '123',
      newPassword: 'abc',
    );

    await repository.changePassword(
      userId: user.id,
      currentPassword: 'abc',
      newPassword: 'xyz',
      masterKey: MasterKey.value,
    );

    final updated = await repository.authenticate(
      username: 'admin',
      password: 'xyz',
    );
    expect(updated, isNotNull);

    final count = await repository.getPasswordChangeCount(user.id);
    expect(count, 2);
  });

  test('changePassword rechaza contraseña actual incorrecta', () async {
    final user = await repository.authenticate(
      username: 'admin',
      password: '123',
    );
    expect(user, isNotNull);

    expect(
      () => repository.changePassword(
        userId: user!.id,
        currentPassword: 'wrong',
        newPassword: 'abc',
      ),
      throwsA(isA<InvalidPasswordException>()),
    );
  });
}

import 'package:barberia/data/repositories/barber_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/test_database.dart';

void main() {
  late BarberRepository repository;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    final helper = await createTestDatabaseHelper();
    repository = BarberRepository(databaseHelper: helper);
  });

  test('getActiveBarbers devuelve barberos seed', () async {
    final barbers = await repository.getActiveBarbers();
    expect(barbers.length, greaterThanOrEqualTo(2));
  });

  test('createBarber agrega barbero activo', () async {
    final id = await repository.createBarber('Carlos');
    final barbers = await repository.getAllBarbers();
    final created = barbers.firstWhere((barber) => barber.id == id);

    expect(created.name, 'Carlos');
    expect(created.isActive, isTrue);
  });

  test('setBarberActive desactiva barbero', () async {
    final barbers = await repository.getActiveBarbers();
    final first = barbers.first;

    await repository.setBarberActive(first.id, false);

    final active = await repository.getActiveBarbers();
    expect(active.any((barber) => barber.id == first.id), isFalse);
  });

  test('updateBarberName cambia el nombre', () async {
    final barbers = await repository.getActiveBarbers();
    final first = barbers.first;

    await repository.updateBarberName(first.id, 'Renombrado');

    final updated = await repository.getAllBarbers();
    final barber = updated.firstWhere((b) => b.id == first.id);
    expect(barber.name, 'Renombrado');
  });
}

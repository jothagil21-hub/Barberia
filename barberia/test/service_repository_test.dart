import 'package:barberia/data/database/schema.dart';
import 'package:barberia/data/repositories/service_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/test_database.dart';

Future<ServiceRepository> _createTestRepository() async {
  final helper = await createTestDatabaseHelper();
  return ServiceRepository(databaseHelper: helper);
}
void main() {
  late ServiceRepository repository;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    repository = await _createTestRepository();
  });

  test('getAllServices devuelve todos los servicios', () async {
    final services = await repository.getAllServices();
    expect(services.length, Schema.defaultServices.length);
  });

  test('setServiceActive desactiva un servicio', () async {
    final services = await repository.getAllServices();
    final first = services.first;

    await repository.setServiceActive(first.id, false);

    final active = await repository.getActiveServices();
    expect(active.any((service) => service.id == first.id), isFalse);
  });

  test('createService agrega servicio activo', () async {
    final id = await repository.createService(
      'Promoción verano',
      price: 25,
      durationMinutes: 30,
    );
    final services = await repository.getAllServices();
    final created = services.firstWhere((service) => service.id == id);

    expect(created.name, 'Promoción verano');
    expect(created.isActive, isTrue);
    expect(created.price, 25);
  });

  test('updateService actualiza precio', () async {
    final id = await repository.createService(
      'Corte promo',
      price: 10,
      durationMinutes: 30,
    );
    await repository.updateService(id, price: 35);

    final service = await repository.getServiceById(id);
    expect(service?.price, 35);
  });

  test('createService rechaza precio negativo', () async {
    expect(
      () => repository.createService(
        'Mal precio',
        price: -1,
        durationMinutes: 30,
      ),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('createService rechaza nombre duplicado', () async {
    await repository.createService(
      'Promo única',
      price: 0,
      durationMinutes: 30,
    );

    expect(
      () => repository.createService(
        'promo única',
        price: 0,
        durationMinutes: 30,
      ),
      throwsA(isA<StateError>()),
    );
  });
}

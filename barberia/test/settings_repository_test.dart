import 'package:barberia/data/database/schema.dart';
import 'package:barberia/data/models/schedule_config.dart';
import 'package:barberia/data/repositories/settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/test_database.dart';

void main() {
  late SettingsRepository repository;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    final helper = await createTestDatabaseHelper();
    repository = SettingsRepository(databaseHelper: helper);
  });

  test('getSettings devuelve valores por defecto', () async {
    final settings = await repository.getSettings();

    expect(settings.shopName, Schema.defaultShopName);
    expect(settings.appDisplayName, Schema.defaultAppDisplayName);
    expect(settings.logoPath, isNull);
    expect(settings.scheduleConfig, ScheduleConfig.defaults());
  });

  test('updateShopName persiste el nuevo nombre', () async {
    await repository.updateShopName('Mi Barbería');
    final settings = await repository.getSettings();

    expect(settings.shopName, 'Mi Barbería');
  });

  test('updateAppDisplayName persiste el nuevo nombre', () async {
    await repository.updateAppDisplayName('Citas Pro');
    final settings = await repository.getSettings();

    expect(settings.appDisplayName, 'Citas Pro');
  });

  test('updateShopName rechaza nombre vacío', () async {
    expect(
      () => repository.updateShopName('   '),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('updateScheduleConfig persiste horario personalizado', () async {
    const config = ScheduleConfig(
      startTime: '08:00',
      endTime: '18:00',
      intervalMinutes: 45,
    );

    await repository.updateScheduleConfig(config);
    final settings = await repository.getSettings();

    expect(settings.scheduleConfig, config);
  });

  test('updateScheduleConfig rechaza inicio posterior al cierre', () async {
    expect(
      () => repository.updateScheduleConfig(
        const ScheduleConfig(
          startTime: '20:00',
          endTime: '09:00',
          intervalMinutes: 30,
        ),
      ),
      throwsA(isA<ArgumentError>()),
    );
  });
}

import 'package:barberia/core/utils/time_slot_generator.dart';
import 'package:barberia/data/models/schedule_config.dart';
import 'package:barberia/data/repositories/schedule_block_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/test_database.dart';

void main() {
  late ScheduleBlockRepository repository;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    final helper = await createTestDatabaseHelper();
    repository = ScheduleBlockRepository(databaseHelper: helper);
  });

  test('bloqueo de día completo devuelve todos los slots', () async {
    await repository.blockFullDay(barberId: 1, date: '2099-06-01');

    final blocked = await repository.getBlockedTimes(
      barberId: 1,
      date: '2099-06-01',
    );

    expect(blocked.length, TimeSlotGenerator.generateAllSlots(ScheduleConfig.defaults()).length);
  });

  test('bloqueo de slot puntual', () async {
    await repository.blockSlots(
      barberId: 1,
      date: '2099-06-02',
      times: ['09:30', '10:00'],
    );

    final blocked = await repository.getBlockedTimes(
      barberId: 1,
      date: '2099-06-02',
    );

    expect(blocked, ['09:30', '10:00']);
  });

  test('desbloquear slot', () async {
    await repository.blockSlots(
      barberId: 1,
      date: '2099-06-03',
      times: ['12:00'],
    );
    await repository.unblockSlot(
      barberId: 1,
      date: '2099-06-03',
      time: '12:00',
    );

    final blocked = await repository.getBlockedTimes(
      barberId: 1,
      date: '2099-06-03',
    );

    expect(blocked, isEmpty);
  });
}

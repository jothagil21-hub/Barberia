import 'package:barberia/data/database/database_helper.dart';
import 'package:barberia/data/repositories/appointment_repository.dart';
import 'package:barberia/data/repositories/schedule_block_repository.dart';
import 'package:barberia/data/repositories/service_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/test_database.dart';

void main() {
  late AppointmentRepository repository;
  late ScheduleBlockRepository blockRepository;
  late DatabaseHelper databaseHelper;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    databaseHelper = await createTestDatabaseHelper();
    blockRepository = ScheduleBlockRepository(databaseHelper: databaseHelper);
    repository = AppointmentRepository(
      databaseHelper: databaseHelper,
      serviceRepository: ServiceRepository(databaseHelper: databaseHelper),
      scheduleBlockRepository: blockRepository,
    );
  });

  Future<int> insertPastAppointment({
    required String date,
    required String time,
    required String clientName,
    int barberId = 1,
  }) async {
    final db = await databaseHelper.database;
    final id = await db.insert('appointments', {
      'client_name': clientName,
      'barber_id': barberId,
      'date': date,
      'time': time,
      'duration_minutes': 30,
      'status': 'scheduled',
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });
    await db.insert('appointment_services', {
      'appointment_id': id,
      'service_id': 1,
      'unit_price': 0,
      'duration_minutes': 30,
    });
    return id;
  }

  test('getBookedTimes excluye la cita indicada por barbero', () async {
    final firstId = await repository.createAppointment(
      clientName: 'Ana',
      barberId: 1,
      date: '2099-06-20',
      time: '09:00',
      serviceIds: [1],
    );
    await repository.createAppointment(
      clientName: 'Luis',
      barberId: 1,
      date: '2099-06-20',
      time: '09:30',
      serviceIds: [1],
    );

    final booked = await repository.getBookedTimes(
      '2099-06-20',
      barberId: 1,
      excludeAppointmentId: firstId,
    );

    expect(booked, ['09:30']);
    expect(booked.contains('09:00'), isFalse);
  });

  test('dos barberos pueden reservar la misma hora', () async {
    await repository.createAppointment(
      clientName: 'Ana',
      barberId: 1,
      date: '2099-06-20',
      time: '09:00',
      serviceIds: [1],
    );

    final secondId = await repository.createAppointment(
      clientName: 'Luis',
      barberId: 2,
      date: '2099-06-20',
      time: '09:00',
      serviceIds: [1],
    );

    expect(secondId, greaterThan(0));
  });

  test('updateAppointment cambia fecha, hora y servicios', () async {
    final id = await repository.createAppointment(
      clientName: 'Carlos',
      barberId: 1,
      date: '2099-06-20',
      time: '10:00',
      serviceIds: [1, 2],
    );

    await repository.updateAppointment(
      id: id,
      barberId: 1,
      date: '2099-06-21',
      time: '11:00',
      serviceIds: [3],
    );

    final updated = await repository.getAppointmentById(id);
    expect(updated?.date, '2099-06-21');
    expect(updated?.time, '11:00');
    expect(updated?.clientName, 'Carlos');

    final serviceIds = await repository.getServiceIdsForAppointment(id);
    expect(serviceIds, [3]);
  });

  test('updateAppointment respeta unicidad de slot activo por barbero', () async {
    await repository.createAppointment(
      clientName: 'Ana',
      barberId: 1,
      date: '2099-06-20',
      time: '09:00',
      serviceIds: [1],
    );
    final secondId = await repository.createAppointment(
      clientName: 'Luis',
      barberId: 1,
      date: '2099-06-20',
      time: '10:00',
      serviceIds: [1],
    );

    expect(
      () => repository.updateAppointment(
        id: secondId,
        barberId: 1,
        date: '2099-06-20',
        time: '09:00',
        serviceIds: [1],
      ),
      throwsA(isA<SlotAlreadyBookedException>()),
    );
  });

  test('getAppointmentsByDate filtra por barbero', () async {
    await repository.createAppointment(
      clientName: 'Ana',
      barberId: 1,
      date: '2099-06-20',
      time: '09:00',
      serviceIds: [1],
    );
    await repository.createAppointment(
      clientName: 'Luis',
      barberId: 2,
      date: '2099-06-20',
      time: '09:00',
      serviceIds: [1],
    );

    final barberOne =
        await repository.getAppointmentsByDate('2099-06-20', barberId: 1);
    final barberTwo =
        await repository.getAppointmentsByDate('2099-06-20', barberId: 2);

    expect(barberOne.length, 1);
    expect(barberOne.first.clientName, 'Ana');
    expect(barberTwo.length, 1);
    expect(barberTwo.first.clientName, 'Luis');
  });

  test('cancelAppointment rechaza citas pasadas', () async {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final date =
        '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

    final id = await insertPastAppointment(
      date: date,
      time: '09:00',
      clientName: 'Ana',
    );

    expect(
      () => repository.cancelAppointment(id),
      throwsA(isA<StateError>()),
    );
  });

  test('updateAppointment rechaza citas pasadas', () async {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final date =
        '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

    final id = await insertPastAppointment(
      date: date,
      time: '10:00',
      clientName: 'Luis',
    );

    expect(
      () => repository.updateAppointment(
        id: id,
        barberId: 1,
        date: date,
        time: '11:00',
        serviceIds: [2],
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('createAppointment rechaza horario pasado de hoy', () async {
    final now = DateTime.now();
    final date =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    expect(
      () => repository.createAppointment(
        clientName: 'Ana',
        barberId: 1,
        date: date,
        time: '09:00',
        serviceIds: [1],
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('getAppointmentsInRange incluye programadas y canceladas', () async {
    await repository.createAppointment(
      clientName: 'Ana',
      barberId: 1,
      date: '2099-06-10',
      time: '09:00',
      serviceIds: [1],
    );
    final canceledId = await repository.createAppointment(
      clientName: 'Luis',
      barberId: 1,
      date: '2099-06-12',
      time: '10:00',
      serviceIds: [1],
    );
    await repository.cancelAppointment(canceledId);

    final results =
        await repository.getAppointmentsInRange('2099-06-01', '2099-06-30');

    expect(results.length, 2);
    expect(results.any((a) => a.isScheduled), isTrue);
    expect(results.any((a) => a.isCanceled), isTrue);
  });

  test('no crea cita en horario bloqueado', () async {
    await blockRepository.blockSlots(
      barberId: 1,
      date: '2099-07-01',
      times: ['11:00'],
    );

    expect(
      () => repository.createAppointment(
        clientName: 'Juan',
        barberId: 1,
        date: '2099-07-01',
        time: '11:00',
        serviceIds: [1],
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('marca asistió y no asistió', () async {
    final attendedId = await insertPastAppointment(
      date: '2020-01-01',
      time: '09:00',
      clientName: 'Asiste',
    );
    final noShowId = await insertPastAppointment(
      date: '2020-01-02',
      time: '10:00',
      clientName: 'NoAsiste',
    );

    await repository.markAttended(attendedId);
    await repository.markNoShow(noShowId);

    final attended = await repository.getAppointmentById(attendedId);
    final noShow = await repository.getAppointmentById(noShowId);

    expect(attended?.isAttended, isTrue);
    expect(noShow?.isNoShow, isTrue);
  });

  test('getAppointmentsByDate solo devuelve programadas', () async {
    final scheduledId = await repository.createAppointment(
      clientName: 'Activa',
      barberId: 1,
      date: '2099-08-01',
      time: '09:00',
      serviceIds: [1],
    );
    await repository.cancelAppointment(scheduledId);
    await insertPastAppointment(
      date: '2099-08-01',
      time: '10:00',
      clientName: 'Pasada',
    );
    final pastId = await insertPastAppointment(
      date: '2020-08-02',
      time: '11:00',
      clientName: 'Marcar',
    );
    await repository.markAttended(pastId);

    final day = await repository.getAppointmentsByDate(
      '2099-08-01',
      barberId: 1,
    );

    expect(day.length, 1);
    expect(day.single.clientName, 'Pasada');
  });

  test('updateClientName actualiza nombre en cita futura programada', () async {
    final id = await repository.createAppointment(
      clientName: 'Carlos',
      barberId: 1,
      date: '2099-09-01',
      time: '09:00',
      serviceIds: [1],
    );

    await repository.updateClientName(id: id, clientName: 'Carlos Actualizado');

    final updated = await repository.getAppointmentById(id);
    expect(updated?.clientName, 'Carlos Actualizado');
  });

  test('updateClientName rechaza citas pasadas', () async {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final date =
        '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

    final id = await insertPastAppointment(
      date: date,
      time: '09:00',
      clientName: 'Ana',
    );

    expect(
      () => repository.updateClientName(id: id, clientName: 'Nuevo'),
      throwsA(isA<StateError>()),
    );
  });

  test('updateClientName rechaza nombre vacío', () async {
    final id = await repository.createAppointment(
      clientName: 'Luis',
      barberId: 1,
      date: '2099-09-02',
      time: '10:00',
      serviceIds: [1],
    );

    expect(
      () => repository.updateClientName(id: id, clientName: '   '),
      throwsA(isA<StateError>()),
    );
  });

  test('reactivateAppointment restaura cita cancelada futura', () async {
    final id = await repository.createAppointment(
      clientName: 'Reactivar',
      barberId: 1,
      date: '2099-09-03',
      time: '11:00',
      serviceIds: [1],
    );
    await repository.cancelAppointment(id);

    await repository.reactivateAppointment(id);

    final reactivated = await repository.getAppointmentById(id);
    expect(reactivated?.isScheduled, isTrue);
    expect(reactivated?.canceledAt, isNull);

    final day = await repository.getAppointmentsByDate(
      '2099-09-03',
      barberId: 1,
    );
    expect(day.any((a) => a.id == id), isTrue);
  });

  test('reactivateAppointment rechaza slot ocupado', () async {
    final canceledId = await repository.createAppointment(
      clientName: 'Cancelada',
      barberId: 1,
      date: '2099-09-04',
      time: '09:00',
      serviceIds: [1],
    );
    await repository.cancelAppointment(canceledId);

    await repository.createAppointment(
      clientName: 'Ocupante',
      barberId: 1,
      date: '2099-09-04',
      time: '09:00',
      serviceIds: [1],
    );

    expect(
      () => repository.reactivateAppointment(canceledId),
      throwsA(isA<SlotAlreadyBookedException>()),
    );
  });

  test('reactivateAppointment rechaza citas canceladas en el pasado', () async {
    final db = await databaseHelper.database;
    final id = await db.insert('appointments', {
      'client_name': 'Pasada',
      'barber_id': 1,
      'date': '2020-01-01',
      'time': '09:00',
      'duration_minutes': 30,
      'status': 'canceled',
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
      'canceled_at': DateTime.now().toIso8601String(),
    });

    expect(
      () => repository.reactivateAppointment(id),
      throwsA(isA<StateError>()),
    );
  });

  test('reactivateAppointment rechaza horario bloqueado', () async {
    final id = await repository.createAppointment(
      clientName: 'Bloqueada',
      barberId: 1,
      date: '2099-09-05',
      time: '14:00',
      serviceIds: [1],
    );
    await repository.cancelAppointment(id);

    await blockRepository.blockSlots(
      barberId: 1,
      date: '2099-09-05',
      times: ['14:00'],
    );

    expect(
      () => repository.reactivateAppointment(id),
      throwsA(isA<StateError>()),
    );
  });
}

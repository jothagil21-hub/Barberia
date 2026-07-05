import 'package:intl/intl.dart';

import '../../core/constants/appointment_status.dart';
import '../../core/constants/service_duration_constants.dart';
import '../../core/sync/sync_service.dart';
import '../../core/sync/sync_tracker.dart';
import '../../core/utils/appointment_slot_utils.dart';
import '../database/database_helper.dart';
import '../database/schema.dart';
import '../models/appointment.dart';
import 'pos_invoice_repository.dart';
import 'schedule_block_repository.dart';
import 'service_repository.dart';

class AppointmentRepository {
  AppointmentRepository({
    DatabaseHelper? databaseHelper,
    ServiceRepository? serviceRepository,
    ScheduleBlockRepository? scheduleBlockRepository,
    PosInvoiceRepository? posInvoiceRepository,
  })  : _databaseHelper = databaseHelper ?? DatabaseHelper.instance,
        _serviceRepository = serviceRepository ?? ServiceRepository(),
        _scheduleBlockRepository =
            scheduleBlockRepository ?? ScheduleBlockRepository(),
        _posInvoiceRepository = posInvoiceRepository ?? PosInvoiceRepository();

  final DatabaseHelper _databaseHelper;
  final ServiceRepository _serviceRepository;
  final ScheduleBlockRepository _scheduleBlockRepository;
  final PosInvoiceRepository _posInvoiceRepository;

  static const String _appointmentSelect = '''
    SELECT a.id,
           a.client_name,
           a.barber_id,
           b.name AS barber_name,
           a.date,
           a.time,
           a.duration_minutes,
           a.status,
           a.created_at,
           a.canceled_at,
           GROUP_CONCAT(s.name, ', ') AS services,
           COALESCE(SUM(aps.unit_price), 0) AS total_price
    FROM appointments a
    LEFT JOIN barbers b ON a.barber_id = b.id
    LEFT JOIN appointment_services aps ON a.id = aps.appointment_id
    LEFT JOIN services s ON aps.service_id = s.id
  ''';

  Future<List<Appointment>> getAppointmentsByDate(
    String date, {
    required int barberId,
  }) async {
    final db = await _databaseHelper.database;
    final rows = await db.rawQuery(
      '''
      $_appointmentSelect
      WHERE a.date = ? AND a.status = ? AND a.barber_id = ?
      GROUP BY a.id
      ORDER BY a.time ASC
      ''',
      [date, AppointmentStatus.scheduled.value, barberId],
    );

    return rows.map(Appointment.fromMap).toList();
  }

  Future<List<String>> getOccupiedSlots(
    String date, {
    required int barberId,
    int? excludeAppointmentId,
  }) async {
    final db = await _databaseHelper.database;
    final rows = excludeAppointmentId == null
        ? await db.query(
            'appointments',
            columns: ['time', 'duration_minutes'],
            where: 'date = ? AND status = ? AND barber_id = ?',
            whereArgs: [
              date,
              AppointmentStatus.scheduled.value,
              barberId,
            ],
          )
        : await db.query(
            'appointments',
            columns: ['time', 'duration_minutes'],
            where: 'date = ? AND status = ? AND barber_id = ? AND id != ?',
            whereArgs: [
              date,
              AppointmentStatus.scheduled.value,
              barberId,
              excludeAppointmentId,
            ],
          );

    final occupied = AppointmentSlotUtils.occupiedFromAppointments(
      rows.map(
        (row) => (
          time: row['time']! as String,
          durationMinutes: row['duration_minutes'] as int? ??
              ServiceDurationConstants.defaultMinutes,
        ),
      ),
    );
    final list = occupied.toList()..sort();
    return list;
  }

  @Deprecated('Use getOccupiedSlots')
  Future<List<String>> getBookedTimes(
    String date, {
    required int barberId,
    int? excludeAppointmentId,
  }) =>
      getOccupiedSlots(
        date,
        barberId: barberId,
        excludeAppointmentId: excludeAppointmentId,
      );

  Future<List<int>> getServiceIdsForAppointment(int id) async {
    final db = await _databaseHelper.database;
    final rows = await db.query(
      'appointment_services',
      columns: ['service_id'],
      where: 'appointment_id = ?',
      whereArgs: [id],
    );

    return rows.map((row) => row['service_id']! as int).toList();
  }

  Future<List<Appointment>> getCanceledAppointments({
    String? date,
    int? barberId,
  }) async {
    final db = await _databaseHelper.database;
    final barberClause = barberId == null ? '' : ' AND a.barber_id = ?';
    final args = barberId == null
        ? (date == null
            ? [AppointmentStatus.canceled.value]
            : [AppointmentStatus.canceled.value, date])
        : (date == null
            ? [AppointmentStatus.canceled.value, barberId]
            : [AppointmentStatus.canceled.value, date, barberId]);

    final rows = date == null
        ? await db.rawQuery(
            '''
            $_appointmentSelect
            WHERE a.status = ?$barberClause
            GROUP BY a.id
            ORDER BY a.canceled_at DESC
            ''',
            args,
          )
        : await db.rawQuery(
            '''
            $_appointmentSelect
            WHERE a.status = ? AND a.date = ?$barberClause
            GROUP BY a.id
            ORDER BY a.canceled_at DESC
            ''',
            args,
          );

    return rows.map(Appointment.fromMap).toList();
  }

  Future<Appointment?> getAppointmentById(int id) async {
    final db = await _databaseHelper.database;
    final rows = await db.rawQuery(
      '''
      $_appointmentSelect
      WHERE a.id = ?
      GROUP BY a.id
      ''',
      [id],
    );

    if (rows.isEmpty) return null;
    return Appointment.fromMap(rows.first);
  }

  Future<List<Appointment>> getUpcomingScheduledAppointments() async {
    final now = DateTime.now();
    final today = DateFormat('yyyy-MM-dd').format(now);
    final currentTime = DateFormat('HH:mm').format(now);

    final db = await _databaseHelper.database;
    final rows = await db.rawQuery(
      '''
      $_appointmentSelect
      WHERE a.status = ?
        AND (a.date > ? OR (a.date = ? AND a.time >= ?))
      GROUP BY a.id
      ORDER BY a.date ASC, a.time ASC
      ''',
      [
        AppointmentStatus.scheduled.value,
        today,
        today,
        currentTime,
      ],
    );

    return rows.map(Appointment.fromMap).toList();
  }

  Future<List<Appointment>> getAppointmentsInRange(
    String startDate,
    String endDate,
  ) async {
    final db = await _databaseHelper.database;
    final rows = await db.rawQuery(
      '''
      $_appointmentSelect
      WHERE a.date BETWEEN ? AND ?
      GROUP BY a.id
      ORDER BY a.date ASC, a.time ASC
      ''',
      [startDate, endDate],
    );

    return rows.map(Appointment.fromMap).toList();
  }

  Future<int> createAppointment({
    required String clientName,
    required int barberId,
    required String date,
    required String time,
    required List<int> serviceIds,
  }) async {
    if (serviceIds.isEmpty) {
      throw ArgumentError('Selecciona al menos un servicio.');
    }

    final durationMinutes =
        await _serviceRepository.totalDurationForServiceIds(serviceIds);
    final prices = await _serviceRepository.getPricesByIds(serviceIds);
    final durations = await _serviceRepository.getDurationsByIds(serviceIds);

    _ensureNotPastSlot(date: date, time: time);
    await _ensureRangeNotBlocked(
      barberId: barberId,
      date: date,
      time: time,
      durationMinutes: durationMinutes,
    );
    await _ensureNoOverlap(
      barberId: barberId,
      date: date,
      time: time,
      durationMinutes: durationMinutes,
    );

    final db = await _databaseHelper.database;

    final appointmentId = await db.transaction<int>((txn) async {
      final id = await txn.insert('appointments', {
        'client_name': clientName.trim(),
        'barber_id': barberId,
        'date': date,
        'time': time,
        'duration_minutes': durationMinutes,
        'status': AppointmentStatus.scheduled.value,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'sync_status': Schema.syncStatusPending,
      });

      for (final serviceId in serviceIds) {
        await txn.insert('appointment_services', {
          'appointment_id': id,
          'service_id': serviceId,
          'unit_price': prices[serviceId] ?? 0,
          'duration_minutes':
              durations[serviceId] ?? ServiceDurationConstants.defaultMinutes,
        });
      }

      return id;
    });
    await _afterAppointmentChange(appointmentId);
    return appointmentId;
  }

  Future<void> updateAppointment({
    required int id,
    required int barberId,
    required String date,
    required String time,
    required List<int> serviceIds,
  }) async {
    if (serviceIds.isEmpty) {
      throw ArgumentError('Selecciona al menos un servicio.');
    }

    await _ensureModifiable(id);

    final durationMinutes =
        await _serviceRepository.totalDurationForServiceIds(serviceIds);
    final prices = await _serviceRepository.getPricesByIds(serviceIds);
    final durations = await _serviceRepository.getDurationsByIds(serviceIds);

    _ensureNotPastSlot(date: date, time: time);
    await _ensureRangeNotBlocked(
      barberId: barberId,
      date: date,
      time: time,
      durationMinutes: durationMinutes,
    );
    await _ensureNoOverlap(
      barberId: barberId,
      date: date,
      time: time,
      durationMinutes: durationMinutes,
      excludeAppointmentId: id,
    );

    final db = await _databaseHelper.database;

    await db.transaction((txn) async {
      final updated = await txn.update(
        'appointments',
        {
          'barber_id': barberId,
          'date': date,
          'time': time,
          'duration_minutes': durationMinutes,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ? AND status = ?',
        whereArgs: [id, AppointmentStatus.scheduled.value],
      );

      if (updated == 0) {
        throw StateError('No se pudo reagendar la cita.');
      }

      await txn.delete(
        'appointment_services',
        where: 'appointment_id = ?',
        whereArgs: [id],
      );

      for (final serviceId in serviceIds) {
        await txn.insert('appointment_services', {
          'appointment_id': id,
          'service_id': serviceId,
          'unit_price': prices[serviceId] ?? 0,
          'duration_minutes':
              durations[serviceId] ?? ServiceDurationConstants.defaultMinutes,
        });
      }
    });
    await _afterAppointmentChange(id);
  }

  Future<void> updateClientName({
    required int id,
    required String clientName,
  }) async {
    await _ensureModifiable(id);

    final trimmed = clientName.trim();
    if (trimmed.isEmpty) {
      throw StateError('El nombre no puede estar vacío.');
    }

    final db = await _databaseHelper.database;
    final updated = await db.update(
      'appointments',
      {
        'client_name': trimmed,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ? AND status = ?',
      whereArgs: [id, AppointmentStatus.scheduled.value],
    );

    if (updated == 0) {
      throw StateError('No se pudo actualizar el nombre.');
    }
    await _afterAppointmentChange(id);
  }

  Future<void> reactivateAppointment(int id) async {
    final appointment = await getAppointmentById(id);
    if (appointment == null || !appointment.isCanceled) {
      throw StateError('Solo se pueden reactivar citas canceladas.');
    }

    _ensureNotPastSlot(date: appointment.date, time: appointment.time);
    await _ensureRangeNotBlocked(
      barberId: appointment.barberId,
      date: appointment.date,
      time: appointment.time,
      durationMinutes: appointment.durationMinutes,
    );
    await _ensureNoOverlap(
      barberId: appointment.barberId,
      date: appointment.date,
      time: appointment.time,
      durationMinutes: appointment.durationMinutes,
      excludeAppointmentId: id,
    );

    final db = await _databaseHelper.database;

    final updated = await db.update(
      'appointments',
      {
        'status': AppointmentStatus.scheduled.value,
        'canceled_at': null,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ? AND status = ?',
      whereArgs: [id, AppointmentStatus.canceled.value],
    );

    if (updated == 0) {
      throw StateError('No se pudo reactivar la cita.');
    }
    await _afterAppointmentChange(id);
  }

  Future<void> cancelAppointment(int id) async {
    await _ensureModifiable(id);

    final db = await _databaseHelper.database;
    final updated = await db.update(
      'appointments',
      {
        'status': AppointmentStatus.canceled.value,
        'canceled_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ? AND status = ?',
      whereArgs: [id, AppointmentStatus.scheduled.value],
    );

    if (updated == 0) {
      throw StateError('No se pudo cancelar la cita.');
    }
    await _afterAppointmentChange(id);
  }

  Future<void> markAttended(int id, {bool createInvoice = true}) async {
    await _updateAttendanceStatus(id, AppointmentStatus.attended);
    if (createInvoice) {
      await _posInvoiceRepository.createForAppointment(id);
    }
  }

  Future<void> markNoShow(int id) async {
    await _updateAttendanceStatus(id, AppointmentStatus.noShow);
  }

  Future<void> _updateAttendanceStatus(
    int id,
    AppointmentStatus status,
  ) async {
    final appointment = await getAppointmentById(id);
    if (appointment == null || !appointment.canMarkAttendanceAt(DateTime.now())) {
      throw StateError('No se puede registrar asistencia para esta cita.');
    }

    final db = await _databaseHelper.database;
    final updated = await db.update(
      'appointments',
      {
        'status': status.value,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ? AND status = ?',
      whereArgs: [id, AppointmentStatus.scheduled.value],
    );

    if (updated == 0) {
      throw StateError('No se pudo actualizar el estado de la cita.');
    }
    await _afterAppointmentChange(id);
  }

  Future<void> _afterAppointmentChange(int id) async {
    await SyncTracker.markAppointment(id);
    await SyncCoordinator.instance.afterMutation();
  }

  Future<void> _ensureRangeNotBlocked({
    required int barberId,
    required String date,
    required String time,
    required int durationMinutes,
  }) async {
    final blocked = await _scheduleBlockRepository.getBlockedTimes(
      barberId: barberId,
      date: date,
    );
    final blockedSet = blocked.toSet();
    final slots = AppointmentSlotUtils.expandOccupiedSlots(
      startTime: time,
      durationMinutes: durationMinutes,
    );

    if (slots.any(blockedSet.contains)) {
      throw StateError('Ese horario está bloqueado para este barbero.');
    }
  }

  Future<void> _ensureNoOverlap({
    required int barberId,
    required String date,
    required String time,
    required int durationMinutes,
    int? excludeAppointmentId,
  }) async {
    final db = await _databaseHelper.database;
    final rows = excludeAppointmentId == null
        ? await db.query(
            'appointments',
            columns: ['time', 'duration_minutes'],
            where: 'date = ? AND status = ? AND barber_id = ?',
            whereArgs: [date, AppointmentStatus.scheduled.value, barberId],
          )
        : await db.query(
            'appointments',
            columns: ['time', 'duration_minutes'],
            where: 'date = ? AND status = ? AND barber_id = ? AND id != ?',
            whereArgs: [
              date,
              AppointmentStatus.scheduled.value,
              barberId,
              excludeAppointmentId,
            ],
          );

    for (final row in rows) {
      final otherTime = row['time']! as String;
      final otherDuration = row['duration_minutes'] as int? ??
          ServiceDurationConstants.defaultMinutes;
      if (AppointmentSlotUtils.rangesOverlap(
        startA: time,
        durationA: durationMinutes,
        startB: otherTime,
        durationB: otherDuration,
      )) {
        throw const SlotAlreadyBookedException();
      }
    }
  }

  void _ensureNotPastSlot({required String date, required String time}) {
    final parts = time.split(':');
    final day = DateTime.parse(date);
    final slotDateTime = DateTime(
      day.year,
      day.month,
      day.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );

    if (slotDateTime.isBefore(DateTime.now())) {
      throw StateError('No se puede agendar en un horario pasado.');
    }
  }

  Future<void> _ensureModifiable(int id) async {
    final appointment = await getAppointmentById(id);
    if (appointment == null || !appointment.canModify) {
      throw StateError('Esta cita ya pasó y no puede modificarse.');
    }
  }
}

class SlotAlreadyBookedException implements Exception {
  const SlotAlreadyBookedException();

  @override
  String toString() => 'Ese horario ya está reservado.';
}

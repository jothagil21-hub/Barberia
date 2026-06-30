import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../core/sync/sync_service.dart';
import '../../core/sync/sync_tracker.dart';
import '../database/database_helper.dart';
import '../database/schema.dart';
import '../models/pos_invoice.dart';

class PosInvoiceRepository {
  PosInvoiceRepository({DatabaseHelper? databaseHelper})
      : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _databaseHelper;

  Future<PosInvoice?> getByAppointmentId(int appointmentId) async {
    final db = await _databaseHelper.database;
    final rows = await db.query(
      'pos_invoices',
      where: 'appointment_id = ?',
      whereArgs: [appointmentId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return PosInvoice.fromMap(rows.first);
  }

  Future<bool> existsForAppointment(int appointmentId) async {
    return (await getByAppointmentId(appointmentId)) != null;
  }

  Future<int> createForAppointment(int appointmentId) async {
    final existing = await getByAppointmentId(appointmentId);
    if (existing != null) return existing.id;

    final db = await _databaseHelper.database;
    final appointmentRows = await db.rawQuery(
      '''
      SELECT a.client_name, a.barber_id, b.name AS barber_name
      FROM appointments a
      LEFT JOIN barbers b ON b.id = a.barber_id
      WHERE a.id = ?
      ''',
      [appointmentId],
    );
    if (appointmentRows.isEmpty) {
      throw StateError('Cita no encontrada.');
    }

    final appointment = appointmentRows.first;
    final lineRows = await db.rawQuery(
      '''
      SELECT s.name, aps.unit_price, aps.duration_minutes
      FROM appointment_services aps
      JOIN services s ON s.id = aps.service_id
      WHERE aps.appointment_id = ?
      ORDER BY s.name ASC
      ''',
      [appointmentId],
    );

    final lines = lineRows
        .map(
          (row) => PosInvoiceLine(
            serviceName: row['name']! as String,
            durationMinutes: row['duration_minutes']! as int,
            unitPrice: (row['unit_price'] as num).toDouble(),
            lineTotal: (row['unit_price'] as num).toDouble(),
          ),
        )
        .toList();
    final subtotal = lines.fold<double>(0, (sum, line) => sum + line.lineTotal);
    final number = await _nextLocalNumber(db);
    final now = DateTime.now().toIso8601String();

    final id = await db.insert('pos_invoices', {
      'appointment_id': appointmentId,
      'number': number,
      'issued_at': now,
      'client_name': appointment['client_name'],
      'barber_name': appointment['barber_name'],
      'subtotal': subtotal,
      'lines_json': jsonEncode(lines.map((l) => l.toJson()).toList()),
      'updated_at': now,
      'sync_status': Schema.syncStatusPending,
    });

    await SyncTracker.markPosInvoice(id);
    await SyncCoordinator.instance.afterMutation();
    return id;
  }

  Future<int> _nextLocalNumber(Database db) async {
    final rows = await db.rawQuery('SELECT MAX(number) AS max_num FROM pos_invoices');
    final maxNum = rows.first['max_num'] as int? ?? 0;
    return maxNum + 1;
  }
}

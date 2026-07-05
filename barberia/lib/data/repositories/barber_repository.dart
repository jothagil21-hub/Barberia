import 'package:sqflite/sqflite.dart';

import '../../core/sync/sync_service.dart';
import '../../core/sync/sync_tracker.dart';
import '../database/database_helper.dart';
import '../database/schema.dart';
import '../models/barber.dart';

class BarberRepository {
  BarberRepository({DatabaseHelper? databaseHelper})
      : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _databaseHelper;

  Future<List<Barber>> getActiveBarbers() async {
    final db = await _databaseHelper.database;
    final rows = await db.query(
      'barbers',
      where: 'is_active = ?',
      whereArgs: [1],
      orderBy: 'name ASC',
    );

    return rows.map(Barber.fromMap).toList();
  }

  Future<List<Barber>> getAllBarbers() async {
    final db = await _databaseHelper.database;
    final rows = await db.query('barbers', orderBy: 'name ASC');
    return rows.map(Barber.fromMap).toList();
  }

  Future<int?> findLocalIdByServerId(String serverId) async {
    final db = await _databaseHelper.database;
    final rows = await db.query(
      'barbers',
      columns: ['id'],
      where: 'server_id = ?',
      whereArgs: [serverId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['id'] as int;
  }

  Future<int> createBarber(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('El nombre del barbero no puede estar vacío.');
    }

    final db = await _databaseHelper.database;
    final now = DateTime.now().toIso8601String();
    try {
      final id = await db.insert('barbers', {
        'name': trimmed,
        'is_active': 1,
        'updated_at': now,
        'sync_status': Schema.syncStatusSynced,
      });
      await SyncTracker.markBarber(id);
      await SyncCoordinator.instance.afterMutation();
      return id;
    } on DatabaseException catch (error) {
      if (error.isUniqueConstraintError()) {
        throw StateError('Ya existe un barbero con ese nombre.');
      }
      rethrow;
    }
  }

  Future<void> setBarberActive(int id, bool active) async {
    final db = await _databaseHelper.database;
    await db.update(
      'barbers',
      {
        'is_active': active ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    await SyncTracker.markBarber(id);
    await SyncCoordinator.instance.afterMutation();
  }

  Future<void> updateBarberName(int id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('El nombre del barbero no puede estar vacío.');
    }

    final db = await _databaseHelper.database;
    final updated = await db.update(
      'barbers',
      {'name': trimmed, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );

    if (updated == 0) {
      throw StateError('Barbero no encontrado.');
    }
    await SyncTracker.markBarber(id);
    await SyncCoordinator.instance.afterMutation();
  }
}

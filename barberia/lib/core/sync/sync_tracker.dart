import 'package:sqflite/sqflite.dart';

import '../../data/database/database_helper.dart';
import '../../data/database/schema.dart';

/// Marca entidades locales como pendientes de sync y encola reintento.
class SyncTracker {
  SyncTracker._();

  static Future<void> markBarber(int id) => _mark('barber', id);
  static Future<void> markService(int id) => _mark('service', id);
  static Future<void> markAppointment(int id) => _mark('appointment', id);
  static Future<void> markBlock(int id) => _mark('block', id);
  static Future<void> markPosInvoice(int id) => _mark('posInvoice', id);
  static Future<void> markSettings() => _mark('settings', 0);

  static String clientId(String entity, int localId) => 'local-$entity-$localId';

  static Future<void> _mark(String entityType, int localId) async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now().toIso8601String();
    final table = _tableFor(entityType);
    if (table != null && localId > 0) {
      await db.update(
        table,
        {'sync_status': Schema.syncStatusPending, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [localId],
      );
    } else if (entityType == 'settings') {
      await db.insert(
        'schema_meta',
        {'key': Schema.metaSettingsUpdatedAt, 'value': now},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await db.insert('sync_queue', {
      'entity_type': entityType,
      'entity_local_id': localId,
      'operation': 'upsert',
      'created_at': now,
    });
  }

  static String? _tableFor(String entityType) {
    switch (entityType) {
      case 'barber':
        return 'barbers';
      case 'service':
        return 'services';
      case 'appointment':
        return 'appointments';
      case 'block':
        return 'barber_schedule_blocks';
      case 'posInvoice':
        return 'pos_invoices';
      default:
        return null;
    }
  }

  static Future<void> clearQueueFor(String entityType, int localId) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete(
      'sync_queue',
      where: 'entity_type = ? AND entity_local_id = ?',
      whereArgs: [entityType, localId],
    );
  }

  static Future<bool> hasPending() async {
    final db = await DatabaseHelper.instance.database;
    const pending = Schema.syncStatusPending;

    for (final table in [
      'barbers',
      'services',
      'appointments',
      'barber_schedule_blocks',
      'pos_invoices',
    ]) {
      final rows = await db.query(
        table,
        columns: ['id'],
        where: 'sync_status = ?',
        whereArgs: [pending],
        limit: 1,
      );
      if (rows.isNotEmpty) return true;
    }

    final settingsRows = await db.query(
      'sync_queue',
      columns: ['id'],
      where: "entity_type = 'settings'",
      limit: 1,
    );
    if (settingsRows.isNotEmpty) return true;

    final orphanAppointments = await db.query(
      'appointments',
      columns: ['id'],
      where: "sync_status = ? AND (server_id IS NULL OR server_id = '')",
      whereArgs: [Schema.syncStatusSynced],
      limit: 1,
    );
    return orphanAppointments.isNotEmpty;
  }

  static Future<bool> hasOrphanSyncedAppointments() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'appointments',
      columns: ['id'],
      where: "sync_status = ? AND (server_id IS NULL OR server_id = '')",
      whereArgs: [Schema.syncStatusSynced],
      limit: 1,
    );
    return rows.isNotEmpty;
  }
}

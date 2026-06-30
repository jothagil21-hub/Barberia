import '../../core/constants/service_duration_constants.dart';
import '../../core/sync/sync_service.dart';
import '../../core/sync/sync_tracker.dart';
import '../database/database_helper.dart';
import '../database/schema.dart';
import '../models/service.dart';

class ServiceRepository {
  ServiceRepository({DatabaseHelper? databaseHelper})
      : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _databaseHelper;

  Future<List<BarberService>> getActiveServices() async {
    final db = await _databaseHelper.database;
    final rows = await db.query(
      'services',
      where: 'is_active = ?',
      whereArgs: [1],
      orderBy: 'name ASC',
    );

    return rows.map(BarberService.fromMap).toList();
  }

  Future<List<BarberService>> getAllServices() async {
    final db = await _databaseHelper.database;
    final rows = await db.query(
      'services',
      orderBy: 'name ASC',
    );

    return rows.map(BarberService.fromMap).toList();
  }

  Future<BarberService?> getServiceById(int id) async {
    final db = await _databaseHelper.database;
    final rows = await db.query(
      'services',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return BarberService.fromMap(rows.first);
  }

  Future<Map<int, double>> getPricesByIds(Iterable<int> ids) async {
    if (ids.isEmpty) return {};

    final db = await _databaseHelper.database;
    final placeholders = List.filled(ids.length, '?').join(', ');
    final rows = await db.rawQuery(
      'SELECT id, price FROM services WHERE id IN ($placeholders)',
      ids.toList(),
    );

    return {
      for (final row in rows)
        row['id']! as int: (row['price'] as num).toDouble(),
    };
  }

  Future<Map<int, int>> getDurationsByIds(Iterable<int> ids) async {
    if (ids.isEmpty) return {};

    final db = await _databaseHelper.database;
    final placeholders = List.filled(ids.length, '?').join(', ');
    final rows = await db.rawQuery(
      'SELECT id, duration_minutes FROM services WHERE id IN ($placeholders)',
      ids.toList(),
    );

    return {
      for (final row in rows)
        row['id']! as int: row['duration_minutes']! as int,
    };
  }

  Future<int> totalDurationForServiceIds(Iterable<int> ids) async {
    final durations = await getDurationsByIds(ids);
    return ServiceDurationConstants.sum(durations.values);
  }

  Future<void> setServiceActive(int id, bool active) async {
    final db = await _databaseHelper.database;
    final updated = await db.update(
      'services',
      {
        'is_active': active ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );

    if (updated == 0) {
      throw StateError('Servicio no encontrado.');
    }
    await SyncTracker.markService(id);
    await SyncCoordinator.instance.afterMutation();
  }

  Future<int> createService(
    String name, {
    required double price,
    required int durationMinutes,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('El nombre del servicio no puede estar vacío.');
    }
    _ensureValidPrice(price);
    ServiceDurationConstants.validate(durationMinutes);

    final db = await _databaseHelper.database;
    final existing = await db.query(
      'services',
      where: 'LOWER(name) = ?',
      whereArgs: [trimmed.toLowerCase()],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      throw StateError('Ya existe un servicio con ese nombre.');
    }

    return db.insert('services', {
      'name': trimmed,
      'price': price,
      'duration_minutes': durationMinutes,
      'is_active': 1,
      'updated_at': DateTime.now().toIso8601String(),
      'sync_status': Schema.syncStatusSynced,
    }).then((id) async {
      await SyncTracker.markService(id);
      await SyncCoordinator.instance.afterMutation();
      return id;
    });
  }

  Future<void> updateService(
    int id, {
    String? name,
    double? price,
    int? durationMinutes,
  }) async {
    final updates = <String, Object?>{};

    if (name != null) {
      final trimmed = name.trim();
      if (trimmed.isEmpty) {
        throw ArgumentError('El nombre del servicio no puede estar vacío.');
      }
      updates['name'] = trimmed;
    }

    if (price != null) {
      _ensureValidPrice(price);
      updates['price'] = price;
    }

    if (durationMinutes != null) {
      ServiceDurationConstants.validate(durationMinutes);
      updates['duration_minutes'] = durationMinutes;
    }

    if (updates.isEmpty) return;
    updates['updated_at'] = DateTime.now().toIso8601String();

    final db = await _databaseHelper.database;
    final updated = await db.update(
      'services',
      updates,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (updated == 0) {
      throw StateError('Servicio no encontrado.');
    }
    await SyncTracker.markService(id);
    await SyncCoordinator.instance.afterMutation();
  }

  void _ensureValidPrice(double price) {
    if (price < 0) {
      throw ArgumentError('El precio no puede ser negativo.');
    }
  }
}

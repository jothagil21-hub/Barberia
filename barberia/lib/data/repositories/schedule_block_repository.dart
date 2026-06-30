import 'package:sqflite/sqflite.dart';

import '../../core/utils/time_slot_generator.dart';
import '../../core/sync/sync_service.dart';
import '../../core/sync/sync_tracker.dart';
import '../database/database_helper.dart';
import '../database/schema.dart';
import '../models/schedule_block.dart';
import '../models/schedule_config.dart';

class ScheduleBlockRepository {
  ScheduleBlockRepository({
    DatabaseHelper? databaseHelper,
    ScheduleConfig Function()? configProvider,
  })  : _databaseHelper = databaseHelper ?? DatabaseHelper.instance,
        _configProvider = configProvider ?? ScheduleConfig.defaults;

  final DatabaseHelper _databaseHelper;
  final ScheduleConfig Function() _configProvider;

  ScheduleConfig get _config => _configProvider();

  Future<List<ScheduleBlock>> getBlocksForDate({
    required int barberId,
    required String date,
  }) async {
    final db = await _databaseHelper.database;
    final rows = await db.query(
      'barber_schedule_blocks',
      where: 'barber_id = ? AND date = ?',
      whereArgs: [barberId, date],
      orderBy: 'is_full_day DESC, time ASC',
    );

    return rows.map(ScheduleBlock.fromMap).toList();
  }

  Future<List<String>> getBlockedTimes({
    required int barberId,
    required String date,
  }) async {
    final blocks = await getBlocksForDate(barberId: barberId, date: date);
    if (blocks.any((block) => block.isFullDay)) {
      return TimeSlotGenerator.generateAllSlots(_config);
    }

    return blocks
        .where((block) => !block.isFullDay && block.time != null)
        .map((block) => block.time!)
        .toList();
  }

  Future<bool> isSlotBlocked({
    required int barberId,
    required String date,
    required String time,
  }) async {
    final blocked = await getBlockedTimes(barberId: barberId, date: date);
    return blocked.contains(time);
  }

  Future<void> blockFullDay({
    required int barberId,
    required String date,
  }) async {
    _ensureValidSlotTime(null);
    final db = await _databaseHelper.database;

    await db.transaction((txn) async {
      await txn.delete(
        'barber_schedule_blocks',
        where: 'barber_id = ? AND date = ?',
        whereArgs: [barberId, date],
      );

      await txn.insert('barber_schedule_blocks', {
        'barber_id': barberId,
        'date': date,
        'time': null,
        'is_full_day': 1,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'sync_status': Schema.syncStatusSynced,
      });
    });
    final blocks = await getBlocksForDate(barberId: barberId, date: date);
    for (final block in blocks.where((b) => b.isFullDay)) {
      await SyncTracker.markBlock(block.id);
    }
    await SyncCoordinator.instance.afterMutation();
  }

  Future<void> unblockFullDay({
    required int barberId,
    required String date,
  }) async {
    final db = await _databaseHelper.database;
    await db.delete(
      'barber_schedule_blocks',
      where: 'barber_id = ? AND date = ? AND is_full_day = 1',
      whereArgs: [barberId, date],
    );
  }

  Future<void> blockSlots({
    required int barberId,
    required String date,
    required List<String> times,
  }) async {
    if (times.isEmpty) return;

    for (final time in times) {
      _ensureValidSlotTime(time);
    }

    final db = await _databaseHelper.database;
    final fullDay = await db.query(
      'barber_schedule_blocks',
      where: 'barber_id = ? AND date = ? AND is_full_day = 1',
      whereArgs: [barberId, date],
      limit: 1,
    );

    if (fullDay.isNotEmpty) {
      throw StateError('El día completo ya está bloqueado.');
    }

    await db.transaction((txn) async {
      for (final time in times) {
        await txn.insert(
          'barber_schedule_blocks',
          {
            'barber_id': barberId,
            'date': date,
            'time': time,
            'is_full_day': 0,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
            'sync_status': Schema.syncStatusSynced,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    });
    final blocks = await getBlocksForDate(barberId: barberId, date: date);
    for (final block in blocks.where((b) => !b.isFullDay && times.contains(b.time))) {
      await SyncTracker.markBlock(block.id);
    }
    await SyncCoordinator.instance.afterMutation();
  }

  Future<void> unblockSlot({
    required int barberId,
    required String date,
    required String time,
  }) async {
    final db = await _databaseHelper.database;
    await db.delete(
      'barber_schedule_blocks',
      where: 'barber_id = ? AND date = ? AND is_full_day = 0 AND time = ?',
      whereArgs: [barberId, date, time],
    );
  }

  void _ensureValidSlotTime(String? time) {
    if (time == null) return;
    if (!TimeSlotGenerator.generateAllSlots(_config).contains(time)) {
      throw ArgumentError('Horario fuera del rango permitido.');
    }
  }
}

import 'package:sqflite/sqflite.dart';

import '../../core/constants/schedule_constants.dart';
import '../../core/security/password_hasher.dart';
import 'schema.dart';

class DatabaseSeeder {
  static Future<void> seedCoreData(Database db) async {
    final now = DateTime.now().toIso8601String();
    for (final name in Schema.defaultServices) {
      await db.insert('services', {
        'name': name,
        'duration_minutes': 30,
        'is_active': 1,
        'updated_at': now,
        'sync_status': Schema.syncStatusSynced,
      });
    }

    for (final name in Schema.defaultBarbers) {
      await db.insert('barbers', {
        'name': name,
        'is_active': 1,
        'updated_at': now,
        'sync_status': Schema.syncStatusSynced,
      });
    }

    await db.insert('users', {
      'username': Schema.defaultAdminUsername,
      'password_hash': PasswordHasher.hash(Schema.defaultAdminPassword),
      'role': Schema.defaultAdminRole,
      'created_at': DateTime.now().toIso8601String(),
      'password_change_count': 0,
    });

    await seedAppSettings(db);
  }

  static Future<void> seedAppSettings(Database db) async {
    await db.insert('app_settings', {
      'key': Schema.settingShopName,
      'value': Schema.defaultShopName,
    });
    await db.insert('app_settings', {
      'key': Schema.settingLogoPath,
      'value': '',
    });
    await db.insert('app_settings', {
      'key': Schema.settingLogoServerUrl,
      'value': '',
    });
    await db.insert('app_settings', {
      'key': Schema.settingAppDisplayName,
      'value': Schema.defaultAppDisplayName,
    });
    await seedScheduleSettings(db);
  }

  static Future<void> seedScheduleSettings(Database db) async {
    final defaults = [
      (Schema.settingScheduleStart, ScheduleConstants.startTime),
      (Schema.settingScheduleEnd, ScheduleConstants.endTime),
      (Schema.settingScheduleInterval, ScheduleConstants.intervalMinutes.toString()),
    ];

    for (final (key, value) in defaults) {
      await db.insert(
        'app_settings',
        {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }
}

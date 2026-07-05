import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/api/api_config.dart';
import '../../core/constants/schedule_constants.dart';
import '../../core/utils/schedule_config_validator.dart';
import '../../core/utils/time_slot_generator.dart';
import '../../core/sync/sync_local_store.dart';
import '../../core/sync/sync_service.dart';
import '../../core/sync/sync_tracker.dart';
import '../../widgets/shop_logo.dart';
import '../database/database_helper.dart';
import '../database/schema.dart';
import '../models/app_settings.dart';
import '../models/schedule_config.dart';

class SettingsRepository {
  SettingsRepository({DatabaseHelper? databaseHelper, SyncLocalStore? syncLocalStore})
      : _databaseHelper = databaseHelper ?? DatabaseHelper.instance,
        _syncLocalStore = syncLocalStore ?? SyncLocalStore();

  final DatabaseHelper _databaseHelper;
  final SyncLocalStore _syncLocalStore;

  static const String logoFileName = 'shop_logo.jpg';

  Future<AppSettings> getSettings() async {
    final db = await _databaseHelper.database;
    final rows = await db.query('app_settings');

    final values = {
      for (final row in rows) row['key']! as String: row['value']! as String,
    };

    final logoPath = values[Schema.settingLogoPath];
    final logoServerUrl = values[Schema.settingLogoServerUrl];
    return AppSettings(
      shopName: values[Schema.settingShopName] ?? Schema.defaultShopName,
      appDisplayName:
          values[Schema.settingAppDisplayName] ?? Schema.defaultAppDisplayName,
      scheduleConfig: _parseScheduleConfig(values),
      logoPath: logoPath != null && logoPath.isNotEmpty ? logoPath : null,
      logoServerUrl:
          logoServerUrl != null && logoServerUrl.isNotEmpty ? logoServerUrl : null,
    );
  }

  ScheduleConfig _parseScheduleConfig(Map<String, String> values) {
    final interval = int.tryParse(
          values[Schema.settingScheduleInterval] ?? '',
        ) ??
        ScheduleConstants.intervalMinutes;

    return ScheduleConfig(
      startTime:
          values[Schema.settingScheduleStart] ?? ScheduleConstants.startTime,
      endTime: values[Schema.settingScheduleEnd] ?? ScheduleConstants.endTime,
      intervalMinutes: interval,
    );
  }

  Future<void> updateShopName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('El nombre de la barbería no puede estar vacío.');
    }
    await _setSetting(Schema.settingShopName, trimmed);
    await SyncTracker.markSettings();
    await SyncCoordinator.instance.afterMutation();
  }

  Future<void> updateAppDisplayName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('El nombre de la app no puede estar vacío.');
    }
    await _setSetting(Schema.settingAppDisplayName, trimmed);
    await SyncTracker.markSettings();
    await SyncCoordinator.instance.afterMutation();
  }

  Future<void> updateScheduleConfig(ScheduleConfig config) async {
    ScheduleConfigValidator.validate(config);

    final allowedSlots = TimeSlotGenerator.generateAllSlots(config).toSet();
    final db = await _databaseHelper.database;
    final rows = await db.query(
      'appointments',
      columns: ['time'],
      where: "status = 'scheduled'",
    );

    final conflicting = rows
        .map((row) => row['time']! as String)
        .where((time) => !allowedSlots.contains(time))
        .toSet();

    if (conflicting.isNotEmpty) {
      throw StateError(
        'Hay citas programadas fuera del nuevo horario (${conflicting.join(', ')}). '
        'Reagenda o cancela esas citas antes de cambiar la agenda.',
      );
    }

    await _setSetting(Schema.settingScheduleStart, config.startTime);
    await _setSetting(Schema.settingScheduleEnd, config.endTime);
    await _setSetting(
      Schema.settingScheduleInterval,
      config.intervalMinutes.toString(),
    );
    await SyncTracker.markSettings();
    await SyncCoordinator.instance.afterMutation();
  }

  /// Guarda el logo localmente e intenta subirlo al servidor.
  /// Devuelve un aviso si quedó pendiente de sincronizar.
  Future<String?> saveLogo(File source) async {
    final settings = await getSettings();
    ShopLogo.evictCache(settings.logoPath);
    final directory = await getApplicationDocumentsDirectory();
    final destination = File(p.join(directory.path, logoFileName));
    await source.copy(destination.path);
    ShopLogo.evictCache(destination.path);
    await _setSetting(Schema.settingLogoPath, destination.path);
    await _syncLocalStore.markLogoPendingUpload();

    final service = SyncCoordinator.instance.service;
    if (service == null || !await service.isLinked) {
      await _syncLocalStore.clearLogoPendingUploadFlag();
      return null;
    }

    try {
      final result = await service.uploadLogoReturningUrl(destination);
      if (result != null && result.logoUrl.isNotEmpty) {
        await _syncLocalStore.completeLogoUpload(
          result.logoUrl,
          updatedAt: result.updatedAt,
        );
        return null;
      }
      return 'Logo guardado. Se subirá al sincronizar con el panel.';
    } on ApiException catch (e) {
      return 'Logo guardado localmente. ${e.message}';
    } catch (_) {
      return 'Logo guardado localmente. Se subirá al sincronizar.';
    }
  }

  /// Elimina el logo localmente e intenta borrarlo en el servidor.
  Future<String?> clearLogo() async {
    final settings = await getSettings();
    final path = settings.logoPath;
    ShopLogo.evictCache(path);
    if (path != null) {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }
    await _setSetting(Schema.settingLogoPath, '');
    await _syncLocalStore.markLogoPendingDelete();

    final service = SyncCoordinator.instance.service;
    if (service == null || !await service.isLinked) {
      await _syncLocalStore.completeLogoDelete();
      return null;
    }

    try {
      final updatedAt = await service.deleteLogoRemote();
      await _syncLocalStore.completeLogoDelete(updatedAt: updatedAt);
      return null;
    } on ApiException catch (e) {
      return 'Logo eliminado en el dispositivo. ${e.message}';
    } catch (_) {
      return 'Logo eliminado en el dispositivo. Se sincronizará al tener conexión.';
    }
  }

  Future<void> _setSetting(String key, String value) async {
    final db = await _databaseHelper.database;
    await db.insert(
      'app_settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../data/database/database_helper.dart';
import '../../data/database/schema.dart';
import '../../data/repositories/settings_repository.dart';
import '../api/api_models.dart';
import '../../widgets/shop_logo.dart';
import 'sync_session_store.dart';
import 'sync_tracker.dart';

class _StoredLogoMeta {
  const _StoredLogoMeta({
    this.logoPath,
    this.logoServerUrl,
    this.settingsUpdatedAt,
  });

  final String? logoPath;
  final String? logoServerUrl;
  final String? settingsUpdatedAt;
}

class SyncLocalStore {
  SyncLocalStore({DatabaseHelper? databaseHelper, SyncSessionStore? sessionStore})
      : _databaseHelper = databaseHelper ?? DatabaseHelper.instance,
        _sessionStore = sessionStore ?? SyncSessionStore();

  final DatabaseHelper _databaseHelper;
  final SyncSessionStore _sessionStore;

  Future<bool> _isStaffUser() async {
    final user = await _sessionStore.readUser();
    return user?.role == 'staff';
  }

  Future<String?> _assignedBarberServerId() async {
    return _sessionStore.assignedBarberServerId;
  }

  Future<String?> applyPull(SyncPullBundle bundle, {String? apiBaseUrl}) async {
    final db = await _databaseHelper.database;
    final storedMeta = await _readStoredLogoMeta(db);
    final pendingUpload = await _isMetaFlag(db, Schema.metaLogoPendingUpload);
    final pendingDelete = await _isMetaFlag(db, Schema.metaLogoPendingDelete);
    final skipLogoPull = pendingUpload || pendingDelete;

    final remoteLogoUrl = bundle.settings.logoUrl;
    final shouldClearLogo =
        !skipLogoPull &&
        (remoteLogoUrl == null || remoteLogoUrl.isEmpty);

    String? logoPath = storedMeta.logoPath;
    String? logoServerUrl = storedMeta.logoServerUrl;
    String? logoWarning;
    var logoPathChanged = shouldClearLogo;
    var logoServerUrlChanged = shouldClearLogo;

    if (!skipLogoPull) {
      if (shouldClearLogo) {
        ShopLogo.evictCache(storedMeta.logoPath);
        await _clearLocalLogoFile();
        logoPath = null;
        logoServerUrl = null;
      } else if (apiBaseUrl != null) {
        final needsRefresh = _shouldRefreshLogo(
          remoteUrl: remoteLogoUrl!,
          remoteSettingsUpdatedAt: bundle.settings.updatedAt,
          storedLogoUrl: storedMeta.logoServerUrl,
          storedSettingsUpdatedAt: storedMeta.settingsUpdatedAt,
          localLogoPath: storedMeta.logoPath,
        );
        if (needsRefresh) {
          final downloaded = await _downloadLogo(remoteLogoUrl, apiBaseUrl);
          if (downloaded != null) {
            ShopLogo.evictCache(storedMeta.logoPath);
            ShopLogo.evictCache(downloaded);
            logoPath = downloaded;
            logoServerUrl = remoteLogoUrl;
            logoPathChanged = true;
            logoServerUrlChanged = true;
          } else {
            logoWarning = 'No se pudo descargar el logo del servidor.';
          }
        } else {
          logoServerUrl = remoteLogoUrl;
          if (logoServerUrl != storedMeta.logoServerUrl) {
            logoServerUrlChanged = true;
          }
        }
      }
    }

    await db.transaction((txn) async {
      final pendingSettings = await txn.query(
        'sync_queue',
        where: "entity_type = 'settings'",
        limit: 1,
      );
      final shouldApplyRemoteSettings = pendingSettings.isEmpty &&
          _isRemoteNewer(
            bundle.settings.updatedAt,
            storedMeta.settingsUpdatedAt,
          );

      if (shouldApplyRemoteSettings) {
        await _applySettings(
          txn,
          bundle.settings,
          logoPath: logoPath,
          logoServerUrl: logoServerUrl,
          clearLogo: shouldClearLogo,
          updateLogoPath: logoPathChanged,
          updateLogoServerUrl: logoServerUrlChanged,
        );
      }
      for (final barber in bundle.barbers) {
        await _upsertBarber(txn, barber);
      }
      for (final service in bundle.services) {
        await _upsertService(txn, service);
      }
      for (final appointment in bundle.appointments) {
        await _upsertAppointment(txn, appointment);
      }
      for (final block in bundle.scheduleBlocks) {
        await _upsertBlock(txn, block);
      }
      for (final invoice in bundle.posInvoices) {
        await _upsertPosInvoice(txn, invoice);
      }
    });
    await _markCatalogWithoutServerIdPending(db);
    return logoWarning;
  }

  Future<bool> isLogoPendingUpload() async {
    final db = await _databaseHelper.database;
    return _isMetaFlag(db, Schema.metaLogoPendingUpload);
  }

  Future<bool> isLogoPendingDelete() async {
    final db = await _databaseHelper.database;
    return _isMetaFlag(db, Schema.metaLogoPendingDelete);
  }

  Future<String?> getLocalLogoPath() async {
    final db = await _databaseHelper.database;
    final meta = await _readStoredLogoMeta(db);
    return meta.logoPath;
  }

  Future<void> markLogoPendingUpload() async {
    final db = await _databaseHelper.database;
    await _setMeta(db, Schema.metaLogoPendingUpload, '1');
    await _setMeta(db, Schema.metaLogoPendingDelete, '');
  }

  Future<void> markLogoPendingDelete() async {
    final db = await _databaseHelper.database;
    await _setMeta(db, Schema.metaLogoPendingDelete, '1');
    await _setMeta(db, Schema.metaLogoPendingUpload, '');
  }

  Future<void> completeLogoUpload(
    String logoServerUrl, {
    String? updatedAt,
  }) async {
    final db = await _databaseHelper.database;
    final resolvedUpdatedAt = updatedAt ?? DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      await txn.insert(
        'app_settings',
        {'key': Schema.settingLogoServerUrl, 'value': logoServerUrl},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.insert(
        'schema_meta',
        {'key': Schema.metaLogoPendingUpload, 'value': ''},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.insert(
        'schema_meta',
        {'key': Schema.metaSettingsUpdatedAt, 'value': resolvedUpdatedAt},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  Future<void> completeLogoDelete({String? updatedAt}) async {
    ShopLogo.evictCache(await getLocalLogoPath());
    await _clearLocalLogoFile();
    final db = await _databaseHelper.database;
    await db.transaction((txn) async {
      await txn.insert(
        'app_settings',
        {'key': Schema.settingLogoPath, 'value': ''},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.insert(
        'app_settings',
        {'key': Schema.settingLogoServerUrl, 'value': ''},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.insert(
        'schema_meta',
        {'key': Schema.metaLogoPendingDelete, 'value': ''},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      if (updatedAt != null && updatedAt.isNotEmpty) {
        await txn.insert(
          'schema_meta',
          {'key': Schema.metaSettingsUpdatedAt, 'value': updatedAt},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<void> clearLogoPendingUploadFlag() async {
    final db = await _databaseHelper.database;
    await _setMeta(db, Schema.metaLogoPendingUpload, '');
  }

  Future<Map<String, dynamic>> buildCatalogChanges() async {
    if (await _isStaffUser()) return {};

    final db = await _databaseHelper.database;
    final barbers = await _buildBarbers(db);
    final services = await _buildServices(db);
    final settings = await _buildSettings(db);

    return {
      if (barbers.isNotEmpty) 'barbers': barbers,
      if (services.isNotEmpty) 'services': services,
      if (settings != null) 'settings': settings,
    };
  }

  Future<Map<String, dynamic>> buildEntityChanges() async {
    final db = await _databaseHelper.database;
    final appointments = await _buildAppointments(db);
    if (await _isStaffUser()) {
      final posInvoices = await _buildPosInvoices(db);
      return {
        if (appointments.isNotEmpty) 'appointments': appointments,
        if (posInvoices.isNotEmpty) 'posInvoices': posInvoices,
      };
    }

    final blocks = await _buildBlocks(db);
    final posInvoices = await _buildPosInvoices(db);

    return {
      if (appointments.isNotEmpty) 'appointments': appointments,
      if (blocks.isNotEmpty) 'scheduleBlocks': blocks,
      if (posInvoices.isNotEmpty) 'posInvoices': posInvoices,
    };
  }

  Future<bool> hasPendingCatalog() async {
    final changes = await buildCatalogChanges();
    return changes.isNotEmpty;
  }

  /// Barberos/servicios semilla quedan synced sin UUID hasta un pull; forzar pending antes de push.
  Future<void> ensureCatalogPendingForSync() async {
    final db = await _databaseHelper.database;
    await _markCatalogWithoutServerIdPending(db);
  }

  /// Citas marcadas synced sin server_id (falso positivo) vuelven a pending.
  Future<void> ensureOrphanAppointmentsPending() async {
    final db = await _databaseHelper.database;
    final now = DateTime.now().toIso8601String();
    await db.rawUpdate(
      '''
      UPDATE appointments
      SET sync_status = ?, updated_at = ?
      WHERE sync_status = ? AND (server_id IS NULL OR server_id = '')
      ''',
      [Schema.syncStatusPending, now, Schema.syncStatusSynced],
    );
  }

  Future<int> countAppointmentsBlockedByBarber() async {
    final db = await _databaseHelper.database;
    final rows = await db.rawQuery(
      '''
      SELECT COUNT(*) AS cnt
      FROM appointments a
      INNER JOIN barbers b ON b.id = a.barber_id
      WHERE a.sync_status = ?
        AND (b.server_id IS NULL OR b.server_id = '')
      ''',
      [Schema.syncStatusPending],
    );
    return (rows.first['cnt'] as int?) ?? 0;
  }

  Future<bool> hasAppointmentsBlockedByBarber() async {
    return (await countAppointmentsBlockedByBarber()) > 0;
  }

  Future<bool> hasAppointmentsReadyToPush() async {
    final changes = await buildEntityChanges();
    return (changes['appointments'] as List?)?.isNotEmpty ?? false;
  }

  static const _activeTenantMetaKey = 'active_tenant_id';

  Future<String?> getActiveTenantId() async {
    final db = await _databaseHelper.database;
    final rows = await db.query(
      'schema_meta',
      where: 'key = ?',
      whereArgs: [_activeTenantMetaKey],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> setActiveTenantId(String tenantId) async {
    final db = await _databaseHelper.database;
    await db.insert(
      'schema_meta',
      {'key': _activeTenantMetaKey, 'value': tenantId},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Borra datos de barbería sincronizados; conserva usuarios locales offline.
  Future<void> clearTenantSyncData() async {
    final db = await _databaseHelper.database;
    await db.transaction((txn) async {
      await txn.delete('appointment_services');
      await txn.delete('appointments');
      await txn.delete('pos_invoices');
      await txn.delete('barber_schedule_blocks');
      await txn.delete('sync_queue');
      await txn.delete('barbers');
      await txn.delete('services');
      for (final key in [
        Schema.settingShopName,
        Schema.settingLogoPath,
        Schema.settingLogoServerUrl,
        Schema.settingAppDisplayName,
        Schema.settingScheduleStart,
        Schema.settingScheduleEnd,
        Schema.settingScheduleInterval,
      ]) {
        await txn.delete('app_settings', where: 'key = ?', whereArgs: [key]);
      }
      await txn.delete(
        'schema_meta',
        where: 'key = ?',
        whereArgs: [Schema.metaSettingsUpdatedAt],
      );
      await txn.delete(
        'schema_meta',
        where: 'key = ?',
        whereArgs: [Schema.metaLogoPendingUpload],
      );
      await txn.delete(
        'schema_meta',
        where: 'key = ?',
        whereArgs: [Schema.metaLogoPendingDelete],
      );
      await txn.delete(
        'schema_meta',
        where: 'key = ?',
        whereArgs: [_activeTenantMetaKey],
      );
    });
  }

  Future<Map<String, dynamic>> buildChanges() async {
    final db = await _databaseHelper.database;
    final barbers = await _buildBarbers(db);
    final services = await _buildServices(db);
    final appointments = await _buildAppointments(db);
    final blocks = await _buildBlocks(db);
    final posInvoices = await _buildPosInvoices(db);
    final settings = await _buildSettings(db);

    return {
      if (barbers.isNotEmpty) 'barbers': barbers,
      if (services.isNotEmpty) 'services': services,
      if (appointments.isNotEmpty) 'appointments': appointments,
      if (blocks.isNotEmpty) 'scheduleBlocks': blocks,
      if (posInvoices.isNotEmpty) 'posInvoices': posInvoices,
      if (settings != null) 'settings': settings,
    };
  }

  Future<void> applyIdMappings(Map<String, Map<String, String>> applied) async {
    final db = await _databaseHelper.database;
    await _mapIds(db, 'barbers', 'barber', applied['barbers'] ?? {});
    await _mapIds(db, 'services', 'service', applied['services'] ?? {});
    await _mapIds(db, 'appointments', 'appointment', applied['appointments'] ?? {});
    await _mapIds(db, 'barber_schedule_blocks', 'block', applied['scheduleBlocks'] ?? {});
    await _mapIds(db, 'pos_invoices', 'posInvoice', applied['posInvoices'] ?? {});
  }

  Future<void> markCatalogSyncedAfterPush(
    Map<String, Map<String, String>> applied,
    Map<String, dynamic> pushedChanges, {
    List<Map<String, dynamic>> conflicts = const [],
  }) async {
    final db = await _databaseHelper.database;
    // applied ya procesado en applyIdMappings; aquí solo updates por server id en payload.
    await _markSyncedByServerIdInPayload(db, 'barbers', pushedChanges['barbers']);
    await _markSyncedByServerIdInPayload(db, 'services', pushedChanges['services']);
    if (pushedChanges.containsKey('settings')) {
      final settingsRejected = conflicts.any((c) => c['entity'] == 'settings');
      if (!settingsRejected) {
        await db.delete('sync_queue', where: "entity_type = 'settings'");
      }
    }
  }

  Future<void> markEntitySyncedAfterPush(
    Map<String, Map<String, String>> applied,
    Map<String, dynamic> pushedChanges,
  ) async {
    final db = await _databaseHelper.database;
    await _markSyncedByAppliedServerIds(db, 'appointments', applied['appointments']);
    await _markSyncedByAppliedServerIds(
      db,
      'barber_schedule_blocks',
      applied['scheduleBlocks'],
    );
    await _markSyncedByAppliedServerIds(db, 'pos_invoices', applied['posInvoices']);
  }

  Future<void> _markSyncedByAppliedServerIds(
    Database db,
    String table,
    Map<String, String>? appliedMap,
  ) async {
    if (appliedMap == null || appliedMap.isEmpty) return;
    final serverIds = appliedMap.values.toSet();
    for (final serverId in serverIds) {
      if (serverId.isEmpty) continue;
      await db.update(
        table,
        {'sync_status': Schema.syncStatusSynced},
        where: 'server_id = ? AND sync_status = ?',
        whereArgs: [serverId, Schema.syncStatusPending],
      );
    }
  }

  Future<void> markSyncedAfterPush(
    Map<String, Map<String, String>> applied,
    Map<String, dynamic> pushedChanges, {
    List<Map<String, dynamic>> conflicts = const [],
  }) async {
    await markCatalogSyncedAfterPush(applied, pushedChanges, conflicts: conflicts);
    await markEntitySyncedAfterPush(applied, pushedChanges);
  }

  Future<void> _markSyncedByServerIdInPayload(
    Database db,
    String table,
    dynamic items,
  ) async {
    if (items is! List) return;
    for (final item in items) {
      if (item is! Map<String, dynamic>) continue;
      final serverId = item['id'] as String?;
      if (serverId == null || serverId.isEmpty) continue;
      await db.update(
        table,
        {'sync_status': Schema.syncStatusSynced},
        where: 'server_id = ? AND sync_status = ?',
        whereArgs: [serverId, Schema.syncStatusPending],
      );
    }
  }

  Future<void> markConflicts(List<Map<String, dynamic>> conflicts) async {
    final db = await _databaseHelper.database;
    for (final conflict in conflicts) {
      final entity = conflict['entity'] as String?;
      final clientId = conflict['clientId'] as String?;
      if (entity == null || clientId == null) continue;
      final localId = _parseLocalId(clientId);
      if (localId == null) continue;
      final table = _tableForEntity(entity);
      if (table == null) continue;
      await db.update(
        table,
        {'sync_status': Schema.syncStatusConflict},
        where: 'id = ?',
        whereArgs: [localId],
      );
    }
  }

  Future<void> _applySettings(
    DatabaseExecutor txn,
    SyncSettingsDto settings, {
    String? logoPath,
    String? logoServerUrl,
    bool clearLogo = false,
    bool updateLogoPath = false,
    bool updateLogoServerUrl = false,
  }) async {
    await txn.insert(
      'app_settings',
      {'key': Schema.settingShopName, 'value': settings.shopName},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await txn.insert(
      'app_settings',
      {'key': Schema.settingAppDisplayName, 'value': settings.displayName},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await txn.insert(
      'app_settings',
      {'key': Schema.settingScheduleStart, 'value': settings.scheduleStart},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await txn.insert(
      'app_settings',
      {'key': Schema.settingScheduleEnd, 'value': settings.scheduleEnd},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await txn.insert(
      'app_settings',
      {
        'key': Schema.settingScheduleInterval,
        'value': settings.scheduleInterval.toString(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await txn.insert(
      'schema_meta',
      {'key': Schema.metaSettingsUpdatedAt, 'value': settings.updatedAt},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    if (clearLogo) {
      await txn.insert(
        'app_settings',
        {'key': Schema.settingLogoPath, 'value': ''},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.insert(
        'app_settings',
        {'key': Schema.settingLogoServerUrl, 'value': ''},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } else {
      if (updateLogoPath && logoPath != null) {
        await txn.insert(
          'app_settings',
          {'key': Schema.settingLogoPath, 'value': logoPath},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      if (updateLogoServerUrl && logoServerUrl != null) {
        await txn.insert(
          'app_settings',
          {'key': Schema.settingLogoServerUrl, 'value': logoServerUrl},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    }
  }

  Future<_StoredLogoMeta> _readStoredLogoMeta(Database db) async {
    final settings = await db.query('app_settings');
    final values = {
      for (final row in settings) row['key']! as String: row['value']! as String,
    };
    final updatedRow = await db.query(
      'schema_meta',
      where: 'key = ?',
      whereArgs: [Schema.metaSettingsUpdatedAt],
      limit: 1,
    );
    final logoPath = values[Schema.settingLogoPath];
    final logoServerUrl = values[Schema.settingLogoServerUrl];
    return _StoredLogoMeta(
      logoPath: logoPath != null && logoPath.isNotEmpty ? logoPath : null,
      logoServerUrl:
          logoServerUrl != null && logoServerUrl.isNotEmpty ? logoServerUrl : null,
      settingsUpdatedAt:
          updatedRow.isNotEmpty ? updatedRow.first['value'] as String? : null,
    );
  }

  bool _shouldRefreshLogo({
    required String remoteUrl,
    required String remoteSettingsUpdatedAt,
    String? storedLogoUrl,
    String? storedSettingsUpdatedAt,
    String? localLogoPath,
  }) {
    if (localLogoPath == null || localLogoPath.isEmpty) return true;
    final file = File(localLogoPath);
    if (!file.existsSync()) return true;
    if (storedLogoUrl != remoteUrl) return true;
    if (storedSettingsUpdatedAt == null || storedSettingsUpdatedAt.isEmpty) {
      return true;
    }
    return _isRemoteNewer(remoteSettingsUpdatedAt, storedSettingsUpdatedAt);
  }

  Future<void> _clearLocalLogoFile() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File(p.join(directory.path, SettingsRepository.logoFileName));
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<String?> _downloadLogo(String logoUrl, String apiBaseUrl) async {
    try {
      final uri = Uri.parse(
        logoUrl.startsWith('http') ? logoUrl : '$apiBaseUrl$logoUrl',
      );
      final response = await http.get(uri);
      if (response.statusCode != 200) return null;
      final directory = await getApplicationDocumentsDirectory();
      final file = File(p.join(directory.path, SettingsRepository.logoFileName));
      await file.writeAsBytes(response.bodyBytes);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  Future<void> _upsertBarber(DatabaseExecutor txn, SyncBarberDto remote) async {
    var localId = await _findLocalId(txn, 'barbers', remote.id);
    final data = {
      'name': remote.name,
      'is_active': remote.active ? 1 : 0,
      'server_id': remote.id,
      'updated_at': remote.updatedAt,
      'sync_status': Schema.syncStatusSynced,
    };
    if (localId != null) {
      final existing = await txn.query('barbers', where: 'id = ?', whereArgs: [localId], limit: 1);
      if (existing.isNotEmpty &&
          !_isRemoteNewer(remote.updatedAt, existing.first['updated_at'] as String?)) {
        return;
      }
      await txn.update('barbers', data, where: 'id = ?', whereArgs: [localId]);
    } else {
      localId = await _findLocalWithoutServerIdByName(txn, 'barbers', remote.name);
      if (localId != null) {
        await txn.update('barbers', data, where: 'id = ?', whereArgs: [localId]);
      } else {
        await txn.insert('barbers', data);
      }
    }
  }

  Future<void> _upsertService(DatabaseExecutor txn, SyncServiceDto remote) async {
    var localId = await _findLocalId(txn, 'services', remote.id);
    final data = {
      'name': remote.name,
      'price': remote.price,
      'duration_minutes': remote.durationMinutes,
      'is_active': remote.active ? 1 : 0,
      'server_id': remote.id,
      'updated_at': remote.updatedAt,
      'sync_status': Schema.syncStatusSynced,
    };
    if (localId != null) {
      final existing = await txn.query('services', where: 'id = ?', whereArgs: [localId], limit: 1);
      if (existing.isNotEmpty &&
          !_isRemoteNewer(remote.updatedAt, existing.first['updated_at'] as String?)) {
        return;
      }
      await txn.update('services', data, where: 'id = ?', whereArgs: [localId]);
    } else {
      localId = await _findLocalWithoutServerIdByName(txn, 'services', remote.name);
      if (localId != null) {
        await txn.update('services', data, where: 'id = ?', whereArgs: [localId]);
      } else {
        await txn.insert('services', data);
      }
    }
  }

  Future<void> _upsertAppointment(DatabaseExecutor txn, SyncAppointmentDto remote) async {
    final localBarberId = await _requireLocalId(txn, 'barbers', remote.barberId);
    if (localBarberId == null) return;

    var localId = await _findLocalId(txn, 'appointments', remote.id);
    final data = {
      'client_name': remote.clientName,
      'client_phone': remote.clientPhone,
      'barber_id': localBarberId,
      'date': remote.date,
      'time': remote.time,
      'duration_minutes': remote.durationMinutes,
      'status': remote.status,
      'source': remote.source ?? 'staff',
      'pending_expires_at': remote.pendingExpiresAt,
      'created_at': remote.createdAt,
      'canceled_at': remote.canceledAt,
      'server_id': remote.id,
      'updated_at': remote.updatedAt,
      'sync_status': Schema.syncStatusSynced,
    };

    int appointmentId;
    if (localId != null) {
      final existing =
          await txn.query('appointments', where: 'id = ?', whereArgs: [localId], limit: 1);
      if (existing.isNotEmpty &&
          !_isRemoteNewer(remote.updatedAt, existing.first['updated_at'] as String?)) {
        return;
      }
      await txn.update('appointments', data, where: 'id = ?', whereArgs: [localId]);
      appointmentId = localId;
    } else {
      if (remote.status == 'scheduled' || remote.status == 'pending') {
        localId = await _findLocalAppointmentByActiveSlot(
          txn,
          localBarberId,
          remote.date,
          remote.time,
        );
      }
      if (localId != null) {
        await txn.update('appointments', data, where: 'id = ?', whereArgs: [localId]);
        appointmentId = localId;
      } else {
        appointmentId = await txn.insert('appointments', data);
      }
    }

    await txn.delete(
      'appointment_services',
      where: 'appointment_id = ?',
      whereArgs: [appointmentId],
    );
    for (final line in remote.services) {
      final serviceLocalId = await _requireLocalId(txn, 'services', line.serviceId);
      if (serviceLocalId == null) continue;
      await txn.insert('appointment_services', {
        'appointment_id': appointmentId,
        'service_id': serviceLocalId,
        'unit_price': line.unitPrice,
        'duration_minutes': line.durationMinutes,
      });
    }
  }

  Future<void> _upsertPosInvoice(DatabaseExecutor txn, SyncPosInvoiceDto remote) async {
    final appointmentLocalId = await _requireLocalId(txn, 'appointments', remote.appointmentId);
    if (appointmentLocalId == null) return;

    var localId = await _findLocalId(txn, 'pos_invoices', remote.id);
    final data = {
      'appointment_id': appointmentLocalId,
      'number': remote.number,
      'issued_at': remote.issuedAt,
      'client_name': remote.clientName,
      'barber_name': remote.barberName,
      'subtotal': remote.subtotal,
      'lines_json': jsonEncode(remote.lines.map((l) => l.toJson()).toList()),
      'server_id': remote.id,
      'updated_at': remote.updatedAt,
      'sync_status': Schema.syncStatusSynced,
    };

    if (localId != null) {
      final existing =
          await txn.query('pos_invoices', where: 'id = ?', whereArgs: [localId], limit: 1);
      if (existing.isNotEmpty &&
          !_isRemoteNewer(remote.updatedAt, existing.first['updated_at'] as String?)) {
        return;
      }
      await txn.update('pos_invoices', data, where: 'id = ?', whereArgs: [localId]);
      return;
    }

    final byAppointment = await txn.query(
      'pos_invoices',
      where: 'appointment_id = ?',
      whereArgs: [appointmentLocalId],
      limit: 1,
    );
    if (byAppointment.isNotEmpty) {
      localId = byAppointment.first['id'] as int;
      await txn.update('pos_invoices', data, where: 'id = ?', whereArgs: [localId]);
    } else {
      await txn.insert('pos_invoices', data);
    }
  }

  Future<void> _upsertBlock(DatabaseExecutor txn, SyncBlockDto remote) async {
    final localBarberId = await _requireLocalId(txn, 'barbers', remote.barberId);
    if (localBarberId == null) return;

    var localId = await _findLocalId(txn, 'barber_schedule_blocks', remote.id);
    final data = {
      'barber_id': localBarberId,
      'date': remote.date,
      'time': remote.time,
      'is_full_day': remote.isFullDay ? 1 : 0,
      'created_at': remote.createdAt,
      'server_id': remote.id,
      'updated_at': remote.updatedAt,
      'sync_status': Schema.syncStatusSynced,
    };

    if (localId != null) {
      final existing = await txn.query(
        'barber_schedule_blocks',
        where: 'id = ?',
        whereArgs: [localId],
        limit: 1,
      );
      if (existing.isNotEmpty &&
          !_isRemoteNewer(remote.updatedAt, existing.first['updated_at'] as String?)) {
        return;
      }
      await txn.update('barber_schedule_blocks', data, where: 'id = ?', whereArgs: [localId]);
    } else {
      localId = await _findLocalBlockBySlot(
        txn,
        localBarberId,
        remote.date,
        remote.time,
        remote.isFullDay,
      );
      if (localId != null) {
        await txn.update('barber_schedule_blocks', data, where: 'id = ?', whereArgs: [localId]);
      } else {
        await txn.insert('barber_schedule_blocks', data);
      }
    }
  }

  Future<List<Map<String, dynamic>>> _buildBarbers(Database db) async {
    final rows = await db.query('barbers', where: 'sync_status = ?', whereArgs: [Schema.syncStatusPending]);
    return rows.map((row) {
      final localId = row['id']! as int;
      final serverId = row['server_id'] as String?;
      return {
        if (serverId != null) 'id': serverId,
        if (serverId == null) 'clientId': SyncTracker.clientId('barber', localId),
        'name': row['name'],
        'active': (row['is_active'] as int) == 1,
        'updatedAt': row['updated_at'] ?? DateTime.now().toIso8601String(),
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _buildServices(Database db) async {
    final rows = await db.query('services', where: 'sync_status = ?', whereArgs: [Schema.syncStatusPending]);
    return rows.map((row) {
      final localId = row['id']! as int;
      final serverId = row['server_id'] as String?;
      return {
        if (serverId != null) 'id': serverId,
        if (serverId == null) 'clientId': SyncTracker.clientId('service', localId),
        'name': row['name'],
        'price': row['price'],
        'durationMinutes': row['duration_minutes'] ?? 30,
        'active': (row['is_active'] as int) == 1,
        'updatedAt': row['updated_at'] ?? DateTime.now().toIso8601String(),
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _buildAppointments(Database db) async {
    final rows =
        await db.query('appointments', where: 'sync_status = ?', whereArgs: [Schema.syncStatusPending]);
    final result = <Map<String, dynamic>>[];
    for (final row in rows) {
      final localId = row['id']! as int;
      final barberLocalId = row['barber_id']! as int;
      final barberRows = await db.query('barbers', where: 'id = ?', whereArgs: [barberLocalId], limit: 1);
      if (barberRows.isEmpty) continue;
      final barberServerId = barberRows.first['server_id'] as String?;
      if (barberServerId == null) continue;

      if (await _isStaffUser()) {
        final assigned = await _assignedBarberServerId();
        if (assigned != null && barberServerId != assigned) continue;
      }

      final serviceLines = await db.rawQuery('''
        SELECT s.server_id, aps.unit_price, aps.duration_minutes
        FROM appointment_services aps
        JOIN services s ON s.id = aps.service_id
        WHERE aps.appointment_id = ?
      ''', [localId]);

      final services = serviceLines
          .where((line) => line['server_id'] != null)
          .map((line) => {
                'serviceId': line['server_id'],
                'unitPrice': line['unit_price'],
                'durationMinutes': line['duration_minutes'] ?? 30,
              })
          .toList();

      final serverId = row['server_id'] as String?;
      result.add({
        if (serverId != null) 'id': serverId,
        if (serverId == null) 'clientId': SyncTracker.clientId('appointment', localId),
        'barberId': barberServerId,
        'clientName': row['client_name'],
        if (row['client_phone'] != null) 'clientPhone': row['client_phone'],
        'date': row['date'],
        'time': row['time'],
        'durationMinutes': row['duration_minutes'] ?? 30,
        'status': row['status'],
        'createdAt': row['created_at'],
        'canceledAt': row['canceled_at'],
        'updatedAt': row['updated_at'] ?? DateTime.now().toIso8601String(),
        'services': services,
      });
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> _buildPosInvoices(Database db) async {
    final rows = await db.query(
      'pos_invoices',
      where: 'sync_status = ?',
      whereArgs: [Schema.syncStatusPending],
    );
    final result = <Map<String, dynamic>>[];
    for (final row in rows) {
      final localId = row['id']! as int;
      final appointmentLocalId = row['appointment_id']! as int;
      final appointmentRows = await db.query(
        'appointments',
        where: 'id = ?',
        whereArgs: [appointmentLocalId],
        limit: 1,
      );
      if (appointmentRows.isEmpty) continue;
      final appointmentServerId = appointmentRows.first['server_id'] as String?;
      if (appointmentServerId == null || appointmentServerId.isEmpty) continue;

      final linesJson = row['lines_json'] as String? ?? '[]';
      final decoded = jsonDecode(linesJson) as List<dynamic>;
      final lines = decoded
          .map((e) => SyncPosInvoiceLineDto.fromJson(e as Map<String, dynamic>))
          .map((l) => l.toJson())
          .toList();

      final serverId = row['server_id'] as String?;
      result.add({
        if (serverId != null) 'id': serverId,
        if (serverId == null) 'clientId': SyncTracker.clientId('posInvoice', localId),
        'appointmentId': appointmentServerId,
        'number': row['number'],
        'issuedAt': row['issued_at'],
        'clientName': row['client_name'],
        'barberName': row['barber_name'],
        'subtotal': row['subtotal'],
        'lines': lines,
        'updatedAt': row['updated_at'] ?? DateTime.now().toIso8601String(),
      });
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> _buildBlocks(Database db) async {
    final rows = await db.query(
      'barber_schedule_blocks',
      where: 'sync_status = ?',
      whereArgs: [Schema.syncStatusPending],
    );
    final result = <Map<String, dynamic>>[];
    for (final row in rows) {
      final localId = row['id']! as int;
      final barberRows =
          await db.query('barbers', where: 'id = ?', whereArgs: [row['barber_id']], limit: 1);
      if (barberRows.isEmpty) continue;
      final barberServerId = barberRows.first['server_id'] as String?;
      if (barberServerId == null) continue;
      final serverId = row['server_id'] as String?;
      result.add({
        if (serverId != null) 'id': serverId,
        if (serverId == null) 'clientId': SyncTracker.clientId('block', localId),
        'barberId': barberServerId,
        'date': row['date'],
        'time': row['time'],
        'isFullDay': (row['is_full_day'] as int) == 1,
        'createdAt': row['created_at'],
        'updatedAt': row['updated_at'] ?? DateTime.now().toIso8601String(),
      });
    }
    return result;
  }

  Future<Map<String, dynamic>?> _buildSettings(Database db) async {
    final pending = await db.query(
      'sync_queue',
      where: "entity_type = 'settings'",
      limit: 1,
    );
    if (pending.isEmpty) return null;

    final settings = await db.query('app_settings');
    final values = {for (final row in settings) row['key']! as String: row['value']! as String};
    final updatedRow = await db.query(
      'schema_meta',
      where: 'key = ?',
      whereArgs: [Schema.metaSettingsUpdatedAt],
      limit: 1,
    );
    final updatedAt = updatedRow.isNotEmpty
        ? updatedRow.first['value']! as String
        : DateTime.now().toIso8601String();

    return {
      'shopName': values[Schema.settingShopName],
      'displayName': values[Schema.settingAppDisplayName],
      'scheduleStart': values[Schema.settingScheduleStart],
      'scheduleEnd': values[Schema.settingScheduleEnd],
      'scheduleInterval': int.tryParse(values[Schema.settingScheduleInterval] ?? '') ?? 30,
      'updatedAt': updatedAt,
    };
  }

  Future<int?> _findLocalId(DatabaseExecutor db, String table, String serverId) async {
    final rows = await db.query(table, where: 'server_id = ?', whereArgs: [serverId], limit: 1);
    if (rows.isEmpty) return null;
    return rows.first['id'] as int;
  }

  Future<int?> _findLocalAppointmentByActiveSlot(
    DatabaseExecutor db,
    int barberLocalId,
    String date,
    String time,
  ) async {
    final rows = await db.query(
      'appointments',
      where: 'barber_id = ? AND date = ? AND time = ? AND status IN (?, ?)',
      whereArgs: [barberLocalId, date, time, 'scheduled', 'pending'],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['id'] as int;
  }

  Future<int?> _findLocalBlockBySlot(
    DatabaseExecutor db,
    int barberLocalId,
    String date,
    String? time,
    bool isFullDay,
  ) async {
    if (isFullDay) {
      final rows = await db.query(
        'barber_schedule_blocks',
        where: 'barber_id = ? AND date = ? AND is_full_day = 1',
        whereArgs: [barberLocalId, date],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return rows.first['id'] as int;
    }
    final rows = await db.query(
      'barber_schedule_blocks',
      where: 'barber_id = ? AND date = ? AND time = ? AND is_full_day = 0',
      whereArgs: [barberLocalId, date, time],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['id'] as int;
  }

  Future<int?> _findLocalWithoutServerIdByName(
    DatabaseExecutor db,
    String table,
    String name,
  ) async {
    final rows = await db.query(
      table,
      where: 'name = ? AND (server_id IS NULL OR server_id = ?)',
      whereArgs: [name, ''],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['id'] as int;
  }

  Future<void> _markCatalogWithoutServerIdPending(Database db) async {
    final now = DateTime.now().toIso8601String();
    for (final table in ['barbers', 'services']) {
      await db.rawUpdate(
        '''
        UPDATE $table
        SET sync_status = ?, updated_at = ?
        WHERE server_id IS NULL OR server_id = ?
        ''',
        [Schema.syncStatusPending, now, ''],
      );
    }
  }

  Future<int?> _requireLocalId(DatabaseExecutor db, String table, String serverId) async {
    return _findLocalId(db, table, serverId);
  }

  Future<void> _mapIds(
    Database db,
    String table,
    String entityPrefix,
    Map<String, String> mapping,
  ) async {
    for (final entry in mapping.entries) {
      final localId = _parseLocalId(entry.key);
      if (localId == null) continue;
      await db.update(
        table,
        {'server_id': entry.value, 'sync_status': Schema.syncStatusSynced},
        where: 'id = ?',
        whereArgs: [localId],
      );
      await SyncTracker.clearQueueFor(entityPrefix, localId);
    }
  }

  int? _parseLocalId(String clientId) {
    final match = RegExp(r'^local-\w+-(\d+)$').firstMatch(clientId);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }

  String? _tableForEntity(String entity) {
    switch (entity) {
      case 'barber':
        return 'barbers';
      case 'service':
        return 'services';
      case 'appointment':
        return 'appointments';
      case 'scheduleBlock':
        return 'barber_schedule_blocks';
      case 'posInvoice':
        return 'pos_invoices';
      default:
        return null;
    }
  }

  bool _isRemoteNewer(String remoteUpdatedAt, String? localUpdatedAt) {
    if (localUpdatedAt == null || localUpdatedAt.isEmpty) return true;
    return DateTime.parse(remoteUpdatedAt).isAfter(DateTime.parse(localUpdatedAt));
  }

  Future<bool> _isMetaFlag(Database db, String key) async {
    final rows = await db.query(
      'schema_meta',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return false;
    return rows.first['value'] == '1';
  }

  Future<void> _setMeta(Database db, String key, String value) async {
    await db.insert(
      'schema_meta',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}

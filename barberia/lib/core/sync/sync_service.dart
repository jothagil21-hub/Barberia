import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:sqflite/sqflite.dart';

import '../../data/repositories/auth_repository.dart';
import '../api/api_client.dart';
import '../api/api_config.dart';
import '../api/api_models.dart';
import '../push/push_notification_service.dart';
import 'sync_local_store.dart';
import 'sync_session_store.dart';
import 'sync_tracker.dart';

enum SyncState { idle, syncing, offline, pending, error }

class SyncService {
  SyncService({
    SyncSessionStore? sessionStore,
    ApiClient? apiClient,
    SyncLocalStore? localStore,
    Connectivity? connectivity,
    AuthRepository? authRepository,
  })  : _session = sessionStore ?? SyncSessionStore(),
        _api = apiClient ?? ApiClient(),
        _local = localStore ?? SyncLocalStore(),
        _connectivity = connectivity ?? Connectivity(),
        _auth = authRepository ?? AuthRepository();

  final SyncSessionStore _session;
  final ApiClient _api;
  final SyncLocalStore _local;
  final Connectivity _connectivity;
  final AuthRepository _auth;

  SyncState _state = SyncState.idle;
  String? _lastError;
  void Function(SyncState state)? onStateChanged;
  void Function()? onSyncCompleted;

  SyncState get state => _state;
  String? get lastError => _lastError;

  Future<bool> get isLinked => _session.isLinked;

  String _resolveBaseUrl([String? apiBaseUrl]) {
    final candidate = normalizeBaseUrl(apiBaseUrl ?? '');
    if (candidate.isNotEmpty) return candidate;
    return ApiConfig.effectiveBaseUrl;
  }

  Future<PanelLoginResult> loginWithPanel({
    String? apiBaseUrl,
    required String username,
    required String password,
    void Function(String phase)? onPhase,
  }) async {
    final resolvedUrl = _resolveBaseUrl(apiBaseUrl);
    if (await _hasNetwork()) {
      try {
        return await linkAndLogin(
          apiBaseUrl: resolvedUrl,
          username: username,
          password: password,
          onPhase: onPhase,
        );
      } on ApiException catch (e) {
        if (e.statusCode != null) rethrow;
      } on SocketException {
        /* sin red real: intentar offline */
      }
    }

    return loginOffline(
      username: username,
      password: password,
    );
  }

  Future<PanelLoginResult> loginOffline({
    required String username,
    required String password,
  }) async {
    final user = await _auth.authenticatePanelUser(
      username: username,
      password: password,
    );
    if (user == null) {
      throw ApiException(
        'Usuario o contraseña incorrectos. '
        'Si es la primera vez, inicia sesión con conexión a internet.',
      );
    }

    final profile = await _session.readOfflineProfile();
    if (profile == null) {
      throw ApiException(
        'Sin conexión. Debes iniciar sesión online al menos una vez.',
      );
    }

    if (profile.username != username.trim()) {
      throw ApiException(
        'Sin conexión. Usa el mismo usuario con el que vinculaste la barbería.',
      );
    }

    await _session.saveLastLinkForm(username: username);
    _api.configure(baseUrl: ApiConfig.effectiveBaseUrl, token: null);
    _setState(SyncState.offline);

    return PanelLoginResult(
      tenantId: profile.tenantId,
      userId: profile.tenantUserId,
      username: profile.username,
      role: profile.role,
      assignedBarberServerId: profile.assignedBarberServerId,
      isOffline: true,
    );
  }

  Future<PanelLoginResult> linkAndLogin({
    required String apiBaseUrl,
    required String username,
    required String password,
    void Function(String phase)? onPhase,
  }) async {
    onPhase?.call('connecting');
    final previousTenantId = await _session.tenantId;
    final storedTenantId = await _local.getActiveTenantId();
    final wasLinked = await _session.isLinked;

    if (wasLinked &&
        previousTenantId != null &&
        await SyncTracker.hasPending() &&
        await _hasNetwork()) {
      await configureFromSession();
      try {
        await syncNow();
      } catch (_) {
        /* flush pending de barbería saliente antes de cambiar credenciales */
      }
    }

    final client = ApiClient();
    client.configure(baseUrl: apiBaseUrl);
    final json = await client.post('/api/app/auth/login', {
      'username': username,
      'password': password,
    });
    final result = AppLoginResult.fromJson(json);

    final shouldClear = (previousTenantId != null &&
            previousTenantId != result.tenantId) ||
        (storedTenantId != null && storedTenantId != result.tenantId) ||
        (storedTenantId == null && previousTenantId == null);
    if (shouldClear) {
      await _local.clearTenantSyncData();
    }

    await _auth.upsertPanelUser(
      username: result.username,
      password: password,
      role: result.role,
      tenantUserId: result.userId,
    );

    await _session.saveLink(
      apiBaseUrl: apiBaseUrl,
      token: result.token,
      tenantId: result.tenantId,
      tenantUserId: result.userId,
      username: result.username,
      role: result.role,
      password: password,
      assignedBarberServerId: result.barberId,
    );
    await _session.saveLastLinkForm(username: username);
    await _local.setActiveTenantId(result.tenantId);
    _api.configure(baseUrl: apiBaseUrl, token: result.token);

    await registerPushToken();

    onPhase?.call('syncing');
    String? syncWarning;
    try {
      await pullFull();
    } catch (e) {
      _lastError = e is ApiException ? e.message : e.toString();
      _setState(SyncState.error);
      syncWarning = _lastError;
    }

    final loginResult = PanelLoginResult.fromAppLogin(result);
    if (syncWarning != null) {
      return PanelLoginResult(
        tenantId: loginResult.tenantId,
        userId: loginResult.userId,
        username: loginResult.username,
        role: loginResult.role,
        assignedBarberServerId: loginResult.assignedBarberServerId,
        syncWarning: syncWarning,
      );
    }
    return loginResult;
  }

  Future<void> configureFromSession() async {
    final token = await _session.token;
    _api.configure(baseUrl: ApiConfig.effectiveBaseUrl, token: token);
    if (token != null) {
      await registerPushToken();
    }
  }

  Future<void> registerPushToken() async {
    if (!await _session.isLinked) return;
    await PushNotificationService.instance.registerWithApi(_api);
  }

  Future<void> pullFull() async {
    await configureFromSession();
    if (!await _session.isLinked) return;
    if (!await _hasNetwork()) return;

    _setState(SyncState.syncing);
    try {
      final serverTime = await _pullAndApply(full: true);
      await _session.setLastSyncAt(serverTime);
      onSyncCompleted?.call();
      try {
        await syncNow();
      } catch (_) {
        /* push local catalog/citas tras pull inicial */
      }
      if (_state != SyncState.error) {
        _setState(await _resolveIdleState());
      }
    } catch (e) {
      _lastError = e is ApiException ? e.message : e.toString();
      _setState(SyncState.error);
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> syncNow() async {
    if (!await _session.isLinked) {
      if (!await _hasNetwork()) {
        _setState(SyncState.offline);
        return [];
      }
      final reauthed = await _tryReauthenticate();
      if (!reauthed) {
        _setState(SyncState.offline);
        return [];
      }
    }

    await configureFromSession();
    if (!await _hasNetwork()) {
      _setState(SyncState.offline);
      return [];
    }

    _setState(SyncState.syncing);
    final conflicts = <Map<String, dynamic>>[];
    SyncPostResult? lastResult;

    try {
      await _local.ensureCatalogPendingForSync();
      await _local.ensureOrphanAppointmentsPending();
      await _flushPendingLogoActions();

      for (var pass = 0; pass < 3; pass++) {
        final catalog = await _local.buildCatalogChanges();
        if (catalog.isEmpty) break;

        lastResult = await _postChangesWithReauth(catalog);
        await _local.applyIdMappings(lastResult.applied);
        await _local.markConflicts(lastResult.conflicts);
        conflicts.addAll(lastResult.conflicts);
        await _local.markCatalogSyncedAfterPush(
          lastResult.applied,
          catalog,
          conflicts: lastResult.conflicts,
        );

        if (!await _local.hasPendingCatalog()) break;
      }

      var appointmentsBlocked = await _local.hasAppointmentsBlockedByBarber();
      if (appointmentsBlocked) {
        _lastError = appointmentBlockedMessage;
      } else {
        final entityChanges = await _local.buildEntityChanges();
        if (entityChanges.isNotEmpty) {
          lastResult = await _postChangesWithReauth(entityChanges);
          await _local.applyIdMappings(lastResult.applied);
          await _local.markConflicts(lastResult.conflicts);
          conflicts.addAll(lastResult.conflicts);
          await _local.markEntitySyncedAfterPush(lastResult.applied, entityChanges);
        }
        appointmentsBlocked = await _local.hasAppointmentsBlockedByBarber();
        if (appointmentsBlocked) {
          _lastError = appointmentBlockedMessage;
        }
      }

      String serverTime;
      if (lastResult != null) {
        final baseUrl = ApiConfig.effectiveBaseUrl;
        final warning =
            await _local.applyPull(lastResult.pull, apiBaseUrl: baseUrl);
        if (warning != null && _lastError == null) {
          _lastError = warning;
        }
        serverTime = lastResult.serverTime;
      } else {
        serverTime = await _pullAndApply();
      }
      await _session.setLastSyncAt(serverTime);
      onSyncCompleted?.call();

      _recordConflicts(conflicts);
      if (_state != SyncState.error) {
        if (appointmentsBlocked || await SyncTracker.hasPending()) {
          if (_lastError == null && await SyncTracker.hasPending()) {
            _lastError = 'Hay cambios pendientes de sincronizar con el panel';
          }
          _setState(SyncState.pending);
        } else {
          _lastError = null;
          _setState(SyncState.idle);
        }
      }
    } catch (e) {
      _lastError = _formatSyncError(e);
      _setState(SyncState.error);
    }
    return conflicts;
  }

  Future<SyncPostResult> _postChangesWithReauth(Map<String, dynamic> changes) async {
    try {
      return await _postChanges(changes);
    } on ApiException catch (e) {
      if (e.statusCode == 401 && await _tryReauthenticate()) {
        return _postChanges(changes);
      }
      rethrow;
    }
  }

  Future<bool> _tryReauthenticate() async {
    final profile = await _session.readOfflineProfile();
    final password = await _session.cachedPassword;
    if (profile == null || password == null) return false;

    try {
      final client = ApiClient();
      client.configure(baseUrl: ApiConfig.effectiveBaseUrl);
      final json = await client.post('/api/app/auth/login', {
        'username': profile.username,
        'password': password,
      });
      final result = AppLoginResult.fromJson(json);
      await _session.saveLink(
        apiBaseUrl: ApiConfig.effectiveBaseUrl,
        token: result.token,
        tenantId: result.tenantId,
        tenantUserId: result.userId,
        username: result.username,
        role: result.role,
        password: password,
      );
      _api.configure(baseUrl: ApiConfig.effectiveBaseUrl, token: result.token);
      await registerPushToken();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<SyncPostResult> _postChanges(Map<String, dynamic> changes) async {
    final since = await _session.lastSyncAt;
    final body = <String, dynamic>{
      'changes': changes,
      if (since != null) 'since': since,
    };
    final json = await _api.post('/api/app/sync', body);
    return SyncPostResult.fromJson(json);
  }

  /// Descarga cambios del servidor y los aplica localmente.
  Future<String> _pullAndApply({bool full = false}) async {
    final since = full ? null : await _session.lastSyncAt;
    final path = since != null
        ? '/api/app/sync?since=${Uri.encodeComponent(since)}'
        : '/api/app/sync';
    final json = await _api.get(path);
    final bundle = SyncPullBundle.fromJson(json);
    final baseUrl = ApiConfig.effectiveBaseUrl;
    final warning = await _local.applyPull(bundle, apiBaseUrl: baseUrl);
    if (warning != null && _lastError == null) {
      _lastError = warning;
    }
    return bundle.serverTime;
  }

  void _recordConflicts(List<Map<String, dynamic>> conflicts) {
    if (conflicts.isEmpty) return;
    for (final conflict in conflicts) {
      if (conflict['entity'] == 'appointment') {
        _lastError = conflict['reason']?.toString() ??
            'No se pudo sincronizar la cita con el panel';
        _setState(SyncState.error);
        return;
      }
    }
  }

  Future<void> trySyncAfterMutation() async {
    final profile = await _session.readOfflineProfile();
    if (!await _session.isLinked && profile == null) return;
    if (!await _hasNetwork()) {
      _setState(SyncState.pending);
      return;
    }
    await syncNow();
  }

  Future<void> onConnectivityRestored() async {
    final hasProfile = await _session.readOfflineProfile();
    if (!await _session.isLinked && hasProfile == null) return;
    await syncNow();
  }

  Future<void> logout() async {
    await _session.clearToken();
    _api.configure(baseUrl: '', token: null);
    _lastError = null;
    _setState(SyncState.idle);
  }

  Future<void> unlinkBarberia() async {
    await _session.clearAll();
    _api.configure(baseUrl: '', token: null);
    _lastError = null;
    _setState(SyncState.idle);
  }

  Future<void> clearTenantSyncData() => _local.clearTenantSyncData();

  Future<void> uploadLogo(File file) async {
    await uploadLogoReturningUrl(file);
  }

  Future<LogoUploadResult?> uploadLogoReturningUrl(File file) async {
    if (!await _ensureApiReady()) return null;
    final json = await _api.uploadMultipart('/api/app/settings/logo', file);
    return LogoUploadResult.fromJson(json);
  }

  Future<String?> deleteLogoRemote() async {
    if (!await _ensureApiReady()) return null;
    final json = await _api.delete('/api/app/settings/logo');
    return json['updatedAt'] as String?;
  }

  Future<void> _flushPendingLogoActions() async {
    if (await _local.isLogoPendingUpload()) {
      final path = await _local.getLocalLogoPath();
      if (path != null && File(path).existsSync()) {
        try {
          final result = await uploadLogoReturningUrl(File(path));
          if (result != null && result.logoUrl.isNotEmpty) {
            await _local.completeLogoUpload(
              result.logoUrl,
              updatedAt: result.updatedAt,
            );
          }
        } catch (_) {
          /* reintento en próxima sync */
        }
      }
    }

    if (await _local.isLogoPendingDelete()) {
      try {
        if (await _ensureApiReady()) {
          final updatedAt = await deleteLogoRemote();
          await _local.completeLogoDelete(updatedAt: updatedAt);
        }
      } catch (_) {
        /* reintento en próxima sync */
      }
    }
  }

  Future<bool> _ensureApiReady() async {
    if (!await _session.isLinked) {
      if (!await _hasNetwork()) return false;
      return _tryReauthenticate();
    }
    await configureFromSession();
    return true;
  }

  Future<bool> _hasNetwork() async {
    final result = await _connectivity.checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }

  Future<SyncState> _resolveIdleState() async {
    if (!await _hasNetwork()) return SyncState.offline;
    if (await SyncTracker.hasPending()) return SyncState.pending;
    return SyncState.idle;
  }

  static const String appointmentBlockedMessage =
      'Las citas no se pueden subir: el barbero aún no está vinculado con el panel';

  String _formatSyncError(Object e) {
    if (e is DatabaseException && e.isUniqueConstraintError()) {
      return 'Error al fusionar citas con el panel. Reintenta la sincronización.';
    }
    if (e is ApiException) return e.message;
    return e.toString();
  }

  void _setState(SyncState value) {
    _state = value;
    onStateChanged?.call(value);
  }
}

/// Singleton para disparar sync desde repositories sin acoplar Riverpod.
class SyncCoordinator {
  SyncCoordinator._();

  static final SyncCoordinator instance = SyncCoordinator._();
  SyncService? service;

  Future<void> afterMutation() async {
    await service?.trySyncAfterMutation();
  }
}

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models/appointment.dart';
import '../data/models/barber.dart';
import '../data/models/service.dart';
import '../data/models/user.dart';
import '../data/repositories/appointment_repository.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/barber_repository.dart';
import '../data/repositories/service_repository.dart';
import '../data/models/app_settings.dart';
import '../data/models/schedule_config.dart';
import '../data/repositories/schedule_block_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../core/api/api_config.dart';
import '../core/sync/sync_service.dart';
import '../core/sync/sync_session_store.dart';

const _authUserIdKey = 'auth_user_id';
const _authUsernameKey = 'auth_username';
const _authRoleKey = 'auth_role';
const _selectedBarberIdKey = 'selected_barber_id';

final appointmentRepositoryProvider = Provider<AppointmentRepository>(
  (ref) => AppointmentRepository(),
);

final serviceRepositoryProvider = Provider<ServiceRepository>(
  (ref) => ServiceRepository(),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(),
);

final barberRepositoryProvider = Provider<BarberRepository>(
  (ref) => BarberRepository(),
);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(),
);

final syncServiceProvider = Provider<SyncService>((ref) {
  final service = SyncService();
  SyncCoordinator.instance.service = service;
  return service;
});

final syncStateProvider = NotifierProvider<SyncStateNotifier, SyncState>(
  SyncStateNotifier.new,
);

class SyncStateNotifier extends Notifier<SyncState> {
  @override
  SyncState build() {
    final service = ref.read(syncServiceProvider);
    service.onStateChanged = (state) => this.state = state;
    service.onSyncCompleted = () {
      ref.read(appSettingsProvider.notifier).refresh();
      ref.read(barbersRefreshProvider.notifier).refresh();
      ref.read(servicesRefreshProvider.notifier).refresh();
      ref.read(appointmentsRefreshProvider.notifier).refresh();
    };
    return service.state;
  }
}

final scheduleBlockRepositoryProvider = Provider<ScheduleBlockRepository>(
  (ref) => ScheduleBlockRepository(
    configProvider: () => ref.read(scheduleConfigProvider),
  ),
);

final scheduleConfigProvider = Provider<ScheduleConfig>((ref) {
  return ref.watch(appSettingsProvider).maybeWhen(
        data: (settings) => settings.scheduleConfig,
        orElse: () => ScheduleConfig.defaults(),
      );
});

class AppSettingsNotifier extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() async {
    return ref.read(settingsRepositoryProvider).getSettings();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncData(await ref.read(settingsRepositoryProvider).getSettings());
  }

  Future<void> updateShopName(String name) async {
    await ref.read(settingsRepositoryProvider).updateShopName(name);
    await refresh();
  }

  Future<void> updateAppDisplayName(String name) async {
    await ref.read(settingsRepositoryProvider).updateAppDisplayName(name);
    await refresh();
  }

  Future<String?> saveLogo(File file) async {
    final warning = await ref.read(settingsRepositoryProvider).saveLogo(file);
    await refresh();
    return warning;
  }

  Future<String?> clearLogo() async {
    final warning = await ref.read(settingsRepositoryProvider).clearLogo();
    await refresh();
    return warning;
  }

  Future<void> updateScheduleConfig(ScheduleConfig config) async {
    await ref.read(settingsRepositoryProvider).updateScheduleConfig(config);
    await refresh();
  }
}

final appSettingsProvider =
    AsyncNotifierProvider<AppSettingsNotifier, AppSettings>(
  AppSettingsNotifier.new,
);

class AuthNotifier extends AsyncNotifier<AuthSession?> {
  final _syncSession = SyncSessionStore();

  @override
  Future<AuthSession?> build() async {
    if (await _syncSession.isLinked) {
      final remote = await _syncSession.readUser();
      final tenantId = await _syncSession.tenantId;
      if (remote != null && tenantId != null) {
        await ref.read(syncServiceProvider).configureFromSession();
        return AuthSession.remote(
          remoteUserId: remote.tenantUserId,
          username: remote.username,
          role: remote.role,
          tenantId: tenantId,
          assignedBarberServerId: remote.assignedBarberServerId,
        );
      }
    }

    return null;
  }

  Future<void> _applyStaffBarberSelection(String? assignedBarberServerId) async {
    if (assignedBarberServerId != null && assignedBarberServerId.isNotEmpty) {
      await ref
          .read(selectedBarberIdProvider.notifier)
          .ensureForAssignedServerBarber(assignedBarberServerId);
      return;
    }
    await ref.read(selectedBarberIdProvider.notifier).ensureDefaultBarber();
  }

  Future<String?> loginWithPanel({
    String? apiBaseUrl,
    required String username,
    required String password,
    void Function(String phase)? onPhase,
  }) async {
    try {
      final result = await ref.read(syncServiceProvider).loginWithPanel(
            apiBaseUrl: apiBaseUrl,
            username: username,
            password: password,
            onPhase: onPhase,
          );
      final session = AuthSession.remote(
        remoteUserId: result.userId,
        username: result.username,
        role: result.role,
        tenantId: result.tenantId,
        assignedBarberServerId: result.assignedBarberServerId,
      );
      state = AsyncData(session);
      await ref.read(appSettingsProvider.notifier).refresh();
      await _applyStaffBarberSelection(result.assignedBarberServerId);
      ref.read(barbersRefreshProvider.notifier).refresh();
      ref.read(servicesRefreshProvider.notifier).refresh();
      ref.read(appointmentsRefreshProvider.notifier).refresh();
      if (result.isOffline) {
        return 'Sin conexión — entrando con credenciales guardadas.';
      }
      return result.syncWarning;
    } catch (e) {
      state = const AsyncData(null);
      if (e is ApiException) return e.message;
      return 'No se pudo iniciar sesión: $e';
    }
  }

  @Deprecated('Modo local eliminado; usar loginWithPanel')
  Future<String?> loginLocal(String username, String password) async {
    if (await _syncSession.isLinked) {
      await ref.read(syncServiceProvider).logout();
    }

    final repo = ref.read(authRepositoryProvider);
    final user = await repo.authenticate(
      username: username,
      password: password,
    );

    if (user == null || user.isPanelUser) {
      state = const AsyncData(null);
      return 'Usuario o contraseña incorrectos.';
    }

    final session = AuthSession.fromUser(user);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_authUserIdKey, session.userId);
    await prefs.setString(_authUsernameKey, session.username);
    await prefs.setString(_authRoleKey, session.role);

    state = AsyncData(session);
    await ref.read(selectedBarberIdProvider.notifier).ensureDefaultBarber();
    ref.read(barbersRefreshProvider.notifier).refresh();
    ref.read(servicesRefreshProvider.notifier).refresh();
    ref.read(appointmentsRefreshProvider.notifier).refresh();
    await ref.read(appSettingsProvider.notifier).refresh();
    return null;
  }

  @Deprecated('Use loginWithPanel')
  Future<String?> login(String username, String password) =>
      loginLocal(username, password);

  @Deprecated('Use loginWithPanel')
  Future<String?> loginRemote({
    String? apiBaseUrl,
    required String username,
    required String password,
    void Function(String phase)? onPhase,
  }) =>
      loginWithPanel(
        apiBaseUrl: apiBaseUrl,
        username: username,
        password: password,
        onPhase: onPhase,
      );

  Future<void> logout() async {
    if (await _syncSession.isLinked) {
      await ref.read(syncServiceProvider).logout();
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_authUserIdKey);
    await prefs.remove(_authUsernameKey);
    await prefs.remove(_authRoleKey);
    state = const AsyncData(null);
  }
}

final authProvider =
    AsyncNotifierProvider<AuthNotifier, AuthSession?>(AuthNotifier.new);

class SelectedBarberIdNotifier extends AsyncNotifier<int?> {
  @override
  Future<int?> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_selectedBarberIdKey);
  }

  Future<void> ensureForAssignedServerBarber(String serverBarberId) async {
    final barberRepo = ref.read(barberRepositoryProvider);
    final localId = await barberRepo.findLocalIdByServerId(serverBarberId);
    if (localId != null) {
      await selectBarber(localId);
      return;
    }
    await ensureDefaultBarber();
  }

  Future<void> ensureDefaultBarber() async {
    final barberRepo = ref.read(barberRepositoryProvider);
    final activeBarbers = await barberRepo.getActiveBarbers();
    if (activeBarbers.isEmpty) {
      state = const AsyncData(null);
      return;
    }

    final current = state.value;
    final isValid = current != null &&
        activeBarbers.any((barber) => barber.id == current);

    if (isValid) return;

    await selectBarber(activeBarbers.first.id);
  }

  Future<void> selectBarber(int barberId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_selectedBarberIdKey, barberId);
    state = AsyncData(barberId);
  }
}

final selectedBarberIdProvider =
    AsyncNotifierProvider<SelectedBarberIdNotifier, int?>(
  SelectedBarberIdNotifier.new,
);

class SelectedDateNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  void setDate(DateTime date) {
    state = DateTime(date.year, date.month, date.day);
  }
}

final selectedDateProvider =
    NotifierProvider<SelectedDateNotifier, DateTime>(SelectedDateNotifier.new);

final selectedDateStringProvider = Provider<String>((ref) {
  final date = ref.watch(selectedDateProvider);
  return DateFormat('yyyy-MM-dd').format(date);
});

class AppointmentsRefreshNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void refresh() => state++;
}

final appointmentsRefreshProvider =
    NotifierProvider<AppointmentsRefreshNotifier, int>(
  AppointmentsRefreshNotifier.new,
);

final appointmentsForDateProvider =
    FutureProvider.autoDispose<List<Appointment>>((ref) async {
  ref.watch(appointmentsRefreshProvider);
  final barberId = ref.watch(selectedBarberIdProvider).value;
  if (barberId == null) return [];

  final date = ref.watch(selectedDateStringProvider);
  final repo = ref.watch(appointmentRepositoryProvider);
  return repo.getAppointmentsByDate(date, barberId: barberId);
});

final appointmentDetailProvider =
    FutureProvider.autoDispose.family<Appointment?, int>((ref, id) async {
  ref.watch(appointmentsRefreshProvider);
  final repo = ref.watch(appointmentRepositoryProvider);
  return repo.getAppointmentById(id);
});

class CanceledFilterDateNotifier extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;

  void setDate(DateTime? date) {
    state = date == null
        ? null
        : DateTime(date.year, date.month, date.day);
  }

  void clear() => state = null;
}

final canceledFilterDateProvider =
    NotifierProvider<CanceledFilterDateNotifier, DateTime?>(
  CanceledFilterDateNotifier.new,
);

final canceledAppointmentsProvider =
    FutureProvider.autoDispose<List<Appointment>>((ref) async {
  ref.watch(appointmentsRefreshProvider);
  final filterDate = ref.watch(canceledFilterDateProvider);
  final dateString =
      filterDate == null ? null : DateFormat('yyyy-MM-dd').format(filterDate);
  final barberId = ref.watch(selectedBarberIdProvider).value;
  final auth = ref.watch(authProvider).value;
  final scopedBarberId = auth?.isStaff == true ? barberId : barberId;
  final repo = ref.watch(appointmentRepositoryProvider);
  return repo.getCanceledAppointments(
    date: dateString,
    barberId: auth?.isStaff == true ? scopedBarberId : null,
  );
});

final activeServicesProvider =
    FutureProvider.autoDispose<List<BarberService>>((ref) async {
  ref.watch(servicesRefreshProvider);
  final repo = ref.watch(serviceRepositoryProvider);
  return repo.getActiveServices();
});

class ServicesRefreshNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void refresh() => state++;
}

final servicesRefreshProvider =
    NotifierProvider<ServicesRefreshNotifier, int>(
  ServicesRefreshNotifier.new,
);

final allServicesProvider =
    FutureProvider.autoDispose<List<BarberService>>((ref) async {
  ref.watch(servicesRefreshProvider);
  final repo = ref.watch(serviceRepositoryProvider);
  return repo.getAllServices();
});

class BarbersRefreshNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void refresh() => state++;
}

final barbersRefreshProvider =
    NotifierProvider<BarbersRefreshNotifier, int>(BarbersRefreshNotifier.new);

final activeBarbersProvider =
    FutureProvider.autoDispose<List<Barber>>((ref) async {
  ref.watch(barbersRefreshProvider);
  final repo = ref.watch(barberRepositoryProvider);
  return repo.getActiveBarbers();
});

final allBarbersProvider = FutureProvider.autoDispose<List<Barber>>((ref) async {
  ref.watch(barbersRefreshProvider);
  final repo = ref.watch(barberRepositoryProvider);
  return repo.getAllBarbers();
});

void refreshAppointments(WidgetRef ref) {
  ref.read(appointmentsRefreshProvider.notifier).refresh();
}

void refreshServices(WidgetRef ref) {
  ref.read(servicesRefreshProvider.notifier).refresh();
}

void refreshBarbers(WidgetRef ref) {
  ref.read(barbersRefreshProvider.notifier).refresh();
}

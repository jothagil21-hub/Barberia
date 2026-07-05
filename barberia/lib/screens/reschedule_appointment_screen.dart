import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../core/constants/service_duration_constants.dart';
import '../core/notifications/appointment_notification_sync.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/time_slot_generator.dart';
import '../data/models/service.dart';
import '../data/repositories/appointment_repository.dart';
import '../providers/providers.dart';
import '../widgets/app_section_title.dart';
import '../widgets/barber_selector.dart';
import '../widgets/date_selector.dart';
import '../widgets/service_checkbox_list.dart';
import '../widgets/time_slot_grid.dart';
import '../widgets/time_slot_legend.dart';

class RescheduleAppointmentScreen extends ConsumerStatefulWidget {
  const RescheduleAppointmentScreen({super.key, required this.appointmentId});

  final int appointmentId;

  @override
  ConsumerState<RescheduleAppointmentScreen> createState() =>
      _RescheduleAppointmentScreenState();
}

class _RescheduleAppointmentScreenState
    extends ConsumerState<RescheduleAppointmentScreen> {
  late DateTime _selectedDate;
  String? _selectedSlot;
  String _clientName = '';
  int? _barberId;
  final Set<int> _selectedServiceIds = {};
  List<TimeSlotEntry> _slotEntries = [];
  List<String> _bookedSlots = [];
  List<String> _blockedTimes = [];
  bool _loading = true;
  bool _loadingSlots = true;
  bool _saving = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadAppointment();
  }

  Future<void> _loadAppointment() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
      final repo = ref.read(appointmentRepositoryProvider);
      final appointment = await repo.getAppointmentById(widget.appointmentId);
      if (appointment == null || !appointment.isScheduled) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _loadError = 'Cita no encontrada o no activa';
        });
        return;
      }

      if (!appointment.canModify) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _loadError = 'Esta cita ya pasó y no puede reagendarse';
        });
        return;
      }

      final serviceIds =
          await repo.getServiceIdsForAppointment(widget.appointmentId);
      final parsedDate = DateTime.parse(appointment.date);

      if (!mounted) return;
      setState(() {
        _clientName = appointment.clientName;
        _barberId = appointment.barberId;
        _selectedDate = DateTime(
          parsedDate.year,
          parsedDate.month,
          parsedDate.day,
        );
        _selectedSlot = appointment.time;
        _selectedServiceIds
          ..clear()
          ..addAll(serviceIds);
        _loading = false;
      });

      await ref
          .read(selectedBarberIdProvider.notifier)
          .selectBarber(appointment.barberId);
      await _loadAvailableSlots();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = error.toString();
      });
    }
  }

  Future<void> _loadAvailableSlots({bool showLoading = true}) async {
    final barberId = ref.read(selectedBarberIdProvider).value ?? _barberId;
    if (barberId == null) return;

    if (showLoading) {
      setState(() => _loadingSlots = true);
    }

    final date = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final repo = ref.read(appointmentRepositoryProvider);
    final blockRepo = ref.read(scheduleBlockRepositoryProvider);
    final booked = await repo.getOccupiedSlots(
      date,
      barberId: barberId,
      excludeAppointmentId: widget.appointmentId,
    );
    final blocked = await blockRepo.getBlockedTimes(
      barberId: barberId,
      date: date,
    );

    final services = ref.read(activeServicesProvider).value ?? [];

    if (!mounted) return;

    setState(() {
      _barberId = barberId;
      _bookedSlots = booked;
      _blockedTimes = blocked;
      _loadingSlots = false;
      _rebuildSlotEntries(services: services);
    });
  }

  void _rebuildSlotEntries({
    required List<BarberService> services,
  }) {
    final durationMinutes = _totalDurationMinutes(services);

    _slotEntries = durationMinutes > 0
        ? TimeSlotGenerator.buildBookingGrid(
            config: ref.read(scheduleConfigProvider),
            date: _selectedDate,
            occupiedSlots: _bookedSlots,
            blockedTimes: _blockedTimes,
            durationMinutes: durationMinutes,
          )
        : <TimeSlotEntry>[];

    final selectedIsSelectable = _selectedSlot != null &&
        _slotEntries.any(
          (entry) => entry.time == _selectedSlot && entry.isSelectable,
        );
    if (!selectedIsSelectable) {
      String? firstAvailable;
      for (final entry in _slotEntries) {
        if (entry.isSelectable) {
          firstAvailable = entry.time;
          break;
        }
      }
      _selectedSlot = firstAvailable;
    }
  }

  int _totalDurationMinutes(List<BarberService> services) {
    if (_selectedServiceIds.isEmpty) {
      return ServiceDurationConstants.defaultMinutes;
    }
    return services
        .where((service) => _selectedServiceIds.contains(service.id))
        .fold<int>(0, (sum, service) => sum + service.durationMinutes);
  }

  int get _selectedDurationMinutes {
    final services = ref.read(activeServicesProvider).value ?? [];
    return _totalDurationMinutes(services);
  }

  int get _blockCount =>
      (_selectedDurationMinutes / ServiceDurationConstants.blockMinutes).ceil();

  bool get _canSave {
    final slotIsAvailable = _selectedSlot != null &&
        _slotEntries.any(
          (entry) => entry.time == _selectedSlot && entry.isSelectable,
        );

    return _barberId != null &&
        slotIsAvailable &&
        _selectedServiceIds.isNotEmpty &&
        !_saving &&
        !_loading;
  }

  Future<void> _save() async {
    if (!_canSave) return;

    setState(() => _saving = true);

    try {
      final repo = ref.read(appointmentRepositoryProvider);
      await repo.updateAppointment(
        id: widget.appointmentId,
        barberId: _barberId!,
        date: DateFormat('yyyy-MM-dd').format(_selectedDate),
        time: _selectedSlot!,
        serviceIds: _selectedServiceIds.toList(),
      );

      final reminderResult =
          await syncReminderById(repo, widget.appointmentId);
      refreshAppointments(ref);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cita reagendada correctamente')),
      );
      showReminderSyncSnackBar(
        reminderResult,
        (message) => ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        ),
      );
      context.pop();
    } on SlotAlreadyBookedException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ese horario ya fue reservado.')),
      );
      await _loadAvailableSlots();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al reagendar: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final servicesAsync = ref.watch(activeServicesProvider);
    ref.listen(selectedBarberIdProvider, (_, __) => _loadAvailableSlots());
    ref.listen(scheduleConfigProvider, (_, __) => _loadAvailableSlots());

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Reagendar cita')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Reagendar cita')),
        body: Center(child: Text(_loadError!)),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Reagendar cita')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const AppSectionTitle('Cliente'),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(
                _clientName,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const AppSectionTitle('Barbero'),
          const SizedBox(height: 8),
          const BarberSelector(),
          const SizedBox(height: 24),
          const AppSectionTitle('1. Selecciona el día'),
          const SizedBox(height: 8),
          DateSelector(
            selectedDate: _selectedDate,
            onDateChanged: (date) {
              setState(() => _selectedDate = date);
              _loadAvailableSlots();
            },
          ),
          const SizedBox(height: 24),
          const AppSectionTitle('2. Selecciona la hora'),
          const SizedBox(height: 8),
          if (_loadingSlots)
            const Center(child: CircularProgressIndicator())
          else if (_slotEntries.isEmpty)
            const Text('No hay horarios para este día')
          else ...[
            const TimeSlotLegend(mode: TimeSlotLegendMode.booking),
            const SizedBox(height: 12),
            TimeSlotGrid(
              entries: _slotEntries,
              selectedSlot: _selectedSlot,
              onSlotSelected: (slot) => setState(() => _selectedSlot = slot),
            ),
            if (!_slotEntries.any((entry) => entry.isSelectable))
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'No hay horarios libres para reservar en este día.',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
          ],
          const SizedBox(height: 24),
          const AppSectionTitle('3. Servicios'),
          servicesAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Text('Error: $error'),
            data: (services) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _selectedServiceIds.isEmpty
                        ? 'Selecciona al menos un servicio.'
                        : 'Duración total: $_selectedDurationMinutes min '
                            '(ocupa $_blockCount bloques)',
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
                ServiceCheckboxList(
                  services: services,
                  selectedIds: _selectedServiceIds,
                  onChanged: (id, selected) {
                    setState(() {
                      if (selected) {
                        _selectedServiceIds.add(id);
                      } else {
                        _selectedServiceIds.remove(id);
                      }
                      _rebuildSlotEntries(services: services);
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _canSave ? _save : null,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.event_repeat),
            label: Text(_saving ? 'Guardando...' : 'Guardar cambios'),
          ),
        ],
      ),
    );
  }
}

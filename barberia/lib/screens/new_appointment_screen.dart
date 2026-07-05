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

class NewAppointmentScreen extends ConsumerStatefulWidget {
  const NewAppointmentScreen({super.key});

  @override
  ConsumerState<NewAppointmentScreen> createState() =>
      _NewAppointmentScreenState();
}

class _NewAppointmentScreenState extends ConsumerState<NewAppointmentScreen> {
  late DateTime _selectedDate;
  String? _selectedSlot;
  final _nameController = TextEditingController();
  final Set<int> _selectedServiceIds = {};
  List<TimeSlotEntry> _slotEntries = [];
  List<String> _bookedSlots = [];
  List<String> _blockedTimes = [];
  bool _loadingSlots = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAvailableSlots());
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  int? get _barberId => ref.read(selectedBarberIdProvider).value;

  Future<void> _loadAvailableSlots() async {
    final barberId = _barberId;
    if (barberId == null) {
      setState(() {
        _slotEntries = [];
        _bookedSlots = [];
        _blockedTimes = [];
        _loadingSlots = false;
      });
      return;
    }

    setState(() {
      _loadingSlots = true;
      _selectedSlot = null;
    });

    final date = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final repo = ref.read(appointmentRepositoryProvider);
    final blockRepo = ref.read(scheduleBlockRepositoryProvider);
    final booked = await repo.getOccupiedSlots(date, barberId: barberId);
    final blocked = await blockRepo.getBlockedTimes(
      barberId: barberId,
      date: date,
    );

    if (!mounted) return;

    setState(() {
      _bookedSlots = booked;
      _blockedTimes = blocked;
      _loadingSlots = false;
      _rebuildSlotEntries(clearSelection: true);
    });
  }

  void _rebuildSlotEntries({bool clearSelection = false}) {
    final services = ref.read(activeServicesProvider).value ?? [];
    final durationMinutes = _totalDurationMinutes(services);

    _slotEntries = durationMinutes > 0
        ? TimeSlotGenerator.buildBookingGrid(
            config: ref.read(scheduleConfigProvider),
            date: _selectedDate,
            occupiedSlots: _bookedSlots,
            blockedTimes: _blockedTimes,
            durationMinutes: durationMinutes,
          )
        : [];

    if (clearSelection) {
      _selectedSlot = null;
    } else if (_selectedSlot != null &&
        !_slotEntries.any(
          (entry) => entry.time == _selectedSlot && entry.isSelectable,
        )) {
      _selectedSlot = null;
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
        _nameController.text.trim().isNotEmpty &&
        slotIsAvailable &&
        _selectedServiceIds.isNotEmpty &&
        !_saving;
  }

  Future<void> _save() async {
    if (!_canSave) return;

    setState(() => _saving = true);

    try {
      final repo = ref.read(appointmentRepositoryProvider);
      final id = await repo.createAppointment(
        clientName: _nameController.text.trim(),
        barberId: _barberId!,
        date: DateFormat('yyyy-MM-dd').format(_selectedDate),
        time: _selectedSlot!,
        serviceIds: _selectedServiceIds.toList(),
      );

      final reminderResult = await syncReminderById(repo, id);
      refreshAppointments(ref);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cita guardada correctamente')),
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
        SnackBar(content: Text('Error al guardar: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final servicesAsync = ref.watch(activeServicesProvider);
    ref.listen(selectedBarberIdProvider, (_, __) => _loadAvailableSlots());
    ref.listen(scheduleConfigProvider, (_, __) {
      if (!_loadingSlots) {
        setState(() => _rebuildSlotEntries());
      } else {
        _loadAvailableSlots();
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Nueva cita')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
          if (_barberId == null)
            const Text('Selecciona un barbero para ver horarios.')
          else if (_loadingSlots)
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
          const AppSectionTitle('3. Datos del cliente'),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Nombre del cliente',
              prefixIcon: Icon(Icons.person_outline),
            ),
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          const AppSectionTitle('Servicios'),
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
                      _rebuildSlotEntries();
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
                : const Icon(Icons.save),
            label: Text(_saving ? 'Guardando...' : 'Guardar cita'),
          ),
        ],
      ),
    );
  }
}

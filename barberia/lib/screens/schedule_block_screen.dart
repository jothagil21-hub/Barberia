import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/utils/time_slot_generator.dart';
import '../data/models/schedule_block.dart';
import '../providers/providers.dart';
import '../widgets/app_section_title.dart';
import '../widgets/barber_selector.dart';
import '../widgets/date_selector.dart';
import '../widgets/time_slot_grid.dart';
import '../widgets/time_slot_legend.dart';

class ScheduleBlockScreen extends ConsumerStatefulWidget {
  const ScheduleBlockScreen({super.key});

  @override
  ConsumerState<ScheduleBlockScreen> createState() =>
      _ScheduleBlockScreenState();
}

class _ScheduleBlockScreenState extends ConsumerState<ScheduleBlockScreen> {
  late DateTime _selectedDate;
  List<ScheduleBlock> _blocks = [];
  List<TimeSlotEntry> _slotEntries = [];
  bool _fullDayBlocked = false;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = ref.read(selectedDateProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadBlocks());
  }

  int? get _barberId => ref.read(selectedBarberIdProvider).value;

  Future<void> _loadBlocks() async {
    final barberId = _barberId;
    if (barberId == null) {
      setState(() {
        _blocks = [];
        _slotEntries = [];
        _fullDayBlocked = false;
        _loading = false;
      });
      return;
    }

    setState(() => _loading = true);

    final date = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final repo = ref.read(scheduleBlockRepositoryProvider);
    final blocks = await repo.getBlocksForDate(barberId: barberId, date: date);
    final blockedTimes = await repo.getBlockedTimes(
      barberId: barberId,
      date: date,
    );
    final scheduleConfig = ref.read(scheduleConfigProvider);

    if (!mounted) return;

    final fullDay = blocks.any((block) => block.isFullDay);
    final entries = TimeSlotGenerator.generateAllSlots(scheduleConfig).map((slot) {
      return TimeSlotEntry(
        time: slot,
        status: blockedTimes.contains(slot)
            ? TimeSlotStatus.blocked
            : TimeSlotStatus.available,
      );
    }).toList();

    setState(() {
      _blocks = blocks;
      _fullDayBlocked = fullDay;
      _slotEntries = entries;
      _loading = false;
    });
  }

  Future<void> _setFullDayBlocked(bool value) async {
    final barberId = _barberId;
    if (barberId == null) return;

    setState(() => _saving = true);
    final date = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final repo = ref.read(scheduleBlockRepositoryProvider);

    try {
      if (value) {
        await repo.blockFullDay(barberId: barberId, date: date);
      } else {
        await repo.unblockFullDay(barberId: barberId, date: date);
      }
      await _loadBlocks();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value ? 'Día bloqueado completo.' : 'Bloqueo de día eliminado.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggleSlot(String time, bool block) async {
    final barberId = _barberId;
    if (barberId == null || _fullDayBlocked) return;

    setState(() => _saving = true);
    final date = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final repo = ref.read(scheduleBlockRepositoryProvider);

    try {
      if (block) {
        await repo.blockSlots(
          barberId: barberId,
          date: date,
          times: [time],
        );
      } else {
        await repo.unblockSlot(
          barberId: barberId,
          date: date,
          time: time,
        );
      }
      await _loadBlocks();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Set<String> get _blockedSlots {
    return _slotEntries
        .where((entry) => entry.status == TimeSlotStatus.blocked)
        .map((entry) => entry.time)
        .toSet();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(selectedBarberIdProvider, (_, __) => _loadBlocks());
    ref.listen(scheduleConfigProvider, (_, __) => _loadBlocks());

    return Scaffold(
      appBar: AppBar(title: const Text('Bloquear horarios')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const AppSectionTitle('Barbero'),
          const SizedBox(height: 8),
          const BarberSelector(),
          const SizedBox(height: 24),
          const AppSectionTitle('Fecha'),
          const SizedBox(height: 8),
          DateSelector(
            selectedDate: _selectedDate,
            allowPastDates: true,
            onDateChanged: (date) {
              setState(() => _selectedDate = date);
              _loadBlocks();
            },
          ),
          const SizedBox(height: 24),
          if (_barberId == null)
            const Text('Selecciona un barbero para gestionar bloqueos.')
          else if (_loading)
            const Center(child: CircularProgressIndicator())
          else ...[
            SwitchListTile(
              title: const Text('Bloquear día completo'),
              subtitle: const Text(
                'Impide reservar cualquier horario de este día.',
              ),
              value: _fullDayBlocked,
              onChanged: _saving ? null : _setFullDayBlocked,
            ),
            if (!_fullDayBlocked) ...[
              const SizedBox(height: 16),
              const AppSectionTitle('Horarios bloqueados'),
              const SizedBox(height: 8),
              const Text(
                'Toca un horario para bloquearlo o desbloquearlo.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              const TimeSlotLegend(),
              const SizedBox(height: 16),
              TimeSlotGrid(
                entries: _slotEntries,
                selectedSlot: null,
                onSlotSelected: (_) {},
                multiSelect: true,
                selectedSlots: _blockedSlots,
                onMultiSelectChanged: (slot, selected) =>
                    _toggleSlot(slot, selected),
              ),
            ],
            if (_blocks.isNotEmpty) ...[
              const SizedBox(height: 24),
              const AppSectionTitle('Bloqueos activos'),
              const SizedBox(height: 8),
              ..._blocks.map((block) {
                final label = block.isFullDay
                    ? 'Día completo'
                    : 'Horario ${block.time}';
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(label),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: _saving
                        ? null
                        : () async {
                            if (block.isFullDay) {
                              await _setFullDayBlocked(false);
                            } else if (block.time != null) {
                              await _toggleSlot(block.time!, false);
                            }
                          },
                  ),
                );
              }),
            ],
          ],
        ],
      ),
    );
  }
}

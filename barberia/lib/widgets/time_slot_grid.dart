import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/time_slot_generator.dart';

class TimeSlotGrid extends StatelessWidget {
  const TimeSlotGrid({
    super.key,
    required this.entries,
    required this.selectedSlot,
    required this.onSlotSelected,
    this.multiSelect = false,
    this.selectedSlots = const {},
    this.onMultiSelectChanged,
  });

  final List<TimeSlotEntry> entries;
  final String? selectedSlot;
  final ValueChanged<String> onSlotSelected;
  final bool multiSelect;
  final Set<String> selectedSlots;
  final void Function(String slot, bool selected)? onMultiSelectChanged;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Sin horarios disponibles para este día.'),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: entries.map(_buildSlotChip).toList(),
    );
  }

  Widget _buildSlotChip(TimeSlotEntry entry) {
    final isSelected = multiSelect
        ? selectedSlots.contains(entry.time)
        : entry.time == selectedSlot;
    final isPast = entry.status == TimeSlotStatus.pastUnavailable;
    final isBlocked = entry.status == TimeSlotStatus.blocked;
    final isBooked = entry.status == TimeSlotStatus.booked;
    final isBlockMode = multiSelect && !isPast;
    final isBookingMode = !multiSelect;

    final chip = ChoiceChip(
      key: Key(_chipKey(entry)),
      label: Text(
        entry.time,
        style: TextStyle(
          color: _labelColor(
            entry: entry,
            isPast: isPast,
            isBlocked: isBlocked,
            isBooked: isBooked,
            isSelected: isSelected,
            isBlockMode: isBlockMode,
            isBookingMode: isBookingMode,
          ),
          fontWeight: (isBlockMode && isBlocked) || (isBookingMode && isBlocked)
              ? FontWeight.bold
              : FontWeight.normal,
        ),
      ),
      showCheckmark: false,
      selected: _chipSelected(
        isBlockMode: isBlockMode,
        isBookingMode: isBookingMode,
        isBlocked: isBlocked,
        isSelected: isSelected,
      ),
      onSelected: entry.isSelectable || (multiSelect && isBlocked)
          ? (_) {
              if (multiSelect) {
                onMultiSelectChanged?.call(entry.time, !isSelected);
              } else if (entry.isSelectable) {
                onSlotSelected(entry.time);
              }
            }
          : null,
      backgroundColor: _backgroundColor(
        isBlockMode: isBlockMode,
        isBookingMode: isBookingMode,
        isBlocked: isBlocked,
        isBooked: isBooked,
        isPast: isPast,
      ),
      selectedColor: _selectedColor(
        isBlockMode: isBlockMode,
        isBookingMode: isBookingMode,
        isBlocked: isBlocked,
      ),
      disabledColor: AppTheme.surface,
      side: BorderSide(
        color: _borderColor(
          isBlockMode: isBlockMode,
          isBookingMode: isBookingMode,
          isBlocked: isBlocked,
          isBooked: isBooked,
          isPast: isPast,
        ),
        width: isBlockMode || isBookingMode ? 1.5 : 1,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );

    final tooltip = _tooltipMessage(
      isBlockMode: isBlockMode,
      isBookingMode: isBookingMode,
      isPast: isPast,
      isBlocked: isBlocked,
      isBooked: isBooked,
    );

    if (tooltip == null) {
      return chip;
    }

    final wrapped = Tooltip(message: tooltip, child: chip);

    if (isPast || (isBlocked && isBookingMode) || isBooked) {
      return Opacity(
        opacity: isPast ? 0.55 : 0.85,
        child: wrapped,
      );
    }

    return wrapped;
  }

  String _chipKey(TimeSlotEntry entry) {
    if (multiSelect) {
      return entry.status == TimeSlotStatus.blocked
          ? 'slot-blocked-${entry.time}'
          : 'slot-available-${entry.time}';
    }

    switch (entry.status) {
      case TimeSlotStatus.available:
        return 'slot-available-${entry.time}';
      case TimeSlotStatus.blocked:
        return 'slot-blocked-${entry.time}';
      case TimeSlotStatus.booked:
        return 'slot-booked-${entry.time}';
      case TimeSlotStatus.pastUnavailable:
        return 'slot-past-${entry.time}';
    }
  }

  bool _chipSelected({
    required bool isBlockMode,
    required bool isBookingMode,
    required bool isBlocked,
    required bool isSelected,
  }) {
    if (isBlockMode) return isBlocked;
    if (isBookingMode) return isSelected;
    return isSelected;
  }

  Color _backgroundColor({
    required bool isBlockMode,
    required bool isBookingMode,
    required bool isBlocked,
    required bool isBooked,
    required bool isPast,
  }) {
    if (isBlockMode && !isBlocked) {
      return AppTheme.slotAvailableBackground;
    }
    if (isBookingMode) {
      if (isBooked) return AppTheme.slotBookedBackground;
      if (isBlocked) return AppTheme.slotBlockedBackground;
      if (isPast) return AppTheme.surface;
      return AppTheme.slotAvailableBackground;
    }
    return AppTheme.surface;
  }

  Color _selectedColor({
    required bool isBlockMode,
    required bool isBookingMode,
    required bool isBlocked,
  }) {
    if (isBlockMode) return AppTheme.slotBlockedBackground;
    if (isBookingMode && isBlocked) return AppTheme.slotBlockedBackground;
    return AppTheme.accent.withValues(alpha: 0.35);
  }

  Color _borderColor({
    required bool isBlockMode,
    required bool isBookingMode,
    required bool isBlocked,
    required bool isBooked,
    required bool isPast,
  }) {
    if (isBlockMode || isBookingMode) {
      if (isBlocked) return AppTheme.slotBlockedBorder;
      if (isBooked) return AppTheme.slotBookedBorder;
      if (isPast) return AppTheme.canceled;
      return AppTheme.slotAvailableBorder;
    }
    return AppTheme.accent;
  }

  String? _tooltipMessage({
    required bool isBlockMode,
    required bool isBookingMode,
    required bool isPast,
    required bool isBlocked,
    required bool isBooked,
  }) {
    if (isBlockMode) {
      return isBlocked ? 'Toca para desbloquear' : 'Toca para bloquear';
    }
    if (isBookingMode) {
      if (isPast) return 'Horario pasado';
      if (isBlocked) return 'Horario bloqueado';
      if (isBooked) return 'Ya tiene cita programada';
      return null;
    }
    if (isPast) return 'Horario pasado';
    if (isBlocked) return 'Horario bloqueado';
    return null;
  }

  Color _labelColor({
    required TimeSlotEntry entry,
    required bool isPast,
    required bool isBlocked,
    required bool isBooked,
    required bool isSelected,
    required bool isBlockMode,
    required bool isBookingMode,
  }) {
    if (isBlockMode) {
      return isBlocked
          ? AppTheme.slotBlockedForeground
          : AppTheme.slotAvailableForeground;
    }

    if (isBookingMode) {
      if (isPast) return AppTheme.canceled;
      if (isBlocked) return AppTheme.slotBlockedForeground;
      if (isBooked) return AppTheme.slotBookedForeground;
      if (isSelected) return AppTheme.accent;
      return AppTheme.slotAvailableForeground;
    }

    if (isPast || isBlocked) return AppTheme.canceled;
    if (isSelected) return AppTheme.accent;
    return AppTheme.textPrimary;
  }
}

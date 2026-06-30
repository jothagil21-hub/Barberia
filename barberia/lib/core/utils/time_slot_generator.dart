import '../../core/constants/service_duration_constants.dart';
import '../../core/utils/appointment_slot_utils.dart';
import '../../data/models/schedule_config.dart';

enum TimeSlotStatus { available, pastUnavailable, blocked, booked }

class TimeSlotEntry {
  const TimeSlotEntry({
    required this.time,
    required this.status,
  });

  final String time;
  final TimeSlotStatus status;

  bool get isSelectable => status == TimeSlotStatus.available;
}

class TimeSlotGenerator {
  static List<String> generateAllSlots(ScheduleConfig config) {
    return generateSlots(
      start: config.startTime,
      end: config.endTime,
      intervalMinutes: config.intervalMinutes,
    );
  }

  static List<String> generateSlots({
    required String start,
    required String end,
    required int intervalMinutes,
  }) {
    final slots = <String>[];
    var current = _parseTime(start);
    final endMinutes = _parseTime(end);

    while (current <= endMinutes) {
      slots.add(_formatTime(current));
      current += intervalMinutes;
    }

    return slots;
  }

  static List<String> getAvailableSlots(
    List<String> bookedTimes, {
    required ScheduleConfig config,
    required DateTime date,
    List<String> blockedTimes = const [],
    DateTime? reference,
  }) {
    return buildSelectableGrid(
      config: config,
      date: date,
      bookedTimes: bookedTimes,
      blockedTimes: blockedTimes,
      reference: reference,
    )
        .where((entry) => entry.isSelectable)
        .map((entry) => entry.time)
        .toList();
  }

  static List<TimeSlotEntry> buildSelectableGrid({
    required ScheduleConfig config,
    required DateTime date,
    required List<String> bookedTimes,
    List<String> blockedTimes = const [],
    DateTime? reference,
  }) {
    final now = reference ?? DateTime.now();
    final day = DateTime(date.year, date.month, date.day);
    final today = DateTime(now.year, now.month, now.day);
    final isToday =
        day.year == today.year && day.month == today.month && day.day == today.day;

    final entries = <TimeSlotEntry>[];
    final blockedSet = blockedTimes.toSet();

    for (final slot in generateAllSlots(config)) {
      if (bookedTimes.contains(slot)) {
        entries.add(TimeSlotEntry(
          time: slot,
          status: TimeSlotStatus.booked,
        ));
        continue;
      }

      if (blockedSet.contains(slot)) {
        entries.add(TimeSlotEntry(
          time: slot,
          status: TimeSlotStatus.blocked,
        ));
        continue;
      }

      if (isToday && _slotDateTime(day, slot).isBefore(now)) {
        entries.add(TimeSlotEntry(
          time: slot,
          status: TimeSlotStatus.pastUnavailable,
        ));
      } else {
        entries.add(TimeSlotEntry(
          time: slot,
          status: TimeSlotStatus.available,
        ));
      }
    }

    return entries;
  }

  static List<TimeSlotEntry> buildBookingGrid({
    required ScheduleConfig config,
    required DateTime date,
    required List<String> occupiedSlots,
    required int durationMinutes,
    List<String> blockedTimes = const [],
    DateTime? reference,
  }) {
    final bookingConfig = config.copyWith(
      intervalMinutes: ServiceDurationConstants.blockMinutes,
    );
    final occupiedSet = occupiedSlots.toSet();
    final blockedSet = blockedTimes.toSet();
    final now = reference ?? DateTime.now();
    final day = DateTime(date.year, date.month, date.day);
    final today = DateTime(now.year, now.month, now.day);
    final isToday =
        day.year == today.year && day.month == today.month && day.day == today.day;

    final entries = <TimeSlotEntry>[];

    for (final slot in generateAllSlots(bookingConfig)) {
      final slotOccupied = occupiedSet.contains(slot);
      final slotBlocked = blockedSet.contains(slot);
      final isPast =
          isToday && _slotDateTime(day, slot).isBefore(now);

      final fits = AppointmentSlotUtils.canFitAtStart(
        startTime: slot,
        durationMinutes: durationMinutes,
        scheduleEnd: config.endTime,
        occupiedSlots: occupiedSet,
        blockedSlots: blockedSet,
      );

      if (!fits) {
        if (slotOccupied) {
          entries.add(TimeSlotEntry(time: slot, status: TimeSlotStatus.booked));
        } else if (slotBlocked) {
          entries.add(TimeSlotEntry(time: slot, status: TimeSlotStatus.blocked));
        } else if (isPast) {
          entries.add(
            TimeSlotEntry(time: slot, status: TimeSlotStatus.pastUnavailable),
          );
        } else {
          entries.add(
            TimeSlotEntry(time: slot, status: TimeSlotStatus.pastUnavailable),
          );
        }
        continue;
      }

      if (isPast) {
        entries.add(TimeSlotEntry(time: slot, status: TimeSlotStatus.pastUnavailable));
      } else {
        entries.add(TimeSlotEntry(time: slot, status: TimeSlotStatus.available));
      }
    }

    return entries;
  }

  static DateTime _slotDateTime(DateTime day, String slot) {
    final parts = slot.split(':');
    return DateTime(
      day.year,
      day.month,
      day.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }

  static int _parseTime(String time) {
    final parts = time.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  static String _formatTime(int totalMinutes) {
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
  }
}

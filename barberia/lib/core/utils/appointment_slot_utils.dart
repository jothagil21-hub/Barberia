import '../constants/service_duration_constants.dart';

class ScheduledRange {
  const ScheduledRange({
    required this.startTime,
    required this.durationMinutes,
    this.excludeAppointmentId,
  });

  final String startTime;
  final int durationMinutes;
  final int? excludeAppointmentId;
}

class AppointmentSlotUtils {
  AppointmentSlotUtils._();

  static int timeToMinutes(String time) {
    final parts = time.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  static String minutesToTime(int totalMinutes) {
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
  }

  static List<String> expandOccupiedSlots({
    required String startTime,
    required int durationMinutes,
  }) {
    ServiceDurationConstants.validate(durationMinutes);
    final start = timeToMinutes(startTime);
    final slots = <String>[];
    for (var offset = 0; offset < durationMinutes; offset += ServiceDurationConstants.blockMinutes) {
      slots.add(minutesToTime(start + offset));
    }
    return slots;
  }

  static bool rangesOverlap({
    required String startA,
    required int durationA,
    required String startB,
    required int durationB,
  }) {
    final aStart = timeToMinutes(startA);
    final aEnd = aStart + durationA;
    final bStart = timeToMinutes(startB);
    final bEnd = bStart + durationB;
    return aStart < bEnd && bStart < aEnd;
  }

  static bool canFitAtStart({
    required String startTime,
    required int durationMinutes,
    required String scheduleEnd,
    required Set<String> occupiedSlots,
    required Set<String> blockedSlots,
  }) {
    final slots = expandOccupiedSlots(
      startTime: startTime,
      durationMinutes: durationMinutes,
    );
    final endMinutes = timeToMinutes(scheduleEnd);
    for (final slot in slots) {
      if (timeToMinutes(slot) >= endMinutes) return false;
      if (occupiedSlots.contains(slot)) return false;
      if (blockedSlots.contains(slot)) return false;
    }
    return true;
  }

  static Set<String> occupiedFromAppointments(
    Iterable<({String time, int durationMinutes})> appointments,
  ) {
    final occupied = <String>{};
    for (final appt in appointments) {
      occupied.addAll(
        expandOccupiedSlots(
          startTime: appt.time,
          durationMinutes: appt.durationMinutes,
        ),
      );
    }
    return occupied;
  }
}

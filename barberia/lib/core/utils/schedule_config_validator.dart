import '../../data/models/schedule_config.dart';
import 'time_slot_generator.dart';

class ScheduleConfigValidator {
  static void validate(ScheduleConfig config) {
    if (!ScheduleConfig.allowedIntervals.contains(config.intervalMinutes)) {
      throw ArgumentError(
        'El intervalo debe ser uno de: ${ScheduleConfig.allowedIntervals.join(', ')} minutos.',
      );
    }

    final start = _parseMinutes(config.startTime);
    final end = _parseMinutes(config.endTime);

    if (start >= end) {
      throw ArgumentError('La hora de inicio debe ser anterior a la de cierre.');
    }

    final slots = TimeSlotGenerator.generateAllSlots(config);
    if (slots.isEmpty) {
      throw ArgumentError('El rango horario no genera ningún turno.');
    }
  }

  static int _parseMinutes(String time) {
    final parts = time.split(':');
    if (parts.length != 2) {
      throw ArgumentError('Formato de hora inválido: $time');
    }
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }
}

import 'package:barberia/core/utils/time_slot_generator.dart';
import 'package:barberia/data/models/schedule_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const defaultConfig = ScheduleConfig(
    startTime: '09:00',
    endTime: '21:00',
    intervalMinutes: 30,
  );

  test('genera 25 slots entre 09:00 y 21:00 con intervalo 30', () {
    final slots = TimeSlotGenerator.generateAllSlots(defaultConfig);
    expect(slots.length, 25);
    expect(slots.first, '09:00');
    expect(slots.last, '21:00');
  });

  test('respeta configuración personalizada', () {
    const custom = ScheduleConfig(
      startTime: '10:00',
      endTime: '12:00',
      intervalMinutes: 60,
    );

    final slots = TimeSlotGenerator.generateAllSlots(custom);
    expect(slots, ['10:00', '11:00', '12:00']);
  });

  test('excluye horarios reservados de disponibles', () {
    final futureDate = DateTime(2099, 6, 20);
    final available = TimeSlotGenerator.getAvailableSlots(
      ['09:00', '09:30'],
      config: defaultConfig,
      date: futureDate,
    );
    expect(available.contains('09:00'), isFalse);
    expect(available.contains('09:30'), isFalse);
    expect(available.contains('10:00'), isTrue);
  });

  test('hoy marca slots pasados como pastUnavailable', () {
    final today = DateTime(2026, 6, 19);
    final reference = DateTime(2026, 6, 19, 10, 9);

    final entries = TimeSlotGenerator.buildSelectableGrid(
      config: defaultConfig,
      date: today,
      bookedTimes: const [],
      reference: reference,
    );

    expect(
      entries.firstWhere((entry) => entry.time == '09:00').status,
      TimeSlotStatus.pastUnavailable,
    );
    expect(
      entries.firstWhere((entry) => entry.time == '09:30').status,
      TimeSlotStatus.pastUnavailable,
    );
    expect(
      entries.firstWhere((entry) => entry.time == '10:30').status,
      TimeSlotStatus.available,
    );
  });

  test('dia futuro muestra reservados como booked', () {
    final futureDate = DateTime(2099, 6, 20);
    final reference = DateTime(2026, 6, 19, 10, 9);

    final entries = TimeSlotGenerator.buildSelectableGrid(
      config: defaultConfig,
      date: futureDate,
      bookedTimes: const ['09:00'],
      reference: reference,
    );

    final booked = entries.firstWhere((entry) => entry.time == '09:00');
    expect(booked.status, TimeSlotStatus.booked);
    expect(booked.isSelectable, isFalse);
    expect(
      entries.firstWhere((entry) => entry.time == '10:00').status,
      TimeSlotStatus.available,
    );
  });

  test('slots bloqueados no son seleccionables', () {
    final futureDate = DateTime(2099, 6, 20);

    final entries = TimeSlotGenerator.buildSelectableGrid(
      config: defaultConfig,
      date: futureDate,
      bookedTimes: const [],
      blockedTimes: const ['10:00'],
    );

    final blocked = entries.firstWhere((entry) => entry.time == '10:00');
    expect(blocked.status, TimeSlotStatus.blocked);
    expect(blocked.isSelectable, isFalse);
  });
}

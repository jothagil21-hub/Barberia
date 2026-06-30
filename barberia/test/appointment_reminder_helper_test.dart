import 'package:barberia/core/constants/appointment_status.dart';
import 'package:barberia/core/notifications/appointment_reminder_helper.dart';
import 'package:barberia/data/models/appointment.dart';
import 'package:flutter_test/flutter_test.dart';

Appointment _appointment({
  required String date,
  required String time,
}) {
  return Appointment(
    id: 1,
    clientName: 'Juan',
    barberId: 1,
    date: date,
    time: time,
    durationMinutes: 30,
    status: AppointmentStatus.scheduled,
    createdAt: '2026-01-01T00:00:00.000',
    services: const ['Corte'],
  );
}

void main() {
  test('no programa recordatorio para cita pasada', () {
    final reference = DateTime(2026, 6, 18, 15, 0);
    final appointment = _appointment(date: '2026-06-18', time: '10:00');

    expect(
      AppointmentReminderHelper.reminderDateTime(
        appointment,
        reference: reference,
      ),
      isNull,
    );
  });

  test('programa recordatorio 15 min antes', () {
    final reference = DateTime(2026, 6, 18, 9, 0);
    final appointment = _appointment(date: '2026-06-18', time: '10:00');

    final reminder = AppointmentReminderHelper.reminderDateTime(
      appointment,
      reference: reference,
    );

    expect(reminder, DateTime(2026, 6, 18, 9, 45));
  });

  test('no programa si faltan menos de 15 minutos', () {
    final reference = DateTime(2026, 6, 18, 9, 50);
    final appointment = _appointment(date: '2026-06-18', time: '10:00');

    expect(
      AppointmentReminderHelper.reminderDateTime(
        appointment,
        reference: reference,
      ),
      isNull,
    );
  });
}

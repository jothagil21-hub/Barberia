import 'package:barberia/core/constants/appointment_status.dart';
import 'package:barberia/core/notifications/appointment_notification_content.dart';
import 'package:barberia/data/models/appointment.dart';
import 'package:flutter_test/flutter_test.dart';

Appointment _appointment({String? barberName, int barberId = 1}) {
  return Appointment(
    id: 1,
    clientName: 'Juan',
    barberId: barberId,
    date: '2099-06-10',
    time: '10:00',
    durationMinutes: 30,
    status: AppointmentStatus.scheduled,
    createdAt: '2026-01-01T00:00:00.000',
    barberName: barberName,
    services: const ['Corte'],
  );
}

void main() {
  test('incluye nombre del barbero en el cuerpo', () {
    final body = buildAppointmentReminderBody(
      _appointment(barberName: 'Carlos'),
    );

    expect(body, contains('Carlos'));
    expect(body, contains('Juan'));
    expect(body, contains('10:00'));
    expect(body, contains('Corte'));
  });

  test('usa fallback cuando no hay nombre de barbero', () {
    final body = buildAppointmentReminderBody(
      _appointment(barberId: 3),
    );

    expect(body, startsWith('Barbero 3 ·'));
  });
}

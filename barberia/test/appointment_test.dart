import 'package:barberia/core/constants/appointment_status.dart';
import 'package:barberia/data/models/appointment.dart';
import 'package:flutter_test/flutter_test.dart';

Appointment _appointment({
  required String date,
  required String time,
  AppointmentStatus status = AppointmentStatus.scheduled,
}) {
  return Appointment(
    id: 1,
    clientName: 'Juan',
    barberId: 1,
    date: date,
    time: time,
    durationMinutes: 30,
    status: status,
    createdAt: '2026-01-01T00:00:00.000',
  );
}

void main() {
  test('canModify es false para citas canceladas', () {
    final appointment = _appointment(
      date: '2099-01-01',
      time: '10:00',
      status: AppointmentStatus.canceled,
    );

    expect(appointment.canModify, isFalse);
  });

  test('canModify es false para fecha anterior', () {
    final reference = DateTime(2026, 6, 18, 12, 0);
    final appointment = _appointment(date: '2026-06-17', time: '10:00');

    expect(appointment.isModifiableAt(reference), isFalse);
  });

  test('canModify es false para hoy con hora pasada', () {
    final reference = DateTime(2026, 6, 18, 15, 0);
    final appointment = _appointment(date: '2026-06-18', time: '10:00');

    expect(appointment.isModifiableAt(reference), isFalse);
  });

  test('canModify es true para hoy con hora futura', () {
    final reference = DateTime(2026, 6, 18, 15, 0);
    final appointment = _appointment(date: '2026-06-18', time: '18:00');

    expect(appointment.isModifiableAt(reference), isTrue);
  });

  test('canModify es true en el mismo minuto de la cita', () {
    final reference = DateTime(2026, 6, 18, 10, 0);
    final appointment = _appointment(date: '2026-06-18', time: '10:00');

    expect(appointment.isModifiableAt(reference), isTrue);
  });

  test('canMarkAttendance es true cuando la cita ya empezó', () {
    final reference = DateTime(2026, 6, 18, 10, 0);
    final appointment = _appointment(date: '2026-06-18', time: '10:00');

    expect(appointment.canMarkAttendanceAt(reference), isTrue);
  });

  test('canMarkAttendance es false para citas futuras', () {
    final reference = DateTime(2026, 6, 18, 9, 0);
    final appointment = _appointment(date: '2026-06-18', time: '10:00');

    expect(appointment.canMarkAttendanceAt(reference), isFalse);
  });
}

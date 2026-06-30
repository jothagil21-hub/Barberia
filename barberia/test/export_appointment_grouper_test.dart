import 'package:barberia/core/constants/appointment_status.dart';
import 'package:barberia/core/export/export_appointment_grouper.dart';
import 'package:barberia/data/models/appointment.dart';
import 'package:flutter_test/flutter_test.dart';

Appointment _appointment({
  required int id,
  required String clientName,
  required int barberId,
  required String date,
  required String time,
  String? barberName,
  AppointmentStatus status = AppointmentStatus.scheduled,
}) {
  return Appointment(
    id: id,
    clientName: clientName,
    barberId: barberId,
    date: date,
    time: time,
    durationMinutes: 30,
    status: status,
    createdAt: '2099-01-01T00:00:00',
    barberName: barberName,
    services: const ['Corte'],
  );
}

void main() {
  test('lista vacía devuelve grupos vacíos', () {
    expect(groupAppointmentsForExport([]), isEmpty);
  });

  test('agrupa citas de dos barberos en fechas distintas', () {
    final groups = groupAppointmentsForExport([
      _appointment(
        id: 1,
        clientName: 'Ana',
        barberId: 1,
        barberName: 'Barbero 1',
        date: '2099-06-10',
        time: '09:00',
      ),
      _appointment(
        id: 2,
        clientName: 'Luis',
        barberId: 2,
        barberName: 'Barbero 2',
        date: '2099-06-11',
        time: '10:00',
      ),
      _appointment(
        id: 3,
        clientName: 'Pedro',
        barberId: 1,
        barberName: 'Barbero 1',
        date: '2099-06-12',
        time: '11:00',
      ),
    ]);

    expect(groups.length, 2);
    expect(groups[0].barberName, 'Barbero 1');
    expect(groups[1].barberName, 'Barbero 2');
    expect(groups[0].dates.length, 2);
    expect(groups[0].dates[0].date, '2099-06-10');
    expect(groups[0].dates[1].date, '2099-06-12');
    expect(groups[1].dates.length, 1);
    expect(groups[1].dates[0].appointments.single.clientName, 'Luis');
  });

  test('ordena barberos alfabéticamente y fechas/horas ascendentes', () {
    final groups = groupAppointmentsForExport([
      _appointment(
        id: 1,
        clientName: 'Zeta',
        barberId: 2,
        barberName: 'Zorro',
        date: '2099-06-15',
        time: '14:00',
      ),
      _appointment(
        id: 2,
        clientName: 'Alfa',
        barberId: 1,
        barberName: 'Alpha',
        date: '2099-06-20',
        time: '10:00',
      ),
      _appointment(
        id: 3,
        clientName: 'Beta',
        barberId: 1,
        barberName: 'Alpha',
        date: '2099-06-10',
        time: '09:30',
      ),
      _appointment(
        id: 4,
        clientName: 'Gamma',
        barberId: 1,
        barberName: 'Alpha',
        date: '2099-06-10',
        time: '09:00',
      ),
    ]);

    expect(groups.map((g) => g.barberName).toList(), ['Alpha', 'Zorro']);
    expect(groups[0].dates.map((d) => d.date).toList(), [
      '2099-06-10',
      '2099-06-20',
    ]);
    expect(
      groups[0].dates.first.appointments.map((a) => a.time).toList(),
      ['09:00', '09:30'],
    );
  });

  test('citas del mismo barbero en la misma fecha quedan juntas', () {
    final groups = groupAppointmentsForExport([
      _appointment(
        id: 1,
        clientName: 'Uno',
        barberId: 1,
        barberName: 'Barbero 1',
        date: '2099-06-10',
        time: '09:00',
      ),
      _appointment(
        id: 2,
        clientName: 'Dos',
        barberId: 1,
        barberName: 'Barbero 1',
        date: '2099-06-10',
        time: '10:00',
      ),
    ]);

    expect(groups.length, 1);
    expect(groups.single.dates.length, 1);
    expect(groups.single.dates.single.appointments.length, 2);
  });

  test('barberDisplayName usa fallback cuando falta nombre', () {
    final name = barberDisplayName(
      _appointment(
        id: 1,
        clientName: 'Cliente',
        barberId: 5,
        date: '2099-06-10',
        time: '09:00',
      ),
    );

    expect(name, 'Barbero 5');
  });
}

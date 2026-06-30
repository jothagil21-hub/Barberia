import 'package:barberia/core/constants/appointment_status.dart';
import 'package:barberia/core/export/export_attended_totals.dart';
import 'package:barberia/core/export/export_appointment_grouper.dart';
import 'package:barberia/data/models/appointment.dart';
import 'package:flutter_test/flutter_test.dart';

Appointment _appointment({
  required int id,
  required AppointmentStatus status,
  required double totalPrice,
  String barberName = 'Barbero 1',
  int barberId = 1,
  String date = '2099-06-10',
}) {
  return Appointment(
    id: id,
    clientName: 'Cliente $id',
    barberId: barberId,
    date: date,
    time: '09:00',
    durationMinutes: 30,
    status: status,
    createdAt: '2026-01-01T00:00:00.000',
    barberName: barberName,
    services: const ['Corte'],
    totalPrice: totalPrice,
  );
}

void main() {
  test('suma solo citas con estado asistió', () {
    final total = sumAttendedTotal([
      _appointment(id: 1, status: AppointmentStatus.attended, totalPrice: 50),
      _appointment(id: 2, status: AppointmentStatus.scheduled, totalPrice: 30),
      _appointment(id: 3, status: AppointmentStatus.canceled, totalPrice: 20),
      _appointment(id: 4, status: AppointmentStatus.noShow, totalPrice: 40),
      _appointment(id: 5, status: AppointmentStatus.attended, totalPrice: 25),
    ]);

    expect(total, 75);
  });

  test('subtotal por barbero coincide con citas del grupo', () {
    final appointments = [
      _appointment(
        id: 1,
        status: AppointmentStatus.attended,
        totalPrice: 50,
        barberName: 'Alpha',
      ),
      _appointment(
        id: 2,
        status: AppointmentStatus.scheduled,
        totalPrice: 30,
        barberName: 'Alpha',
      ),
      _appointment(
        id: 3,
        status: AppointmentStatus.attended,
        totalPrice: 20,
        barberName: 'Beta',
        barberId: 2,
      ),
    ];

    final groups = groupAppointmentsForExport(appointments);
    final alphaGroup = groups.firstWhere((group) => group.barberName == 'Alpha');
    final betaGroup = groups.firstWhere((group) => group.barberName == 'Beta');

    expect(sumAttendedTotalForBarberGroup(alphaGroup), 50);
    expect(sumAttendedTotalForBarberGroup(betaGroup), 20);
    expect(sumAttendedTotal(appointments), 70);
  });
}

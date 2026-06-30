import '../../data/models/appointment.dart';
import 'export_appointment_grouper.dart';

double sumAttendedTotal(Iterable<Appointment> appointments) {
  return appointments
      .where((appointment) => appointment.isAttended)
      .fold(0.0, (sum, appointment) => sum + appointment.totalPrice);
}

double sumAttendedTotalForBarberGroup(ExportBarberGroup group) {
  final appointments = group.dates
      .expand((dateGroup) => dateGroup.appointments)
      .toList();
  return sumAttendedTotal(appointments);
}

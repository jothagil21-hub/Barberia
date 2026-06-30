import '../../data/models/appointment.dart';

String buildAppointmentReminderBody(Appointment appointment) {
  final barber = appointment.barberName?.trim();
  final barberLabel = (barber != null && barber.isNotEmpty)
      ? barber
      : 'Barbero ${appointment.barberId}';
  return '$barberLabel · ${appointment.clientName} · ${appointment.time} · ${appointment.servicesLabel}';
}

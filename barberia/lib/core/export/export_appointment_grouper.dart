import '../../data/models/appointment.dart';

class ExportDateGroup {
  const ExportDateGroup({
    required this.date,
    required this.appointments,
  });

  final String date;
  final List<Appointment> appointments;
}

class ExportBarberGroup {
  const ExportBarberGroup({
    required this.barberName,
    required this.dates,
  });

  final String barberName;
  final List<ExportDateGroup> dates;
}

String barberDisplayName(Appointment appointment) {
  final name = appointment.barberName?.trim();
  if (name != null && name.isNotEmpty) return name;
  return 'Barbero ${appointment.barberId}';
}

List<ExportBarberGroup> groupAppointmentsForExport(
  List<Appointment> appointments,
) {
  if (appointments.isEmpty) return [];

  final byBarber = <String, Map<String, List<Appointment>>>{};

  for (final appointment in appointments) {
    final barberKey = barberDisplayName(appointment);
    byBarber.putIfAbsent(barberKey, () => {});
    byBarber[barberKey]!.putIfAbsent(appointment.date, () => []);
    byBarber[barberKey]![appointment.date]!.add(appointment);
  }

  final barberNames = byBarber.keys.toList()..sort();

  return barberNames.map((barberName) {
    final datesMap = byBarber[barberName]!;
    final sortedDates = datesMap.keys.toList()..sort();

    final dateGroups = sortedDates.map((date) {
      final dayAppointments = List<Appointment>.from(datesMap[date]!)
        ..sort((a, b) => a.time.compareTo(b.time));
      return ExportDateGroup(date: date, appointments: dayAppointments);
    }).toList();

    return ExportBarberGroup(barberName: barberName, dates: dateGroups);
  }).toList();
}

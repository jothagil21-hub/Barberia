import '../../data/models/appointment.dart';

class AppointmentReminderHelper {
  static const Duration reminderLeadTime = Duration(minutes: 15);

  static DateTime? reminderDateTime(
    Appointment appointment, {
    DateTime? reference,
  }) {
    if (!appointment.isScheduled) return null;

    final now = reference ?? DateTime.now();
    final reminder = appointment.appointmentDateTime.subtract(reminderLeadTime);
    if (!reminder.isAfter(now)) return null;

    return reminder;
  }
}

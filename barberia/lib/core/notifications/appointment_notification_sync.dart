import '../../data/models/appointment.dart';
import '../../data/repositories/appointment_repository.dart';
import 'notification_service.dart';

Future<ReminderScheduleResult> syncReminderForAppointment(
  Appointment? appointment,
) async {
  if (appointment == null) return ReminderScheduleResult.failed;

  if (appointment.isScheduled) {
    return NotificationService.instance
        .scheduleAppointmentReminder(appointment);
  }

  await NotificationService.instance.cancelReminder(appointment.id);
  return ReminderScheduleResult.scheduled;
}

Future<void> cancelReminderForAppointment(int appointmentId) async {
  await NotificationService.instance.cancelReminder(appointmentId);
}

Future<void> resyncAllAppointmentReminders(
  AppointmentRepository repository,
) async {
  final upcoming = await repository.getUpcomingScheduledAppointments();
  await NotificationService.instance.resyncAllReminders(upcoming);
}

Future<ReminderScheduleResult> syncReminderById(
  AppointmentRepository repository,
  int appointmentId,
) async {
  final appointment = await repository.getAppointmentById(appointmentId);
  return syncReminderForAppointment(appointment);
}

void showReminderSyncSnackBar(
  ReminderScheduleResult result,
  void Function(String message) showMessage,
) {
  switch (result) {
    case ReminderScheduleResult.skippedTooSoon:
      showMessage(
        'Cita guardada. El recordatorio no se programó (faltan menos de 15 min).',
      );
    case ReminderScheduleResult.skippedNoPermission:
      showMessage(
        'Cita guardada. Activa las notificaciones para recibir recordatorios.',
      );
    case ReminderScheduleResult.failed:
      showMessage(
        'Cita guardada, pero no se pudo programar el recordatorio.',
      );
    case ReminderScheduleResult.scheduled:
      break;
  }
}

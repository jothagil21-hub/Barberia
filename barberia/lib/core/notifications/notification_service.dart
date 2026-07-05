import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../data/models/appointment.dart';
import 'appointment_notification_content.dart';
import 'appointment_reminder_helper.dart';

enum ReminderScheduleResult {
  scheduled,
  skippedTooSoon,
  skippedNoPermission,
  failed,
}

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _notificationsEnabled = true;
  bool _exactAlarmsEnabled = true;

  static const String _channelId = 'appointment_reminders';
  static const String _channelName = 'Recordatorios de citas';

  Future<void> initialize() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    final timeZoneInfo = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timeZoneInfo.identifier));

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(initSettings);

    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'Avisos 15 minutos antes de cada cita',
      importance: Importance.high,
    );

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();

    await android?.createNotificationChannel(channel);

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      _notificationsEnabled = await ios?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    } else {
      _notificationsEnabled =
          await android?.requestNotificationsPermission() ?? true;
    }

    await android?.requestExactAlarmsPermission();
    _exactAlarmsEnabled =
        await android?.canScheduleExactNotifications() ?? false;

    if (!_notificationsEnabled) {
      debugPrint('Permiso POST_NOTIFICATIONS denegado.');
    }
    if (!_exactAlarmsEnabled) {
      debugPrint(
        'Alarmas exactas no disponibles; se usará modo inexacto.',
      );
    }

    _initialized = true;
  }

  Future<ReminderScheduleResult> scheduleAppointmentReminder(
    Appointment appointment,
  ) async {
    if (!_initialized) return ReminderScheduleResult.failed;

    if (!_notificationsEnabled) {
      return ReminderScheduleResult.skippedNoPermission;
    }

    final reminderAt =
        AppointmentReminderHelper.reminderDateTime(appointment);
    if (reminderAt == null) {
      return ReminderScheduleResult.skippedTooSoon;
    }

    await cancelReminder(appointment.id);

    final body = buildAppointmentReminderBody(appointment);

    var mode = _exactAlarmsEnabled
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    try {
      await _plugin.zonedSchedule(
        appointment.id,
        'Cita en 15 minutos',
        body,
        tz.TZDateTime.from(reminderAt, tz.local),
        NotificationDetails(
          android: const AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: 'Avisos 15 minutos antes de cada cita',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: mode,
      );
      return ReminderScheduleResult.scheduled;
    } catch (error) {
      if (mode != AndroidScheduleMode.exactAllowWhileIdle) {
        debugPrint('Error al programar recordatorio: $error');
        return ReminderScheduleResult.failed;
      }

      debugPrint(
        'Alarmas exactas no disponibles, reintentando inexacto: $error',
      );

      try {
        await _plugin.zonedSchedule(
          appointment.id,
          'Cita en 15 minutos',
          body,
          tz.TZDateTime.from(reminderAt, tz.local),
          NotificationDetails(
            android: const AndroidNotificationDetails(
              _channelId,
              _channelName,
              channelDescription: 'Avisos 15 minutos antes de cada cita',
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: const DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
        return ReminderScheduleResult.scheduled;
      } catch (fallbackError) {
        debugPrint('Error al programar recordatorio inexacto: $fallbackError');
        return ReminderScheduleResult.failed;
      }
    }
  }

  Future<void> cancelReminder(int appointmentId) async {
    if (!_initialized) return;
    await _plugin.cancel(appointmentId);
  }

  Future<void> resyncAllReminders(List<Appointment> appointments) async {
    if (!_initialized) return;

    await _plugin.cancelAll();
    for (final appointment in appointments) {
      final result = await scheduleAppointmentReminder(appointment);
      if (result != ReminderScheduleResult.scheduled &&
          result != ReminderScheduleResult.skippedTooSoon) {
        debugPrint(
          'No se pudo programar cita ${appointment.id}: $result',
        );
      }
    }
  }
}

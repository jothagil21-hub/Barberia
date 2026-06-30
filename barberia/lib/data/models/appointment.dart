import '../../core/constants/appointment_status.dart';

class Appointment {
  const Appointment({
    required this.id,
    required this.clientName,
    required this.barberId,
    required this.date,
    required this.time,
    required this.durationMinutes,
    required this.status,
    required this.createdAt,
    this.canceledAt,
    this.barberName,
    this.services = const [],
    this.totalPrice = 0,
  });

  final int id;
  final String clientName;
  final int barberId;
  final String date;
  final String time;
  final int durationMinutes;
  final AppointmentStatus status;
  final String createdAt;
  final String? canceledAt;
  final String? barberName;
  final List<String> services;
  final double totalPrice;

  bool get isCanceled => status == AppointmentStatus.canceled;
  bool get isScheduled => status == AppointmentStatus.scheduled;
  bool get isAttended => status == AppointmentStatus.attended;
  bool get isNoShow => status == AppointmentStatus.noShow;

  bool get canModify => isModifiableAt(DateTime.now());

  bool canReactivateAt(DateTime reference) {
    if (!isCanceled) return false;
    return !appointmentDateTime.isBefore(reference);
  }

  DateTime get appointmentDateTime {
    final parts = time.split(':');
    final day = DateTime.parse(date);
    return DateTime(
      day.year,
      day.month,
      day.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }

  bool isModifiableAt(DateTime reference) {
    if (!isScheduled) return false;
    return !appointmentDateTime.isBefore(reference);
  }

  bool canMarkAttendanceAt(DateTime reference) {
    if (!isScheduled) return false;
    return !appointmentDateTime.isAfter(reference);
  }

  String get servicesLabel =>
      services.isEmpty ? 'Sin servicios' : services.join(', ');

  factory Appointment.fromMap(Map<String, Object?> map) {
    return Appointment(
      id: map['id'] as int,
      clientName: map['client_name'] as String,
      barberId: map['barber_id'] as int,
      date: map['date'] as String,
      time: map['time'] as String,
      durationMinutes: map['duration_minutes'] as int? ?? 30,
      status: AppointmentStatus.fromValue(map['status'] as String),
      createdAt: map['created_at'] as String,
      canceledAt: map['canceled_at'] as String?,
      barberName: map['barber_name'] as String?,
      services: _parseServices(map['services']),
      totalPrice: (map['total_price'] as num?)?.toDouble() ?? 0,
    );
  }

  static List<String> _parseServices(Object? value) {
    if (value == null) return [];
    if (value is String && value.isNotEmpty) {
      return value.split(', ').where((s) => s.isNotEmpty).toList();
    }
    return [];
  }
}

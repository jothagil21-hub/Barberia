enum AppointmentStatus {
  scheduled,
  canceled,
  attended,
  noShow;

  String get value {
    switch (this) {
      case AppointmentStatus.noShow:
        return 'no_show';
      default:
        return name;
    }
  }

  static AppointmentStatus fromValue(String value) {
    switch (value) {
      case 'no_show':
        return AppointmentStatus.noShow;
      default:
        return AppointmentStatus.values.firstWhere(
          (status) => status.value == value,
          orElse: () => AppointmentStatus.scheduled,
        );
    }
  }
}

extension AppointmentStatusLabel on AppointmentStatus {
  String get displayLabel {
    switch (this) {
      case AppointmentStatus.scheduled:
        return 'Programada';
      case AppointmentStatus.canceled:
        return 'Cancelada';
      case AppointmentStatus.attended:
        return 'Asistió';
      case AppointmentStatus.noShow:
        return 'No asistió';
    }
  }
}

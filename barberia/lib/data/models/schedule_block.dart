class ScheduleBlock {
  const ScheduleBlock({
    required this.id,
    required this.barberId,
    required this.date,
    required this.isFullDay,
    this.time,
    required this.createdAt,
  });

  final int id;
  final int barberId;
  final String date;
  final bool isFullDay;
  final String? time;
  final String createdAt;

  factory ScheduleBlock.fromMap(Map<String, Object?> map) {
    return ScheduleBlock(
      id: map['id'] as int,
      barberId: map['barber_id'] as int,
      date: map['date'] as String,
      isFullDay: (map['is_full_day'] as int? ?? 0) == 1,
      time: map['time'] as String?,
      createdAt: map['created_at'] as String,
    );
  }
}

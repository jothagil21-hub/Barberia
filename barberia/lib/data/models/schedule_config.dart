import '../../core/constants/schedule_constants.dart';

class ScheduleConfig {
  const ScheduleConfig({
    required this.startTime,
    required this.endTime,
    required this.intervalMinutes,
  });

  final String startTime;
  final String endTime;
  final int intervalMinutes;

  static const List<int> allowedIntervals = [15, 20, 30, 45, 60];

  factory ScheduleConfig.defaults() {
    return const ScheduleConfig(
      startTime: ScheduleConstants.startTime,
      endTime: ScheduleConstants.endTime,
      intervalMinutes: ScheduleConstants.intervalMinutes,
    );
  }

  String get rangeLabel => '$startTime–$endTime';

  ScheduleConfig copyWith({
    String? startTime,
    String? endTime,
    int? intervalMinutes,
  }) {
    return ScheduleConfig(
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      intervalMinutes: intervalMinutes ?? this.intervalMinutes,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ScheduleConfig &&
        other.startTime == startTime &&
        other.endTime == endTime &&
        other.intervalMinutes == intervalMinutes;
  }

  @override
  int get hashCode => Object.hash(startTime, endTime, intervalMinutes);
}

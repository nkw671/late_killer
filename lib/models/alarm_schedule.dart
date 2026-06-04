import 'day_of_week.dart';

/// 클래스 다이어그램의 AlarmSchedule
///
/// - day : DayOfWeek
/// - isEnabled : bool
/// - alarmTime : date  (요일별 출발 목표 시각)
/// + setEnabled(isEnabled) / setAlarmTime(alarmTime)
///
/// REQ-08(요일별 활성/비활성) + REQ-09(요일별 시각)를 한 객체로 묶음.
class AlarmSchedule {
  final DayOfWeek day;
  bool isEnabled;

  /// 출발 목표 시각. 날짜 부분은 무시하고 시:분만 사용 (HH:MM)
  int hour;
  int minute;

  AlarmSchedule({
    required this.day,
    this.isEnabled = false,
    this.hour = 8,
    this.minute = 0,
  });

  /// + setEnabled(isEnabled: bool) : void
  void setEnabled(bool value) => isEnabled = value;

  /// + setAlarmTime(alarmTime: date) : void
  void setAlarmTime(int h, int m) {
    hour = h;
    minute = m;
  }

  String get timeLabel =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  Map<String, dynamic> toJson() => {
        'day': day.index,
        'isEnabled': isEnabled,
        'hour': hour,
        'minute': minute,
      };

  factory AlarmSchedule.fromJson(Map<String, dynamic> j) => AlarmSchedule(
        day: DayOfWeek.values[j['day'] as int],
        isEnabled: j['isEnabled'] as bool? ?? false,
        hour: j['hour'] as int? ?? 8,
        minute: j['minute'] as int? ?? 0,
      );
}

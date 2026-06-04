import 'package:flutter/material.dart';

class AlarmSchedule {
  final int day; // DateTime.monday ~ DateTime.sunday (1~7)
  bool isEnabled;
  TimeOfDay alarmTime;

  AlarmSchedule({
    required this.day,
    this.isEnabled = false,
    required this.alarmTime,
  });

  Map<String, dynamic> toJson() => {
        'day': day,
        'isEnabled': isEnabled,
        'h': alarmTime.hour,
        'm': alarmTime.minute,
      };

  factory AlarmSchedule.fromJson(Map<String, dynamic> j) => AlarmSchedule(
        day: j['day'] as int,
        isEnabled: j['isEnabled'] as bool,
        alarmTime: TimeOfDay(hour: j['h'] as int, minute: j['m'] as int),
      );
}

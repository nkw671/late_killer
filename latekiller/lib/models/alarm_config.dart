import 'alarm_schedule.dart';

/// 사용자가 저장한 알람 한 건 — 정류장 + 선택한 버스들 + 요일별 스케줄
class AlarmConfig {
  final String stopId;
  final String stopName;
  final int stopNumber;
  final List<String> busNumbers; // 선택된 버스 번호들
  final int walkTimeToStop; // 초
  final Map<int, AlarmSchedule> schedules; // day -> schedule

  AlarmConfig({
    required this.stopId,
    required this.stopName,
    required this.stopNumber,
    required this.busNumbers,
    required this.walkTimeToStop,
    required this.schedules,
  });

  Map<String, dynamic> toJson() => {
        'stopId': stopId,
        'stopName': stopName,
        'stopNumber': stopNumber,
        'busNumbers': busNumbers,
        'walkTimeToStop': walkTimeToStop,
        'schedules': schedules.map((k, v) => MapEntry(k.toString(), v.toJson())),
      };

  factory AlarmConfig.fromJson(Map<String, dynamic> j) => AlarmConfig(
        stopId: j['stopId'] as String,
        stopName: j['stopName'] as String,
        stopNumber: j['stopNumber'] as int,
        busNumbers: (j['busNumbers'] as List).cast<String>(),
        walkTimeToStop: j['walkTimeToStop'] as int,
        schedules: (j['schedules'] as Map).map(
          (k, v) => MapEntry(
              int.parse(k as String), AlarmSchedule.fromJson(v as Map<String, dynamic>)),
        ),
      );
}

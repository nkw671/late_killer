import 'alarm_schedule.dart';
import 'day_of_week.dart';

/// 저장된 버스 알람 한 개.
/// 정류장 + 선택 노선 + 요일별 스케줄 + 도보시간을 묶어 영속화한다.
class BusAlarm {
  final String id;       // 고유 ID (생성 시각 ms)
  final String stopId;
  final String stopName;
  final List<SavedRoute> routes;                    // 선택된 노선들
  final Map<DayOfWeek, AlarmSchedule> schedules;   // 요일별 스케줄
  int walkTimeToStop;                               // 도보 소요시간 (분)

  BusAlarm({
    required this.id,
    required this.stopId,
    required this.stopName,
    required this.routes,
    required this.schedules,
    this.walkTimeToStop = 5,
  });

  /// 활성화된 요일 목록 (홈 화면 표시용)
  List<AlarmSchedule> get enabledSchedules =>
      schedules.values.where((s) => s.isEnabled).toList();

  /// 활성화된 요일 레이블 문자열. 예) "월 화 수"
  String get scheduleLabel {
    final labels =
        schedules.entries
            .where((e) => e.value.isEnabled)
            .map((e) => e.key.labelKo)
            .toList();
    if (labels.isEmpty) return '상시';
    return labels.join(' ');
  }

  /// 첫 번째 활성 스케줄의 시간 문자열. 여러 요일이면 대표로 첫 번째.
  String get timeLabel {
    final first = schedules.values.firstWhere(
      (s) => s.isEnabled,
      orElse: () => AlarmSchedule(day: DayOfWeek.mon),
    );
    return first.timeLabel;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'stopId': stopId,
        'stopName': stopName,
        'routes': routes.map((r) => r.toJson()).toList(),
        'schedules': schedules.values.map((s) => s.toJson()).toList(),
        'walkTimeToStop': walkTimeToStop,
      };

  factory BusAlarm.fromJson(Map<String, dynamic> j) {
    final routes = (j['routes'] as List)
        .map((e) => SavedRoute.fromJson(e as Map<String, dynamic>))
        .toList();
    final scheduleList = (j['schedules'] as List)
        .map((e) => AlarmSchedule.fromJson(e as Map<String, dynamic>))
        .toList();
    final scheduleMap = {
      for (final s in scheduleList) s.day: s,
      // 누락된 요일은 기본값으로 채움
      for (final d in DayOfWeek.values)
        if (!scheduleList.any((s) => s.day == d)) d: AlarmSchedule(day: d),
    };
    return BusAlarm(
      id: j['id'] as String,
      stopId: j['stopId'] as String,
      stopName: j['stopName'] as String,
      routes: routes,
      schedules: scheduleMap,
      walkTimeToStop: j['walkTimeToStop'] as int? ?? 5,
    );
  }
}

/// 알람에 저장되는 노선 최소 정보
class SavedRoute {
  final String routeId;
  final String routeNo;

  const SavedRoute({required this.routeId, required this.routeNo});

  Map<String, dynamic> toJson() => {'routeId': routeId, 'routeNo': routeNo};

  factory SavedRoute.fromJson(Map<String, dynamic> j) => SavedRoute(
        routeId: j['routeId'] as String,
        routeNo: j['routeNo'] as String,
      );
}

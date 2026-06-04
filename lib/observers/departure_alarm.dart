import '../models/alarm_schedule.dart';
import '../models/bus_route.dart';
import '../models/day_of_week.dart';
import 'observer.dart';

/// 클래스 다이어그램의 DepartureAlarm (Observer 구현)
///
/// - walkTimeToStop : int (분)
/// - thresholdTime : int
/// - schedules : Map<DayOfWeek, AlarmSchedule>
/// + setSchedule(day, isEnabled, alarmTime) : void
/// + setWalkTimeToStop() : void
/// + setDepartureThreshold(walkTimeToStop) : int
/// + switchToNextEarliestBus() : void
/// + update(busNumber, busArriveTime) : void
///
/// 알림 로직의 핵심 (REQ-07 ~ REQ-14).
class DepartureAlarm implements Observer {
  /// REQ-07: 도보 소요 시간 (분, 1~60)
  int walkTimeToStop;

  /// REQ-11: 출발 임계 — busArriveTime(초)이 이 값 이하가 되면 출발 알림
  int thresholdTime;

  /// REQ-08/09: 요일별 스케줄
  final Map<DayOfWeek, AlarmSchedule> schedules;

  /// REQ-06: 알람 대상으로 선택된 노선들
  final List<BusRoute> selectedRoutes;

  /// REQ-10: 현재 알림 기준 버스
  BusRoute? currentTargetBus;

  /// 출발 알림이 이미 1회 발생했는지 (REQ-11 "1회")
  bool _departureFired = false;

  /// 모든 버스 통과 메시지가 1회 표시됐는지 (REQ-13 "1회")
  bool _allPassedFired = false;

  /// 주기 안내: 마지막으로 안내한 "분 경계" 값. null=아직 없음.
  /// 예) 15분 경계에서 안내했으면 15. 이후 14→10까지 안내 없음, 10에서 다시 안내.
  int? _lastAnnouncedMark;

  /// 한 번이라도 유효한 기준 버스가 존재한 적이 있는지.
  /// 초기 데이터 미로딩(전부 0초) 상태에서 '모두 통과'를 오발화하지 않기 위한 가드.
  bool _hadTargetBus = false;

  // 콜백
  void Function(int busNumber, int busArriveTime)? onDeparture;  // REQ-11
  void Function(String message)? onAllPassed;                    // REQ-13
  void Function(BusRoute target)? onTargetChanged;              // REQ-10/12
  // 주기적 남은시간 안내 (>10분→5분간격, ≤10분→1분간격)
  void Function(int busNumber, int busArriveTime)? onAnnounce;

  DepartureAlarm({
    this.walkTimeToStop = 5,
    this.thresholdTime = 0,
    Map<DayOfWeek, AlarmSchedule>? schedules,
    List<BusRoute>? selectedRoutes,
  })  : schedules = schedules ??
            {for (final d in DayOfWeek.values) d: AlarmSchedule(day: d)},
        selectedRoutes = selectedRoutes ?? [];

  /// + setSchedule(day, isEnabled, alarmTime) : void
  void setSchedule(DayOfWeek day, bool isEnabled, int hour, int minute) {
    final s = schedules[day] ?? AlarmSchedule(day: day);
    s.setEnabled(isEnabled);
    s.setAlarmTime(hour, minute);
    schedules[day] = s;
  }

  /// + setWalkTimeToStop() : void  (REQ-07, 1~60분)
  void setWalkTimeToStop(int minutes) {
    walkTimeToStop = minutes.clamp(1, 60);
  }

  /// + setDepartureThreshold(walkTimeToStop) : int
  /// 출발 임계(초) = 도보시간(분) × 60. 도착예정이 이 값 이하가 되면 출발 시점.
  int setDepartureThreshold(int walkMinutes) {
    thresholdTime = walkMinutes * 60;
    return thresholdTime;
  }

  /// 알람 대상 노선 등록 (REQ-06)
  void setSelectedRoutes(List<BusRoute> routes) {
    selectedRoutes
      ..clear()
      ..addAll(routes);
    reset();
    _pickEarliest();
  }

  /// REQ-10: 선택된 노선 중 도착예정이 가장 이른 버스를 기준 버스로.
  /// 기준 버스가 바뀔 때만 _departureFired를 리셋한다.
  void _pickEarliest() {
    final alive = selectedRoutes.where((r) => r.busArriveTime > 0).toList()
      ..sort((a, b) => a.busArriveTime.compareTo(b.busArriveTime));
    final next = alive.isEmpty ? null : alive.first;
    if (next != currentTargetBus) {
      currentTargetBus = next;
      _departureFired = false;    // 새 기준 버스로 바뀔 때만 리셋
      _lastAnnouncedMark = null; // 주기 안내 마크도 리셋
      if (next != null) {
        _hadTargetBus = true;
        onTargetChanged?.call(next);
      }
    }
    // 한 번이라도 기준 버스가 있었던 경우에만 '모두 통과'로 판단.
    // 알람 시작 직후 도착정보가 아직 없을 때(전부 0초) 오발화하지 않도록 가드.
    if (next == null && _hadTargetBus && !_allPassedFired) {
      _allPassedFired = true;
      onAllPassed?.call('오늘 선택한 버스가 모두 지나갔습니다');
    }
  }

  /// + switchToNextEarliestBus() : void
  /// REQ-12: 기준 버스가 통과(도착정보 소멸)하면 다음으로 이른 버스로 전환.
  /// REQ-13: 더 이상 없으면 메시지 1회.
  /// ※ _departureFired 리셋은 _pickEarliest 내부에서 기준 버스 변경 시에만 수행.
  void switchToNextEarliestBus() {
    _pickEarliest();
  }

  /// REQ-08/09: 오늘 요일에 활성 스케줄이 있고 알람 창 안인지 확인.
  /// 활성화된 스케줄이 하나도 없으면 '항상 활성(스케줄 없음)' 취급.
  bool isScheduleActiveNow() {
    final hasAny = schedules.values.any((s) => s.isEnabled);
    if (!hasAny) return true; // 스케줄 미설정 = 상시 감시

    final now = DateTime.now();
    final today = DayOfWeek.fromDateTime(now);
    final s = schedules[today];
    if (s == null || !s.isEnabled) return false;

    final target =
        DateTime(now.year, now.month, now.day, s.hour, s.minute);
    // 목표 시각 30분 전 ~ 60분 후를 감시 창으로 설정
    final windowStart = target.subtract(const Duration(minutes: 30));
    final windowEnd = target.add(const Duration(minutes: 60));
    return now.isAfter(windowStart) && now.isBefore(windowEnd);
  }

  /// + update(busNumber, busArriveTime) : void
  /// 실시간 갱신마다 호출됨 (EventManager.notify → 여기로).
  @override
  void update(int busNumber, int busArriveTime) {
    // 기준 버스 통과 여부 재평가
    final stillAlive =
        currentTargetBus != null && currentTargetBus!.busArriveTime > 0;
    if (!stillAlive) {
      switchToNextEarliestBus();
      return;
    }
    evaluateAlerts(busNumber, busArriveTime);
  }

  /// 출발 임계/주기 안내를 평가한다(기준 버스 전환은 하지 않음).
  /// 8초 폴링(update)과 1초 UI 틱(AppState._uiTick) 양쪽에서 호출되어
  /// 출발 시점을 1초 단위로 정확히 잡는다.
  void evaluateAlerts(int busNumber, int busArriveTime) {
    if (currentTargetBus == null) return;

    // REQ-08/09: 스케줄 창이 아니면 알림 억제
    if (!isScheduleActiveNow()) return;

    // REQ-11: 도착예정 - 도보시간 <= 0 → 출발 시점 (1회만)
    setDepartureThreshold(walkTimeToStop);
    if (busArriveTime <= thresholdTime && !_departureFired) {
      _departureFired = true;
      onDeparture?.call(busNumber, busArriveTime);
    }

    // 주기적 남은시간 안내 (출발 전까지만)
    if (!_departureFired) {
      _checkPeriodicAnnouncement(busNumber, busArriveTime);
    }
  }

  /// 분 경계 통과 감지 방식으로 주기 안내.
  /// ≥10분: 5의 배수(15, 10분 등) 경계를 지날 때마다 안내.
  /// <10분: 매 분(8→7→6…) 경계를 지날 때마다 안내.
  /// _lastAnnouncedMark보다 낮은 경계에 처음 진입했을 때만 발화해
  /// API 오차로 값이 오르내려도 중복 안내하지 않는다.
  void _checkPeriodicAnnouncement(int busNumber, int busArriveTime) {
    final remainSec = busArriveTime - thresholdTime;
    if (remainSec <= 0) return;

    final currentMin = remainSec ~/ 60;
    if (currentMin <= 0) return;

    // 현재 분이 "안내해야 할 경계"인지 먼저 확인
    //   ≥10분: 5의 배수(10, 15, 20…)일 때만
    //   <10분: 매 분(9, 8, 7…, 1)
    final bool isAtBoundary =
        currentMin >= 10 ? (currentMin % 5 == 0) : true;
    if (!isAtBoundary) return;

    // 같은 경계를 중복 안내하지 않음 (API 오차로 값이 오르내려도 방지)
    if (_lastAnnouncedMark == null || currentMin < _lastAnnouncedMark!) {
      _lastAnnouncedMark = currentMin;
      onAnnounce?.call(busNumber, busArriveTime);
    }
  }

  void reset() {
    _departureFired = false;
    _allPassedFired = false;
    _lastAnnouncedMark = null;
    _hadTargetBus = false;
    currentTargetBus = null;
  }
}

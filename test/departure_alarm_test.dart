import 'package:flutter_test/flutter_test.dart';

import 'package:bus_alarm_app/models/bus_route.dart';
import 'package:bus_alarm_app/models/day_of_week.dart';
import 'package:bus_alarm_app/observers/departure_alarm.dart';

/// 알람 "출력"(콜백 발화) 로직 검증.
/// onDeparture(출발 알림) / onAllPassed(모두 통과) / onAnnounce(주기 안내)가
/// 의도대로 정확히 1회/조건에 맞게 호출되는지 확인한다.
void main() {
  BusRoute route(String id, String no, int sec) =>
      BusRoute(routeId: id, routeNo: no, busNumber: BusRoute.parseNumber(no), busArriveTime: sec);

  test('출발 알림: 임계(도보*60) 이하로 떨어지면 1회만 발화', () {
    final alarm = DepartureAlarm(walkTimeToStop: 5); // 임계 300초
    var departureCalls = 0;
    int? gotBus;
    alarm.onDeparture = (busNo, sec) {
      departureCalls++;
      gotBus = busNo;
    };

    final r = route('R1', '564', 600);
    alarm.setSelectedRoutes([r]); // 기준 버스 선정 (스케줄 미설정 = 상시 감시)

    expect(alarm.currentTargetBus, isNotNull, reason: '기준 버스가 선정되어야 함');

    // 아직 임계 초과 → 발화 X
    alarm.evaluateAlerts(564, 600);
    alarm.evaluateAlerts(564, 301);
    expect(departureCalls, 0);

    // 임계 도달 → 1회 발화
    alarm.evaluateAlerts(564, 300);
    expect(departureCalls, 1);
    expect(gotBus, 564);

    // 이후 계속 떨어져도 중복 발화 X
    alarm.evaluateAlerts(564, 250);
    alarm.evaluateAlerts(564, 60);
    expect(departureCalls, 1);
  });

  test('버그1 회귀: 시작 시 도착정보 0초뿐이면 onAllPassed 오발화 안 함', () {
    final alarm = DepartureAlarm(walkTimeToStop: 5);
    var allPassed = 0;
    alarm.onAllPassed = (_) => allPassed++;

    // 저장된 알람 실행 직후처럼 전부 0초 상태
    alarm.setSelectedRoutes([route('R1', '564', 0), route('R2', '8', 0)]);

    expect(alarm.currentTargetBus, isNull);
    expect(allPassed, 0, reason: '데이터 미로딩 상태에서 모두통과 발화 금지');
  });

  test('모두 통과: 기준 버스가 생겼다가 사라지면 onAllPassed 1회', () {
    final alarm = DepartureAlarm(walkTimeToStop: 5);
    var allPassed = 0;
    alarm.onAllPassed = (_) => allPassed++;

    final r = route('R1', '564', 400);
    alarm.setSelectedRoutes([r]);
    expect(alarm.currentTargetBus, isNotNull);

    // 버스가 통과 → 0초
    r.busArriveTime = 0;
    alarm.switchToNextEarliestBus();
    expect(allPassed, 1);

    // 재호출해도 중복 X
    alarm.switchToNextEarliestBus();
    expect(allPassed, 1);
  });

  test('기준 버스 전환: 통과 시 다음으로 이른 버스로', () {
    final alarm = DepartureAlarm(walkTimeToStop: 5);
    final a = route('A', '111', 200);
    final b = route('B', '222', 500);
    alarm.setSelectedRoutes([a, b]);
    expect(alarm.currentTargetBus?.routeId, 'A');

    a.busArriveTime = 0; // A 통과
    alarm.switchToNextEarliestBus();
    expect(alarm.currentTargetBus?.routeId, 'B');
  });

  test('주기 안내: 임계 초과 구간에서 분 경계마다 onAnnounce', () {
    final alarm = DepartureAlarm(walkTimeToStop: 1); // 임계 60초
    var announces = 0;
    alarm.onAnnounce = (_, __) => announces++;

    alarm.setSelectedRoutes([route('R1', '564', 700)]);

    // ≤10분 구간: 매 분 경계(앞 시간엔 thresholdTime=60 차감 후 남은 분)
    alarm.evaluateAlerts(564, 360); // 남은 300초=5분
    alarm.evaluateAlerts(564, 300); // 남은 240초=4분
    alarm.evaluateAlerts(564, 240); // 남은 180초=3분
    expect(announces, greaterThanOrEqualTo(3));
  });

  test('스케줄 창 밖: 알림 억제', () {
    final alarm = DepartureAlarm(walkTimeToStop: 5);
    var departureCalls = 0;
    alarm.onDeparture = (_, __) => departureCalls++;

    // 오늘 요일에 활성 스케줄이 있으나 시각이 한참 안 맞게(+5시간) 설정 → 창 밖
    final now = DateTime.now();
    final today = DayOfWeek.fromDateTime(now);
    final farHour = (now.hour + 5) % 24;
    alarm.setSchedule(today, true, farHour, 0);

    alarm.setSelectedRoutes([route('R1', '564', 100)]);
    alarm.evaluateAlerts(564, 100); // 임계(300) 이하지만 창 밖 → 억제
    expect(departureCalls, 0);
  });
}

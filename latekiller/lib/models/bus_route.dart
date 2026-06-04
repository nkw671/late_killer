import '../services/event_manager.dart';

/// 한 정류장에서 도착하는 한 버스 노선
class BusRoute {
  final String routeId;
  final String busNumber; // 버스 번호 (문자/숫자 혼합 가능)
  int busArriveTime; // 초 단위 남은시간
  final EventManager events = EventManager();

  BusRoute({
    required this.routeId,
    required this.busNumber,
    this.busArriveTime = 0,
  });

  /// 매 초 호출 — 남은시간 1초 감소 후 옵저버 통지
  void tick() {
    if (busArriveTime > 0) busArriveTime--;
    events.notify(busNumber, busArriveTime);
  }

  /// 1분 주기 API 응답으로 카운트다운을 항상 갱신 (누적 오차 제거)
  void correctArriveTime(int apiTime) {
    busArriveTime = apiTime;
    events.notify(busNumber, busArriveTime);
  }
}

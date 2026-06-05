// === MOCK DATA — 테스트 후 이 파일 삭제 + bus_api.dart 의 MOCK 마커 블록 삭제 ===
//
// 심야 등 실API에 도착정보가 없을 때 임시로 가짜 도착시간을 만든다.
// 노선별로 "처음 본 시각"을 기록하고, 그로부터 초가 흐르면서 줄어들도록 계산.
// 0초 근처가 되면 새 인스턴스로 점프(>= 120s) → DepartureAlarm의 "버스 통과" 분기도 트리거됨.
import '../models/bus_route.dart';

class MockBusData {
  /// 끄려면 false. 파일 삭제 시 더 이상 import 안 됨.
  static const bool enabled = false;

  static final Map<String, DateTime> _firstSeen = {};

  /// 노선별 초기 도착시간(초). 등록 안 된 노선은 [defaultInitial].
  static const Map<String, int> initialByRouteId = {};
  static const int defaultInitial = 1200; // 20분
  static const int maxInitial = 1200; // 상한

  /// 특정 노선의 현재 가상 도착시간(초).
  static int arrivalSeconds(String routeId, {int? initial}) {
    final base = initial ?? initialByRouteId[routeId] ?? defaultInitial;
    final now = DateTime.now();
    _firstSeen[routeId] ??= now;
    var elapsed = now.difference(_firstSeen[routeId]!).inSeconds;
    // 회전: 도착(0)이 지나면 새 인스턴스로 점프
    final cycle = base + 60;
    var t = base - elapsed;
    while (t < -5) {
      _firstSeen[routeId] = _firstSeen[routeId]!.add(Duration(seconds: cycle));
      elapsed -= cycle;
      t = base - elapsed;
    }
    return t < 0 ? 0 : t;
  }

  /// 정류장 경유 노선 mock. 실제 노선 목록을 받아 각 노선에 가상 도착시간을 채워 반환.
  /// 실 routes가 비어있으면 더미 노선을 만든다.
  static List<BusRoute> mockRoutes(List<BusRoute> realRoutes) {
    if (realRoutes.isEmpty) {
      // 정류장 노선목록조차 없을 때 임의 노선 3개 생성 (5분 · 12분 · 20분)
      return [
        BusRoute(
            routeId: 'MOCK-1',
            busNumber: '환승1',
            busArriveTime: arrivalSeconds('MOCK-1', initial: 300)),
        BusRoute(
            routeId: 'MOCK-2',
            busNumber: '환승2',
            busArriveTime: arrivalSeconds('MOCK-2', initial: 720)),
        BusRoute(
            routeId: 'MOCK-3',
            busNumber: '환승3',
            busArriveTime: arrivalSeconds('MOCK-3', initial: 1200)),
      ];
    }
    // 실제 노선 목록 유지하되 도착시간만 갱신 — 2분, 4분, ..., 20분 상한.
    final list = <BusRoute>[];
    for (var i = 0; i < realRoutes.length; i++) {
      final r = realRoutes[i];
      final init = ((i + 1) * 120).clamp(60, maxInitial);
      list.add(BusRoute(
        routeId: r.routeId,
        busNumber: r.busNumber,
        busArriveTime: arrivalSeconds(r.routeId, initial: init),
      ));
    }
    return list;
  }
}

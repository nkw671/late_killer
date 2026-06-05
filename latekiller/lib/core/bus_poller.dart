import 'dart:async';
import '../models/bus_route.dart';
import '../services/bus_api.dart';

/// 후보 노선들의 도착시간을 주기적으로 갱신한다.
/// - 1초 tick으로 카운트다운 (`BusRoute.tick`)
/// - 60초마다 API 재호출 (`BusRoute.correctArriveTime`)
/// - "버스 통과" 감지 시 [onBusPassed] 콜백 호출
class BusPoller {
  final List<BusRoute> candidates;
  final String stopId;
  final void Function(BusRoute passed)? onBusPassed;

  /// 매 refresh 완료 직후 호출 — 가장 이른 버스 재선택 등에 사용.
  final void Function()? onRefreshed;

  Timer? _apiTimer;
  Timer? _tickTimer;
  Future<void>? _firstRefresh;

  BusPoller({
    required this.candidates,
    required this.stopId,
    this.onBusPassed,
    this.onRefreshed,
  });

  /// 첫 API 응답이 도착한 시점 — 시작 안내 등에서 await 가능.
  Future<void> get firstRefreshed => _firstRefresh ?? Future.value();

  void start() {
    _firstRefresh = refresh();
    _apiTimer?.cancel();
    _apiTimer = Timer.periodic(const Duration(seconds: 60), (_) => refresh());
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      for (final r in candidates) {
        r.tick();
      }
    });
  }

  void stop() {
    _apiTimer?.cancel();
    _apiTimer = null;
    _tickTimer?.cancel();
    _tickTimer = null;
  }

  Future<void> refresh() async {
    for (final r in candidates) {
      try {
        final t = await BusApi().getBusArrivalList(stopId, r.routeId);
        final before = r.busArriveTime;
        // 카운트다운이 거의 0인데 API가 새 인스턴스(>=120s) 반환 → 통과로 간주
        final passed = before <= 30 && t >= 120;
        r.correctArriveTime(t);
        // ignore: avoid_print
        print('[API] ${r.busNumber} api=${t}s countdown=${before}s '
            'diff=${(t - before).abs()}s applied=${r.busArriveTime}s'
            '${passed ? " [PASSED]" : ""}');
        if (passed) onBusPassed?.call(r);
      } catch (e) {
        // ignore: avoid_print
        print('[API] ${r.busNumber} error: $e');
      }
    }
    onRefreshed?.call();
  }
}

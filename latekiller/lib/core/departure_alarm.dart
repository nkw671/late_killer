import '../models/alarm_schedule.dart';
import '../models/bus_route.dart';
import '../services/event_manager.dart';
import '../services/notification.dart';
import '../services/tts.dart';
import 'bus_poller.dart';
import 'periodic_announcer.dart';
import 'start_announcer.dart';
import 'threshold_announcer.dart';

/// 알람 조정자 (Coordinator).
/// - 후보 노선 중 가장 이른 버스를 선택해 추적
/// - [BusPoller]로 폴링, [ThresholdAnnouncer]로 출발 알림,
///   [PeriodicAnnouncer]로 주기 안내, [StartAnnouncer]로 시작 안내
/// - 자기 자신만 후보들을 옵저버로 구독해 매 tick마다 판정
class DepartureAlarm implements Observer {
  final int walkTimeToStop; // 초
  final String stopId;
  final List<BusRoute> candidates;
  final PlayTTS tts;
  final LockNotification notif;
  final Map<int, AlarmSchedule> schedules;

  late final BusPoller _poller;
  late final ThresholdAnnouncer _threshold;
  late final PeriodicAnnouncer _periodic;
  late final StartAnnouncer _start;

  BusRoute? selectedBus;

  DepartureAlarm({
    required this.walkTimeToStop,
    required this.stopId,
    required this.candidates,
    required this.tts,
    required this.notif,
    Map<int, AlarmSchedule>? schedules,
  }) : schedules = schedules ?? {} {
    _threshold = ThresholdAnnouncer(tts: tts, notif: notif);
    _periodic = PeriodicAnnouncer(tts: tts);
    _start = StartAnnouncer(tts: tts);
    _poller = BusPoller(
      candidates: candidates,
      stopId: stopId,
      onBusPassed: (passed) {
        // 통과한 버스가 현재 선택 버스라면 다음 인스턴스에 다시 발화 가능하도록 리셋
        if (identical(passed, selectedBus)) _threshold.reset();
      },
      // 매 갱신마다 가장 이른 버스 재선택 (REQ-12 순위 변동 반영)
      onRefreshed: selectEarliestBus,
    );
    for (final r in candidates) {
      r.events.subscribe(this);
    }
  }

  /// 가장 이른(도착시간 > 0) 버스를 선택. 새 버스 선택 시 임계 플래그 리셋.
  void selectEarliestBus() {
    if (candidates.isEmpty) return;
    candidates.sort((a, b) => a.busArriveTime.compareTo(b.busArriveTime));
    final next = candidates.firstWhere(
      (r) => r.busArriveTime > 0,
      orElse: () => candidates.first,
    );
    if (next != selectedBus) {
      selectedBus = next;
      _threshold.reset();
    }
  }

  /// 다음으로 이른 버스로 강제 전환 (REQ-12 시뮬레이션 등).
  void switchToNextEarliestBus() {
    if (candidates.length <= 1) return;
    candidates.sort((a, b) => a.busArriveTime.compareTo(b.busArriveTime));
    final next = candidates.firstWhere(
      (r) => r != selectedBus && r.busArriveTime > 0,
      orElse: () => candidates.first,
    );
    selectedBus = next;
    _threshold.reset();
  }

  /// 폴링 시작 + 첫 API 응답 후 시작 안내 1회 발화.
  /// (selectEarliestBus는 onRefreshed 콜백에서 이미 호출됨)
  void callAPI() {
    _poller.start();
    _poller.firstRefreshed.then((_) => _start.announce(selectedBus));
  }

  void stopAPI() => _poller.stop();

  void stopAlarm() {
    _poller.stop();
    for (final r in candidates) {
      r.events.unsubscribe(this);
    }
  }

  /// 테스트 호환용 — REQ-18 판정 위임.
  bool shouldAnnounceNow(int remainingTime, DateTime now) =>
      _periodic.shouldAnnounceNow(remainingTime, now);

  @override
  void update(String busNumber, int busArriveTime) {
    if (selectedBus == null || busNumber != selectedBus!.busNumber) return;
    // 우선 임계 발화 시도 (1회만 true 반환)
    if (_threshold.maybeFire(busNumber, busArriveTime, walkTimeToStop)) return;
    // 임계 이후엔 주기 안내
    _periodic.maybeAnnounce(busNumber, busArriveTime, DateTime.now());
  }
}

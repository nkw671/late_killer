import 'dart:async';
import '../models/alarm_schedule.dart';
import '../models/bus_route.dart';
import '../services/bus_api.dart';
import '../services/event_manager.dart';
import '../services/tts.dart';
import '../services/notification.dart';

/// 알람 실행 엔진.
/// - 후보 노선들을 1초 tick + 30초 API polling으로 추적
/// - 매 tick은 UI 갱신용으로만 사용 (옵저버 통지)
/// - TTS/알림은 DepartureAlarm이 직접 제어 (주기/임계 이벤트 시에만)
class DepartureAlarm implements Observer {
  int walkTimeToStop; // 초
  int thresholdTime = 0;
  final Map<int, AlarmSchedule> schedules;
  final String stopId;
  final List<BusRoute> candidates;
  final PlayTTS tts;
  final LockNotification notif;

  BusRoute? selectedBus;
  Timer? _apiTimer;
  Timer? _tickTimer;
  bool _alertedThreshold = false;

  DepartureAlarm({
    required this.walkTimeToStop,
    required this.stopId,
    required this.candidates,
    required this.tts,
    required this.notif,
    Map<int, AlarmSchedule>? schedules,
  }) : schedules = schedules ?? {} {
    for (final r in candidates) {
      r.events.subscribe(this); // UI 갱신용 (자기 자신만 구독)
    }
  }

  void selectEarliestBus() {
    if (candidates.isEmpty) return;
    candidates.sort((a, b) => a.busArriveTime.compareTo(b.busArriveTime));
    final next = candidates.firstWhere(
      (r) => r.busArriveTime > 0,
      orElse: () => candidates.first,
    );
    if (next != selectedBus) {
      selectedBus = next;
      _alertedThreshold = false; // 새 버스 선택 시 임계 플래그 리셋
    }
  }

  void switchToNextEarliestBus() {
    if (candidates.length <= 1) return;
    candidates.sort((a, b) => a.busArriveTime.compareTo(b.busArriveTime));
    final next = candidates.firstWhere(
      (r) => r != selectedBus && r.busArriveTime > 0,
      orElse: () => candidates.first,
    );
    selectedBus = next;
    _alertedThreshold = false;
  }

  int setDepartureThreshold(int walk, int arrive) {
    thresholdTime = arrive - walk;
    return thresholdTime;
  }

  void callAPI() {
    // 첫 API 응답 도착 후 알람 시작 안내 + 선택 버스 남은시간 1회 발화
    _refresh().then((_) {
      final s = selectedBus;
      if (s == null || s.busArriveTime <= 0) {
        tts.speakMessage('알람을 시작합니다');
        return;
      }
      final m = s.busArriveTime ~/ 60;
      final tail = m > 0
          ? '${s.busNumber}번 버스 약 $m분 후 도착'
          : '${s.busNumber}번 버스 곧 도착';
      tts.speakMessage('알람을 시작합니다. $tail');
    });
    _apiTimer?.cancel();
    // REQ-15: 1분 간격 API polling
    _apiTimer = Timer.periodic(const Duration(seconds: 60), (_) => _refresh());
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      for (final r in candidates) {
        r.tick();
      }
    });
  }

  void stopAPI() {
    _apiTimer?.cancel();
    _tickTimer?.cancel();
  }

  Future<void> _refresh() async {
    for (final r in candidates) {
      try {
        final t = await BusApi().getBusArrivalList(stopId, r.routeId);
        final before = r.busArriveTime;
        // 버스 통과 감지: 카운트다운 거의 0인데 API가 새 인스턴스(>=120s) 반환
        final bool passed = before <= 30 && t >= 120;
        r.correctArriveTime(t);
        if (passed && r == selectedBus) {
          _alertedThreshold = false; // 새 인스턴스에 대해 다시 알림 가능
        }
        // ignore: avoid_print
        print('[API] ${r.busNumber} api=${t}s countdown=${before}s '
            'diff=${(t - before).abs()}s applied=${r.busArriveTime}s'
            '${passed ? " [PASSED]" : ""}');
      } catch (e) {
        // ignore: avoid_print
        print('[API] ${r.busNumber} error: $e');
      }
    }
    selectEarliestBus();
  }

  /// REQ-18: 남은시간 기준 — 남은시간이 분 정각(예: 9분 0초)에 도달할 때 안내.
  /// 10분 이상: 5분 간격(10·15·20…분).
  /// 10분 미만: 1분 간격(9·8·7…분).
  bool shouldAnnounceNow(int remainingTime, DateTime now) {
    if (remainingTime <= 0) return false;
    if (remainingTime % 60 != 0) return false;
    if (remainingTime >= 600) return remainingTime % 300 == 0;
    return true;
  }

  void stopAlarm() {
    stopAPI();
    for (final r in candidates) {
      r.events.unsubscribe(this);
    }
  }

  @override
  void update(String busNumber, int busArriveTime) {
    if (selectedBus == null || busNumber != selectedBus!.busNumber) return;
    setDepartureThreshold(walkTimeToStop, busArriveTime);

    // REQ-11: 임계시간 도달 시 1회만 출발 알림
    // REQ-20: TTS에 노선번호 + 남은시간(분) 포함
    // REQ-21/22: 알림에 노선번호 + 예정 도착시각 포함
    if (!_alertedThreshold &&
        busArriveTime <= walkTimeToStop &&
        busArriveTime > 0) {
      _alertedThreshold = true;
      final m = busArriveTime ~/ 60;
      final ttsMsg = m > 0
          ? '$busNumber번 버스 $m분 후 도착. 지금 출발하세요'
          : '$busNumber번 버스 곧 도착. 지금 출발하세요';
      tts.speakMessage(ttsMsg);
      notif.showDeparture(busNumber, busArriveTime);
      return;
    }

    // REQ-18: 벽시계 정각 기준 주기 안내
    if (shouldAnnounceNow(busArriveTime, DateTime.now())) {
      tts.speak(busNumber, busArriveTime);
    }
  }
}

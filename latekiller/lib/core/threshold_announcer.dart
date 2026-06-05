import '../services/notification.dart';
import '../services/tts.dart';

/// REQ-11: 알림 기준 버스의 도착시간이 도보 소요시간과 같아지는 순간
/// **1회만** 출발 알림(TTS + 잠금화면 알림)을 발화한다.
class ThresholdAnnouncer {
  final PlayTTS tts;
  final LockNotification notif;
  bool _fired = false;

  ThresholdAnnouncer({required this.tts, required this.notif});

  /// 발화 조건 충족 시 1회 발화하고 true 반환. 이미 발화했거나 조건 미충족이면 false.
  bool maybeFire(String busNumber, int busArriveTime, int walkTimeToStop) {
    if (_fired) return false;
    if (busArriveTime <= 0 || busArriveTime > walkTimeToStop) return false;
    _fired = true;
    final m = busArriveTime ~/ 60;
    final msg = m > 0
        ? '$busNumber번 버스 $m분 후 도착. 지금 출발하세요'
        : '$busNumber번 버스 곧 도착. 지금 출발하세요';
    tts.speakMessage(msg);
    notif.showDeparture(busNumber, busArriveTime);
    return true;
  }

  /// 새 버스 선택 / 버스 통과 시 다시 발화 가능하도록 리셋.
  void reset() => _fired = false;

  bool get hasFired => _fired;
}

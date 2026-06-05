import '../services/tts.dart';

/// REQ-18: 남은시간 기준 주기 안내.
/// - 10분 이상 → 5분 배수 정각(15분 0초·20분 0초…)
/// - 10분 미만 → 매 분 정각(9분 0초·8분 0초…)
class PeriodicAnnouncer {
  final PlayTTS tts;

  PeriodicAnnouncer({required this.tts});

  bool shouldAnnounceNow(int remainingTime, DateTime now) {
    if (remainingTime <= 0) return false;
    if (remainingTime % 60 != 0) return false;
    if (remainingTime >= 600) return remainingTime % 300 == 0;
    return true;
  }

  /// 조건 충족 시 TTS로 1회 발화.
  void maybeAnnounce(String busNumber, int remainingTime, DateTime now) {
    if (shouldAnnounceNow(remainingTime, now)) {
      tts.speak(busNumber, remainingTime);
    }
  }
}

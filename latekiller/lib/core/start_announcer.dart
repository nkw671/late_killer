import '../models/bus_route.dart';
import '../services/tts.dart';

/// 알람 시작 직후 1회만 발화하는 시작 안내.
/// - 선택 버스가 있으면: "알람을 시작합니다. X번 버스 약 N분 후 도착"
/// - 선택 버스 없음/도착정보 없음: "알람을 시작합니다"
class StartAnnouncer {
  final PlayTTS tts;
  StartAnnouncer({required this.tts});

  void announce(BusRoute? selected) {
    if (selected == null || selected.busArriveTime <= 0) {
      tts.speakMessage('알람을 시작합니다');
      return;
    }
    final m = selected.busArriveTime ~/ 60;
    final tail = m > 0
        ? '${selected.busNumber}번 버스 약 $m분 후 도착'
        : '${selected.busNumber}번 버스 곧 도착';
    tts.speakMessage('알람을 시작합니다. $tail');
  }
}

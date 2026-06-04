import 'package:flutter_tts/flutter_tts.dart';
import 'observer.dart';

/// 클래스 다이어그램의 PlayTTS (Observer 구현)
///
/// - volume : int
/// + speak(busNumber, remainingTime) : void          (REQ-15, REQ-16)
/// + speakMessage(message) : void                     (REQ-13 음성)
/// + setVolume() : void                               (REQ-17)
/// + update(busNumber, busArriveTime) : void
///
/// 임계 시각 도달 시(DepartureAlarm가 판단) update가 호출되며,
/// 내부에서 speak()를 불러 음성 안내한다.
class PlayTTS implements Observer {
  final FlutterTts _tts = FlutterTts();
  int volume = 100; // 0~100 (REQ-17)
  bool _ready = false;

  Future<void> init() async {
    await _tts.setLanguage('ko-KR'); // 한국어 음성 (REQ-15/16)
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(volume / 100.0);
    _ready = true;
  }

  /// + setVolume() : void  (0~100, 시스템 미디어 볼륨과 독립)
  Future<void> setVolume(int value) async {
    volume = value.clamp(0, 100);
    await _tts.setVolume(volume / 100.0);
  }

  /// + speak(busNumber: int, remainingTime: int) : void
  /// REQ-15: 노선 번호, REQ-16: 남은 시간(분)을 한국어로 출력.
  Future<void> speak(int busNumber, int remainingTimeSec) async {
    if (!_ready) await init();
    final minutes = (remainingTimeSec / 60).round();
    final text = '$busNumber번 버스, 약 $minutes분 후 도착. 지금 출발하세요.';
    await _tts.stop();
    await _tts.speak(text);
  }

  /// + speakMessage(message: string) : void
  Future<void> speakMessage(String message) async {
    if (!_ready) await init();
    await _tts.stop();
    await _tts.speak(message);
  }

  /// + update(busNumber, busArriveTime) : void
  /// 출발 임계 알림 시점에 호출 — 음성 안내 트리거.
  @override
  void update(int busNumber, int busArriveTime) {
    speak(busNumber, busArriveTime);
  }

  void dispose() {
    _tts.stop();
  }
}

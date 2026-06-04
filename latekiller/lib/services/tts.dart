import 'package:flutter_tts/flutter_tts.dart';
import 'event_manager.dart';

class PlayTTS implements Observer {
  final FlutterTts _tts = FlutterTts();
  int volume = 100;
  late final Future<void> _ready;

  PlayTTS() {
    _ready = _init();
  }

  Future<void> _init() async {
    await _tts.awaitSpeakCompletion(true);
    for (var i = 0; i < 40; i++) {
      try {
        final engine = await _tts.getDefaultEngine;
        if (engine != null && engine.toString().isNotEmpty) {
          try {
            await _tts.setEngine(engine.toString());
          } catch (_) {}
          final avail = await _tts.isLanguageAvailable('ko-KR');
          if (avail == true) break;
        }
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 250));
    }
    try {
      await _tts.setLanguage('ko-KR');
      await _tts.setVolume(1.0);
    } catch (_) {}
  }

  Future<void> _speakWithRetry(String msg) async {
    await _ready;
    for (var i = 0; i < 5; i++) {
      try {
        final r = await _tts.speak(msg);
        if (r == 1) return;
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 300));
    }
  }

  Future<void> speak(String busNumber, int remainingTime) async {
    final m = remainingTime ~/ 60;
    final msg = m > 0 ? '$busNumber번 버스 약 $m분 후 도착' : '$busNumber번 버스 곧 도착';
    await _speakWithRetry(msg);
  }

  Future<void> speakMessage(String message) async {
    await _speakWithRetry(message);
  }

  Future<void> setVolume(int v) async {
    volume = v;
    await _ready;
    await _tts.setVolume(v / 100.0);
  }

  @override
  void update(String busNumber, int busArriveTime) {
    // 안내 주기 — 외부에서 컨트롤
  }
}

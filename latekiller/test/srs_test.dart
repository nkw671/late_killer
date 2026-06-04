// SRS 요구사항 자동 검증 (REQ-01 ~ REQ-24 중 단위 테스트 가능 항목)
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latekiller/core/departure_alarm.dart';
import 'package:latekiller/models/bus_route.dart';
import 'package:latekiller/services/tts.dart';
import 'package:latekiller/services/notification.dart';
import 'package:latekiller/services/event_manager.dart';
import 'package:intl/intl.dart';

class _FakeTts implements PlayTTS {
  final List<String> messages = [];
  @override
  int volume = 100;
  @override
  Future<void> speak(String busNumber, int remainingTime) async {
    final m = remainingTime ~/ 60;
    messages.add(m > 0 ? '$busNumber번 버스 약 $m분 후 도착' : '$busNumber번 버스 곧 도착');
  }
  @override
  Future<void> speakMessage(String message) async => messages.add(message);
  @override
  Future<void> setVolume(int v) async => volume = v;
  @override
  void update(String busNumber, int busArriveTime) {}
  @override
  noSuchMethod(Invocation i) => null;
}

class _FakeNotif implements LockNotification {
  final List<String> calls = [];
  @override
  Future<void> init() async {}
  @override
  Future<void> showNotification(String b, int t) async =>
      calls.add('arrival:$b:$t');
  @override
  Future<void> showMessage(String m) async => calls.add('msg:$m');
  @override
  Future<void> showDeparture(String busNumber, int busArriveTime) async {
    final hhmm = DateFormat('HH:mm')
        .format(DateTime.now().add(Duration(seconds: busArriveTime)));
    calls.add('dep:$busNumber:$hhmm');
  }
  @override
  void update(String b, int t) {}
  @override
  noSuchMethod(Invocation i) => null;
}

DepartureAlarm _mk({
  required int walkSec,
  required List<BusRoute> cs,
  _FakeTts? tts,
  _FakeNotif? notif,
}) {
  return DepartureAlarm(
    walkTimeToStop: walkSec,
    stopId: 'S1',
    candidates: cs,
    tts: tts ?? _FakeTts(),
    notif: notif ?? _FakeNotif(),
  );
}

void main() {
  test('[REQ-10] selectEarliestBus picks earliest >0', () {
    final a = BusRoute(routeId: 'A', busNumber: 'A', busArriveTime: 600);
    final b = BusRoute(routeId: 'B', busNumber: 'B', busArriveTime: 300);
    final c = BusRoute(routeId: 'C', busNumber: 'C', busArriveTime: 900);
    final al = _mk(walkSec: 300, cs: [a, b, c]);
    al.selectEarliestBus();
    expect(al.selectedBus?.busNumber, 'B');
  });

  test('[REQ-11] threshold alert fires exactly once', () async {
    final tts = _FakeTts();
    final notif = _FakeNotif();
    final r = BusRoute(routeId: 'A', busNumber: '100', busArriveTime: 600);
    final al = _mk(walkSec: 600, cs: [r], tts: tts, notif: notif);
    al.selectEarliestBus();
    // 도착 == 도보 → 임계 도달
    al.update('100', 600);
    await Future.delayed(const Duration(milliseconds: 10));
    // 다시 호출해도 1회만
    al.update('100', 599);
    al.update('100', 500);
    expect(notif.calls.where((c) => c.startsWith('dep:')).length, 1);
    expect(tts.messages.where((m) => m.contains('지금 출발')).length, 1);
  });

  test('[REQ-12] switchToNextEarliestBus picks next candidate', () {
    final a = BusRoute(routeId: 'A', busNumber: 'A', busArriveTime: 100);
    final b = BusRoute(routeId: 'B', busNumber: 'B', busArriveTime: 300);
    final al = _mk(walkSec: 60, cs: [a, b]);
    al.selectEarliestBus();
    expect(al.selectedBus?.busNumber, 'A');
    al.switchToNextEarliestBus();
    expect(al.selectedBus?.busNumber, 'B');
  });

  test('[REQ-13] stopAlarm unsubscribes from routes', () {
    final r = BusRoute(routeId: 'A', busNumber: 'A', busArriveTime: 100);
    final al = _mk(walkSec: 60, cs: [r]);
    al.stopAlarm();
    // 옵저버 제거 후 tick 호출 시 update 호출되지 않음 (예외 없이 동작)
    r.tick();
    expect(r.busArriveTime, 99);
  });

  test('[REQ-17] tick decrements 1 second', () {
    final r = BusRoute(routeId: 'A', busNumber: 'A', busArriveTime: 10);
    r.tick();
    expect(r.busArriveTime, 9);
    r.tick();
    expect(r.busArriveTime, 8);
  });

  test('[REQ-17] tick stops at 0', () {
    final r = BusRoute(routeId: 'A', busNumber: 'A', busArriveTime: 0);
    r.tick();
    expect(r.busArriveTime, 0);
  });

  group('[REQ-18] shouldAnnounceNow (남은시간 기준)', () {
    final al = _mk(walkSec: 60, cs: []);
    final t = DateTime(2026, 1, 1, 10, 0, 0); // 벽시계 무관
    test('>=10분 → 5분 배수 정각에만 true', () {
      expect(al.shouldAnnounceNow(600, t), true);   // 10분
      expect(al.shouldAnnounceNow(900, t), true);   // 15분
      expect(al.shouldAnnounceNow(660, t), false);  // 11분
      expect(al.shouldAnnounceNow(615, t), false);  // 10분15초
    });
    test('<10분 → 매 분 정각에 true', () {
      expect(al.shouldAnnounceNow(540, t), true);   // 9분
      expect(al.shouldAnnounceNow(480, t), true);   // 8분
      expect(al.shouldAnnounceNow(60, t), true);    // 1분
      expect(al.shouldAnnounceNow(535, t), false);  // 8분55초
    });
    test('remaining<=0 → false', () => expect(al.shouldAnnounceNow(0, t), false));
  });

  test('[REQ-19/20] 출발 TTS 메시지에 노선번호와 분 포함', () async {
    final tts = _FakeTts();
    final r = BusRoute(routeId: 'A', busNumber: '787', busArriveTime: 300);
    final al = _mk(walkSec: 300, cs: [r], tts: tts);
    al.selectEarliestBus();
    al.update('787', 300);
    expect(tts.messages.any((m) => m.contains('787번') && m.contains('5분')), true);
    expect(tts.messages.any((m) => m.contains('지금 출발')), true);
  });

  test('[REQ-21/22] 출발 알림 본문에 노선번호와 HH:MM 포함', () async {
    final notif = _FakeNotif();
    final r = BusRoute(routeId: 'A', busNumber: '100', busArriveTime: 120);
    final al = _mk(walkSec: 120, cs: [r], notif: notif);
    al.selectEarliestBus();
    al.update('100', 120);
    expect(notif.calls.first.startsWith('dep:100:'), true);
    expect(RegExp(r'dep:100:\d{2}:\d{2}').hasMatch(notif.calls.first), true);
  });

  test('[REQ-12 보강] 새 버스 선택 시 임계 플래그 리셋', () async {
    final notif = _FakeNotif();
    final a = BusRoute(routeId: 'A', busNumber: 'A', busArriveTime: 60);
    final b = BusRoute(routeId: 'B', busNumber: 'B', busArriveTime: 300);
    final al = _mk(walkSec: 60, cs: [a, b], notif: notif);
    al.selectEarliestBus();
    al.update('A', 60); // 알림 1회
    al.switchToNextEarliestBus(); // → B
    expect(al.selectedBus?.busNumber, 'B');
    al.update('B', 60); // B로 다시 1회 발생 가능
    expect(notif.calls.where((c) => c.startsWith('dep:')).length, 2);
  });

  test('[REQ EventManager] subscribe/notify/unsubscribe', () {
    final em = EventManager();
    final received = <String>[];
    final obs = _Sub((b, t) => received.add('$b:$t'));
    em.subscribe(obs);
    em.notify('A', 10);
    em.unsubscribe(obs);
    em.notify('A', 9);
    expect(received, ['A:10']);
  });
}

class _Sub implements Observer {
  final void Function(String, int) cb;
  _Sub(this.cb);
  @override
  void update(String b, int t) => cb(b, t);
}

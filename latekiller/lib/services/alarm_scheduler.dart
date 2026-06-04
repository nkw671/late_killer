import 'dart:async';
import 'package:flutter/material.dart';
import '../models/alarm_config.dart';
import '../screens/alarm_active_screen.dart';
import 'bus_api.dart';
import 'storage.dart';

/// REQ-08/09: 저장된 알람의 요일/시각이 도래하면 자동으로 AlarmActiveScreen 진입.
/// 30초 주기로 모든 알람을 검사하며, 같은 분 내 중복 트리거를 방지한다.
class AlarmScheduler {
  static final AlarmScheduler _i = AlarmScheduler._();
  factory AlarmScheduler() => _i;
  AlarmScheduler._();

  Timer? _timer;
  final Set<String> _fired = {}; // 'stopId-day-HH:MM-yyyyMMdd'
  bool _launching = false;
  GlobalKey<NavigatorState>? _navKey;

  void start(GlobalKey<NavigatorState> navKey) {
    _navKey = navKey;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _tick());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _tick() async {
    if (_launching) return;
    final nav = _navKey?.currentState;
    if (nav == null) return;

    final now = DateTime.now();
    final today = now.weekday; // 1~7
    final dateKey =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';

    final alarms = await Storage().loadAlarms();
    for (final cfg in alarms) {
      final sch = cfg.schedules[today];
      if (sch == null || !sch.isEnabled) continue;
      if (sch.alarmTime.hour != now.hour ||
          sch.alarmTime.minute != now.minute) continue;
      final key =
          '${cfg.stopId}-$today-${sch.alarmTime.hour}:${sch.alarmTime.minute}-$dateKey';
      if (_fired.contains(key)) continue;
      _fired.add(key);
      await _launch(cfg);
      break; // 한 tick에 한 알람만
    }

    // 어제 키 정리
    if (_fired.length > 200) _fired.clear();
  }

  Future<void> _launch(AlarmConfig cfg) async {
    final nav = _navKey?.currentState;
    if (nav == null) return;
    _launching = true;
    try {
      final routes = await BusApi().getAllRouteBusArrivalList(cfg.stopId);
      nav.push(
        MaterialPageRoute(
          builder: (_) => AlarmActiveScreen(config: cfg, allRoutes: routes),
        ),
      );
    } catch (_) {
      // API 실패 시 조용히 스킵 (다음 분에 재시도 안 함 — 이미 _fired 등록됨)
    } finally {
      _launching = false;
    }
  }
}

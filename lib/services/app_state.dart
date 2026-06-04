import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../models/bus_stop.dart';
import '../models/bus_route.dart';
import '../models/bus_alarm.dart';
import '../models/alarm_schedule.dart';
import '../models/day_of_week.dart';
import 'bus_api_service.dart';
import '../observers/departure_alarm.dart';
import '../observers/play_tts.dart';
import '../observers/lock_notification.dart';
import '../observers/floating_widget.dart';

/// 앱 전체 상태 + Observer 패턴 배선(wiring) 컨트롤러.
class AppState extends ChangeNotifier {
  final BusApiService api = BusApiService();

  final DepartureAlarm departureAlarm = DepartureAlarm();
  final PlayTTS playTTS = PlayTTS();
  final LockNotification lockNotification = LockNotification();
  final FloatingWidget floatingWidget = FloatingWidget();

  final List<BusStop> favorites = [];
  final List<BusAlarm> busAlarms = [];   // 저장된 알람 목록
  BusStop? activeStop;
  List<BusRoute> arrivals = [];
  List<BusRoute> selectedRoutes = [];

  bool alarmRunning = false;
  String? lastEvent;
  String? apiError; // API 오류 메시지 (UI 표시용)
  Timer? _pollTimer;
  Timer? _uiTimer; // 1초 간격 UI 카운트다운
  BusRoute? _subscribedTarget; // 현재 옵저버가 구독 중인 기준 버스 (누수 방지)

  static const Duration pollInterval = Duration(seconds: 8); // REQ-14: ≤10초


  // ──────────────────────────────────────────────
  //  초기화
  // ──────────────────────────────────────────────
  Future<void> init() async {
    await playTTS.init();
    await lockNotification.init();
    await _loadFavorites();
    await _loadBusAlarms();

    departureAlarm.onDeparture = (busNumber, sec) {
      lastEvent = '🚍 $busNumber번 — 지금 출발하세요!';
      playTTS.speak(busNumber, sec);
      lockNotification.showNotification(busNumber, sec);
      notifyListeners();
    };
    departureAlarm.onAllPassed = (msg) {
      lastEvent = '🛑 $msg';
      lockNotification.showMessage(msg);
      playTTS.speakMessage(msg);
      stopAlarm();
      notifyListeners();
    };
    departureAlarm.onTargetChanged = (target) {
      lastEvent = '기준 버스: ${target.routeNo}번';
      notifyListeners();
    };
    // 주기적 남은시간 안내 (10분↑: 5분간격, 10분↓: 1분간격)
    departureAlarm.onAnnounce = (busNumber, sec) {
      final min = (sec / 60).round();
      playTTS.speakMessage('$busNumber번 버스 약 $min분 후 도착 예정입니다');
    };
  }

  // ──────────────────────────────────────────────
  //  검색 (REQ-01/02)
  // ──────────────────────────────────────────────
  Future<List<BusStop>> searchStops(String query, {required bool byNumber}) {
    return api.searchStopsByName(query);
  }

  Future<List<BusRoute>> searchRoutes(String routeNo) {
    return api.searchRoutesByNumber(routeNo);
  }

  Future<List<BusStop>> loadRouteSections(String routeId) {
    return api.getRouteSections(routeId);
  }

  // ──────────────────────────────────────────────
  //  즐겨찾기 (REQ-03/04)
  // ──────────────────────────────────────────────
  Future<void> addFavorite(BusStop stop) async {
    if (!favorites.contains(stop)) {
      stop.addFavorite();
      favorites.add(stop);
      await _saveFavorites();
      notifyListeners();
    }
  }

  Future<void> removeFavorite(BusStop stop) async {
    stop.deleteFavorite();
    favorites.remove(stop);
    await _saveFavorites();
    notifyListeners();
  }

  // ──────────────────────────────────────────────
  //  버스 알람 저장/삭제/실행
  // ──────────────────────────────────────────────

  /// 현재 설정(stop, selectedRoutes, schedules, walkTime)으로 알람을 저장한다.
  /// [stop]은 알람설정 화면이 보유한 정류장. activeStop은 알람 실행 시에만
  /// 설정되므로 저장 흐름에서는 화면이 가진 정류장을 직접 전달받아야 한다.
  Future<BusAlarm> saveCurrentAlarm(BusStop stop) async {
    final alarm = BusAlarm(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      stopId: stop.stopId,
      stopName: stop.stopName,
      routes: selectedRoutes
          .map((r) => SavedRoute(routeId: r.routeId, routeNo: r.routeNo))
          .toList(),
      schedules: {
        for (final e in departureAlarm.schedules.entries)
          e.key: AlarmSchedule(
            day: e.key,
            isEnabled: e.value.isEnabled,
            hour: e.value.hour,
            minute: e.value.minute,
          )
      },
      walkTimeToStop: departureAlarm.walkTimeToStop,
    );
    busAlarms.add(alarm);
    await _saveBusAlarms();
    notifyListeners();
    return alarm;
  }

  Future<void> deleteBusAlarm(String id) async {
    busAlarms.removeWhere((a) => a.id == id);
    await _saveBusAlarms();
    notifyListeners();
  }

  /// 저장된 알람을 로드하여 알람 실행 상태로 전환한다.
  Future<void> runBusAlarm(BusAlarm alarm) async {
    // 노선 복원
    selectedRoutes = alarm.routes
        .map((r) => BusRoute(routeId: r.routeId, routeNo: r.routeNo,
              busNumber: BusRoute.parseNumber(r.routeNo)))
        .toList();
    // 스케줄/도보시간 복원
    for (final e in alarm.schedules.entries) {
      departureAlarm.setSchedule(
          e.key, e.value.isEnabled, e.value.hour, e.value.minute);
    }
    departureAlarm.setWalkTimeToStop(alarm.walkTimeToStop);
    // 알람 시작
    await startAlarm(
        BusStop(stopId: alarm.stopId, stopName: alarm.stopName, stopNumber: 0));
  }

  // ──────────────────────────────────────────────
  //  노선 조회/선택 (REQ-05/06)
  // ──────────────────────────────────────────────
  Future<List<BusRoute>> loadArrivals(BusStop stop) async {
    try {
      arrivals = await api.getArrivalsAtStop(stop.stopId);
      await api.enrichRoutes(arrivals); // routeNo / 기점·종점 채우기
      apiError = null;
    } catch (e) {
      apiError = '도착정보 조회 실패: $e';
      arrivals = [];
    }
    notifyListeners();
    return arrivals;
  }

  void toggleRouteSelection(BusRoute route) {
    route.selectBusNumber();
    if (route.isSelected) {
      if (!selectedRoutes.contains(route)) selectedRoutes.add(route);
    } else {
      selectedRoutes.remove(route);
    }
    notifyListeners();
  }

  void clearRouteSelection() {
    for (final r in selectedRoutes) {
      r.isSelected = false;
      r.selectedBus = 0;
    }
    selectedRoutes.clear();
    notifyListeners();
  }

  // ──────────────────────────────────────────────
  //  알람 설정 (REQ-07/08/09)
  // ──────────────────────────────────────────────
  void setWalkTime(int minutes) {
    departureAlarm.setWalkTimeToStop(minutes);
    notifyListeners();
  }

  void setSchedule(DayOfWeek day, bool enabled, int hour, int minute) {
    departureAlarm.setSchedule(day, enabled, hour, minute);
    notifyListeners();
  }

  // ──────────────────────────────────────────────
  //  알람 시작/정지 + 실시간 폴링 (REQ-10~14)
  // ──────────────────────────────────────────────
  Future<void> startAlarm(BusStop stop) async {
    activeStop = stop;
    departureAlarm.reset();
    departureAlarm.setSelectedRoutes(selectedRoutes);

    await floatingWidget.show();
    alarmRunning = true;
    apiError = null;
    notifyListeners();

    await _tick(); // 즉시 1회

    // 8초 API 폴링
    _pollTimer = Timer.periodic(pollInterval, (_) => _tick());
    // 1초 UI 카운트다운 (로컬 추정값)
    _uiTimer = Timer.periodic(const Duration(seconds: 1), (_) => _uiTick());
  }

  Future<void> stopAlarm() async {
    _pollTimer?.cancel();
    _pollTimer = null;
    _uiTimer?.cancel();
    _uiTimer = null;
    if (_subscribedTarget != null) {
      _subscribedTarget!.events.unsubscribe('arrival', departureAlarm);
      _subscribedTarget!.events.unsubscribe('arrival', floatingWidget);
      _subscribedTarget = null;
    }
    alarmRunning = false;
    await floatingWidget.close();
    await lockNotification.cancelAll();
    notifyListeners();
  }

  /// 매초 로컬에서 도착시간 1초 감산 → 부드러운 UI 카운트다운.
  /// 감산 후 분 경계 통과 여부를 DepartureAlarm에 알려 주기 안내를 정확히 트리거.
  void _uiTick() {
    for (final r in selectedRoutes) {
      if (r.busArriveTime > 0) r.busArriveTime -= 1;
    }
    final target = departureAlarm.currentTargetBus;
    if (target != null && alarmRunning) {
      // 1초 단위로 출발 임계/주기 안내 평가 (전환은 폴링 _tick에서만).
      departureAlarm.evaluateAlerts(target.busNumber, target.busArriveTime);
    }
    notifyListeners();
  }

  /// 폴링 1회: API 갱신 → 기준 버스의 EventManager.notify로 모든 Observer 구동.
  Future<void> _tick() async {
    if (activeStop == null) return;

    // 1) 실시간 도착정보 갱신
    List<BusRoute> fresh;
    try {
      fresh = await api.getArrivalsAtStop(activeStop!.stopId);
      apiError = null;
    } catch (e) {
      apiError = 'API 오류: $e';
      notifyListeners();
      return;
    }

    // 2) 선택된 노선의 도착시간을 최신값으로 반영.
    for (final sel in selectedRoutes) {
      final match = fresh.where((f) => f.routeId == sel.routeId);
      if (match.isEmpty) {
        // 도착목록에서 사라짐 = 통과(또는 도착정보 없음). 0으로 리셋해
        // 로컬 감산이 계속되거나 통과한 버스에 다시 알림이 울리는 것을 막는다.
        sel.busArriveTime = 0;
        continue;
      }
      final apiTime = match.first.busArriveTime;
      // API가 권위 있는 값. 단 같은 버스가 자연 감소하는 동안은 로컬 _uiTick
      // 감산이 더 부드러우므로, 소폭(≤30초) 증가만 무시하고 로컬값을 유지한다.
      // 로컬이 0까지 깎였거나(추정 오차) API가 더 작거나 큰 폭 증가면 API값 채택.
      if (sel.busArriveTime == 0 ||
          apiTime <= sel.busArriveTime ||
          apiTime - sel.busArriveTime > 30) {
        sel.busArriveTime = apiTime;
      }
    }
    arrivals = fresh;

    // 3) 기준 버스 통과 여부 확인 → 필요시에만 전환.
    // '통과'는 로컬 카운트다운 0이 아니라 이번 도착목록(fresh)에서 사라졌는지로 판단.
    final currentTarget = departureAlarm.currentTargetBus;
    final targetStillComing = currentTarget != null &&
        fresh.any((f) =>
            f.routeId == currentTarget.routeId && f.busArriveTime > 0);
    if (currentTarget == null || !targetStillComing) {
      departureAlarm.switchToNextEarliestBus();
    }

    final target = departureAlarm.currentTargetBus;

    // 4) 기준 버스 refresh() → EventManager.notify → Observer.update()
    if (target != null) {
      _ensureSubscribed(target);
      target.refresh(
        newArriveTime: target.busArriveTime,
        newBusNumber: target.busNumber,
      );
    }
    notifyListeners();
  }

  /// 기준 버스(BusRoute)가 소유한 EventManager에 Observer를 구독시킨다.
  /// PlayTTS·LockNotification은 DepartureAlarm의 콜백으로만 구동 (매 폴링마다
  /// 호출되면 8초마다 음성/알림이 울리므로).
  /// 기준 버스가 바뀌면 이전 Subject에서 구독 해제해 옵저버 누적(누수)을 막는다.
  void _ensureSubscribed(BusRoute target) {
    if (identical(_subscribedTarget, target)) return;
    if (_subscribedTarget != null) {
      _subscribedTarget!.events.unsubscribe('arrival', departureAlarm);
      _subscribedTarget!.events.unsubscribe('arrival', floatingWidget);
    }
    target.events.subscribe('arrival', departureAlarm);
    target.events.subscribe('arrival', floatingWidget);
    _subscribedTarget = target;
  }

  // ──────────────────────────────────────────────
  //  TTS 볼륨 (REQ-17)
  // ──────────────────────────────────────────────
  Future<void> setTtsVolume(int v) async {
    await playTTS.setVolume(v);
    notifyListeners();
  }

  // ──────────────────────────────────────────────
  //  영속화
  // ──────────────────────────────────────────────
  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final data = favorites.map((f) => f.toJson()).toList();
    await prefs.setString('favorites', jsonEncode(data));
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('favorites');
    if (raw == null) return;
    final list = (jsonDecode(raw) as List)
        .map((e) => BusStop.fromJson(e as Map<String, dynamic>))
        .toList();
    favorites
      ..clear()
      ..addAll(list);
  }

  Future<void> _saveBusAlarms() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'busAlarms', jsonEncode(busAlarms.map((a) => a.toJson()).toList()));
  }

  Future<void> _loadBusAlarms() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('busAlarms');
    if (raw == null) return;
    final list = (jsonDecode(raw) as List)
        .map((e) => BusAlarm.fromJson(e as Map<String, dynamic>))
        .toList();
    busAlarms
      ..clear()
      ..addAll(list);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _uiTimer?.cancel();
    playTTS.dispose();
    super.dispose();
  }
}

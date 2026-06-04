import '../services/event_manager.dart';

/// 클래스 다이어그램의 BusRoute (Subject / 도메인 객체)
///
/// - busNumber : int
/// - busArriveTime : int (초 단위)
/// - selectedBus : int
/// + events : EventManager
/// + selectBusNumber() : int
/// + refresh() : int
///
/// 인천 OpenAPI 매핑:
///   routeId(ROUTEID) — 도착정보 조회 키
///   busNumber(ROUTENO) — 사용자가 보는 노선 번호 (예: "564-1")
///   busArriveTime(ARRIVALESTIMATETIME) — 도착예정 시간(초)
class BusRoute {
  final String routeId; // ROUTEID
  String routeNo; // ROUTENO (문자열일 수 있어 별도 보관: "564-1")
  int busNumber; // 숫자 표현 (TTS/위젯용)
  int busArriveTime; // 도착까지 남은 시간(초)
  int selectedBus; // 선택된 노선 식별 (선택=1)
  bool isSelected;

  /// + events : EventManager — BusRoute가 EventManager를 소유 (aggregation)
  final EventManager events;

  /// 이 노선의 차량번호(막차 판별 등) 부가 정보
  String busNumPlate;
  bool isLastBus;

  /// getBusRouteNo 응답: 기점/종점 정류소명
  String originStopName;
  String destStopName;

  BusRoute({
    required this.routeId,
    required this.routeNo,
    this.busNumber = 0,
    this.busArriveTime = 0,
    this.selectedBus = 0,
    this.isSelected = false,
    this.busNumPlate = '',
    this.isLastBus = false,
    this.originStopName = '',
    this.destStopName = '',
    EventManager? events,
  }) : events = events ?? EventManager();

  /// + selectBusNumber() : int
  /// 이 노선을 알람 대상으로 선택. 선택 상태를 토글하고 결과 반환.
  int selectBusNumber() {
    isSelected = !isSelected;
    selectedBus = isSelected ? 1 : 0;
    return selectedBus;
  }

  /// + refresh() : int
  /// 실시간 도착정보 갱신 후 Observer들에게 통지 (REQ-14).
  /// 새 도착시간(초)을 적용하고 notify를 트리거한다.
  int refresh({int? newArriveTime, int? newBusNumber}) {
    if (newArriveTime != null) busArriveTime = newArriveTime;
    if (newBusNumber != null) busNumber = newBusNumber;
    // 상태 변화 → 구독자 통지 (수업 예시의 modifyState → notify)
    events.notify(busNumber, busArriveTime);
    return busArriveTime;
  }

  /// 노선번호 문자열에서 숫자만 추출 (TTS 음성용)
  static int parseNumber(String routeNo) {
    final digits = RegExp(r'\d+').firstMatch(routeNo)?.group(0);
    return int.tryParse(digits ?? '0') ?? 0;
  }

  Map<String, dynamic> toJson() => {
        'routeId': routeId,
        'routeNo': routeNo,
        'isSelected': isSelected,
      };

  factory BusRoute.fromJson(Map<String, dynamic> j) => BusRoute(
        routeId: j['routeId'] as String,
        routeNo: j['routeNo'] as String,
        busNumber: BusRoute.parseNumber(j['routeNo'] as String),
        isSelected: j['isSelected'] as bool? ?? false,
      );

  @override
  bool operator ==(Object other) =>
      other is BusRoute && other.routeId == routeId;

  @override
  int get hashCode => routeId.hashCode;
}

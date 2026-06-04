/// 클래스 다이어그램의 <<interface>> Observer
///
/// + update(busNumber: int, busArriveTime: int) : void
///
/// 수업 예시(Editor/EventManager)의 EventListeners.update(filename)에 해당.
/// 모든 Observer 구현체는 동일한 시그니처를 갖는다 (LSP/ISP 준수).
abstract class Observer {
  /// busNumber : 알림 기준 버스의 노선 번호
  /// busArriveTime : 도착까지 남은 시간(초)
  void update(int busNumber, int busArriveTime);
}

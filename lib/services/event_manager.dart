import '../observers/observer.dart';

/// 클래스 다이어그램의 EventManager
///
/// - listeners : List<Observer>
/// + subscribe(eventType, listener) / unsubscribe(eventType, listener)
/// + notify(busNumber, busArriveTime)
///
/// 수업 예시의 EventManager 역할. BusRoute(Subject)가 직접 listener를
/// 관리하지 않고 이 클래스에 위임한다 (단일 책임 / 낮은 결합도).
class EventManager {
  final List<Observer> _listeners = [];

  List<Observer> get listeners => List.unmodifiable(_listeners);

  /// + subscribe(eventType: string, listener: Observer) : void
  void subscribe(String eventType, Observer listener) {
    if (!_listeners.contains(listener)) {
      _listeners.add(listener);
    }
  }

  /// + unsubscribe(eventType: string, listener: Observer) : void
  void unsubscribe(String eventType, Observer listener) {
    _listeners.remove(listener);
  }

  /// + notify(busNumber: int, busArriveTime: int) : void
  /// 등록된 모든 Observer의 update()를 호출한다.
  void notify(int busNumber, int busArriveTime) {
    // 복사본 순회 (콜백 내에서 구독 해제되어도 안전)
    for (final l in List<Observer>.from(_listeners)) {
      l.update(busNumber, busArriveTime);
    }
  }
}

abstract class Observer {
  void update(String busNumber, int busArriveTime);
}

class EventManager {
  final List<Observer> _listeners = [];

  void subscribe(Observer listener) {
    if (!_listeners.contains(listener)) _listeners.add(listener);
  }

  void unsubscribe(Observer listener) {
    _listeners.remove(listener);
  }

  void notify(String busNumber, int busArriveTime) {
    for (final l in List<Observer>.from(_listeners)) {
      l.update(busNumber, busArriveTime);
    }
  }
}

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'event_manager.dart';

class LockNotification implements Observer {
  static final LockNotification _i = LockNotification._();
  factory LockNotification() => _i;
  LockNotification._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _inited = false;

  Future<void> init() async {
    if (_inited) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
    _inited = true;
  }

  Future<void> showNotification(String busNumber, int busArriveTime) async {
    final body = _arrivalBody(busArriveTime);
    await _show('$busNumber번 버스', body);
  }

  Future<void> showMessage(String message) async {
    await _show('LateKiller', message);
  }

  /// REQ-11/21/22: 출발 알림 — 노선번호 + 예정 도착 시각(HH:MM)
  Future<void> showDeparture(String busNumber, int busArriveTime) async {
    final hhmm = DateFormat('HH:mm')
        .format(DateTime.now().add(Duration(seconds: busArriveTime)));
    await _show('지금 출발 — $busNumber번 버스', '도착 예정 $hhmm');
  }

  String _arrivalBody(int busArriveTime) {
    final hhmm = DateFormat('HH:mm')
        .format(DateTime.now().add(Duration(seconds: busArriveTime)));
    final m = busArriveTime ~/ 60;
    final remain = m > 0 ? '약 $m분 후' : '곧';
    return '$remain 도착 ($hhmm)';
  }

  Future<void> _show(String title, String body) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'latekiller_alarm',
        '버스 도착 알림',
        importance: Importance.high,
        priority: Priority.high,
        fullScreenIntent: true,
      ),
      iOS: DarwinNotificationDetails(),
    );
    await _plugin.show(0, title, body, details);
  }

  @override
  void update(String busNumber, int busArriveTime) {
    showNotification(busNumber, busArriveTime);
  }
}

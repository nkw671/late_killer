import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'observer.dart';

/// 클래스 다이어그램의 LockNotification (Observer 구현)
///
/// + showNotification(busNumber, busArriveTime) : void   (REQ-18, REQ-19 잠금화면)
/// + showMessage(message) : void                          (REQ-13 화면 메시지)
/// + update(busNumber, busArriveTime) : void
///
/// Android/iOS 잠금화면에 노선번호 + 도착 예정 시각을 표시.
class LockNotification implements Observer {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const int _arrivalId = 1001;
  static const int _messageId = 1002;

  Future<void> init() async {
    const androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );

    // Android 13+ 알림 권한
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  NotificationDetails get _details {
    const android = AndroidNotificationDetails(
      'bus_alarm_channel',
      '버스 출발 알림',
      channelDescription: '버스 도착 및 출발 시점을 잠금화면에 표시합니다.',
      importance: Importance.max,
      priority: Priority.high,
      visibility: NotificationVisibility.public, // 잠금화면 공개 표시
      ongoing: true,
      category: AndroidNotificationCategory.alarm,
    );
    const ios = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );
    return const NotificationDetails(android: android, iOS: ios);
  }

  /// + showNotification(busNumber: int, busArriveTime: int) : void
  Future<void> showNotification(int busNumber, int busArriveTimeSec) async {
    final minutes = (busArriveTimeSec / 60).round();
    await _plugin.show(
      _arrivalId,
      '$busNumber번 곧 도착',
      '약 $minutes분 후 도착 예정 · 지금 출발하세요',
      _details,
    );
  }

  /// + showMessage(message: string) : void  (REQ-13)
  Future<void> showMessage(String message) async {
    await _plugin.show(_messageId, '버스 알림', message, _details);
  }

  /// + update(busNumber, busArriveTime) : void
  @override
  void update(int busNumber, int busArriveTime) {
    showNotification(busNumber, busArriveTime);
  }

  Future<void> cancelAll() => _plugin.cancelAll();
}

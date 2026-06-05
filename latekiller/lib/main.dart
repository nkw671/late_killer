import 'package:flutter/material.dart';
import 'config.dart';
import 'screens/home_screen.dart';
import 'services/alarm_scheduler.dart';
import 'services/floating_overlay.dart';
import 'services/notification.dart';
import 'services/stop_csv.dart';
import 'theme.dart';

// flutter_overlay_window가 호출하는 별도 entrypoint
@pragma('vm:entry-point')
void overlayMain() => floatingOverlayMain();

final navigatorKey = GlobalKey<NavigatorState>();
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kBusServiceKey.isEmpty) {
    // ignore: avoid_print
    print('[WARN] BUS_SERVICE_KEY 미설정 — '
        'flutter run --dart-define=BUS_SERVICE_KEY=xxx 로 주입 필요');
  }
  await StopCsv().load();
  await LockNotification().init();
  AlarmScheduler().start(navigatorKey);
  runApp(const LateKillerApp());
}

class LateKillerApp extends StatelessWidget {
  const LateKillerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LateKiller',
      theme: kAppTheme,
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: scaffoldMessengerKey,
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

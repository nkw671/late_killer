import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'theme/app_theme.dart';
import 'services/app_state.dart';
import 'screens/home_screen.dart';
import 'observers/floating_widget.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BusAlarmApp());
}

class BusAlarmApp extends StatelessWidget {
  const BusAlarmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState()..init(),
      child: MaterialApp(
        title: '버스 알람',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: const HomeScreen(),
      ),
    );
  }
}

/// 플로팅 오버레이 전용 엔트리포인트 (REQ-20/21).
/// flutter_overlay_window가 별도 isolate에서 이 함수를 실행한다.
@pragma("vm:entry-point")
void overlayMain() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: FloatingOverlayView(),
  ));
}

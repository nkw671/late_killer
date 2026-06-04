import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'observer.dart';

/// 클래스 다이어그램의 Widget (Observer 구현, 플로팅 UI)
///
/// + show() : void
/// + update(busNumber, busArriveTime) : void   (REQ-20, REQ-21)
/// + hide() : void
/// + close() : void
///
/// 다른 앱 위에 떠 있는 시스템 오버레이로 노선번호 + 남은시간(MM:SS)을
/// 실시간 표시 (Android system_alert_window 권한 필요).
class FloatingWidget implements Observer {
  bool _active = false;

  /// 오버레이 권한 확인/요청
  Future<bool> ensurePermission() async {
    final granted = await FlutterOverlayWindow.isPermissionGranted();
    if (granted) return true;
    return await FlutterOverlayWindow.requestPermission() ?? false;
  }

  /// + show() : void
  Future<void> show() async {
    if (!await ensurePermission()) return;
    if (await FlutterOverlayWindow.isActive()) return;
    await FlutterOverlayWindow.showOverlay(
      enableDrag: true,
      overlayTitle: '버스 알림',
      overlayContent: '대기 중…',
      flag: OverlayFlag.defaultFlag,
      visibility: NotificationVisibility.visibilityPublic,
      positionGravity: PositionGravity.auto,
      height: 220,
      width: 420,
    );
    _active = true;
  }

  /// + update(busNumber: int, busArriveTime: int) : void
  /// REQ-21: 남은 시간을 MM:SS로 실시간 갱신하여 오버레이로 전달.
  @override
  void update(int busNumber, int busArriveTime) {
    if (!_active) return;
    FlutterOverlayWindow.shareData({
      'busNumber': busNumber,
      'seconds': busArriveTime,
    });
  }

  /// + hide() : void
  Future<void> hide() async {
    // 오버레이는 닫되 상태는 유지
    await FlutterOverlayWindow.closeOverlay();
  }

  /// + close() : void
  Future<void> close() async {
    await FlutterOverlayWindow.closeOverlay();
    _active = false;
  }
}

/// 오버레이 위에 렌더링되는 실제 위젯 (별도 엔트리포인트에서 사용).
/// REQ-20: 노선번호 + 실시간 도착예정, REQ-21: MM:SS 카운트다운.
class FloatingOverlayView extends StatefulWidget {
  const FloatingOverlayView({super.key});

  @override
  State<FloatingOverlayView> createState() => _FloatingOverlayViewState();
}

class _FloatingOverlayViewState extends State<FloatingOverlayView> {
  int _busNumber = 0;
  int _seconds = 0;
  Timer? _ticker;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    // 메인 isolate에서 shareData로 보낸 값 수신
    _sub = FlutterOverlayWindow.overlayListener.listen((event) {
      if (event is Map) {
        setState(() {
          _busNumber = event['busNumber'] ?? _busNumber;
          _seconds = event['seconds'] ?? _seconds;
        });
      }
    });
    // 1초마다 로컬 카운트다운 (부드러운 MM:SS 갱신)
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_seconds > 0) setState(() => _seconds--);
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _sub?.cancel();
    super.dispose();
  }

  String get _mmss {
    final m = (_seconds ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF171C24), Color(0xFF0E1116)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFF2A323D)),
          boxShadow: const [
            BoxShadow(color: Colors.black54, blurRadius: 18, spreadRadius: 2),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4ADE80), Color(0xFF22D3EE)],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.directions_bus_rounded,
                  color: Color(0xFF06210F)),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$_busNumber번',
                    style: const TextStyle(
                        color: Color(0xFFF2F5F8),
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
                const Text('도착까지',
                    style:
                        TextStyle(color: Color(0xFF9AA6B2), fontSize: 11)),
              ],
            ),
            const Spacer(),
            Text(_mmss,
                style: const TextStyle(
                    color: Color(0xFF4ADE80),
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    fontFeatures: [FontFeature.tabularFigures()])),
          ],
        ),
      ),
    );
  }
}

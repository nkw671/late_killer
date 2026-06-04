import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

/// REQ-23/24: 알람 중일 때 다른 앱 위에 노선번호 + 남은시간(MM:SS) 표시.
class FloatingOverlay {
  static final FloatingOverlay _i = FloatingOverlay._();
  factory FloatingOverlay() => _i;
  FloatingOverlay._();

  bool _active = false;

  Future<void> show() async {
    if (_active) return;
    final granted = await FlutterOverlayWindow.isPermissionGranted();
    if (!granted) {
      final ok = await FlutterOverlayWindow.requestPermission();
      if (ok != true) return;
    }
    await FlutterOverlayWindow.showOverlay(
      enableDrag: true,
      overlayTitle: 'LateKiller',
      overlayContent: '',
      flag: OverlayFlag.defaultFlag,
      visibility: NotificationVisibility.visibilityPublic,
      positionGravity: PositionGravity.auto,
      height: 180,
      width: 360,
    );
    _active = true;
  }

  Future<void> update(String busNumber, int remainingSec) async {
    if (!_active) return;
    await FlutterOverlayWindow.shareData({
      'bus': busNumber,
      'sec': remainingSec,
    });
  }

  Future<void> hide() async {
    if (!_active) return;
    await FlutterOverlayWindow.closeOverlay();
    _active = false;
  }
}

/// main.dart의 @pragma('vm:entry-point') overlayMain에서 호출
void floatingOverlayMain() {
  runApp(const _OverlayApp());
}

class _OverlayApp extends StatefulWidget {
  const _OverlayApp();
  @override
  State<_OverlayApp> createState() => _OverlayAppState();
}

class _OverlayAppState extends State<_OverlayApp> {
  String _bus = '-';
  int _sec = 0;

  @override
  void initState() {
    super.initState();
    FlutterOverlayWindow.overlayListener.listen((event) {
      if (event is Map) {
        setState(() {
          _bus = (event['bus'] ?? '-').toString();
          _sec = (event['sec'] is int) ? event['sec'] as int : 0;
        });
      }
    });
  }

  String _mmss(int s) {
    if (s < 0) s = 0;
    final m = s ~/ 60;
    final r = s % 60;
    return '${m.toString().padLeft(2, '0')}:${r.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF4A90E2),
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2)),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('LateKiller',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                  Text(_bus,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w700)),
                ],
              ),
              Text(_mmss(_sec),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                      fontFeatures: [FontFeature.tabularFigures()])),
            ],
          ),
        ),
      ),
    );
  }
}

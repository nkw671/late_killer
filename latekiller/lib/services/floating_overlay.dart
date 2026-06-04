import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

/// REQ-23/24: 알람 중일 때 다른 앱 위에 노선번호 + 남은시간(MM:SS) 표시.
class FloatingOverlay {
  static final FloatingOverlay _i = FloatingOverlay._();
  factory FloatingOverlay() => _i;
  FloatingOverlay._();

  bool _active = false;
  bool _permissionAsked = false;

  /// 알람 시작 시 미리 호출 — 권한 다이얼로그를 포그라운드에서 띄운다.
  /// 백그라운드 전환 후엔 시스템이 다이얼로그를 띄울 수 없어 show()가 실패한다.
  Future<bool> ensurePermission() async {
    final granted = await FlutterOverlayWindow.isPermissionGranted();
    if (granted) return true;
    if (_permissionAsked) return false;
    _permissionAsked = true;
    final ok = await FlutterOverlayWindow.requestPermission();
    return ok == true;
  }

  Future<void> show() async {
    if (_active) return;
    // 권한 체크만 (요청은 ensurePermission이 처리)
    final granted = await FlutterOverlayWindow.isPermissionGranted();
    if (!granted) return;
    final isActive = await FlutterOverlayWindow.isActive();
    if (isActive == true) {
      _active = true;
      return;
    }
    await FlutterOverlayWindow.showOverlay(
      enableDrag: true,
      overlayTitle: 'LateKiller',
      overlayContent: '',
      flag: OverlayFlag.defaultFlag,
      visibility: NotificationVisibility.visibilityPublic,
      positionGravity: PositionGravity.auto,
      height: 260,
      width: WindowSize.matchParent,
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
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF4A90E2),
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                      color: Colors.black26,
                      blurRadius: 8,
                      offset: Offset(0, 2)),
                ],
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('LateKiller',
                            style: TextStyle(
                                color: Colors.white70, fontSize: 13)),
                        const SizedBox(height: 2),
                        Text(_bus,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(width: 20),
                    Text(_mmss(_sec),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 40,
                            fontWeight: FontWeight.w700,
                            fontFeatures: [FontFeature.tabularFigures()])),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

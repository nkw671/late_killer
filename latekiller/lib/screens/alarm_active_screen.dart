import 'package:flutter/material.dart';
import '../core/departure_alarm.dart';
import '../models/alarm_config.dart';
import '../models/bus_route.dart';
import '../services/event_manager.dart';
import '../services/floating_overlay.dart';
import '../services/notification.dart';
import '../services/tts.dart';

class AlarmActiveScreen extends StatefulWidget {
  final AlarmConfig config;
  final List<BusRoute> allRoutes;
  const AlarmActiveScreen(
      {super.key, required this.config, required this.allRoutes});

  @override
  State<AlarmActiveScreen> createState() => _AlarmActiveScreenState();
}

class _AlarmActiveScreenState extends State<AlarmActiveScreen>
    implements Observer {
  late DepartureAlarm _alarm;
  late List<BusRoute> _candidates;
  late PlayTTS _tts;

  @override
  void initState() {
    super.initState();
    _tts = PlayTTS();
    _candidates = widget.allRoutes
        .where((r) => widget.config.busNumbers.contains(r.busNumber))
        .toList();
    _alarm = DepartureAlarm(
      walkTimeToStop: widget.config.walkTimeToStop,
      stopId: widget.config.stopId,
      candidates: _candidates,
      tts: _tts,
      notif: LockNotification(),
      schedules: widget.config.schedules,
    );
    for (final r in _candidates) {
      r.events.subscribe(this);
    }
    _alarm.selectEarliestBus();
    _alarm.callAPI();
    FloatingOverlay().show();
  }

  @override
  void dispose() {
    for (final r in _candidates) {
      r.events.unsubscribe(this);
    }
    _alarm.stopAlarm();
    FloatingOverlay().hide();
    super.dispose();
  }

  @override
  void update(String busNumber, int busArriveTime) {
    if (mounted) setState(() {});
    final sel = _alarm.selectedBus;
    if (sel != null) {
      FloatingOverlay().update(sel.busNumber, sel.busArriveTime);
    }
  }

  String _fmt(int s) {
    if (s <= 0) return '곧 도착';
    final m = s ~/ 60;
    final r = s % 60;
    return m > 0 ? '$m분 ${r}초' : '${r}초';
  }

  @override
  Widget build(BuildContext context) {
    final sel = _alarm.selectedBus;
    final others = _candidates.where((r) => r != sel).toList()
      ..sort((a, b) => a.busArriveTime.compareTo(b.busArriveTime));
    return Scaffold(
      appBar: AppBar(title: Text(widget.config.stopName)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              flex: 2,
              child: Card(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('현재 추적 버스',
                          style: TextStyle(color: Color(0xFF6B7280))),
                      const SizedBox(height: 8),
                      Text(sel?.busNumber ?? '-',
                          style: const TextStyle(
                              fontSize: 36, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 16),
                      Text(
                        sel == null ? '-' : _fmt(sel.busArriveTime),
                        style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF4A90E2)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: Card(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(20, 12, 20, 4),
                      child: Text('다음 버스',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF6B7280))),
                    ),
                    if (others.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('없음',
                            style: TextStyle(color: Color(0xFF9CA3AF))),
                      )
                    else
                      ...others.map((r) => ListTile(
                            title: Text(r.busNumber),
                            trailing: Text(_fmt(r.busArriveTime)),
                          )),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: () {
                _alarm.stopAlarm();
                Navigator.popUntil(context, (r) => r.isFirst);
              },
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('중지'),
            ),
          ],
        ),
      ),
    );
  }
}

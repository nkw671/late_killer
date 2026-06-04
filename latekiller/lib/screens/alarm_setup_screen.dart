import 'package:flutter/material.dart';
import '../models/alarm_config.dart';
import '../models/alarm_schedule.dart';
import '../models/bus_route.dart';
import '../models/bus_stop.dart';
import '../services/storage.dart';
import '../main.dart' show scaffoldMessengerKey;

class AlarmSetupScreen extends StatefulWidget {
  final BusStop stop;
  final List<BusRoute> allRoutes;
  final BusRoute? initiallySelected;
  // 편집 모드: 기존 알람을 prefill하고 저장 시 해당 index를 교체한다.
  final AlarmConfig? existing;
  final int? existingIndex;

  const AlarmSetupScreen({
    super.key,
    required this.stop,
    required this.allRoutes,
    this.initiallySelected,
    this.existing,
    this.existingIndex,
  });

  bool get isEditing => existing != null && existingIndex != null;

  @override
  State<AlarmSetupScreen> createState() => _AlarmSetupScreenState();
}

class _AlarmSetupScreenState extends State<AlarmSetupScreen> {
  static const _dayLabel = ['월', '화', '수', '목', '금', '토', '일'];
  late Map<int, AlarmSchedule> _schedules;
  late Set<String> _picked; // busNumbers
  int _walkMin = 5;

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    if (ex != null) {
      // 편집 모드: 기존 값으로 prefill
      _schedules = {
        for (var d = 1; d <= 7; d++)
          d: ex.schedules[d] ??
              AlarmSchedule(
                  day: d, isEnabled: false, alarmTime: TimeOfDay.now()),
      };
      _picked = ex.busNumbers.toSet();
      _walkMin = (ex.walkTimeToStop / 60).round().clamp(1, 60);
    } else {
      final now = TimeOfDay.now();
      _schedules = {
        for (var d = 1; d <= 7; d++)
          d: AlarmSchedule(day: d, isEnabled: false, alarmTime: now),
      };
      final initial = widget.initiallySelected;
      _picked = initial != null ? {initial.busNumber} : <String>{};
    }
  }

  Future<void> _pickTime(int day) async {
    final t = await showTimePicker(
        context: context, initialTime: _schedules[day]!.alarmTime);
    if (t != null) setState(() => _schedules[day]!.alarmTime = t);
  }

  Future<void> _save() async {
    final config = AlarmConfig(
      stopId: widget.stop.stopId,
      stopName: widget.stop.stopName,
      stopNumber: widget.stop.stopNumber,
      busNumbers: _picked.toList(),
      walkTimeToStop: _walkMin * 60,
      schedules: _schedules,
    );
    final st = Storage();
    final list = await st.loadAlarms();
    if (widget.isEditing) {
      final i = widget.existingIndex!;
      if (i >= 0 && i < list.length) {
        list[i] = config;
      } else {
        list.add(config);
      }
    } else {
      list.add(config);
    }
    await st.saveAlarms(list);
    if (!mounted) return;
    // 홈까지 한 번에 복귀 + 루트 ScaffoldMessenger로 SnackBar 표시
    Navigator.popUntil(context, (r) => r.isFirst);
    scaffoldMessengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(
        content: Text('알람이 저장되었습니다'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.isEditing ? '알람 편집' : '알람 설정')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _section('알람 요일 / 시간'),
          Card(
            child: Column(
              children: [
                for (var d = 1; d <= 7; d++)
                  ListTile(
                    title: Text('${_dayLabel[d - 1]}요일'),
                    subtitle: Text(_schedules[d]!.alarmTime.format(context)),
                    onTap: () => _pickTime(d),
                    trailing: Switch(
                      value: _schedules[d]!.isEnabled,
                      onChanged: (v) =>
                          setState(() => _schedules[d]!.isEnabled = v),
                    ),
                  ),
              ],
            ),
          ),
          _section('정류장까지 도보 시간'),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.directions_walk),
                  Expanded(
                    child: Slider(
                      value: _walkMin.toDouble(),
                      min: 1,
                      max: 60,
                      divisions: 59,
                      label: '$_walkMin분',
                      onChanged: (v) => setState(() => _walkMin = v.round()),
                    ),
                  ),
                  Text('$_walkMin분'),
                ],
              ),
            ),
          ),
          _section('선택 버스 (여러개 가능)'),
          Card(
            child: Column(
              children: widget.allRoutes
                  .map((r) => CheckboxListTile(
                        title: Text(r.busNumber),
                        value: _picked.contains(r.busNumber),
                        onChanged: (v) {
                          setState(() {
                            if (v == true) {
                              _picked.add(r.busNumber);
                            } else {
                              _picked.remove(r.busNumber);
                            }
                          });
                        },
                      ))
                  .toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              onPressed: _picked.isEmpty ? null : _save,
              child: Text(widget.isEditing ? '변경사항 저장' : '알람 저장'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: Text(t,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280))),
      );
}

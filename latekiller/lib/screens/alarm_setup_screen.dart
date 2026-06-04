import 'package:flutter/material.dart';
import '../models/alarm_config.dart';
import '../models/alarm_schedule.dart';
import '../models/bus_route.dart';
import '../models/bus_stop.dart';
import '../services/storage.dart';
import 'alarm_active_screen.dart';

class AlarmSetupScreen extends StatefulWidget {
  final BusStop stop;
  final List<BusRoute> allRoutes;
  final BusRoute initiallySelected;

  const AlarmSetupScreen({
    super.key,
    required this.stop,
    required this.allRoutes,
    required this.initiallySelected,
  });

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
    final now = TimeOfDay.now();
    _schedules = {
      for (var d = 1; d <= 7; d++)
        d: AlarmSchedule(day: d, isEnabled: false, alarmTime: now),
    };
    _picked = {widget.initiallySelected.busNumber};
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
    list.add(config);
    await st.saveAlarms(list);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => AlarmActiveScreen(
          config: config,
          allRoutes: widget.allRoutes,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('알람 설정')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _section('알람 요일 / 시간'),
          Card(
            child: Column(
              children: [
                for (var d = 1; d <= 7; d++)
                  SwitchListTile(
                    title: Text('${_dayLabel[d - 1]}요일'),
                    subtitle: Text(_schedules[d]!.alarmTime.format(context)),
                    value: _schedules[d]!.isEnabled,
                    onChanged: (v) =>
                        setState(() => _schedules[d]!.isEnabled = v),
                    secondary: TextButton(
                      onPressed: () => _pickTime(d),
                      child: const Text('시간'),
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
              child: const Text('저장 후 알람 시작'),
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

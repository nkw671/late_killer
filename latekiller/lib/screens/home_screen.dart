import 'package:flutter/material.dart';
import '../models/alarm_config.dart';
import '../models/bus_stop.dart';
import '../services/storage.dart';
import '../services/bus_api.dart';
import '../services/stop_csv.dart';
import 'search_result_screen.dart';
import 'stop_detail_screen.dart';
import 'alarm_setup_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _controller = TextEditingController();
  final _storage = Storage();
  List<BusStop> _favs = [];
  List<AlarmConfig> _alarms = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final favs = await _storage.loadFavorites();
    final alarms = await _storage.loadAlarms();
    if (!mounted) return;
    setState(() {
      _favs = favs;
      _alarms = alarms;
      _loading = false;
    });
  }

  Future<void> _search() async {
    final q = _controller.text.trim();
    if (q.isEmpty) return;
    final num = int.tryParse(q);
    if (num != null) {
      // 번호 검색: CSV → ID
      final row = StopCsv().findByNumber(num);
      if (row == null) {
        _toast('해당 번호의 정류장 없음');
        return;
      }
      final stop = BusStop(
        stopName: row.stopName,
        stopNumber: row.stopNumber,
        stopId: row.stopId,
      );
      _open(stop);
    } else {
      // 이름 검색: API
      try {
        final list = await BusApi().getBusStationNmList(q);
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SearchResultScreen(query: q, stops: list),
          ),
        );
      } catch (e) {
        _toast('검색 실패: $e');
      }
    }
  }

  void _open(BusStop stop) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => StopDetailScreen(stop: stop)),
    ).then((_) => _load());
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LateKiller',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: TextField(
                    controller: _controller,
                    onSubmitted: (_) => _search(),
                    decoration: InputDecoration(
                      hintText: '정류장 번호 또는 이름',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.arrow_forward_rounded),
                        onPressed: _search,
                      ),
                    ),
                  ),
                ),
                _section('설정한 알람'),
                if (_alarms.isEmpty)
                  _emptyHint('아직 알람이 없어요')
                else
                  ..._alarms.map(_alarmCard),
                const SizedBox(height: 16),
                _section('즐겨찾기'),
                if (_favs.isEmpty)
                  _emptyHint('정류장을 즐겨찾기에 추가해 보세요')
                else
                  ..._favs.map(_favCard),
              ],
            ),
    );
  }

  Widget _section(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
        child: Text(t,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280))),
      );

  Widget _emptyHint(String t) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(t,
              style: const TextStyle(color: Color(0xFF9CA3AF))),
        ),
      );

  static const _dayLabels = ['월', '화', '수', '목', '금', '토', '일'];

  /// 활성 요일/시간을 같은 시간끼리 묶어서 "월·수·금 08:00 · 화 09:30" 형태로.
  String _scheduleSummary(AlarmConfig a) {
    final byTime = <String, List<String>>{};
    for (var d = 1; d <= 7; d++) {
      final s = a.schedules[d];
      if (s == null || !s.isEnabled) continue;
      final hhmm =
          '${s.alarmTime.hour.toString().padLeft(2, '0')}:${s.alarmTime.minute.toString().padLeft(2, '0')}';
      byTime.putIfAbsent(hhmm, () => []).add(_dayLabels[d - 1]);
    }
    if (byTime.isEmpty) return '비활성';
    final entries = byTime.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return entries.map((e) => '${e.value.join('·')} ${e.key}').join(' · ');
  }

  Widget _alarmCard(AlarmConfig a) => Card(
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          title: Text(a.stopName,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(_scheduleSummary(a),
                  style: const TextStyle(
                      color: Color(0xFF4A90E2),
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
              const SizedBox(height: 2),
              Text(a.busNumbers.join(', '),
                  style: const TextStyle(
                      color: Color(0xFF6B7280), fontSize: 12)),
            ],
          ),
          isThreeLine: true,
          onTap: () => _editAlarm(a),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              _alarms.remove(a);
              await _storage.saveAlarms(_alarms);
              setState(() {});
            },
          ),
        ),
      );

  Future<void> _editAlarm(AlarmConfig a) async {
    final idx = _alarms.indexOf(a);
    if (idx < 0) return;
    final stop = BusStop(
      stopId: a.stopId,
      stopName: a.stopName,
      stopNumber: a.stopNumber,
    );
    try {
      final routes = await BusApi().getAllRouteBusArrivalList(a.stopId);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AlarmSetupScreen(
            stop: stop,
            allRoutes: routes,
            existing: a,
            existingIndex: idx,
          ),
        ),
      );
      _load();
    } catch (e) {
      _toast('노선 정보 조회 실패: $e');
    }
  }

  Widget _favCard(BusStop s) => Card(
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          leading: const Icon(Icons.star, color: Color(0xFFFBBF24)),
          title: Text(s.stopName,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text('정류소 ${s.stopNumber}'),
          onTap: () => _open(s),
          trailing: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () async {
              _favs.removeWhere((x) => x.stopId == s.stopId);
              await _storage.saveFavorites(_favs);
              setState(() {});
            },
          ),
        ),
      );
}

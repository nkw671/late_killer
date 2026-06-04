import 'package:flutter/material.dart';
import '../models/bus_route.dart';
import '../models/bus_stop.dart';
import '../services/bus_api.dart';
import '../services/storage.dart';
import 'alarm_setup_screen.dart';

class StopDetailScreen extends StatefulWidget {
  final BusStop stop;
  const StopDetailScreen({super.key, required this.stop});

  @override
  State<StopDetailScreen> createState() => _StopDetailScreenState();
}

class _StopDetailScreenState extends State<StopDetailScreen> {
  List<BusRoute> _routes = [];
  bool _loading = true;
  bool _isFav = false;
  final _storage = Storage();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final routes =
          await BusApi().getAllRouteBusArrivalList(widget.stop.stopId);
      final favs = await _storage.loadFavorites();
      if (!mounted) return;
      setState(() {
        _routes = routes;
        _isFav = favs.any((f) => f.stopId == widget.stop.stopId);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('도착정보 조회 실패: $e')));
    }
  }

  Future<void> _toggleFav() async {
    final favs = await _storage.loadFavorites();
    if (_isFav) {
      favs.removeWhere((f) => f.stopId == widget.stop.stopId);
    } else {
      favs.add(widget.stop);
    }
    await _storage.saveFavorites(favs);
    setState(() => _isFav = !_isFav);
  }

  String _fmt(int s) {
    if (s <= 0) return '곧 도착';
    final m = s ~/ 60;
    final r = s % 60;
    return m > 0 ? '${m}분 ${r}초' : '${r}초';
  }

  void _selectRoute(BusRoute r) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AlarmSetupScreen(
          stop: widget.stop,
          allRoutes: _routes,
          initiallySelected: r,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.stop.stopName),
        actions: [
          IconButton(
            icon: Icon(_isFav ? Icons.star : Icons.star_border,
                color: const Color(0xFFFBBF24)),
            onPressed: _toggleFav,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _routes.isEmpty
              ? const Center(child: Text('경유 노선이 없어요'))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _routes.length,
                  itemBuilder: (_, i) {
                    final r = _routes[i];
                    return Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFFE0EAFC),
                          child: Text(r.busNumber,
                              style: const TextStyle(
                                  color: Color(0xFF4A90E2),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12)),
                        ),
                        title: Text(r.busNumber,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600)),
                        subtitle: Text(_fmt(r.busArriveTime)),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _selectRoute(r),
                      ),
                    );
                  },
                ),
    );
  }
}

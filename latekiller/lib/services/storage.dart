import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/bus_stop.dart';
import '../models/alarm_config.dart';

class Storage {
  static const _kFav = 'favorites';
  static const _kAlarms = 'alarms';

  Future<List<BusStop>> loadFavorites() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getStringList(_kFav) ?? [];
    return raw
        .map((s) => BusStop.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveFavorites(List<BusStop> stops) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setStringList(
        _kFav, stops.map((s) => jsonEncode(s.toJson())).toList());
  }

  Future<List<AlarmConfig>> loadAlarms() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getStringList(_kAlarms) ?? [];
    return raw
        .map((s) => AlarmConfig.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveAlarms(List<AlarmConfig> alarms) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setStringList(
        _kAlarms, alarms.map((a) => jsonEncode(a.toJson())).toList());
  }
}

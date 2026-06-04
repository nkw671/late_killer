import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import '../models/bus_stop.dart';
import '../models/bus_route.dart';

/// 인천광역시 버스정보 OpenAPI 연동 서비스.
/// 오류 시 예외를 throw → 호출부에서 처리.
class BusApiService {
  static const String serviceKey =
      '7493996691b612e82a3281632b6531ebd83f3f6286cc9f47c8b0c460e593646c';

  static const String _stationBase =
      'http://apis.data.go.kr/6280000/busStationService';
  static const String _routeBase =
      'http://apis.data.go.kr/6280000/busRouteService';
  static const String _arrivalBase =
      'http://apis.data.go.kr/6280000/busArrivalService';

  /// routeId → BusRoute 기본정보 캐시 (enrichRoutes 호출 시 채워짐)
  final Map<String, BusRoute> _routeInfoCache = {};

  // ──────────────────────────────────────────────
  // 1) 정류소 이름으로 검색 (getBusStationNmList)  REQ-01
  // ──────────────────────────────────────────────
  Future<List<BusStop>> searchStopsByName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return [];
    final uri = Uri.parse('$_stationBase/getBusStationNmList'
        '?serviceKey=$serviceKey&bstopNm=${Uri.encodeComponent(trimmed)}&numOfRows=30&pageNo=1');
    final body = await _get(uri);
    return _parseStopList(body);
  }

  // ──────────────────────────────────────────────
  // 2) 노선번호로 노선 검색 (getBusRouteNo)  REQ-05
  // ──────────────────────────────────────────────
  Future<List<BusRoute>> searchRoutesByNumber(String routeNo) async {
    if (routeNo.trim().isEmpty) return [];
    final uri = Uri.parse('$_routeBase/getBusRouteNo'
        '?serviceKey=$serviceKey&routeNo=${routeNo.trim()}&numOfRows=30&pageNo=1');
    final body = await _get(uri);
    return _parseRouteList(body);
  }

  // ──────────────────────────────────────────────
  // 3) 노선 경유 정류소 목록 (getBusRouteSectionList)
  // ──────────────────────────────────────────────
  Future<List<BusStop>> getRouteSections(String routeId) async {
    final uri = Uri.parse('$_routeBase/getBusRouteSectionList'
        '?serviceKey=$serviceKey&routeId=$routeId&numOfRows=100&pageNo=1');
    final body = await _get(uri);
    return _parseSectionStopList(body);
  }

  // ──────────────────────────────────────────────
  // 4) 정류소 실시간 도착정보 (getAllRouteBusArrivalList)
  // ──────────────────────────────────────────────
  Future<List<BusRoute>> getArrivalsAtStop(String bstopId) async {
    final uri = Uri.parse('$_arrivalBase/getAllRouteBusArrivalList'
        '?serviceKey=$serviceKey&bstopId=$bstopId&numOfRows=50&pageNo=1');
    final body = await _get(uri);
    return _parseArrivalList(body);
  }

  // ──────────────────────────────────────────────
  // 5) routeId로 노선 기본정보 조회 (getBusRouteId) — 캐시 우선
  // ──────────────────────────────────────────────
  Future<BusRoute?> getRouteById(String routeId) async {
    if (_routeInfoCache.containsKey(routeId)) return _routeInfoCache[routeId];
    final uri = Uri.parse('$_routeBase/getBusRouteId'
        '?serviceKey=$serviceKey&routeId=$routeId&numOfRows=1&pageNo=1');
    final body = await _get(uri);
    final doc = XmlDocument.parse(body);
    final items = doc.findAllElements('itemList');
    if (items.isEmpty) return null;
    final e = items.first;
    final routeNo = _text(e, 'ROUTENO');
    final route = BusRoute(
      routeId: routeId,
      routeNo: routeNo,
      busNumber: BusRoute.parseNumber(routeNo),
      originStopName: _text(e, 'ORIGIN_BSTOPNM'),
      destStopName: _text(e, 'DEST_BSTOPNM'),
    );
    _routeInfoCache[routeId] = route;
    return route;
  }

  /// 도착정보 목록의 routeNo/originStopName/destStopName을 getBusRouteId로 채운다.
  Future<void> enrichRoutes(List<BusRoute> routes) async {
    for (final r in routes) {
      if (_routeInfoCache.containsKey(r.routeId)) {
        final cached = _routeInfoCache[r.routeId]!;
        r.routeNo = cached.routeNo;
        r.busNumber = cached.busNumber;
        r.originStopName = cached.originStopName;
        r.destStopName = cached.destStopName;
      } else {
        try {
          final info = await getRouteById(r.routeId);
          if (info != null) {
            r.routeNo = info.routeNo;
            r.busNumber = info.busNumber;
            r.originStopName = info.originStopName;
            r.destStopName = info.destStopName;
          }
        } catch (_) {
          // 실패해도 routeId를 routeNo 대체값으로 유지
        }
      }
    }
  }

  // ──────────────────────────────────────────────
  //  공통 HTTP GET — UTF-8 디코딩 + 상태코드 체크
  // ──────────────────────────────────────────────
  Future<String> _get(Uri uri) async {
    final res = await http.get(uri).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) {
      throw Exception('서버 오류 (HTTP ${res.statusCode})');
    }
    return utf8.decode(res.bodyBytes);
  }

  // ──────────────────────────────────────────────
  //  XML 파서
  // ──────────────────────────────────────────────

  /// getBusStationNmList 응답 파싱 (BSTOPID, BSTOPNM, SHORT_BSTOPID)
  List<BusStop> _parseStopList(String body) {
    final doc = XmlDocument.parse(body);
    final items = doc.findAllElements('itemList');
    return items.map((e) {
      return BusStop(
        stopId: _text(e, 'BSTOPID'),
        stopName: _text(e, 'BSTOPNM'),
        stopNumber: 0,
        shortStopId: _text(e, 'SHORT_BSTOPID'),
      );
    }).toList();
  }

  /// getBusRouteSectionList 응답 파싱
  List<BusStop> _parseSectionStopList(String body) {
    final doc = XmlDocument.parse(body);
    final items = doc.findAllElements('itemList');
    return items.map((e) {
      return BusStop(
        stopId: _text(e, 'BSTOPID'),
        stopName: _text(e, 'BSTOPNM'),
        stopNumber: int.tryParse(_text(e, 'BSTOPSEQ')) ?? 0,
        shortStopId: _text(e, 'SHORT_BSTOPID'),
      );
    }).toList();
  }

  List<BusRoute> _parseRouteList(String body) {
    final doc = XmlDocument.parse(body);
    final items = doc.findAllElements('itemList');
    return items.map((e) {
      final routeNo = _text(e, 'ROUTENO');
      return BusRoute(
        routeId: _text(e, 'ROUTEID'),
        routeNo: routeNo,
        busNumber: BusRoute.parseNumber(routeNo),
        originStopName: _text(e, 'ORIGIN_BSTOPNM'),
        destStopName: _text(e, 'DEST_BSTOPNM'),
      );
    }).toList();
  }

  List<BusRoute> _parseArrivalList(String body) {
    final doc = XmlDocument.parse(body);
    var items = doc.findAllElements('itemList');
    if (items.isEmpty) items = doc.findAllElements('item');
    return items.map((e) {
      final routeId = _text(e, 'ROUTEID');
      final routeNo =
          _text(e, 'ROUTENO').isNotEmpty ? _text(e, 'ROUTENO') : routeId;
      final secs = int.tryParse(_text(e, 'ARRIVALESTIMATETIME')) ?? 0;
      return BusRoute(
        routeId: routeId,
        routeNo: routeNo,
        busNumber: BusRoute.parseNumber(routeNo),
        busArriveTime: secs,
        busNumPlate: _text(e, 'BUS_NUM_PLATE'),
        isLastBus: _text(e, 'LASTBUSYN') == '1',
      );
    }).toList();
  }

  String _text(XmlElement parent, String tag) {
    final el = parent.findElements(tag);
    if (el.isEmpty) return '';
    return el.first.innerText.trim();
  }
}

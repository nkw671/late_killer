import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import '../config.dart';
import '../models/bus_stop.dart';
import '../models/bus_route.dart';

/// 인천광역시 버스정보 OpenAPI 래퍼 (공식 스펙 기준).
/// - 응답 wrapper: <itemList>, 필드명은 대문자.
/// - 요청 파라미터: bstopId, bstopNm, routeId.
class BusApi {
  static final BusApi _i = BusApi._();
  factory BusApi() => _i;
  BusApi._();

  Future<XmlDocument> _get(String url) async {
    final r = await http.get(Uri.parse(url));
    if (r.statusCode != 200) {
      throw Exception('HTTP ${r.statusCode}');
    }
    // 서버가 charset 미지정 시 http 패키지는 latin1로 디코딩 → 한글 깨짐.
    // 응답 바이트를 UTF-8로 직접 디코딩한다.
    final body = utf8.decode(r.bodyBytes, allowMalformed: true);
    final doc = XmlDocument.parse(body);
    final code = doc.findAllElements('resultCode').firstOrNull?.innerText.trim();
    if (code != null && code != '0' && code != '00') {
      final msg = doc.findAllElements('resultMsg').firstOrNull?.innerText.trim();
      throw Exception('API err $code: $msg');
    }
    return doc;
  }

  String _enc(String v) => Uri.encodeQueryComponent(v);

  /// 정류소명 검색
  Future<List<BusStop>> getBusStationNmList(String name) async {
    final url =
        '$kStationApiBase/getBusStationNmList?serviceKey=$kBusServiceKey&bstopNm=${_enc(name)}&numOfRows=100&pageNo=1';
    final doc = await _get(url);
    return doc.findAllElements('itemList').map((e) {
      return BusStop(
        stopId: _t(e, 'BSTOPID'),
        stopName: _t(e, 'BSTOPNM'),
        stopNumber: int.tryParse(_t(e, 'SHORT_BSTOPID')) ?? 0,
      );
    }).toList();
  }

  /// 정류소ID로 경유 버스노선 (routeId + routeNo)
  Future<List<BusRoute>> getBusStationViaRouteList(String stopId) async {
    final url =
        '$kStationApiBase/getBusStationViaRouteList?serviceKey=$kBusServiceKey&bstopId=${_enc(stopId)}&numOfRows=200&pageNo=1';
    final doc = await _get(url);
    return doc.findAllElements('itemList').map((e) {
      return BusRoute(
        routeId: _t(e, 'ROUTEID'),
        busNumber: _t(e, 'ROUTENO'),
      );
    }).toList();
  }

  /// 정류장의 모든 버스 도착시간 — 응답엔 ROUTENO가 없으므로
  /// getBusStationViaRouteList로 받은 노선명과 머지한다.
  Future<List<BusRoute>> getAllRouteBusArrivalList(String stopId) async {
    final routes = await getBusStationViaRouteList(stopId);
    final nameById = {for (final r in routes) r.routeId: r.busNumber};

    final url =
        '$kBusApiBase/getAllRouteBusArrivalList?serviceKey=$kBusServiceKey&bstopId=${_enc(stopId)}&numOfRows=200&pageNo=1';
    final doc = await _get(url);
    final arrivals = doc.findAllElements('itemList').map((e) {
      final rid = _t(e, 'ROUTEID');
      return BusRoute(
        routeId: rid,
        busNumber: nameById[rid] ?? rid,
        busArriveTime: int.tryParse(_t(e, 'ARRIVALESTIMATETIME')) ?? 0,
      );
    }).toList();

    // 도착정보 없는 노선도 목록에 포함 (시간 0 = 미정)
    final arrivedIds = arrivals.map((a) => a.routeId).toSet();
    for (final r in routes) {
      if (!arrivedIds.contains(r.routeId)) arrivals.add(r);
    }
    return arrivals;
  }

  /// 특정 정류장+노선 도착시간
  Future<int> getBusArrivalList(String stopId, String routeId) async {
    final url =
        '$kBusApiBase/getBusArrivalList?serviceKey=$kBusServiceKey&bstopId=${_enc(stopId)}&routeId=${_enc(routeId)}&numOfRows=10&pageNo=1';
    final doc = await _get(url);
    final item = doc.findAllElements('itemList').firstOrNull;
    if (item == null) {
      // ignore: avoid_print
      print('[API:getBusArrivalList] stopId=$stopId routeId=$routeId → itemList 없음');
      return 0;
    }
    final t1 = _t(item, 'ARRIVALESTIMATETIME');
    final t2 = _t(item, 'ARRIVALESTIMATETIME2');
    final lowPlate = _t(item, 'LOW_PLATE');
    final seat1 = _t(item, 'REMAINSEATCNT');
    final seat2 = _t(item, 'REMAINSEATCNT2');
    // ignore: avoid_print
    print('[API:getBusArrivalList] stopId=$stopId routeId=$routeId '
        'ARRIVALESTIMATETIME=$t1 ARRIVALESTIMATETIME2=$t2 '
        'REMAINSEATCNT=$seat1 REMAINSEATCNT2=$seat2 LOW_PLATE=$lowPlate');
    return int.tryParse(t1) ?? 0;
  }

  String _t(XmlElement e, String tag) =>
      e.findElements(tag).firstOrNull?.innerText.trim() ?? '';
}

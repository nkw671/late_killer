import 'bus_route.dart';

/// 클래스 다이어그램의 BusStop
///
/// - stopName : string
/// - stopNumber : int
/// - routes : List<BusRoute>
/// + addFavorite() / deleteFavorite() / searchByName() / searchByNumber() / getRoutes()
///
/// 인천 OpenAPI 매핑: stopId(BSTOPID)가 실제 조회 키이므로 함께 보관.
class BusStop {
  final String stopName;   // BSTOPNM
  final int stopNumber;    // 순번(BSTOPSEQ) 또는 내부 식별용
  final String stopId;     // BSTOPID (9자리) — API 조회용 고유 ID
  final String shortStopId; // SHORT_BSTOPID (단축번호) — 정류장 표지판 번호
  List<BusRoute> routes;
  bool isFavorite;

  BusStop({
    required this.stopName,
    required this.stopNumber,
    required this.stopId,
    this.shortStopId = '',
    List<BusRoute>? routes,
    this.isFavorite = false,
  }) : routes = routes ?? [];

  /// + getRoutes() : List<BusRoute>
  List<BusRoute> getRoutes() => routes;

  /// + addFavorite() : void
  void addFavorite() => isFavorite = true;

  /// + deleteFavorite() : void
  void deleteFavorite() => isFavorite = false;

  Map<String, dynamic> toJson() => {
        'stopName': stopName,
        'stopNumber': stopNumber,
        'stopId': stopId,
        'shortStopId': shortStopId,
        'isFavorite': isFavorite,
      };

  factory BusStop.fromJson(Map<String, dynamic> j) => BusStop(
        stopName: j['stopName'] as String,
        stopNumber: j['stopNumber'] as int,
        stopId: j['stopId'] as String,
        shortStopId: j['shortStopId'] as String? ?? '',
        isFavorite: j['isFavorite'] as bool? ?? false,
      );

  @override
  bool operator ==(Object other) =>
      other is BusStop && other.stopId == stopId;

  @override
  int get hashCode => stopId.hashCode;
}

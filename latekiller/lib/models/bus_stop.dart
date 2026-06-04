import 'bus_route.dart';

class BusStop {
  final String stopName;
  final int stopNumber;
  final String stopId;
  List<BusRoute> routes;

  BusStop({
    required this.stopName,
    required this.stopNumber,
    required this.stopId,
    this.routes = const [],
  });

  Map<String, dynamic> toJson() => {
        'stopName': stopName,
        'stopNumber': stopNumber,
        'stopId': stopId,
      };

  factory BusStop.fromJson(Map<String, dynamic> j) => BusStop(
        stopName: j['stopName'] as String,
        stopNumber: j['stopNumber'] as int,
        stopId: j['stopId'] as String,
      );
}

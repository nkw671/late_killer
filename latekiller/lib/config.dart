/// 공공데이터포털 인천광역시 버스정보 ServiceKey (URL 디코딩 된 값).
///
/// **하드코딩 금지** — 빌드 시점에 주입한다:
/// ```
/// flutter run   --dart-define=BUS_SERVICE_KEY=xxxxxxxxxxxx
/// flutter build apk --dart-define=BUS_SERVICE_KEY=xxxxxxxxxxxx
/// ```
///
/// IDE 실행 시에는 launch.json / additional run args에 `--dart-define`을 추가한다.
/// 미설정 시 빈 문자열 — API 호출은 ServiceKey 누락으로 실패한다.
const String kBusServiceKey = String.fromEnvironment(
  'BUS_SERVICE_KEY',
  defaultValue: '',
);

/// 인천 버스정보 OpenAPI 베이스 URL
const String kBusApiBase =
    'http://apis.data.go.kr/6280000/busArrivalService';
const String kStationApiBase =
    'http://apis.data.go.kr/6280000/busStationService';
const String kRouteApiBase =
    'http://apis.data.go.kr/6280000/busRouteService';

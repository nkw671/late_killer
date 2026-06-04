# LateKiller

Flutter 기반 인천 버스 도착 알림 앱. 정류장까지 도보 시간을 고려해 "지금 출발" 시점을 음성/알림으로 알려준다.

## 실행

```bash
flutter pub get
flutter run
```

`lib/config.dart`의 `kBusServiceKey`에 공공데이터포털 인천광역시 버스정보 ServiceKey(URL 디코딩된 값)를 넣어야 동작한다.

## 프로젝트 구조

```
lib/
├── main.dart                    # CSV/알림 init 후 LateKillerApp 실행
├── config.dart                  # ServiceKey + API base URL
├── theme.dart                   # 밝은 파스텔 블루 M3 테마
├── models/
│   ├── bus_stop.dart            # 정류장 (stopId/stopNumber/stopName)
│   ├── bus_route.dart           # 노선 (routeId/busNumber + tick/correctArriveTime + EventManager)
│   ├── alarm_schedule.dart      # 요일별 알람 (day/isEnabled/alarmTime)
│   └── alarm_config.dart        # 저장된 알람 한 건 (정류장+선택버스들+도보시간+요일스케줄)
├── services/
│   ├── event_manager.dart       # Observer 패턴 (subscribe/unsubscribe/notify)
│   ├── stop_csv.dart            # assets/stopdata.csv 로딩 → 정류소번호→ID 매핑
│   ├── bus_api.dart             # 인천 OpenAPI 4종 (XML 응답, UTF-8 강제 디코딩)
│   ├── tts.dart                 # PlayTTS (flutter_tts, ko-KR 준비 대기)
│   ├── notification.dart        # LockNotification (flutter_local_notifications, 잠금화면)
│   └── storage.dart             # SharedPreferences (즐겨찾기/알람 저장)
├── core/
│   └── departure_alarm.dart     # 알람 엔진: 1초 tick + 30초 API polling, 임계시간 도달 알림/TTS
└── screens/
    ├── home_screen.dart         # 검색창 + 설정한 알람 + 즐겨찾기
    ├── search_result_screen.dart  # 이름 검색 결과
    ├── stop_detail_screen.dart    # 경유 노선 + 도착시간 (즐겨찾기 토글)
    ├── alarm_setup_screen.dart    # 요일/시간/도보분/버스선택 → 저장
    └── alarm_active_screen.dart   # 추적 중인 버스 + 다음 버스 + 중지
```

## API 로직 (인천 OpenAPI)

- **번호 검색**: `stopdata.csv`에서 정류소번호 → 정류소ID → `getBusStationViaRouteList`
- **이름 검색**: `getBusStationNmList` (param `bstopNm`) → 정류장 선택
- **정류장 선택**: `getAllRouteBusArrivalList` + `getBusStationViaRouteList` 머지 (도착 응답에 노선번호가 없어서 노선번호 매핑 필요)
- **특정 버스 도착**: `getBusArrivalList(bstopId, routeId)` — 30초 주기로 polling

응답 wrapper는 `<itemList>`, 필드는 대문자 (`BSTOPID`, `BSTOPNM`, `SHORT_BSTOPID`, `ROUTEID`, `ROUTENO`, `ARRIVALESTIMATETIME`).

## 알람 동작

1. `AlarmSetupScreen`에서 저장 → `AlarmActiveScreen`으로 `pushReplacement`
2. `DepartureAlarm`이 후보 노선들을 1초 tick + 30초 API polling
3. `DepartureAlarm`만 옵저버 등록 (UI 갱신용) — TTS/알림은 옵저버 미등록, DepartureAlarm이 직접 호출
4. **출발 임계시간 도달 시 1회**만 `notif.showMessage` + `tts.speakMessage`
5. 임계 이후엔 음성만 주기적 안내 (≤60초→15초, ≤180초→60초, 그 외 안함)
6. 새 버스 선택되면 `_alertedThreshold` 플래그 리셋

## 주의사항

- **CSV는 UTF-8 인코딩으로 저장됨** (원본 CP949 → 변환됨). 다시 교체할 땐 UTF-8로.
- **HTTP 응답 한글**: `http` 패키지는 charset 미지정 시 latin1로 디코딩하므로 `utf8.decode(r.bodyBytes, allowMalformed: true)` 사용 중 ([bus_api.dart](lib/services/bus_api.dart))
- **TTS 준비 대기**: `PlayTTS`는 ko-KR 가용성 확인 후 사용 ([tts.dart](lib/services/tts.dart) `_ready` future)
- **Android desugaring**: `flutter_local_notifications` 요구사항. `android/app/build.gradle.kts`에 `isCoreLibraryDesugaringEnabled = true` + `desugar_jdk_libs` 의존성 적용됨
- **StopDetail → AlarmSetup 흐름**: `Navigator.push` 후 `Navigator.pop` 호출 금지 (`pushReplacement`로 인해 await가 즉시 풀려 알람 화면이 닫힘)

## 의존성 (pubspec.yaml)

`http`, `shared_preferences`, `flutter_tts`, `flutter_local_notifications`, `csv`, `xml`, `intl`

## 작업 원칙

- 간결하게. 수정은 외과 수술처럼 해당 부분만.
- 코드 작성 전 다시 한번 생각.
- 디자인: 밝고 세련된 톤 (흰 배경 + 파스텔 블루 액센트 + 둥근 카드).

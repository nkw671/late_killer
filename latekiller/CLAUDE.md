# LateKiller

Flutter 기반 인천 버스 도착 알림 앱. 정류장까지 도보 시간을 고려해 "지금 출발" 시점을 음성/알림으로 알려준다.

## 실행

1. 프로젝트 루트에 `env.json` 생성 (gitignore됨):
   ```json
   { "BUS_SERVICE_KEY": "발급받은_URL_디코딩값" }
   ```
2. 실행/빌드:
   ```bash
   flutter pub get
   flutter run --dart-define-from-file=env.json
   flutter build apk --dart-define-from-file=env.json
   ```

VS Code에선 `.vscode/launch.json`(gitignore됨)이 자동으로 `env.json`을 읽어 F5만 누르면 된다.

**키를 코드에 하드코딩하지 말 것** — `lib/config.dart`의 `kBusServiceKey`는 `String.fromEnvironment('BUS_SERVICE_KEY')`로 빌드 시 주입받는다. 미설정 시 빈 문자열로 API 호출이 실패하며 콘솔에 경고가 찍힌다.

## 프로젝트 구조

```
lib/
├── main.dart                    # CSV/알림 init + AlarmScheduler 시작 → LateKillerApp 실행
│                                # navigatorKey, scaffoldMessengerKey 전역 공유
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
│   ├── bus_api.dart             # 인천 OpenAPI 4종 (XML 응답, UTF-8 강제 디코딩) + MOCK 분기
│   ├── tts.dart                 # PlayTTS (flutter_tts, ko-KR 준비 대기)
│   ├── notification.dart        # LockNotification (flutter_local_notifications, 잠금화면)
│   ├── storage.dart             # SharedPreferences (즐겨찾기/알람 저장)
│   ├── alarm_scheduler.dart     # 저장된 알람의 요일/시각 도래 시 AlarmActiveScreen 자동 진입 (30초 polling)
│   ├── floating_overlay.dart    # 시스템 오버레이 윈도우 (백그라운드 시 표시)
│   └── mock_bus_data.dart       # ⚠ 테스트용 mock 도착시간 (현재 enabled=false). 완전 제거 시 파일 + bus_api.dart MOCK 마커 삭제
├── core/                        # 알람 엔진 (DepartureAlarm 책임 분리)
│   ├── departure_alarm.dart     # 조정자(Coordinator): 버스 선택 + 하위 컴포넌트 조립
│   ├── bus_poller.dart          # API polling(60s) + 1초 tick + 버스 통과 감지(onBusPassed)
│   ├── threshold_announcer.dart # REQ-11 임계시간 1회 발화 (maybeFire/reset)
│   ├── periodic_announcer.dart  # REQ-18 남은시간 기준 주기 안내 (shouldAnnounceNow)
│   └── start_announcer.dart     # 알람 시작 시 1회 안내 ("알람을 시작합니다. X번 약 N분 후 도착")
└── screens/
    ├── home_screen.dart         # 검색창 + 설정한 알람(탭→편집) + 즐겨찾기
    ├── search_result_screen.dart  # 이름 검색 결과
    ├── stop_detail_screen.dart    # 경유 노선(탭 비활성) + 하단 "정류장 선택" 버튼
    ├── alarm_setup_screen.dart    # 요일/시간/도보분/버스선택 → 저장 (신규/편집 모드)
    └── alarm_active_screen.dart   # 추적 중인 버스 + 다음 버스 + 중지 (백그라운드 시 플로팅 표시)
```

## API 로직 (인천 OpenAPI)

- **번호 검색**: `stopdata.csv`에서 정류소번호 → 정류소ID → `getBusStationViaRouteList`
- **이름 검색**: `getBusStationNmList` (param `bstopNm`) → 정류장 선택
- **정류장 선택**: `getAllRouteBusArrivalList` + `getBusStationViaRouteList` 머지 (도착 응답에 노선번호가 없어서 노선번호 매핑 필요)
- **특정 버스 도착**: `getBusArrivalList(bstopId, routeId)` — 60초 주기로 polling

응답 wrapper는 `<itemList>`, 필드는 대문자 (`BSTOPID`, `BSTOPNM`, `SHORT_BSTOPID`, `ROUTEID`, `ROUTENO`, `ARRIVALESTIMATETIME`).

## 사용자 흐름

1. **홈**: 검색창(번호/이름) · 설정한 알람 목록 · 즐겨찾기. 알람 카드 탭 → 편집 모드, 휴지통 → 삭제
2. **정류장 상세**: 경유 노선 + 실시간 도착시간. 노선 카드는 표시 전용(탭 비활성). 하단 **「정류장 선택」** 버튼으로 알람 설정 진입. 우상단 별로 즐겨찾기 토글
3. **알람 설정**: 요일별 행 탭 → 시간 선택, 우측 Switch → 활성/비활성. 도보 시간(1~60분), 버스 다중선택. 저장 시 **`Navigator.popUntil(isFirst)`로 홈 복귀** + 루트 ScaffoldMessenger로 "알람이 저장되었습니다" SnackBar
4. **알람 자동 실행**: `AlarmScheduler`가 30초 주기로 검사. 활성 요일·시각 매치 시 `navigatorKey`로 `AlarmActiveScreen` push. 같은 분 내 중복 발화 방지(dateKey 기반 `_fired` 셋)
5. **알람 화면**: `DepartureAlarm` 동작 + 백그라운드(`paused/inactive/hidden`) 진입 시에만 플로팅 표시, 복귀(`resumed`) 시 숨김

## 알람 동작 (DepartureAlarm + 하위 컴포넌트)

`DepartureAlarm`은 조정자(coordinator)로 슬림화. 실제 동작은 4개 컴포넌트가 분담:

1. **`BusPoller`** — 후보 노선들을 1초 tick + 60초 API polling
   - 매 API 호출 시 `correctArriveTime`으로 카운트다운 갱신
   - `before <= 30 && api >= 120`이면 "버스 통과" → `onBusPassed` 콜백 (Coordinator가 임계 리셋)
   - 매 refresh 끝에 `onRefreshed` 콜백 → Coordinator의 `selectEarliestBus` 호출 (순위 변동 반영)
2. **Coordinator (`DepartureAlarm`)** — `selectEarliestBus`로 가장 이른 노선을 선택 버스로 지정
3. **`StartAnnouncer`** — 첫 API 응답 후 1회 발화: `"알람을 시작합니다. X번 버스 약 N분 후 도착"` (도착정보 없으면 `"알람을 시작합니다"`만)
4. **`ThresholdAnnouncer`** — 출발 임계시간(`busArriveTime <= walkTimeToStop`) 도달 시 **1회만** `tts.speakMessage` + `notif.showDeparture` ([REQ-11](#))
5. **`PeriodicAnnouncer`** — 임계 이후 **남은시간 기준 주기 안내** ([REQ-18](#))
   - 10분 이상 → 5분 배수 정각(15분 0초·20분 0초…)
   - 10분 미만 → 매 분 정각(9분 0초·8분 0초…)
   - `shouldAnnounceNow`: `remainingTime > 0 && remainingTime % 60 == 0` 가드
6. 새 버스 선택(`selectEarliestBus`/`switchToNextEarliestBus`) 또는 통과 감지 시 `ThresholdAnnouncer.reset()`
7. **TTS/알림은 옵저버 미등록** — Coordinator의 `update`가 ThresholdAnnouncer → PeriodicAnnouncer 순으로 위임 (이중 발화 방지)

## 플로팅 오버레이 (FloatingOverlay)

- `AlarmActiveScreen` `initState`에서 `ensurePermission()` 호출 (포그라운드에서만 시스템 다이얼로그 가능)
- 라이프사이클 `paused/inactive/hidden` → `show()`, `resumed` → `hide()`
- `WindowSize.matchParent` 가로 + height 260px, 내부 컨텐츠는 `FittedBox(scaleDown)` + 좌측 `Flexible(ellipsis)`로 잘림 방지
- 별도 entrypoint `overlayMain` (`@pragma('vm:entry-point')`) → `_OverlayApp`이 `FlutterOverlayWindow.overlayListener`로 `{bus, sec}` 수신해 MM:SS 표시

## 주의사항

- **CSV는 UTF-8 인코딩으로 저장됨** (원본 CP949 → 변환됨). 다시 교체할 땐 UTF-8로.
- **HTTP 응답 한글**: `http` 패키지는 charset 미지정 시 latin1로 디코딩하므로 `utf8.decode(r.bodyBytes, allowMalformed: true)` 사용 중 ([bus_api.dart](lib/services/bus_api.dart))
- **TTS 준비 대기**: `PlayTTS`는 ko-KR 가용성 확인 후 사용 ([tts.dart](lib/services/tts.dart) `_ready` future)
- **Android desugaring**: `flutter_local_notifications` 요구사항. `android/app/build.gradle.kts`에 `isCoreLibraryDesugaringEnabled = true` + `desugar_jdk_libs` 의존성 적용됨
- **알람 동작 범위**: 현재 `AlarmScheduler`는 Dart `Timer` 기반. **앱 프로세스가 살아있는 동안만** 동작. 작업관리자 스와이프/OS 강제 종료/재부팅 후엔 동작 안 함 (시중 알람앱 수준 보장 필요 시 `android_alarm_manager_plus` + 매니페스트 권한 추가 필요)
- **편집 모드 식별**: `AlarmSetupScreen`은 `existing: AlarmConfig?` + `existingIndex: int?`로 신규/편집 분기. 편집 저장 시 인덱스 위치 교체, 신규는 append
- **즐겨찾기 중복 방지**: `_toggleFav` 추가 경로에 `!favs.any((f) => f.stopId == widget.stop.stopId)` 가드. `_load`는 API 실패와 무관하게 `_isFav`를 먼저 반영
- **MOCK 데이터**: [mock_bus_data.dart](lib/services/mock_bus_data.dart)의 `MockBusData.enabled = false` (현재 비활성, 실 API 사용). 다시 켜려면 `enabled = true` (defaultInitial 1200초=20분, 회전 cycle). 완전 제거는 mock 파일 삭제 + [bus_api.dart](lib/services/bus_api.dart) 내 `// === MOCK BEGIN ===` ~ `END` 블록 3개 제거

## 의존성 (pubspec.yaml)

`http`, `shared_preferences`, `flutter_tts`, `flutter_local_notifications`, `csv`, `xml`, `intl`, `flutter_overlay_window`

## 테스트

```bash
flutter test test/srs_test.dart
```

`test/srs_test.dart` — SRS 24개 요구사항 중 단위 테스트 가능 항목(REQ-10/11/12/13/17/18/19/20/21/22) 자동 검증. **13/13 통과**.

## 작업 원칙

- 간결하게. 수정은 외과 수술처럼 해당 부분만.
- 코드 작성 전 다시 한번 생각.
- 디자인: 밝고 세련된 톤 (흰 배경 + 파스텔 블루 액센트 + 둥근 카드).

# CLAUDE.md

이 파일은 Claude(및 다른 AI 어시스턴트)가 이 프로젝트를 이어받을 때 빠르게
맥락을 잡도록 돕는 안내서입니다. 새 세션에서 이 파일을 먼저 읽어주세요.

---

## 프로젝트 개요

**버스 알람 앱** — 인천광역시 버스정보 OpenAPI로 실시간 도착정보를 확인하고,
정류장까지의 도보 시간을 고려해 "지금 출발하세요" 알림을 주는 Flutter 앱.

요구명세(SRS) → 유스케이스 → 클래스 다이어그램 → 구현 순으로 진행했고,
**클래스 다이어그램 구조를 코드에 1:1로 반영**하는 것이 핵심 원칙입니다.

---

## 기술 스택

- **Flutter** (Dart, SDK >=3.3.0), 상태관리 `provider`
- 네트워크 `http` + XML 파싱 `xml` (인천 API는 XML 응답)
- TTS `flutter_tts`, 잠금화면 알림 `flutter_local_notifications`
- 플로팅 오버레이 `flutter_overlay_window` (Android `SYSTEM_ALERT_WINDOW`)
- 영속화 `shared_preferences`, 폰트 `google_fonts`

---

## 디자인 시스템

컨셉: **"Calm Transit"** — 다크 잉크 베이스(#0E1116) + 민트/시안 그라데이션
액센트(#4ADE80 → #22D3EE). 신호등 메타포(초록=출발/앰버=임박/빨강=통과),
둥근 카드, 부드러운 그림자, 카운트다운은 모노스페이스 숫자.
모든 토큰은 `lib/theme/app_theme.dart`에 정의. 새 UI는 이 토큰을 따를 것.

---

## 아키텍처 = 클래스 다이어그램 (중요)

```
BusRoute (Subject) ◇ owns → EventManager ◇ → <<interface>> Observer
                                                   △ (구현)
              ┌──────────────┬──────────────┬───────────────┐
        DepartureAlarm     PlayTTS     FloatingWidget   LockNotification
```

| 다이어그램 클래스 | 파일 | 역할 |
|---|---|---|
| BusStop | `models/bus_stop.dart` | 정류장, 즐겨찾기, 노선 보유 |
| BusRoute (Subject) | `models/bus_route.dart` | 버스 데이터 + `refresh()`로 통지 트리거 |
| AlarmSchedule | `models/alarm_schedule.dart` | 요일별 (활성여부+시각) |
| DayOfWeek (enum) | `models/day_of_week.dart` | 요일 |
| EventManager | `services/event_manager.dart` | subscribe/unsubscribe/notify |
| Observer (interface) | `observers/observer.dart` | `update(busNumber, busArriveTime)` |
| DepartureAlarm | `observers/departure_alarm.dart` | **알림 로직 핵심** (REQ-07~14) |
| PlayTTS | `observers/play_tts.dart` | 음성 안내 |
| Widget(플로팅) | `observers/floating_widget.dart` | 오버레이 MM:SS |
| LockNotification | `observers/lock_notification.dart` | 잠금화면 알림 |

`services/app_state.dart` = 전체 배선 + 실시간 폴링 루프 (Provider).

### Observer 패턴 동작 흐름
1. `AppState._tick()`이 **8초**(≤10초, REQ-14)마다 API로 도착정보 갱신
2. 기준 버스 선정/전환(REQ-10/12) → `BusRoute.refresh()` 호출
3. `refresh()`가 자신의 `EventManager.notify()` 실행
4. 구독된 Observer의 `update(busNumber, busArriveTime)` 호출
5. `DepartureAlarm`이 출발 시점/모두 통과를 판단해 콜백 트리거

---

## ⚠️ 설계 결정 / 주의사항 (코드 수정 전 반드시 숙지)

1. **busArriveTime은 "초" 단위.** 도착 API의 `ARRIVALESTIMATETIME`이 초라서
   설계도 초로 통일함. 분으로 바꾸지 말 것.

2. **Observer 구독에 다이어그램과의 의도적 차이가 있음.**
   다이어그램은 4개 Observer 모두 EventManager에 구독되지만, 실제로는
   매 틱(8초) 갱신이 필요한 **DepartureAlarm·FloatingWidget만 구독**시킴.
   PlayTTS·LockNotification을 매 틱 호출하면 음성/알림이 8초마다 울려버리므로,
   이 둘은 DepartureAlarm의 판단 **콜백**(`onDeparture`/`onAllPassed`)으로 구동.
   → `app_state.dart`의 `_ensureSubscribed` 주석 참고. 이 분리를 깨지 말 것.

3. **API 키 없음 → MOCK 모드 기본.** `bus_api_service.dart`의 `serviceKey`가
   기본값이면 `useMock=true`로 가짜 데이터 사용. 실제 키는 공공데이터포털에서
   사용자가 직접 발급(초당 30건 제한). AI가 키를 생성/삽입하지 말 것.

4. **API 서비스 상태 (확인됨):**
   - `busArrivalService` (`getAllRouteBusArrivalList`) → **정상 동작**.
     응답에 ROUTENO 없고 ROUTEID만 존재 → `AppState.loadArrivals()`에서 `enrichRoutes()`로
     `getBusRouteId` 호출해 routeNo/기점·종점 보완. 조회 결과는 `_routeInfoCache`에 캐싱.
   - `busRouteService` → **정상 동작** (구독 완료).
     `getBusRouteNo`, `getBusRouteId`, `getBusRouteSectionList` 모두 사용 가능.
   - `getBusRouteId` 응답 필드: ROUTEID, ROUTENO, ORIGIN_BSTOPNM, DEST_BSTOPNM,
     ROUTELEN, FBUS_DEPHMS, LBUS_DEPHMS, MIN_ALLOCGAP, MAX_ALLOCGAP, TURN_BSTOPID/NM.
   - 단축번호(SHORT_BSTOPID) 42891 → BSTOPID **168000891** (검증 완료).

5. **Mock routeId vs 실 API routeId 불일치:**
   Mock에서 564-1 노선 routeId로 `'165000111'`을 사용하나, 실 API의 정류소 `165000111`에서는
   `165000004`·`168000016`·`168000030` 등이 반환됨. Mock 모드에서만 내부적으로 사용되므로
   실 API 사용 시 영향 없음. 단, `useMock=false`로 전환 후 노선 선택 화면의 routeNo 표시가
   "165000004" 같은 ID로 나오는 것은 ROUTENO 미제공 때문이며 정상 동작.

6. **REQ-01(정류장 이름 검색)은 데모상 목업.** 공개 API에 이름→정류소 직접
   검색이 없음. 실서비스는 정류소 마스터 데이터 연동 필요.

5. **빌드 골격 미포함.** `flutter create`로 만든 android/ios/gradle 등은 없음.
   빈 Flutter 프로젝트에 `lib/`·`pubspec.yaml`·`AndroidManifest.xml`을 얹는 구조.

---

## 요구사항 추적성 (21개 전부 매핑)

| REQ | 구현 위치 |
|---|---|
| 01/02 검색 | `search_screen.dart` |
| 03/04 즐겨찾기 | `AppState.addFavorite/removeFavorite` |
| 05 노선 조회 | `route_select_screen.dart` |
| 06 노선 선택 | `AppState.toggleRouteSelection` |
| 07 도보시간 | `DepartureAlarm.setWalkTimeToStop` |
| 08/09 요일별 활성·시각 | `AlarmSchedule` |
| 10 가장 이른 버스 | `DepartureAlarm._pickEarliest` |
| 11 출발 알림(1회) | `DepartureAlarm.update` + `onDeparture` |
| 12 다음 버스 전환 | `DepartureAlarm.switchToNextEarliestBus` |
| 13 모두 통과(1회) | `onAllPassed` → Lock/TTS |
| 14 상시 갱신(≤10초) | `AppState.pollInterval = 8s` |
| 15/16 음성 | `PlayTTS.speak` (ko-KR) |
| 17 볼륨 | `PlayTTS.setVolume` |
| 18/19 잠금화면 | `LockNotification.showNotification` |
| 20/21 플로팅 MM:SS | `FloatingWidget` + `FloatingOverlayView` |

---

## 알려진 미해결 / 다음 작업 후보

- [ ] **빌드 골격 추가** — `flutter create` 산출물(MainActivity.kt, gradle 등)을
      채워 바로 빌드 가능하게.
- [x] **주기적 남은시간 안내 구현됨** — `DepartureAlarm._checkPeriodicAnnouncement()`:
      10분↑ → 5분 간격, 10분↓ → 1분 간격. `onAnnounce` 콜백 → `PlayTTS.speakMessage`.
      `_lastAnnounceSec`로 마지막 안내 시점 추적. `reset()`에서 초기화.
- [x] **busRouteService 구독 완료** — `getBusRouteNo`, `getBusRouteId`, `getBusRouteSectionList`
      모두 정상 동작. `enrichRoutes()`로 도착정보 노선번호 표시 해결.
- [ ] **시퀀스 다이어그램** — UC-07(도착 알림 수신) 흐름을 코드와 맞춰 작성.
- [ ] **Observer 구독 구조 정합성** — 위 주의사항 2번을 다이어그램에 명시할지 결정.
- [ ] iOS 플로팅: OS 정책상 시스템 오버레이 불가 → 잠금화면 알림으로 대체됨.

---

## 코딩 규칙

- 클래스/변수/메서드 이름은 **클래스 다이어그램과 일치**시킬 것. 변경 시 다이어그램도 갱신.
- 주석은 한국어, 각 클래스 상단에 다이어그램 멤버 시그니처를 명시(추적성).
- 새 기능이 요구사항을 늘리면, 먼저 명세/다이어그램부터 합의 후 구현.
- UI는 `app_theme.dart`의 디자인 토큰을 따를 것 (임의 색상 하드코딩 지양).

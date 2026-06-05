// LateKiller SRS 테스트 결과 docx 생성기
// 사용: node scripts/make_test_results_docx.js
const fs = require('fs');
const path = require('path');
const {
  Document, Packer, Paragraph, TextRun, Table, TableRow, TableCell,
  HeadingLevel, AlignmentType, BorderStyle, WidthType, ShadingType,
  LevelFormat, PageOrientation,
} = require('docx');

const FONT = 'Malgun Gothic'; // 한글 안전 폰트
const MONO = 'Consolas';

const border = { style: BorderStyle.SINGLE, size: 1, color: 'BFBFBF' };
const borders = { top: border, bottom: border, left: border, right: border };
const headerFill = 'D5E8F0';
const cellMargins = { top: 80, bottom: 80, left: 120, right: 120 };

// US Letter, 1" 여백
const PAGE_W = 12240, PAGE_H = 15840, MARGIN = 1440;
const CONTENT_W = PAGE_W - 2 * MARGIN; // 9360

function p(text, opts = {}) {
  const runs = Array.isArray(text)
    ? text
    : [new TextRun({ text, font: FONT, size: opts.size ?? 22, bold: opts.bold, color: opts.color })];
  return new Paragraph({
    children: runs,
    spacing: { before: opts.before ?? 60, after: opts.after ?? 60 },
    alignment: opts.align,
  });
}

function h1(text) {
  return new Paragraph({
    heading: HeadingLevel.HEADING_1,
    children: [new TextRun({ text, font: FONT, size: 32, bold: true })],
    spacing: { before: 240, after: 160 },
  });
}

function h2(text) {
  return new Paragraph({
    heading: HeadingLevel.HEADING_2,
    children: [new TextRun({ text, font: FONT, size: 26, bold: true, color: '1F4E79' })],
    spacing: { before: 200, after: 120 },
  });
}

function cell(text, opts = {}) {
  const isHeader = opts.header === true;
  const children = Array.isArray(text) ? text : [text];
  return new TableCell({
    borders,
    width: { size: opts.width, type: WidthType.DXA },
    margins: cellMargins,
    shading: isHeader ? { fill: headerFill, type: ShadingType.CLEAR } : undefined,
    children: children.map((t) =>
      typeof t === 'string'
        ? new Paragraph({
            children: [
              new TextRun({
                text: t,
                font: FONT,
                size: opts.size ?? 20,
                bold: isHeader || opts.bold,
                color: opts.color,
              }),
            ],
            alignment: opts.align,
            spacing: { before: 20, after: 20 },
          })
        : t
    ),
  });
}

function table(rows, columnWidths) {
  return new Table({
    width: { size: CONTENT_W, type: WidthType.DXA },
    columnWidths,
    rows: rows.map(
      (r) =>
        new TableRow({
          children: r.cells.map((c, i) =>
            cell(c.text, { ...c.opts, width: columnWidths[i] })
          ),
        })
    ),
  });
}

function bullet(text) {
  return new Paragraph({
    numbering: { reference: 'bullets', level: 0 },
    children: [new TextRun({ text, font: FONT, size: 22 })],
    spacing: { before: 30, after: 30 },
  });
}

function codeLine(text) {
  return new Paragraph({
    children: [new TextRun({ text, font: MONO, size: 18 })],
    spacing: { before: 0, after: 0 },
    shading: { fill: 'F4F4F4', type: ShadingType.CLEAR },
  });
}

// === 데이터 ===
const summary = [
  ['분류', '건수'],
  ['자동 단위 테스트 통과', '13 / 13'],
  ['코드 정적 검증 통과', '10'],
  ['부분 통과 (스펙 임계조건 미구현)', '1 (REQ-16)'],
  ['전체 PASS', '23 / 24'],
];

const matrix = [
  ['ID', '분류', '결과', '검증 방법 / 근거'],
  ['REQ-01', '정류장 선택', '✅', '이름 검색 — getBusStationNmList 호출, 실패시 SnackBar (home_screen.dart)'],
  ['REQ-02', '정류장 선택', '✅', '번호 검색 — CSV 조회, 없으면 "해당 번호의 정류장 없음" 토스트 (home_screen.dart)'],
  ['REQ-03', '정류장 선택', '✅', '즐겨찾기 등록 — _toggleFav, 상한 없음 (stop_detail_screen.dart)'],
  ['REQ-04', '정류장 선택', '✅', '즐겨찾기 삭제 — close 버튼 + saveFavorites (home_screen.dart)'],
  ['REQ-05', '버스 선택', '✅', '경유 노선 조회 — getAllRouteBusArrivalList (stop_detail_screen.dart)'],
  ['REQ-06', '버스 선택', '✅', '노선 다중 선택 — Checkbox, _picked.isEmpty 시 저장 비활성 (alarm_setup_screen.dart)'],
  ['REQ-07', '알람 설정', '✅', '도보 1~60분 — Slider min:1, max:60 UI 강제 (alarm_setup_screen.dart)'],
  ['REQ-08', '알람 설정', '✅', '요일별 활성화 — sch.isEnabled 분기 (alarm_scheduler.dart:44)'],
  ['REQ-09', '알람 설정', '✅', '요일별 HH:MM 독립 설정 — hour/minute 매칭 (alarm_scheduler.dart:45)'],
  ['REQ-10', '알림 로직', '✅ TEST', '[REQ-10] selectEarliestBus picks earliest >0'],
  ['REQ-11', '알림 로직', '✅ TEST', '[REQ-11] threshold alert fires exactly once'],
  ['REQ-12', '알림 로직', '✅ TEST', '[REQ-12] switchToNextEarliestBus picks next candidate + 보강'],
  ['REQ-13', '알림 로직', '✅ TEST', '[REQ-13] stopAlarm unsubscribes from routes, 중지 버튼'],
  ['REQ-14', '알림 로직', '✅', '시작 시 API 호출 — callAPI → _refresh 즉시 (departure_alarm.dart:69)'],
  ['REQ-15', '알림 로직', '✅', '1분 주기 polling — Timer.periodic(60s) (departure_alarm.dart:73)'],
  ['REQ-16', '알림 로직', '⚠ PARTIAL', 'correctArriveTime이 차이 무관 항상 덮어씀. 테스트 기준은 충족하나 스펙의 >=20s 임계 가드 미구현 (bus_route.dart:23)'],
  ['REQ-17', '알림 로직', '✅ TEST', '[REQ-17] tick decrements 1 second, tick stops at 0'],
  ['REQ-18', '알림 로직', '✅ TEST', 'shouldAnnounceNow 3개 케이스 (10분±별 주기)'],
  ['REQ-19', 'TTS 안내', '✅ TEST', '[REQ-19/20] TTS 메시지에 노선번호 포함'],
  ['REQ-20', 'TTS 안내', '✅ TEST', 'TTS 메시지에 남은시간(분) 포함 (5분 검증)'],
  ['REQ-21', '잠금화면', '✅ TEST', '[REQ-21/22] 출발 알림 본문에 HH:MM 포함, fullScreenIntent:true'],
  ['REQ-22', '잠금화면', '✅ TEST', '동상 — DarwinNotificationDetails iOS 본문 포맷 동일'],
  ['REQ-23', '플로팅 화면', '✅', '플로팅 UI 표시 — showOverlay, AlarmActiveScreen update (floating_overlay.dart)'],
  ['REQ-24', '플로팅 화면', '✅', 'MM:SS 실시간 갱신 — _mmss + 매 tick shareData (floating_overlay.dart)'],
];

const testLog = [
  '+1  [REQ-10] selectEarliestBus picks earliest >0',
  '+2  [REQ-11] threshold alert fires exactly once',
  '+3  [REQ-12] switchToNextEarliestBus picks next candidate',
  '+4  [REQ-13] stopAlarm unsubscribes from routes',
  '+5  [REQ-17] tick decrements 1 second',
  '+6  [REQ-17] tick stops at 0',
  '+7  [REQ-18] shouldAnnounceNow (남은시간 기준) >=10분 → 5분 배수 정각에만 true',
  '+8  [REQ-18] shouldAnnounceNow (남은시간 기준) <10분 → 매 분 정각에 true',
  '+9  [REQ-18] shouldAnnounceNow (남은시간 기준) remaining<=0 → false',
  '+10 [REQ-19/20] 출발 TTS 메시지에 노선번호와 분 포함',
  '+11 [REQ-21/22] 출발 알림 본문에 노선번호와 HH:MM 포함',
  '+12 [REQ-12 보강] 새 버스 선택 시 임계 플래그 리셋',
  '+13 [REQ EventManager] subscribe/notify/unsubscribe',
  '',
  '00:00 +13: All tests passed!',
];

const req16 = [
  ['항목', '내용'],
  ['스펙', 'API 호출로 받은 도착시간과 카운트다운이 20초 이상 차이날 때만 API값으로 갱신'],
  ['현재 구현', 'correctArriveTime(apiTime) — 차이 무관하게 항상 busArriveTime = apiTime (bus_route.dart:23)'],
  ['테스트 기준 충족', '✅ "20초 이상 차이나면 바뀌는지"'],
  ['스펙 충족', '❌ 임계 가드 부재'],
  ['권장 패치', 'if ((apiTime - busArriveTime).abs() >= 20) busArriveTime = apiTime;'],
];

const manual = [
  ['ID', '수동 검증 포인트'],
  ['REQ-01·02·05·14·15', '실 API 응답 (시간대·지역에 따라 노선/도착 데이터 차이)'],
  ['REQ-19·20', '실제 TTS 음성 발화 (장치별 음성 엔진)'],
  ['REQ-21·22', '실 잠금화면에서 알림 표시 (Android Lockscreen / iOS Lock Screen)'],
  ['REQ-23·24', '플로팅 윈도우 실표시 (시스템 오버레이 권한 grant 후)'],
];

const accumulated = [
  '즐겨찾기 등록 중복 가드 + API 실패 시 _isFav 누락 버그 수정',
  '알람 카드 탭 → 편집 모드 (existing/existingIndex 분기)',
  'mock 도착시간 데이터 (최대 20분, 회전 cycle) — 테스트 종료 후 제거 대상',
  'REQ-18 안내 주기: 벽시계 기준 → 남은시간 기준 (9·8·7분 정각 발화)',
  '플로팅 오버레이: 백그라운드 진입 시에만 표시, FittedBox + matchParent로 잘림 해결',
  '정류장 상세: 노선 탭 비활성, 하단 "정류장 선택" 버튼으로 알람 설정 진입',
  '알람 설정 저장 시 자동 발사 제거, 홈 복귀 + "알람이 저장되었습니다" SnackBar',
  '알람 설정 화면: "시간" 버튼 제거, 행 본문 탭 = 시간 선택 / 우측 Switch = 활성화 토글',
  '알람 시작 시 1회 TTS 안내 ("알람을 시작합니다. X번 버스 약 N분 후 도착")',
  '홈 알람 카드에 활성 요일·시각 표시 (같은 시간 그룹화)',
];

const todo = [
  ['항목', '영향'],
  ['REQ-16 임계 조건 (abs>=20s)', '스펙 완전 충족'],
  ['앱 종료 후에도 동작하는 알람', '시중 알람앱 수준 신뢰성 (Android AlarmManager 기반)'],
  ['Mock 데이터 제거', '운영 빌드 전 mock_bus_data.dart 삭제 + bus_api.dart MOCK 마커 제거'],
];

// === 표 빌더 ===
function buildSummaryTable() {
  return table(
    summary.map((row, i) => ({
      cells: row.map((c) => ({
        text: c,
        opts: { header: i === 0, bold: i === summary.length - 1 },
      })),
    })),
    [5616, 3744]
  );
}

function buildMatrixTable() {
  // ID 900, 분류 1300, 결과 1400, 근거 5760
  return table(
    matrix.map((row, i) => ({
      cells: row.map((c, j) => ({
        text: c,
        opts: {
          header: i === 0,
          color: row[2] === '⚠ PARTIAL' && j === 2 ? 'C04A00' : undefined,
        },
      })),
    })),
    [900, 1300, 1400, 5760]
  );
}

function buildReq16Table() {
  return table(
    req16.map((row, i) => ({
      cells: row.map((c) => ({ text: c, opts: { header: i === 0 } })),
    })),
    [2200, 7160]
  );
}

function buildManualTable() {
  return table(
    manual.map((row, i) => ({
      cells: row.map((c) => ({ text: c, opts: { header: i === 0 } })),
    })),
    [2400, 6960]
  );
}

function buildTodoTable() {
  return table(
    todo.map((row, i) => ({
      cells: row.map((c) => ({ text: c, opts: { header: i === 0 } })),
    })),
    [3500, 5860]
  );
}

// === 문서 ===
const doc = new Document({
  styles: {
    default: { document: { run: { font: FONT, size: 22 } } },
    paragraphStyles: [
      {
        id: 'Heading1', name: 'Heading 1', basedOn: 'Normal', next: 'Normal',
        quickFormat: true,
        run: { size: 32, bold: true, font: FONT },
        paragraph: { spacing: { before: 240, after: 160 }, outlineLevel: 0 },
      },
      {
        id: 'Heading2', name: 'Heading 2', basedOn: 'Normal', next: 'Normal',
        quickFormat: true,
        run: { size: 26, bold: true, font: FONT, color: '1F4E79' },
        paragraph: { spacing: { before: 200, after: 120 }, outlineLevel: 1 },
      },
    ],
  },
  numbering: {
    config: [
      {
        reference: 'bullets',
        levels: [
          {
            level: 0,
            format: LevelFormat.BULLET,
            text: '•',
            alignment: AlignmentType.LEFT,
            style: { paragraph: { indent: { left: 540, hanging: 270 } } },
          },
        ],
      },
    ],
  },
  sections: [
    {
      properties: {
        page: {
          size: { width: PAGE_W, height: PAGE_H, orientation: PageOrientation.PORTRAIT },
          margin: { top: MARGIN, right: MARGIN, bottom: MARGIN, left: MARGIN },
        },
      },
      children: [
        h1('LateKiller — SRS 테스트 결과'),
        p('대상: bus_alarm_srs.xlsx REQ-01 ~ REQ-24'),
        p('일시: 2026-06-06'),
        p('환경: Flutter 3.32.4 (stable) · Windows 11 · flutter test test/srs_test.dart'),

        h2('요약'),
        buildSummaryTable(),
        p(''),
        codeLine('$ flutter test test/srs_test.dart'),
        codeLine('00:00 +13: All tests passed!'),

        h2('결과 매트릭스'),
        buildMatrixTable(),
        p('TEST 표시 = flutter test로 자동 검증, 그 외는 코드 정적 검증.', { size: 18, color: '6B7280' }),

        h2('자동 단위 테스트 13건'),
        p('소스: test/srs_test.dart'),
        ...testLog.map((l) => codeLine(l)),

        h2('REQ-16 부분 통과 상세'),
        buildReq16Table(),

        h2('환경 한계로 수동 검증이 필요한 항목'),
        p('자동화 환경에서 실시할 수 없는 항목 — 실기기에서 수동 검증 권장:'),
        buildManualTable(),

        h2('누적 작업 반영'),
        p('본 테스트 시점 기준 구현 완료/수정 사항:'),
        ...accumulated.map((t) => bullet(t)),

        h2('미구현 권장 작업'),
        buildTodoTable(),
      ],
    },
  ],
});

const out = path.join(__dirname, '..', 'TEST_RESULTS.docx');
Packer.toBuffer(doc).then((buf) => {
  fs.writeFileSync(out, buf);
  console.log('Wrote', out);
});

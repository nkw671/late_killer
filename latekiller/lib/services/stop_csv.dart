import 'package:flutter/services.dart' show rootBundle;

/// stopdata.csv (CP949) → 정류소번호로 정류소ID 조회
class StopCsv {
  static final StopCsv _i = StopCsv._();
  factory StopCsv() => _i;
  StopCsv._();

  final Map<int, _StopRow> _byNumber = {};
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    final raw = await rootBundle.loadString('assets/stopdata.csv');
    // 줄단위로 분해(CRLF/LF 둘 다 처리) 후 쉼표 분리
    final lines = raw.split(RegExp(r'\r?\n'));
    for (var i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      final r = line.split(',');
      if (r.length < 4) continue;
      final num = int.tryParse(r[2].trim());
      final id = r[3].trim();
      if (num == null || id.isEmpty) continue;
      _byNumber[num] = _StopRow(num, id, r[1].trim());
    }
    _loaded = true;
  }

  /// 정류소번호 → (id, name)
  ({String stopId, String stopName, int stopNumber})? findByNumber(int number) {
    final r = _byNumber[number];
    if (r == null) return null;
    return (stopId: r.id, stopName: r.name, stopNumber: r.number);
  }
}

class _StopRow {
  final int number;
  final String id;
  final String name;
  _StopRow(this.number, this.id, this.name);
}

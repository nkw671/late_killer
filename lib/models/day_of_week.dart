/// 클래스 다이어그램의 enum DayOfWeek
enum DayOfWeek {
  mon,
  tue,
  wed,
  thu,
  fri,
  sat,
  sun;

  String get labelKo {
    switch (this) {
      case DayOfWeek.mon:
        return '월';
      case DayOfWeek.tue:
        return '화';
      case DayOfWeek.wed:
        return '수';
      case DayOfWeek.thu:
        return '목';
      case DayOfWeek.fri:
        return '금';
      case DayOfWeek.sat:
        return '토';
      case DayOfWeek.sun:
        return '일';
    }
  }

  /// Dart의 DateTime.weekday(1=월 … 7=일) → DayOfWeek
  static DayOfWeek fromDateTime(DateTime dt) {
    return DayOfWeek.values[dt.weekday - 1];
  }
}

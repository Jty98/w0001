/// 경력 문자열 파싱·포맷 유틸.
abstract final class CareerInputUtils {
  static const maxYears = 100;

  /// 서버 검증 상한 (`SERVER_WORKER_RANK_CAREER_GUIDE`).
  static const maxApiYears = 50;

  /// 시작 연도 휠 최솟값 (1900년부터 스크롤 가능).
  static const minStartYear = 1900;

  /// 경력 미입력 시 시작 연도 휠 초기값.
  static const defaultStartYear = 2000;

  /// 피커 0·경력 0년일 때 저장·표시 문자열.
  static const lessThanOneYearLabel = '1년 미만';

  /// API `career` 필드 (`"5년"`, `5`, `"0년"` 등) → UI 표시 문자열.
  static String parseWireField(Object? careerRaw) {
    if (careerRaw is String) return formatForDisplay(careerRaw);
    if (careerRaw is num) return formatYears(careerRaw.toInt());
    return '';
  }

  /// API·저장값 → UI 표시 (`0년` → `1년 미만`, `5` → `5년`).
  static String formatForDisplay(String careerStr) {
    final trimmed = careerStr.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.contains('미만')) return lessThanOneYearLabel;
    return formatYears(parseYears(trimmed));
  }

  /// `"5년"`, `"1년 미만"` 등에서 년수 추출 (0 = 1년 미만).
  static int parseYears(String careerStr) {
    final trimmed = careerStr.trim();
    if (trimmed.isEmpty) return 0;
    if (trimmed.contains('미만')) return 0;
    final match = RegExp(r'(\d+)').firstMatch(trimmed);
    if (match != null) {
      final years = int.tryParse(match.group(1)!) ?? 0;
      return years.clamp(0, maxYears);
    }
    return 0;
  }

  static String formatYears(int years) {
    final clamped = years.clamp(0, maxYears);
    if (clamped == 0) return lessThanOneYearLabel;
    return '$clamped년';
  }

  /// API 전송용 — `"0년"` ~ `"50년"` (`^(\d+)년$` 검증 통과).
  static String formatYearsForApi(int years) {
    final clamped = years.clamp(0, maxApiYears);
    return '${clamped}년';
  }

  /// UI 표시 문자열 → API `career` 필드.
  static String careerForApi(String displayCareer) {
    final trimmed = displayCareer.trim();
    if (trimmed.isEmpty) return '';
    return formatYearsForApi(parseYears(trimmed));
  }

  /// 경력 년수 피커 라벨 (0 → `1년 미만`).
  static String pickerLabelForYears(int years) =>
      years == 0 ? lessThanOneYearLabel : '$years년';

  static int yearsFromStartYear(int startYear, {DateTime? now}) {
    final currentYear = (now ?? DateTime.now()).year;
    return (currentYear - startYear).clamp(0, maxYears);
  }

  static int startYearFromYears(int years, {DateTime? now}) {
    final currentYear = (now ?? DateTime.now()).year;
    return (currentYear - years.clamp(0, maxYears)).clamp(
      minStartYear,
      currentYear,
    );
  }

  /// [careerStr]가 비어 있을 때 피커 초기 상태.
  static ({int years, int startYear}) initialPickerState(String careerStr) {
    if (careerStr.trim().isEmpty) {
      final startYear = defaultStartYear;
      return (
        years: yearsFromStartYear(startYear),
        startYear: startYear,
      );
    }
    final years = parseYears(careerStr);
    return (
      years: years,
      startYear: startYearFromYears(years),
    );
  }

  static int startYearItemCount({DateTime? now}) {
    final currentYear = (now ?? DateTime.now()).year;
    return currentYear - minStartYear + 1;
  }

  static int startYearToIndex(int startYear) =>
      startYear.clamp(minStartYear, DateTime.now().year) - minStartYear;

  static int indexToStartYear(int index) => minStartYear + index;
}

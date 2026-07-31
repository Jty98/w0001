import 'package:flutter/material.dart';
import 'package:w0001/enums.dart';

String formatDateTimeToKorean(DateTime dateTime) {
  return ('${dateTime.year}년 ${dateTime.month}월 ${dateTime.day}일');
}

String formatDateTimeToStringByDot(DateTime dateTime) {
  String month = dateTime.month.toString().padLeft(2, '0');
  String day = dateTime.day.toString().padLeft(2, '0');

  return ('${dateTime.year}.$month.$day');
}

String formatDateTimeToStringByDotWithoutYear(DateTime dateTime) {
  String month = dateTime.month.toString().padLeft(2, '0');
  String day = dateTime.day.toString().padLeft(2, '0');

  return ('$month.$day');
}

String formatDateTimeToStringBySlash(DateTime dateTime) {
  String month = dateTime.month.toString().padLeft(2, '0');
  String day = dateTime.day.toString().padLeft(2, '0');

  return ('${dateTime.year}/$month/$day');
}

String formatDateTimeWeekDayToString(DateTime dateTime) {
  String month = dateTime.month.toString();
  String day = dateTime.day.toString();
  int weekDay = dateTime.weekday;

  return ('${dateTime.year}년 $month월 $day일 ${getWeekDay(weekDay)}요일');
}

String formatDateTimeToIsoDate(DateTime dateTime) {
  final m = dateTime.month.toString().padLeft(2, '0');
  final d = dateTime.day.toString().padLeft(2, '0');
  return '${dateTime.year}-$m-$d';
}

/// API 등에서 온 날짜 문자열을 표시·정렬용 `yyyy-MM-dd` 로 맞춘다.
String normalizeToIsoDateString(String raw) {
  final v = raw.trim();
  if (v.isEmpty) return v;
  final isoPrefix = RegExp(r'^(\d{4}-\d{2}-\d{2})').firstMatch(v);
  if (isoPrefix != null) return isoPrefix.group(1)!;
  final dt = DateTime.tryParse(v);
  if (dt != null) {
    return formatDateTimeToIsoDate(DateTime(dt.year, dt.month, dt.day));
  }
  return v;
}

DateTime parseFlexibleDateString(String value, {DateTime? fallback}) {
  final v = value.trim();
  if (v.isEmpty) return fallback ?? DateTime.now();
  try {
    return DateTime.parse(v);
  } catch (_) {
    final m = RegExp(r'^(\d{4})년\s*(\d{1,2})월\s*(\d{1,2})일').firstMatch(v);
    if (m != null) {
      final y = int.tryParse(m.group(1) ?? '');
      final mo = int.tryParse(m.group(2) ?? '');
      final d = int.tryParse(m.group(3) ?? '');
      if (y != null && mo != null && d != null) {
        return DateTime(y, mo, d);
      }
    }
    return fallback ?? DateTime.now();
  }
}

bool isSameCalendarDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// 현장·인건비 등에서 「전체 기간」 조회에 쓰는 고정 범위(2000-01-01 ~ 2099-12-31).
bool isFullPeriodDateRange(DateTimeRange range) {
  return isSameCalendarDay(range.start, DateTime(2000, 1, 1)) &&
      isSameCalendarDay(range.end, DateTime(2099, 12, 31));
}

bool isFullYearDateRange(DateTimeRange range) {
  final s = range.start;
  final e = range.end;
  return s.year == e.year &&
      s.month == 1 &&
      s.day == 1 &&
      e.month == 12 &&
      e.day == 31;
}

DateTimeRange getYearDateRange(int year) {
  return DateTimeRange(
    start: DateTime(year, 1, 1),
    end: DateTime(year, 12, 31),
  );
}

String formatDateTimeRangeToString(
  DateTimeRange dateTimeRange, {
  bool showYear = true,
  DayTpye? periodType,
}) {
  final start = dateTimeRange.start;
  final end = dateTimeRange.end;

  if (periodType == DayTpye.whole || isFullPeriodDateRange(dateTimeRange)) {
    return '전체 기간';
  }

  if (periodType == DayTpye.year || isFullYearDateRange(dateTimeRange)) {
    return '${start.year}년';
  }

  // 시작 날짜가 해당 달의 첫째 날인지, 끝 날짜가 해당 달의 마지막 날인지 확인
  bool isFullMonth = (start.day == 1 &&
      end.year == start.year &&
      end.month == start.month &&
      end.day == DateTime(start.year, start.month + 1, 0).day);

  if (isFullMonth) {
    // "2024년 6월 전체" 형식으로 반환
    return showYear ? '${start.year}년 ${start.month}월' : '${start.month}월';
  } else {
    // 범위를 "yyyy.MM.dd ~ yyyy.MM.dd" 형식으로 반환
    final startText = showYear
        ? formatDateTimeToStringByDot(start)
        : formatDateTimeToStringByDotWithoutYear(start);
    final endText = showYear
        ? formatDateTimeToStringByDot(end)
        : formatDateTimeToStringByDotWithoutYear(end);
    return '$startText ~ $endText';
  }
}

String formatDuration(String start, String end) {
  String startDate = formatDateTimeToStringByDot(DateTime.parse(start));
  String endDate =
      end == '0' ? '' : formatDateTimeToStringByDot(DateTime.parse(end));

  return '$startDate ~ $endDate';
}

String getWeekDay(int index) {
  switch (index) {
    case 1:
      return '월';
    case 2:
      return '화';
    case 3:
      return '수';
    case 4:
      return '목';
    case 5:
      return '금';
    case 6:
      return '토';
    case 7:
      return '일';
    default:
      return '';
  }
}

/// 편집 필드용: 천 단위 콤마만 (`원` 없음).
String formatIntegerWithComma(int value) {
  final isNegative = value < 0;
  final numberString = value.abs().toString();
  final length = numberString.length;
  var formattedString = '';
  for (var i = length - 1; i >= 0; i--) {
    formattedString = numberString[i] + formattedString;
    if ((length - i) % 3 == 0 && i != 0) {
      formattedString = ',$formattedString';
    }
  }
  if (isNegative) {
    formattedString = '-$formattedString';
  }
  return formattedString;
}

/// 인건비·근로 현황 표시용 — [isTaxApply] true면 3.3% 원천징수 후 실수령(×0.967).
int applyIncomeTaxNet(int grossAmount, {required bool isTaxApply}) {
  if (!isTaxApply) return grossAmount;
  return (grossAmount * 0.967).toInt();
}

String getPrice({required int price, bool? isTaxApply, bool? isContainWon}) {
  final price2 = applyIncomeTaxNet(
    price,
    isTaxApply: isTaxApply == true,
  );

  // 음수 여부 체크
  bool isNegative = price2 < 0;

  // 절대값으로 변환
  String numberString = price2.abs().toString();

  int length = numberString.length;

  String formattedString = '';

  for (int i = length - 1; i >= 0; i--) {
    formattedString = numberString[i] + formattedString;
    if ((length - i) % 3 == 0 && i != 0) {
      formattedString = ',$formattedString';
    }
  }

  // 음수일 경우 부호 추가
  if (isNegative) {
    formattedString = '-$formattedString';
  }

  // 원 표시 여부
  if (isContainWon == null || isContainWon) {
    formattedString += '원';
  }

  return formattedString;
}

/// 좁은 UI용 원화 축약 — 억·만·천·백 조합 (소수점 없음).
///
/// 길이에 따라 자릿수를 줄인다 (정확한 값은 [getPrice]·Tooltip).
/// * **1억 미만 · 1천만 미만** — `63만 5천원` (만 + 천·백)
/// * **1천만 이상 · 1억 미만** — `1,234만원` (만까지만)
/// * **1억 이상** — `1억 2,345만원` (억·만까지만, `1억 5천원` 예외)
String formatCompactKrw(int price, {bool includeWon = true}) {
  final suffix = includeWon ? '원' : '';
  final negative = price < 0;
  final n = price.abs();
  final sign = negative ? '-' : '';

  String comma(int v) => getPrice(price: v, isContainWon: false);

  if (n < 1000) {
    return '$sign${comma(n)}$suffix';
  }
  if (n < 10000) {
    final underMan = _formatKrwUnderMan(n);
    return underMan.isEmpty
        ? '$sign${comma(n)}$suffix'
        : '$sign$underMan$suffix';
  }

  // 1억 이상 — 억·만 (만 미만은 억 단위만 있을 때만 천·백 표시)
  if (n >= 100000000) {
    final parts = <String>['${comma(n ~/ 100000000)}억'];
    var rest = n % 100000000;
    if (rest >= 10000) {
      parts.add('${comma(rest ~/ 10000)}만');
      rest %= 10000;
    }
    if (rest > 0) {
      parts.add(_formatKrwUnderMan(rest));
    }
    return '$sign${parts.join(' ')}$suffix';
  }

  // 1천만 이상 — 만 단위까지만 (칸 너비 절약)
  if (n >= 10000000) {
    return '$sign${comma(n ~/ 10000)}만$suffix';
  }

  // 1천만 미만 — 만 + 천·백
  final parts = <String>['${comma(n ~/ 10000)}만'];
  final rest = n % 10000;
  if (rest > 0) {
    parts.add(_formatKrwUnderMan(rest));
  }
  return '$sign${parts.join(' ')}$suffix';
}

/// 1만 원 미만 — `5천`, `5천 5백`, `5,678` 등 한국어 단위 조합.
String _formatKrwUnderMan(int amount) {
  if (amount <= 0) return '';

  final parts = <String>[];
  var rest = amount;

  final cheon = rest ~/ 1000;
  if (cheon > 0) {
    parts.add('$cheon천');
    rest %= 1000;
  }
  if (rest <= 0) return parts.join(' ');

  if (rest >= 100 && rest % 100 == 0) {
    parts.add('${rest ~/ 100}백');
    return parts.join(' ');
  }

  parts.add(getPrice(price: rest, isContainWon: false));
  return parts.join(' ');
}

/// 인건비 지급 완료 일시 표시 (`wcompleted_at` ISO 문자열).
String formatWorkCostCompletedAt(String completedAt) {
  try {
    final dt = DateTime.parse(completedAt).toLocal();
    final y = dt.year % 100;
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final mi = dt.minute.toString().padLeft(2, '0');
    return '$y.$m.$d $h시$mi분';
  } catch (_) {
    return completedAt;
  }
}

String formatWorkCostWorkDate(String raw) {
  final ymd = normalizeToIsoDateString(raw);
  final parsed = DateTime.tryParse(ymd);
  if (parsed == null) return raw;
  final local = parsed.toLocal();
  final y = local.year % 100;
  return '${y.toString().padLeft(2, '0')}.'
      '${local.month.toString().padLeft(2, '0')}.'
      '${local.day.toString().padLeft(2, '0')}';
}

DateTimeRange getMonthDateRange(DateTime now) {
  final startOfMonth = DateTime(now.year, now.month, 1);
  final endOfMonth = (startOfMonth.month < 12)
      ? DateTime(now.year, now.month + 1, 1).subtract(const Duration(days: 1))
      : DateTime(now.year + 1, 1, 1).subtract(const Duration(days: 1));

  return DateTimeRange(
    start: startOfMonth,
    end: endOfMonth,
  );
}

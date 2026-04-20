import 'package:flutter/material.dart';

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

String formatDateTimeRangeToString(
  DateTimeRange dateTimeRange, {
  bool showYear = true,
} ) {
  final start = dateTimeRange.start;
  final end = dateTimeRange.end;

  // 시작 날짜가 해당 달의 첫째 날인지, 끝 날짜가 해당 달의 마지막 날인지 확인
  bool isFullMonth = (start.day == 1 && 
                      end.year == start.year && 
                      end.month == start.month &&
                      end.day == DateTime(start.year, start.month + 1, 0).day);

  if (isFullMonth) {
    // "2024년 6월 전체" 형식으로 반환
    return showYear ? '${start.year}년 ${start.month}월' : '${start.month}월';
  } else if(dateTimeRange.toString() == '2000-01-01 00:00:00.000 - 2099-12-31 00:00:00.000'){
    return '전체 기간';
  }else {
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

String getPrice({required int price, bool? isTaxApply, bool? isContainWon}) {
  // 세금 적용 여부에 따라 가격 계산
  int price2 = (isTaxApply == null || isTaxApply == false)
      ? price
      : (price * 0.967).toInt();

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

DateTimeRange getMonthDateRange(DateTime now) {
  final startOfMonth = DateTime(now.year, now.month, 1);
  final endOfMonth = (startOfMonth.month < 12)
      ? DateTime(now.year, now.month + 1, 1)
          .subtract(const Duration(days: 1))
      : DateTime(now.year + 1, 1, 1).subtract(const Duration(days: 1));

  return DateTimeRange(
    start: startOfMonth,
    end: endOfMonth,
  );
}

import 'package:flutter/material.dart';

/// 캘린더에 표시할 이벤트 모델
class CalendarEvent {
  /// 이벤트 시작일
  final DateTime startDate;

  /// 이벤트 종료일
  final DateTime endDate;

  /// 이벤트 ID (선택사항, 데이터베이스와 매핑용)
  final String? id;

  /// 이벤트 제목 (선택사항)
  final String? title;

  /// 이벤트 색상 (선택사항, 기본값은 CalendarStyle 사용)
  final Color? color;

  CalendarEvent({
    required this.startDate,
    required this.endDate,
    this.id,
    this.title,
    this.color,
  }) {
    assert(
      !endDate.isBefore(startDate),
      'endDate must be after or equal to startDate',
    );
  }

  /// 날짜만 비교하는 헬퍼 함수
  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  /// 날짜가 이 이벤트 범위에 포함되는지 확인
  bool containsDate(DateTime date) {
    final dateOnly = DateTime(date.year, date.month, date.day);
    final startOnly = DateTime(startDate.year, startDate.month, startDate.day);
    final endOnly = DateTime(endDate.year, endDate.month, endDate.day);
    return (_isSameDay(dateOnly, startOnly) || dateOnly.isAfter(startOnly)) &&
           (_isSameDay(dateOnly, endOnly) || dateOnly.isBefore(endOnly));
  }

  /// 날짜가 이벤트의 시작일인지 확인
  bool isStartDate(DateTime date) {
    return _isSameDay(startDate, date);
  }

  /// 날짜가 이벤트의 종료일인지 확인
  bool isEndDate(DateTime date) {
    return _isSameDay(endDate, date);
  }
}

import 'package:flutter/material.dart';

/// 달력 전체 스타일 옵션
class CalendarStyle {
  /// 포커스된(현재) 달 카드 배경/테두리
  final Color focusedMonthBackgroundColor;
  final Color focusedMonthBorderColor;

  /// 포커스 테두리 색 (카드 테두리 전용)
  /// - 기존에는 [focusedMonthBorderColor]가 테두리/헤더/버튼 강조색을 모두 담당했는데,
  ///   용도를 분리해서 모드별/상태별 스타일 결합을 줄입니다.
  final Color focusBorderColor;

  /// 헤더/버튼 강조색 (화살표/뷰모드 버튼 등)
  final Color headerAccentColor;

  /// 달 카드 모서리
  final BorderRadius calendarBorderRadius;

  /// 헤더(년도/월) 텍스트 스타일
  final TextStyle headerTextStyle;

  /// 요일 텍스트 스타일
  final TextStyle weekdayTextStyle;
  final Color weekdaySundayTextColor;
  final Color weekdaySaturdayTextColor;

  /// 일반 날짜/선택된 날짜 배경색
  final Color dayBackgroundColor;
  final Color selectedDayBackgroundColor;

  /// 일반 날짜/선택된 날짜 텍스트 스타일
  final TextStyle dayTextStyle;
  final Color daySundayTextColor;
  final Color daySaturdayTextColor;
  final TextStyle selectedDayTextStyle;

  /// 오늘 날짜 스타일
  final TextStyle todayTextStyle;
  final Color todayBorderColor;
  final double todayBorderWidth;

  /// 이벤트 기간 내 날짜 배경색
  final Color eventRangeBackgroundColor;

  /// 이벤트 시작일/종료일 배경색
  final Color eventStartEndBackgroundColor;

  /// 이벤트 시작일/종료일 텍스트 스타일
  final TextStyle eventStartEndTextStyle;

  /// 겹치는 이벤트를 표시할 색상 리스트 (최대 10개)
  final List<Color> eventColors;

  /// 이벤트 저장 버튼 스타일
  final TextStyle eventSaveButtonTextStyle;

  /// 이벤트 저장 버튼 색상
  final Color eventSaveButtonColor;

  /// 이벤트 저장 버튼 테두리 색상
  final Color eventSaveButtonBorderColor;

  /// 이벤트 저장 버튼 테두리 두께
  final double eventSaveButtonBorderWidth;

  const CalendarStyle({
    // Default palette: modern indigo + neutral selection.
    // - Range(start/end): indigo
    // - Selected day: neutral dark to distinguish from range boundaries
    // - Range fill: indigo tint
    this.focusedMonthBackgroundColor = const Color(0x0A2563EB),
    this.focusedMonthBorderColor = const Color(0xFF2563EB),
    this.focusBorderColor = const Color(0xFF2563EB),
    this.headerAccentColor = const Color(0xFF2563EB),
    this.calendarBorderRadius = const BorderRadius.all(Radius.circular(12)),
    this.headerTextStyle = const TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.bold,
      color: Colors.black,
    ),
    this.weekdayTextStyle = const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.bold,
      color: Colors.grey,
    ),
    this.weekdaySundayTextColor = const Color(0xFFD14343),
    this.weekdaySaturdayTextColor = const Color(0xFF2B66D9),
    this.dayBackgroundColor = Colors.transparent,
    this.selectedDayBackgroundColor = const Color(0xFF111827),
    this.dayTextStyle = const TextStyle(
      color: Colors.black,
      fontWeight: FontWeight.bold,
    ),
    this.daySundayTextColor = const Color(0xFFD14343),
    this.daySaturdayTextColor = const Color(0xFF2B66D9),
    this.selectedDayTextStyle = const TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.bold,
    ),
    this.todayTextStyle = const TextStyle(
      color: Color(0xFF1D4ED8),
      fontWeight: FontWeight.w800,
    ),
    this.todayBorderColor = const Color(0xFF1D4ED8),
    this.todayBorderWidth = 1.4,
    this.eventRangeBackgroundColor = const Color(0x332563EB),
    this.eventStartEndBackgroundColor = const Color(0xFF2563EB),
    this.eventStartEndTextStyle = const TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.bold,
    ),
    this.eventColors = const [
      Color(0xFF2563EB), // Indigo
      Color(0xFF16A34A), // Green
      Color(0xFFF59E0B), // Amber
      Color(0xFF7C3AED), // Violet
      Color(0xFFEF4444), // Red
      Color(0xFF06B6D4), // Cyan
      Color(0xFFDB2777), // Pink
      Color(0xFF0EA5E9), // Sky
      Color(0xFF22C55E), // Emerald
      Color(0xFFF97316), // Orange
    ],
    this.eventSaveButtonTextStyle = const TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.bold,
    ),
    this.eventSaveButtonColor = const Color(0xFF2563EB),
    this.eventSaveButtonBorderColor = const Color(0xFF2563EB),
    this.eventSaveButtonBorderWidth = 1,
  });
}

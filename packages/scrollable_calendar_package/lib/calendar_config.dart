import 'package:scrollable_calendar_package/calendar_event.dart';

enum CalendarPageScrollDirection { vertical, horizontal }
enum CalendarSelectionMode { none, single, range }

/// 달력 동작/레이아웃 관련 설정 값 + 유틸 함수
class CalendarConfig {
  /// 기준 연도 기준으로 ±몇 년까지 보여줄지
  final int yearRange;

  /// 화면 높이 대비 한 달 캘린더가 차지할 비율 (0~1)
  final double calendarHeightFactor;

  /// 처음 진입 시 포커스를 맞출 날짜
  final DateTime initialDate;

  /// 날짜 선택 동작 모드
  /// - none: 선택 비활성화 (뷰어)
  /// - single: 단일 날짜 선택
  /// - range: 기간 선택
  final CalendarSelectionMode selectionMode;

  /// 월 페이지 스크롤 방향
  final CalendarPageScrollDirection pageScrollDirection;

  /// 헤더의 이전/다음 월 화살표 표시 여부
  final bool showMonthArrowButtons;

  /// 초기 이벤트 시작일 (외부에서 기존 이벤트 데이터를 불러올 때 사용)
  /// @deprecated Use [initialEvents] instead for multiple events support
  final DateTime? initialEventStartDate;

  /// 초기 이벤트 종료일 (외부에서 기존 이벤트 데이터를 불러올 때 사용)
  /// @deprecated Use [initialEvents] instead for multiple events support
  final DateTime? initialEventEndDate;

  /// 등록된 이벤트 리스트 (데이터베이스에서 불러온 다수의 이벤트)
  final List<CalendarEvent> initialEvents;

  /// true면 헤더 탭 시 캘린더 영역 대신 고정 크기 다이얼로그로 년·월을 선택합니다.
  final bool yearMonthPickerUsesDialog;

  const CalendarConfig({
    this.yearRange = 5,
    this.calendarHeightFactor = 0.5,
    required this.initialDate,
    this.selectionMode = CalendarSelectionMode.single,
    this.pageScrollDirection = CalendarPageScrollDirection.vertical,
    this.showMonthArrowButtons = false,
    this.initialEventStartDate,
    this.initialEventEndDate,
    this.initialEvents = const [],
    this.yearMonthPickerUsesDialog = false,
  });

  /// yearRange와 initialDate를 기준으로 달 리스트와 초기 페이지 인덱스를 생성하는 헬퍼
  CalendarGeneratedData generate() {
    final baseYear = initialDate.year;
    final months = <DateTime>[];

    for (int year = baseYear - yearRange; year <= baseYear + yearRange; year++) {
      for (int month = 1; month <= 12; month++) {
        months.add(DateTime(year, month, 1));
      }
    }

    final initialPage = months.indexWhere(
      (m) => m.year == initialDate.year && m.month == initialDate.month,
    );

    return CalendarGeneratedData(
      months: months,
      initialPage: initialPage >= 0 ? initialPage : 0,
    );
  }
}

/// CalendarConfig.generate()가 반환하는 결과 데이터
class CalendarGeneratedData {
  final List<DateTime> months;
  final int initialPage;

  const CalendarGeneratedData({
    required this.months,
    required this.initialPage,
  });
}




/*
  생각을 정리하기

  1. 상위 위젯에서 인자로 받을 것들
    - 최소 년도, 최대 년도, 현재일, 선택일, 선택된 날짜범위 (시작일, 종료일)

  2. 캘린더 위젯에서 필요한 것들
    - 캘린더 헤더 (년도, 월)
      - 년도 클릭시 년도가 뜨고, 누르면 해당 년도로 변경
      - 월 클릭시 해당 년도의 월별 캘린더가 작게 뜨고, 누르면 해당 월로 변경
    - 캘린더 바디 (날짜)
      - 날짜 범위 지정 가능
      - 지정된 범위에 이벤트 표시 가능
      - 공휴일 표시 가능
    
  3. 캘린더 방식
    - 캘린더의 달은 스크롤뷰로 구현해서 저번달, 이번달, 다음달 캘린더가 모두 보여야함
*/

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:scrollable_calendar_package/calendar_config.dart';
import 'package:scrollable_calendar_package/calendar_style.dart';
import 'package:scrollable_calendar_package/calendar_event.dart';

enum CalendarViewMode { month, oneWeek, twoWeeks }

Color _weekdayHeaderColor(CalendarStyle style, int weekdayIndex) {
  if (weekdayIndex == 0) return style.weekdaySundayTextColor;
  if (weekdayIndex == 6) return style.weekdaySaturdayTextColor;
  return style.weekdayTextStyle.color ?? Colors.grey;
}

Color _dayNumberBaseColor(CalendarStyle style, DateTime date) {
  if (date.weekday == DateTime.sunday) return style.daySundayTextColor;
  if (date.weekday == DateTime.saturday) return style.daySaturdayTextColor;
  return style.dayTextStyle.color ?? Colors.black;
}

/// 1주/2주 줄의 포함 기간 기준 헤더(같은 달이면 `2026년 5월`, 월 넘김이면 범위).
String calendarWeekStripTitle(DateTime rangeStart, DateTime rangeEnd) {
  final y1 = rangeStart.year;
  final m1 = rangeStart.month;
  final y2 = rangeEnd.year;
  final m2 = rangeEnd.month;
  if (y1 == y2 && m1 == m2) return '$y1년 $m1월';
  if (y1 == y2) return '$y1년 $m1월–$m2월';
  return '$y1년 $m1월–$y2년 $m2월';
}

/// 내부 구현용 위젯 (패키지 사용자에게는 노출되지 않음)
/// StatelessWidget으로 유지하여 패키지 설계 원칙 준수
class BuildCalendarWidget extends StatelessWidget {
  const BuildCalendarWidget({
    super.key,
    required this.year,
    required this.month,
    this.isFocused = false,
    required this.pageIndex,
    required this.currentPage,
    this.selectedDate,
    this.eventStartDate,
    this.eventEndDate,
    this.registeredEvents = const [],
    this.selectionMode = CalendarSelectionMode.single,
    this.showMonthArrowButtons = false,
    this.onTap,
    this.onDaySelected,
    this.onYearHeaderTap,
    this.onPreviousMonthTap,
    this.onNextMonthTap,
    this.viewMode = CalendarViewMode.month,
    this.onViewModeSelected,
    this.onViewModeButtonTap,
    this.viewModeButtonLabel = '1주',
    this.viewModeButtonIcon = Icons.view_week_outlined,
    this.style = const CalendarStyle(),
  });

  final int year;
  final int month;
  final bool isFocused;
  final int pageIndex; // 이 위젯이 나타내는 달의 인덱스
  final int currentPage; // 현재 포커스된 달의 인덱스
  final DateTime? selectedDate; // 선택된 날짜 (외부에서 주입)
  final DateTime? eventStartDate; // 이벤트 시작일 (편집 중인 이벤트)
  final DateTime? eventEndDate; // 이벤트 종료일 (편집 중인 이벤트)
  final List<CalendarEvent> registeredEvents; // 등록된 이벤트 리스트
  final CalendarSelectionMode selectionMode; // 날짜 선택 모드
  final bool showMonthArrowButtons; // 월 이동 화살표 표시 여부
  final VoidCallback? onTap; // 탭했을 때 호출될 콜백
  final void Function(int year, int month, int day)?
  onDaySelected; // 날짜 클릭 시 호출될 콜백
  final void Function(int year, int month)? onYearHeaderTap; // 헤더 클릭 시 호출될 콜백
  final VoidCallback? onPreviousMonthTap;
  final VoidCallback? onNextMonthTap;
  final CalendarViewMode viewMode;
  final void Function(CalendarViewMode mode)? onViewModeSelected;
  final VoidCallback? onViewModeButtonTap;
  final String viewModeButtonLabel;
  final IconData viewModeButtonIcon;
  final CalendarStyle style;

  @override
  Widget build(BuildContext context) {
    // 이 위젯이 표현할 년/월
    final DateTime currentYear = DateTime(year);
    final DateTime currentMonth = DateTime(year, month);

    final DateTime firstDayOfMonth = DateTime(year, month, 1);
    final int daysInMonth = DateTime(year, month + 1, 0).day;
    final int firstWeekday = firstDayOfMonth.weekday % 7;
    final int totalCells = firstWeekday + daysInMonth;

    // 이벤트를 날짜별로 미리 그룹화하여 성능 최적화
    // Map<날짜키, 이벤트리스트> 형태로 저장하여 O(1) 접근
    final eventsByDate = <String, List<CalendarEvent>>{};
    for (final event in registeredEvents) {
      // 이 이벤트가 이 달에 포함되는지 확인
      final eventStart = DateTime(event.startDate.year, event.startDate.month, event.startDate.day);
      final eventEnd = DateTime(event.endDate.year, event.endDate.month, event.endDate.day);
      final monthStart = DateTime(year, month, 1);
      final monthEnd = DateTime(year, month + 1, 0);

      // 이벤트가 이 달과 겹치는지 확인
      if (eventEnd.isBefore(monthStart) || eventStart.isAfter(monthEnd)) {
        continue; // 이 달과 겹치지 않으면 스킵
      }

      // 이벤트 범위 내의 각 날짜에 이벤트 추가
      var current = eventStart.isBefore(monthStart) ? monthStart : eventStart;
      final end = eventEnd.isAfter(monthEnd) ? monthEnd : eventEnd;

      while (!current.isAfter(end)) {
        final dateKey = '${current.year}-${current.month}-${current.day}';
        eventsByDate.putIfAbsent(dateKey, () => []).add(event);
        current = current.add(const Duration(days: 1));
      }
    }

    return GestureDetector(
      onTap: () {
        // 현재 포커스된 달이 아니면, 이 달로 스크롤 이동
        if (pageIndex != currentPage && onTap != null) {
          onTap!();
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: isFocused
              ? style.focusedMonthBackgroundColor
              : Colors.transparent,
          borderRadius: style.calendarBorderRadius,
          // 현장 등록 다이얼로그 UX에서는 "포커스 테두리"가 과하게 보여서 제거.
          // (버튼/아이콘 색상은 headerAccentColor를 사용하므로 투명으로 만들지 말 것)
          border: null,
        ),
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 5),
        margin: const EdgeInsets.symmetric(vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCalnderHeader(
              currentYear.year,
              currentMonth.month,
              isFocused: isFocused,
              onTap: onYearHeaderTap != null
                  ? () => onYearHeaderTap!(currentYear.year, currentMonth.month)
                  : null,
              showMonthArrowButtons: showMonthArrowButtons,
              onPreviousMonthTap: onPreviousMonthTap,
              onNextMonthTap: onNextMonthTap,
              activeViewMode: viewMode,
              onViewModeSelected: onViewModeSelected,
              onViewModeButtonTap: onViewModeButtonTap,
              viewModeButtonLabel: viewModeButtonLabel,
              viewModeButtonIcon: viewModeButtonIcon,
            style: style,
          ),
          SizedBox(
            height: 8 / MediaQuery.textScaleFactorOf(context).clamp(1.0, 1.2),
          ),
          buildCalendarBody(
              context,
              totalCells,
              firstWeekday,
              currentMonth,
              currentYear,
              selectedDate: selectedDate,
              eventStartDate: eventStartDate,
              eventEndDate: eventEndDate,
              eventsByDate: eventsByDate,
              selectionMode: selectionMode,
              onDaySelected: onDaySelected,
              viewMode: viewMode,
              style: style,
            ),
          ],
        ),
      ),
    );
  }
}

/// 주/2주 모드 전용 위젯 (월 그리드 row 자르기 방식 사용 X)
class BuildWeekWidget extends StatelessWidget {
  const BuildWeekWidget({
    super.key,
    required this.startDate,
    required this.days,
    this.isFocused = false,
    required this.pageIndex,
    required this.currentPage,
    this.selectedDate,
    this.eventStartDate,
    this.eventEndDate,
    this.registeredEvents = const [],
    this.selectionMode = CalendarSelectionMode.single,
    this.showMonthArrowButtons = false,
    this.onTap,
    this.onDaySelected,
    this.onYearHeaderTap,
    this.onPreviousPageTap,
    this.onNextPageTap,
    this.viewMode = CalendarViewMode.oneWeek,
    this.onViewModeSelected,
    this.onViewModeButtonTap,
    this.viewModeButtonLabel = '2주 보기',
    this.viewModeButtonIcon = Icons.calendar_view_week_outlined,
    this.style = const CalendarStyle(),
  });

  final DateTime startDate; // 페이지 시작 날짜(주 시작일)
  final int days; // 7 or 14
  final bool isFocused;
  final int pageIndex;
  final int currentPage;
  final DateTime? selectedDate;
  final DateTime? eventStartDate;
  final DateTime? eventEndDate;
  final List<CalendarEvent> registeredEvents;
  final CalendarSelectionMode selectionMode;
  final bool showMonthArrowButtons;
  final VoidCallback? onTap;
  final void Function(int year, int month, int day)? onDaySelected;
  final void Function(int year, int month)? onYearHeaderTap;
  final VoidCallback? onPreviousPageTap;
  final VoidCallback? onNextPageTap;
  final CalendarViewMode viewMode;
  final void Function(CalendarViewMode mode)? onViewModeSelected;
  final VoidCallback? onViewModeButtonTap;
  final String viewModeButtonLabel;
  final IconData viewModeButtonIcon;
  final CalendarStyle style;

  @override
  Widget build(BuildContext context) {
    final rangeStart = DateTime(startDate.year, startDate.month, startDate.day);
    final rangeEnd = rangeStart.add(Duration(days: days - 1));

    // 헤더에 표시할 "대표" 월/년
    // - 기존: startDate(주 시작일) 기준 → 4/7이 포함된 2주라도 3월로 표시될 수 있음
    // - 개선: 선택된 날짜가 현재 페이지(range) 안에 있으면 그 날짜의 월/년을 표시
    //         없으면 rangeStart를 기본으로 사용
    final selected = selectedDate == null
        ? null
        : DateTime(selectedDate!.year, selectedDate!.month, selectedDate!.day);
    final repBase = (selected != null && !_isDateInRange(selected, rangeStart, rangeEnd))
        ? rangeStart
        : (selected ?? rangeStart);
    final repYear = repBase.year;
    final repMonth = repBase.month;

    // 이벤트를 날짜별로 미리 그룹화
    final eventsByDate = <String, List<CalendarEvent>>{};
    for (final event in registeredEvents) {
      final eventStart = DateTime(
        event.startDate.year,
        event.startDate.month,
        event.startDate.day,
      );
      final eventEnd = DateTime(
        event.endDate.year,
        event.endDate.month,
        event.endDate.day,
      );

      if (eventEnd.isBefore(rangeStart) || eventStart.isAfter(rangeEnd)) {
        continue;
      }

      var current = eventStart.isBefore(rangeStart) ? rangeStart : eventStart;
      final end = eventEnd.isAfter(rangeEnd) ? rangeEnd : eventEnd;
      while (!current.isAfter(end)) {
        final dateKey = '${current.year}-${current.month}-${current.day}';
        eventsByDate.putIfAbsent(dateKey, () => []).add(event);
        current = current.add(const Duration(days: 1));
      }
    }

    return GestureDetector(
      onTap: () {
        if (pageIndex != currentPage && onTap != null) {
          onTap!();
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: isFocused ? style.focusedMonthBackgroundColor : Colors.transparent,
          borderRadius: style.calendarBorderRadius,
          // 주/2주 모드에서도 "포커스 테두리"는 제거하여 모드별 UI 일관성 유지
          border: null,
        ),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 5),
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCalnderHeader(
              repYear,
              repMonth,
              titleTextOverride: calendarWeekStripTitle(rangeStart, rangeEnd),
              isFocused: isFocused,
              onTap: onYearHeaderTap != null ? () => onYearHeaderTap!(repYear, repMonth) : null,
              showMonthArrowButtons: showMonthArrowButtons,
              onPreviousMonthTap: onPreviousPageTap,
              onNextMonthTap: onNextPageTap,
              activeViewMode: viewMode,
              onViewModeSelected: onViewModeSelected,
              onViewModeButtonTap: onViewModeButtonTap,
              viewModeButtonLabel: viewModeButtonLabel,
              viewModeButtonIcon: viewModeButtonIcon,
            style: style,
          ),
          SizedBox(
            height: 12 / MediaQuery.textScaleFactorOf(context).clamp(1.0, 1.2),
          ),
          buildWeekBody(
              context,
              rangeStart,
              days: days,
              selectedDate: selectedDate,
              eventStartDate: eventStartDate,
              eventEndDate: eventEndDate,
              eventsByDate: eventsByDate,
              selectionMode: selectionMode,
              onDaySelected: onDaySelected,
              representativeMonth: repMonth,
              style: style,
            ),
          ],
        ),
      ),
    );
  }
}

Widget _buildViewModeSegmentBar({
  required CalendarViewMode activeViewMode,
  required void Function(CalendarViewMode mode) onSelected,
}) {
  const segmentPadding = EdgeInsets.symmetric(horizontal: 10, vertical: 8);
  const segmentTextStyle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
  );

  return SizedBox(
    width: double.infinity,
    child: CupertinoSlidingSegmentedControl<CalendarViewMode>(
      groupValue: activeViewMode,
      padding: const EdgeInsets.all(3),
      children: const {
        CalendarViewMode.oneWeek: Padding(
          padding: segmentPadding,
          child: Text('1주', style: segmentTextStyle),
        ),
        CalendarViewMode.twoWeeks: Padding(
          padding: segmentPadding,
          child: Text('2주', style: segmentTextStyle),
        ),
        CalendarViewMode.month: Padding(
          padding: segmentPadding,
          child: Text('월별', style: segmentTextStyle),
        ),
      },
      onValueChanged: (mode) {
        if (mode != null) onSelected(mode);
      },
    ),
  );
}

Widget _buildCalnderHeader(
  int currentYear,
  int currentMonth, {
  /// null이 아니면 [currentYear]/[currentMonth] 대신 한 줄 제목으로 표시(주/2주 줄).
  String? titleTextOverride,
  bool isFocused = false,
  VoidCallback? onTap,
  bool showMonthArrowButtons = false,
  VoidCallback? onPreviousMonthTap,
  VoidCallback? onNextMonthTap,
  CalendarViewMode? activeViewMode,
  void Function(CalendarViewMode mode)? onViewModeSelected,
  VoidCallback? onViewModeButtonTap,
  String viewModeButtonLabel = '1주',
  IconData viewModeButtonIcon = Icons.view_week_outlined,
  required CalendarStyle style,
}) {
  List<String> daysOfWeek = ['일', '월', '화', '수', '목', '금', '토'];
  final useViewModeSegment =
      onViewModeSelected != null && activeViewMode != null;
  final hasLegacyViewModeButton =
      !useViewModeSegment && onViewModeButtonTap != null;

  final titleStyle = style.headerTextStyle.copyWith(
    fontSize: (style.headerTextStyle.fontSize ?? 24) *
        (useViewModeSegment || hasLegacyViewModeButton ? 0.72 : 1.0),
  );

  final titleContent = titleTextOverride != null
      ? Text(
          titleTextOverride,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: titleStyle.copyWith(color: style.headerTextStyle.color),
        )
      : Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$currentYear년 ',
              style: titleStyle.copyWith(color: style.headerTextStyle.color),
            ),
            Text(
              '$currentMonth월',
              style: titleStyle.copyWith(color: style.headerTextStyle.color),
            ),
          ],
        );

  final titleRow = Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      if (showMonthArrowButtons)
        IconButton(
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          onPressed: onPreviousMonthTap,
          icon: const Icon(Icons.chevron_left, size: 22),
          color: style.headerAccentColor,
        ),
      Expanded(
        child: GestureDetector(
          onTap: isFocused && onTap != null ? onTap : null,
          child: titleContent,
        ),
      ),
      if (showMonthArrowButtons)
        IconButton(
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          onPressed: onNextMonthTap,
          icon: const Icon(Icons.chevron_right, size: 22),
          color: style.headerAccentColor,
        ),
    ],
  );

  return Column(
    children: [
      if (useViewModeSegment || hasLegacyViewModeButton) ...[
        titleRow,
        const SizedBox(height: 8),
        if (useViewModeSegment)
          _buildViewModeSegmentBar(
            activeViewMode: activeViewMode,
            onSelected: onViewModeSelected,
          )
        else
          Align(
            alignment: Alignment.centerRight,
            child: Material(
              color: style.headerAccentColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: onViewModeButtonTap,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: style.headerAccentColor,
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        viewModeButtonIcon,
                        size: 14,
                        color: style.headerAccentColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        viewModeButtonLabel,
                        style: style.weekdayTextStyle.copyWith(
                          color: style.headerAccentColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ] else
        titleRow,
      const SizedBox(height: 10),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (var i = 0; i < daysOfWeek.length; i++)
            Text(
              daysOfWeek[i],
              style: style.weekdayTextStyle.copyWith(
                color: _weekdayHeaderColor(style, i),
              ),
            ),
        ],
      ),
    ],
  );
}

Widget buildCalendarBody(
  BuildContext context,
  int totalCells,
  int firstWeekday,
  DateTime currentMonth,
  DateTime currentYear, {
  DateTime? selectedDate,
  DateTime? eventStartDate,
  DateTime? eventEndDate,
  Map<String, List<CalendarEvent>> eventsByDate = const {},
  CalendarSelectionMode selectionMode = CalendarSelectionMode.single,
  void Function(int year, int month, int day)? onDaySelected,
  CalendarViewMode viewMode = CalendarViewMode.month,
  required CalendarStyle style,
}) {
  final firstDayOfCurrentMonth = DateTime(currentYear.year, currentMonth.month, 1);
  final selectedCellIndex = (selectedDate != null &&
          selectedDate.year == currentYear.year &&
          selectedDate.month == currentMonth.month)
      ? firstWeekday + selectedDate.day - 1
      : firstWeekday;
  final selectedWeekIndex = selectedCellIndex ~/ 7;
  final weekCount = (totalCells / 7).ceil();
  final fullCellCount = weekCount * 7;

  int startRow = 0;
  int endRow = weekCount - 1;

  if (viewMode == CalendarViewMode.oneWeek) {
    startRow = selectedWeekIndex;
    endRow = selectedWeekIndex;
  } else if (viewMode == CalendarViewMode.twoWeeks) {
    // 월의 마지막 주(또는 첫 주)에서는 "다음 주"가 같은 월에 없어서 1주 보기와 같아질 수 있음.
    // 이때는 항상 2주가 보이도록 현재 주 기준으로 앞/뒤를 보정한다.
    if (weekCount <= 1) {
      startRow = 0;
      endRow = 0;
    } else if (selectedWeekIndex == 0) {
      startRow = 0;
      endRow = 1;
    } else if (selectedWeekIndex >= weekCount - 1) {
      startRow = weekCount - 2;
      endRow = weekCount - 1;
    } else {
      startRow = selectedWeekIndex;
      endRow = selectedWeekIndex + 1;
    }
  }

  final visibleRowCount = endRow - startRow + 1;
  final visibleItemCount = visibleRowCount * 7;
  const crossAxisCount = 7;
  // 월별: 셀을 약간 납작하게 해 6주 달도 리스트 영역을 덜 잡음.
  // textScaleFactor 고려하여 동적 조정
  final baseAspect = viewMode == CalendarViewMode.month ? 1.32 : 1.2;
  final textScale = MediaQuery.textScaleFactorOf(context);
  final aspect = baseAspect * (1.0 + (textScale - 1.0) * 0.5);
  const mainAxisSpacing = 2.0;
  const crossAxisSpacing = 2.0;
  final useIntrinsicMonthHeight = viewMode == CalendarViewMode.month;

  final gridView = GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      addAutomaticKeepAlives: false, // AutomaticKeepAlive 비활성화 (이미 위젯에서 처리)
      addRepaintBoundaries: false, // RepaintBoundary 비활성화 (이미 처리됨)
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: aspect,
        mainAxisSpacing: mainAxisSpacing,
        crossAxisSpacing: crossAxisSpacing,
      ),
      itemCount: visibleItemCount,
      itemBuilder: (context, index) {
        final actualIndex = (startRow * 7) + index;
        if (actualIndex >= fullCellCount) return const SizedBox.shrink();

        final cellDate = firstDayOfCurrentMonth.add(Duration(days: actualIndex - firstWeekday));
        final isCurrentMonthDate = cellDate.month == currentMonth.month;
        final dateKey = '${cellDate.year}-${cellDate.month}-${cellDate.day}';
        final eventsOnThisDate =
            isCurrentMonthDate ? (eventsByDate[dateKey] ?? const <CalendarEvent>[]) : const <CalendarEvent>[];

        return _buildDayCard(
          context,
          cellDate.day,
          cellDate.year,
          cellDate.month,
          style: style,
          selectedDate: onDaySelected != null ? selectedDate : null,
          eventStartDate: eventStartDate,
          eventEndDate: eventEndDate,
          eventsOnThisDate: eventsOnThisDate,
          selectionMode: selectionMode,
          onDaySelected: onDaySelected,
          isCurrentMonthDate: isCurrentMonthDate,
        );
      },
  );

  if (useIntrinsicMonthHeight) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final innerW = constraints.maxWidth;
        final cellW =
            (innerW - crossAxisSpacing * (crossAxisCount - 1)) / crossAxisCount;
        final cellH = cellW / aspect;
        final gridH = visibleRowCount * cellH +
            (visibleRowCount > 1
                ? (visibleRowCount - 1) * mainAxisSpacing
                : 0.0);
        return SizedBox(height: gridH, child: gridView);
      },
    );
  }

  return Expanded(child: gridView);
}

Widget buildWeekBody(
  BuildContext context,
  DateTime startDate, {
  required int days,
  DateTime? selectedDate,
  DateTime? eventStartDate,
  DateTime? eventEndDate,
  Map<String, List<CalendarEvent>> eventsByDate = const {},
  CalendarSelectionMode selectionMode = CalendarSelectionMode.single,
  void Function(int year, int month, int day)? onDaySelected,
  required int representativeMonth,
  required CalendarStyle style,
}) {
  return GridView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    padding: EdgeInsets.zero,
    addAutomaticKeepAlives: false,
    addRepaintBoundaries: false,
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 7,
      childAspectRatio: 1.2,
      mainAxisSpacing: 2,
      crossAxisSpacing: 2,
    ),
    itemCount: days,
    itemBuilder: (context, index) {
      final cellDate = DateTime(
        startDate.year,
        startDate.month,
        startDate.day,
      ).add(Duration(days: index));

      final dateKey = '${cellDate.year}-${cellDate.month}-${cellDate.day}';
      final eventsOnThisDate = eventsByDate[dateKey] ?? const <CalendarEvent>[];

      final isCurrentMonthDate = cellDate.month == representativeMonth;

      return _buildDayCard(
        context,
        cellDate.day,
        cellDate.year,
        cellDate.month,
        style: style,
        selectedDate: onDaySelected != null ? selectedDate : null,
        eventStartDate: eventStartDate,
        eventEndDate: eventEndDate,
        eventsOnThisDate: eventsOnThisDate,
        selectionMode: selectionMode,
        onDaySelected: onDaySelected,
        isCurrentMonthDate: isCurrentMonthDate,
      );
    },
  );
}

// 날짜만 비교하는 헬퍼 함수
bool _isSameDay(DateTime date1, DateTime date2) {
  return date1.year == date2.year &&
      date1.month == date2.month &&
      date1.day == date2.day;
}

bool _isDateInRange(DateTime date, DateTime start, DateTime end) {
  // 날짜만 비교 (시간 제거)
  final dateOnly = DateTime(date.year, date.month, date.day);
  final startOnly = DateTime(start.year, start.month, start.day);
  final endOnly = DateTime(end.year, end.month, end.day);
  return (dateOnly.isAfter(startOnly) || _isSameDay(dateOnly, startOnly)) &&
         (dateOnly.isBefore(endOnly) || _isSameDay(dateOnly, endOnly));
}

Widget _buildDayCard(
  BuildContext context,
  int day,
  int year,
  int month, {
  required CalendarStyle style,
  DateTime? selectedDate,
  DateTime? eventStartDate,
  DateTime? eventEndDate,
  List<CalendarEvent> eventsOnThisDate = const [],
  CalendarSelectionMode selectionMode = CalendarSelectionMode.single,
  void Function(int year, int month, int day)? onDaySelected,
  bool isCurrentMonthDate = true,
}) {
  final currentDate = DateTime(year, month, day);
  final dayBaseColor = _dayNumberBaseColor(style, currentDate);
  
  final isSelected =
      selectedDate != null &&
      selectedDate.year == year &&
      selectedDate.month == month &&
      selectedDate.day == day;
  final isToday = _isSameDay(currentDate, DateTime.now());

  // 편집 중인 이벤트 날짜 범위 확인 (편집 모드일 때만)
  final isEventStart = selectionMode == CalendarSelectionMode.range && eventStartDate != null &&
      eventStartDate.year == year &&
      eventStartDate.month == month &&
      eventStartDate.day == day;

  final isEventEnd = selectionMode == CalendarSelectionMode.range && eventEndDate != null &&
      eventEndDate.year == year &&
      eventEndDate.month == month &&
      eventEndDate.day == day;

  // 편집 중인 이벤트가 이 날짜에 포함되는지 확인 (시작일/종료일 제외)
  final isInEditingEventRange = selectionMode == CalendarSelectionMode.range && eventStartDate != null &&
      eventEndDate != null &&
      !isEventStart &&
      !isEventEnd &&
      _isDateInRange(currentDate, eventStartDate, eventEndDate);

  // 편집 중인 이벤트의 시작일/종료일 여부
  final isEventBoundary = isEventStart || isEventEnd;

  // 등록된 이벤트들만 색상 바에 표시 (편집 중인 이벤트는 배경색으로 표시)
  final eventCount = eventsOnThisDate.length;
  final maxColors = style.eventColors.length;

  return GestureDetector(
    onTap: () {
      if (onDaySelected != null) {
        onDaySelected(year, month, day);
        final y = year.toString();
        final m = month.toString().padLeft(2, '0');
        final d = day.toString().padLeft(2, '0');
        debugPrint('selectedDate: $y-$m-$d'); // 디버그 로그도 yyyy-MM-dd 형식으로 통일
      }
    },
    child: Container(
      decoration: BoxDecoration(
        color: isSelected
            ? style.selectedDayBackgroundColor
            : style.dayBackgroundColor,
        borderRadius: BorderRadius.circular(10),
        border: isToday
            ? Border.all(
                color: style.todayBorderColor,
                width: style.todayBorderWidth,
              )
            : null,
      ),
      child: Stack(
        children: [
          // 날짜 텍스트
          Center(
            child: Text(
              day.toString(),
              style: isEventBoundary
                  ? style.eventStartEndTextStyle
                  : isSelected
                      ? style.selectedDayTextStyle
                      : isToday
                          ? style.todayTextStyle
                          : style.dayTextStyle.copyWith(
                              color: isCurrentMonthDate
                                  ? dayBaseColor
                                  : dayBaseColor.withValues(alpha: 0.42),
                            ),
            ),
          ),
          // 편집 중인 이벤트 배경 표시 (시작일/종료일)
          if (isEventBoundary)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: style.eventStartEndBackgroundColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    day.toString(),
                    style: style.eventStartEndTextStyle,
                  ),
                ),
              ),
            )
          // 편집 중인 이벤트 배경 표시 (범위 내)
          else if (isInEditingEventRange)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: style.eventRangeBackgroundColor,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          // 등록된 이벤트들 표시 (하단에 작은 점으로)
          if (eventsOnThisDate.isNotEmpty)
            Positioned(
              bottom: 4,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 최대 5개까지만 점으로 표시, 그 이상은 숫자로
                  if (eventCount <= 5)
                    ...List.generate(
                      eventCount > maxColors ? maxColors : eventCount,
                      (index) {
                        final event = eventsOnThisDate[index];
                        final color = event.color ?? 
                            (index < style.eventColors.length 
                                ? style.eventColors[index] 
                                : style.eventRangeBackgroundColor);
                        return Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.symmetric(horizontal: 1.5),
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        );
                      },
                    )
                  else
                    // 5개 이상이면 숫자로 표시
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: style.eventRangeBackgroundColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$eventCount',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: style.eventStartEndBackgroundColor,
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

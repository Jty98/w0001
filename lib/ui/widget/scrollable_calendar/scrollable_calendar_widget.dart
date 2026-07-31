import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:scrollable_calendar_package/calendar.dart';
import 'package:w0001/util/funtions.dart';
import 'package:w0001/util/responsive_layout.dart';

/// [ScrollableCalendarWidget.adaptiveHeightForWeekModes]용 — 패키지
/// `BuildWeekWidget`(헤더·요일·그리드)과 동일 비율(1주/2줄) 근사.
double estimateScrollableCalendarWeekStripeHeight(
  double viewportWidth,
  CalendarViewMode mode,
) {
  if (mode != CalendarViewMode.oneWeek && mode != CalendarViewMode.twoWeeks) {
    return 320;
  }
  const containerVMargin = 8.0;
  const containerVPadding = 16.0;
  const gapHeaderToGrid = 12.0;
  const horizontalPaddingTotal = 10.0;
  // 주/2주 모드 헤더는 월별보다 세그먼트/제목 조합으로 높이가 더 커질 수 있어
  // 보수적으로 여유치를 둔다.
  const headerAndWeekTitleApprox = 126.0;
  const crossAxisCount = 7;
  const aspect = 1.2;
  const mainAxisSpacing = 2.0;
  const crossAxisSpacing = 2.0;
  const bottomSafety = 10.0;

  final innerW = math
      .max(0.0, viewportWidth - horizontalPaddingTotal)
      .clamp(120.0, 2000.0);
  final cellW =
      (innerW - crossAxisSpacing * (crossAxisCount - 1)) / crossAxisCount;
  final cellH = cellW / aspect;

  final dayCount = mode == CalendarViewMode.twoWeeks ? 14 : 7;
  final rows = (dayCount / crossAxisCount).ceil();
  final gridH = rows * cellH + (rows > 1 ? (rows - 1) * mainAxisSpacing : 0.0);

  return containerVMargin +
      containerVPadding +
      headerAndWeekTitleApprox +
      gapHeaderToGrid +
      gridH +
      bottomSafety;
}

/// 해당 월 달력 그리드에 필요한 주(행) 수 (5 또는 6).
int scrollableCalendarWeekRowsForMonth(int year, int month) {
  final firstWeekday = DateTime(year, month, 1).weekday % 7;
  final daysInMonth = DateTime(year, month + 1, 0).day;
  return ((firstWeekday + daysInMonth) / 7).ceil();
}

/// 월별 보기 카드 높이 근사 — [scrollableCalendarWeekRowsForMonth] 행 수 반영.
double estimateScrollableCalendarMonthStripeHeight(
  double viewportWidth, {
  required int weekRows,
}) {
  const containerVMargin = 4.0;
  const containerVPadding = 10.0;
  const gapHeaderToGrid = 8.0;
  const horizontalPaddingTotal = 10.0;
  const headerAndWeekTitleApprox = 112.0;
  const crossAxisCount = 7;
  const aspect = 1.32;
  const mainAxisSpacing = 2.0;
  const crossAxisSpacing = 2.0;
  const bottomSafety = 4.0;

  final innerW = math
      .max(0.0, viewportWidth - horizontalPaddingTotal)
      .clamp(120.0, 2000.0);
  final cellW =
      (innerW - crossAxisSpacing * (crossAxisCount - 1)) / crossAxisCount;
  final cellH = cellW / aspect;
  final rows = weekRows.clamp(4, 6);
  final gridH = rows * cellH + (rows > 1 ? (rows - 1) * mainAxisSpacing : 0.0);

  return containerVMargin +
      containerVPadding +
      headerAndWeekTitleApprox +
      gapHeaderToGrid +
      gridH +
      bottomSafety;
}

/// 앱 [ThemeData.colorScheme]에 맞춘 달력 스타일 — 패키지 기본(인디고 고정) 대신 사용합니다.
CalendarStyle scrollableCalendarStyleFromColorScheme(
  ColorScheme cs, {
  required bool subtleSelection,
  TextTheme? textTheme,
}) {
  final tt = textTheme ?? const TextTheme();
  final titleBase = tt.titleLarge ?? tt.titleMedium;
  final labelBase = tt.labelLarge ?? tt.bodyMedium;
  final bodyBase = tt.bodyLarge ?? tt.bodyMedium;

  final headerText = (titleBase ?? const TextStyle()).copyWith(
    fontWeight: FontWeight.bold,
    color: cs.onSurface,
    fontSize: 17,
    height: 1.15,
  );
  final weekdayText = (labelBase ?? const TextStyle()).copyWith(
    fontWeight: FontWeight.w700,
    color: cs.onSurfaceVariant,
  );
  final dayText = (bodyBase ?? const TextStyle()).copyWith(
    color: cs.onSurface,
    fontWeight: FontWeight.w700,
  );
  final sunday = cs.error;
  final saturday = cs.primary;

  final eventPalette = <Color>[
    cs.primary,
    cs.secondary,
    cs.tertiary,
    cs.error,
    cs.primary,
  ];

  if (subtleSelection) {
    return CalendarStyle(
      focusedMonthBackgroundColor: Colors.transparent,
      focusedMonthBorderColor: cs.outlineVariant.withValues(alpha: 0.45),
      focusBorderColor: cs.primary,
      headerAccentColor: cs.primary,
      calendarBorderRadius: const BorderRadius.all(Radius.circular(16)),
      headerTextStyle: headerText,
      weekdayTextStyle: weekdayText,
      weekdaySundayTextColor: sunday,
      weekdaySaturdayTextColor: saturday,
      dayBackgroundColor: Colors.transparent,
      selectedDayBackgroundColor: cs.primary.withValues(alpha: 0.12),
      dayTextStyle: dayText,
      daySundayTextColor: sunday,
      daySaturdayTextColor: saturday,
      selectedDayTextStyle: dayText.copyWith(
        color: cs.primary,
        fontWeight: FontWeight.bold,
      ),
      todayTextStyle: dayText.copyWith(
        color: cs.primary,
        fontWeight: FontWeight.w900,
      ),
      todayBorderColor: cs.primary,
      todayBorderWidth: 1.6,
      eventRangeBackgroundColor: cs.tertiaryContainer.withValues(alpha: 0.55),
      eventStartEndBackgroundColor: cs.primary.withValues(alpha: 0.22),
      eventStartEndTextStyle: dayText.copyWith(
        color: cs.primary,
        fontWeight: FontWeight.bold,
      ),
      eventColors: eventPalette,
      eventSaveButtonTextStyle: dayText.copyWith(
        color: cs.onPrimary,
        fontWeight: FontWeight.bold,
      ),
      eventSaveButtonColor: cs.primary,
      eventSaveButtonBorderColor: cs.primary,
    );
  }

  return CalendarStyle(
    focusedMonthBackgroundColor: Colors.transparent,
    focusedMonthBorderColor: cs.outlineVariant.withValues(alpha: 0.45),
    focusBorderColor: cs.primary,
    headerAccentColor: cs.primary,
    calendarBorderRadius: const BorderRadius.all(Radius.circular(16)),
    headerTextStyle: headerText,
    weekdayTextStyle: weekdayText,
    weekdaySundayTextColor: sunday,
    weekdaySaturdayTextColor: saturday,
    dayBackgroundColor: Colors.transparent,
    selectedDayBackgroundColor: cs.primary.withValues(alpha: 0.14),
    dayTextStyle: dayText,
    daySundayTextColor: sunday,
    daySaturdayTextColor: saturday,
    selectedDayTextStyle: dayText.copyWith(
      color: cs.primary,
      fontWeight: FontWeight.bold,
    ),
    todayTextStyle: dayText.copyWith(
      color: cs.primary,
      fontWeight: FontWeight.w800,
    ),
    todayBorderColor: cs.primary,
    todayBorderWidth: 1.6,
    eventRangeBackgroundColor: cs.tertiaryContainer.withValues(alpha: 0.55),
    eventStartEndBackgroundColor: cs.primary,
    eventStartEndTextStyle: dayText.copyWith(
      color: cs.onPrimary,
      fontWeight: FontWeight.bold,
    ),
    eventColors: eventPalette,
    eventSaveButtonTextStyle: dayText.copyWith(
      color: cs.onPrimary,
      fontWeight: FontWeight.bold,
    ),
    eventSaveButtonColor: cs.primary,
    eventSaveButtonBorderColor: cs.primary,
  );
}

class ScrollableCalendarWidget extends StatefulWidget {
  const ScrollableCalendarWidget({
    super.key,
    this.height = 320,

    /// true면 1주·2주 모드에서는 [height]를 상한만 두고, 실제 카드 높이는
    /// 그리드 행 수에 맞춰 줄어들어 바로 아래 위젯이 위로 붙습니다. 월별은 [height].
    this.adaptiveHeightForWeekModes = false,
    this.onRangeChanged,
    this.onDayPicked,
    this.initialRangeStart,
    this.initialRangeEnd,
    this.initialSelectedDay,
    this.calendarKey,
    this.useSingleDaySelection = false,
    this.initialCalendarViewMode,
    this.showViewModeToggle = true,
    this.onMonthChanged,
    this.onCalendarPageAnchorChanged,
    this.onViewModeChanged,
    this.initialEvents = const [],
    this.showRangeSummarySection = true,
    this.disableDateSelectionHighlight = false,
    this.yearMonthPickerUsesDialog,
  });

  final double height;

  /// 1주·2주 ↔ 월별 전환 시 뷰포트 높이를 내용에 맞출지(아래 레이아웃 밀림).
  final bool adaptiveHeightForWeekModes;

  /// Inclusive date range (time stripped). Used by place add/edit dialog.
  final void Function(DateTime? start, DateTime? end)? onRangeChanged;

  /// 단일 날짜 선택 콜백(금액추가 등). range는 "표시용 고정"으로 유지한다.
  final void Function(DateTime pickedDay)? onDayPicked;

  /// 기존 현장 기간 등 미리 표시할 때 사용. 둘 다 null이면 선택 없음.
  final DateTime? initialRangeStart;
  final DateTime? initialRangeEnd;

  /// 다이얼로그 최초 진입 시 포커스/선택 기준일. 기본은 오늘.
  final DateTime? initialSelectedDay;

  /// [ScrollableCalendar] 상태에 접근할 때(모드 전환 등).
  final GlobalKey<ScrollableCalendarState>? calendarKey;

  /// true면 기간 선택·기간 칩을 쓰지 않고 단일 선택만 사용합니다.
  final bool useSingleDaySelection;

  /// 최초 1주/2주/월 모드.
  final CalendarViewMode? initialCalendarViewMode;

  /// false면 헤더의 1주/2주/월 전환 칩을 숨깁니다.
  final bool showViewModeToggle;

  /// 월 페이지가 바뀔 때(월 보기에서).
  final void Function(DateTime monthFirst)? onMonthChanged;

  /// 주/월 페이지 앵커가 바뀔 때.
  final void Function(DateTime anchor)? onCalendarPageAnchorChanged;

  /// 패키지 내부에서 1주/2주/월이 바뀔 때
  final void Function(CalendarViewMode mode)? onViewModeChanged;

  /// 캘린더 날짜별 점/이벤트 표시용 데이터
  final List<CalendarEvent> initialEvents;

  /// range 선택 모드에서 상단 선택 기간 요약 UI 표시 여부
  final bool showRangeSummarySection;

  /// 날짜 선택 시 배경/범위 하이라이트를 비활성화합니다.
  final bool disableDateSelectionHighlight;

  /// 년·월 헤더 탭 시 다이얼로그 사용 여부. null이면 [adaptiveHeightForWeekModes]와 동일.
  final bool? yearMonthPickerUsesDialog;

  bool get _yearMonthPickerUsesDialog =>
      yearMonthPickerUsesDialog ?? adaptiveHeightForWeekModes;

  @override
  State<ScrollableCalendarWidget> createState() =>
      _ScrollableCalendarWidgetState();
}

class _ScrollableCalendarWidgetState extends State<ScrollableCalendarWidget> {
  DateTime? _rangeStart;
  DateTime? _rangeEnd;
  late DateTime _selectedDay;
  int _rebuildNonce = 0;
  late final int _instanceSeed;

  late CalendarViewMode _calendarViewModeForHeight;
  late DateTime _monthAnchorForHeight;

  bool get _isFixedRangeSinglePickMode =>
      widget.onDayPicked != null && !widget.useSingleDaySelection;

  bool get _showRangeSummary =>
      widget.onRangeChanged != null &&
      !widget.useSingleDaySelection &&
      widget.showRangeSummarySection;

  @override
  void initState() {
    super.initState();
    _instanceSeed = DateTime.now().microsecondsSinceEpoch;
    _calendarViewModeForHeight =
        widget.initialCalendarViewMode ?? CalendarViewMode.month;
    _rangeStart = widget.initialRangeStart;
    _rangeEnd = widget.initialRangeEnd ?? widget.initialRangeStart;
    final base = widget.initialSelectedDay ?? DateTime.now();
    _selectedDay = DateTime(base.year, base.month, base.day);
    _monthAnchorForHeight = _selectedDay;
  }

  @override
  void didUpdateWidget(covariant ScrollableCalendarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.adaptiveHeightForWeekModes &&
        oldWidget.initialCalendarViewMode != widget.initialCalendarViewMode) {
      _calendarViewModeForHeight =
          widget.initialCalendarViewMode ?? CalendarViewMode.month;
    }
    if (oldWidget.initialRangeStart != widget.initialRangeStart ||
        oldWidget.initialRangeEnd != widget.initialRangeEnd) {
      setState(() {
        _rangeStart = widget.initialRangeStart;
        _rangeEnd = widget.initialRangeEnd ?? widget.initialRangeStart;
      });
    }
    if (oldWidget.initialSelectedDay != widget.initialSelectedDay &&
        widget.initialSelectedDay != null) {
      final d = widget.initialSelectedDay!;
      setState(() {
        _selectedDay = DateTime(d.year, d.month, d.day);
        _monthAnchorForHeight = _selectedDay;
        if (_isFixedRangeSinglePickMode) {
          _rebuildNonce++;
        }
      });
    }
  }

  void _handleMonthChanged(DateTime monthFirst) {
    widget.onMonthChanged?.call(monthFirst);
    if (!widget.adaptiveHeightForWeekModes) return;
    final anchor = DateTime(monthFirst.year, monthFirst.month, 1);
    if (_monthAnchorForHeight.year == anchor.year &&
        _monthAnchorForHeight.month == anchor.month) {
      return;
    }
    setState(() => _monthAnchorForHeight = anchor);
  }

  void _handleViewModeChanged(CalendarViewMode mode) {
    if (widget.adaptiveHeightForWeekModes &&
        _calendarViewModeForHeight != mode) {
      setState(() => _calendarViewModeForHeight = mode);
    }
    widget.onViewModeChanged?.call(mode);
  }

  double _viewportHeight(double layoutMaxWidth) {
    if (!widget.adaptiveHeightForWeekModes) {
      return widget.height;
    }
    final w = layoutMaxWidth.isFinite && layoutMaxWidth > 0
        ? layoutMaxWidth
        : MediaQuery.sizeOf(context).width;
    if (_calendarViewModeForHeight == CalendarViewMode.month) {
      final rows = scrollableCalendarWeekRowsForMonth(
        _monthAnchorForHeight.year,
        _monthAnchorForHeight.month,
      );
      final est = estimateScrollableCalendarMonthStripeHeight(
        w,
        weekRows: rows,
      );
      final screenCap = MediaQuery.sizeOf(context).height * 0.405;
      // 내용이 잘리지 않게 하되, 과한 여유는 화면 비율로 상한.
      if (est <= screenCap) return est;
      return math.max(screenCap, est * 0.98);
    }
    final oneW =
        estimateScrollableCalendarWeekStripeHeight(w, CalendarViewMode.oneWeek);
    // 주/2주 모드는 기존 height 상한에 강하게 clamp하면 잘림으로 overflow가 나기 쉬움.
    // 화면 비율 상한만 두고, 내용 기반 높이를 우선한다.
    final screenCap = MediaQuery.sizeOf(context).height * 0.52;
    final est = estimateScrollableCalendarWeekStripeHeight(
        w, _calendarViewModeForHeight);
    final upper = math.max(widget.height, screenCap);
    return est.clamp(oneW, upper).toDouble();
  }

  String _rangeLabel() {
    final start = _rangeStart;
    if (start == null) return '기간을 선택해주세요.';

    final end = _rangeEnd ?? start;
    final normalizedStart = start.isBefore(end) ? start : end;
    final normalizedEnd = start.isBefore(end) ? end : start;
    final days = normalizedEnd.difference(normalizedStart).inDays + 1;

    return '${formatDateTimeRangeToString(DateTimeRange(start: normalizedStart, end: normalizedEnd), showYear: true)} ($days일)';
  }

  String _rangeDaysLabel() {
    final start = _rangeStart;
    if (start == null) return '';
    final end = _rangeEnd ?? start;
    final normalizedStart = start.isBefore(end) ? start : end;
    final normalizedEnd = start.isBefore(end) ? end : start;
    final days = normalizedEnd.difference(normalizedStart).inDays + 1;
    return '$days일';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final mq = MediaQuery.of(context);
    // 날짜 셀은 폭이 매우 촘촘해서 과도한 전역 글자 배율(큰글씨 모드 포함)을
    // 그대로 적용하면 숫자 렌더링이 깨질 수 있어 캘린더 내부 텍스트 스케일을 고정한다.
    final calendarMq = mq.copyWith(textScaler: const TextScaler.linear(1.0));
    final style = scrollableCalendarStyleFromColorScheme(
      cs,
      subtleSelection: widget.disableDateSelectionHighlight,
      textTheme: Theme.of(context).textTheme,
    );

    final initialStart = widget.initialRangeStart;
    final initialEnd = widget.initialRangeEnd ?? initialStart;
    final focusDate = _selectedDay;

    final useRangeMode =
        widget.onRangeChanged != null && !widget.useSingleDaySelection;

    Widget sizedCalendar(double viewportHeight) => Material(
          color: cs.surface,
          elevation: 0,
          clipBehavior: Clip.antiAlias,
          shadowColor: cs.shadow.withValues(alpha: 0.08),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(context.rs(18)),
            side: BorderSide(
              color: cs.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: SizedBox(
            height: viewportHeight,
            width: double.infinity,
            child: MediaQuery(
              data: calendarMq,
              child: ScrollableCalendar(
                key: widget.calendarKey ??
                    (_isFixedRangeSinglePickMode
                        ? ValueKey(
                            'addcost-calendar-$_rebuildNonce-${_selectedDay.toIso8601String()}',
                          )
                        : ValueKey(
                            'scroll-cal-$_instanceSeed-'
                            '${widget.useSingleDaySelection ? 'single' : 'range'}-'
                            '${widget.disableDateSelectionHighlight ? 'flat' : 'normal'}-'
                            '${widget.showViewModeToggle ? 'toggle' : 'notoggle'}',
                          )),
                config: CalendarConfig(
                  initialDate: focusDate,
                  pageScrollDirection: CalendarPageScrollDirection.horizontal,
                  selectionMode: useRangeMode
                      ? CalendarSelectionMode.range
                      : CalendarSelectionMode.single,
                  showMonthArrowButtons: true,
                  calendarHeightFactor: 1,
                  initialEventStartDate: useRangeMode ? initialStart : null,
                  initialEventEndDate: useRangeMode ? initialEnd : null,
                  initialEvents: widget.initialEvents,
                  yearMonthPickerUsesDialog: widget._yearMonthPickerUsesDialog,
                ),
                style: style,
                initialCalendarViewMode: widget.initialCalendarViewMode,
                showViewModeToggle: widget.showViewModeToggle,
                onMonthChanged: _handleMonthChanged,
                onCalendarPageAnchorChanged: widget.onCalendarPageAnchorChanged,
                onViewModeChanged: _handleViewModeChanged,
                onDaySelected: widget.onDayPicked == null
                    ? null
                    : (date) {
                        if (!mounted) return;
                        final d = DateTime(date.year, date.month, date.day);
                        if (widget.useSingleDaySelection) {
                          setState(() {
                            _selectedDay = d;
                            _monthAnchorForHeight = d;
                          });
                          widget.onDayPicked?.call(d);
                          return;
                        }
                        setState(() {
                          _selectedDay = d;
                          _rebuildNonce++;
                        });
                        widget.onDayPicked?.call(d);
                      },
                onEventRangeChanged: widget.onRangeChanged == null
                    ? null
                    : (start, end) {
                        if (!mounted) return;
                        setState(() {
                          _rangeStart = start;
                          _rangeEnd = end;
                        });
                        widget.onRangeChanged?.call(start, end);
                      },
                builder: (context, selectedDate, calendar) {
                  return Column(
                    children: [
                      if (_showRangeSummary)
                        Padding(
                          padding: ResponsiveLayout.only(
                            context,
                            left: 12,
                            top: 12,
                            right: 12,
                            bottom: 8,
                          ),
                          child: Container(
                            width: double.infinity,
                            padding: ResponsiveLayout.symmetric(
                              context,
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  cs.tertiaryContainer.withValues(alpha: 0.38),
                              borderRadius:
                                  BorderRadius.circular(context.rs(12)),
                              border: Border.all(
                                color: cs.outlineVariant.withValues(alpha: 0.45),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.date_range_outlined,
                                  size: context.rsi(18),
                                  color: cs.primary,
                                ),
                                rsH(context, 8),
                                Expanded(
                                  child: Text(
                                    _rangeLabel(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: tt.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: cs.onSurface,
                                    ),
                                  ),
                                ),
                                rsH(context, 8),
                                Container(
                                  padding: ResponsiveLayout.symmetric(
                                    context,
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: cs.primaryContainer,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    _rangeDaysLabel(),
                                    style: tt.labelSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: cs.onPrimaryContainer,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      Expanded(child: calendar),
                    ],
                  );
                },
              ),
            ),
          ),
        );

    if (!widget.adaptiveHeightForWeekModes) {
      return sizedCalendar(widget.height);
    }
    return LayoutBuilder(
      builder: (context, constraints) =>
          sizedCalendar(_viewportHeight(constraints.maxWidth)),
    );
  }
}

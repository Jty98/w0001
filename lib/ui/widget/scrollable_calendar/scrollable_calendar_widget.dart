import 'package:flutter/material.dart';
import 'package:scrollable_calendar_package/calendar.dart';
import 'package:w0001/util/funtions.dart';

class ScrollableCalendarWidget extends StatefulWidget {
  const ScrollableCalendarWidget({
    super.key,
    this.height = 320,
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
  });

  final double height;

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
    _rangeStart = widget.initialRangeStart;
    _rangeEnd = widget.initialRangeEnd ?? widget.initialRangeStart;
    final base = widget.initialSelectedDay ?? DateTime.now();
    _selectedDay = DateTime(base.year, base.month, base.day);
  }

  @override
  void didUpdateWidget(covariant ScrollableCalendarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
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
        if (_isFixedRangeSinglePickMode) {
          _rebuildNonce++;
        }
      });
    }
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
    final style = widget.disableDateSelectionHighlight
        ? CalendarStyle(
            focusedMonthBackgroundColor: Colors.transparent,
            selectedDayBackgroundColor: const Color(0x2B3B82F6),
            selectedDayTextStyle: TextStyle(
              color: cs.primary,
              fontWeight: FontWeight.bold,
            ),
            todayTextStyle: const TextStyle(
              color: Color(0xFF1D4ED8),
              fontWeight: FontWeight.w900,
            ),
            todayBorderColor: const Color(0xFF1D4ED8),
            todayBorderWidth: 1.6,
            eventRangeBackgroundColor: const Color(0x1F3B82F6),
            eventStartEndBackgroundColor: const Color(0x3B2563EB),
            eventStartEndTextStyle: TextStyle(
              color: cs.primary,
              fontWeight: FontWeight.bold,
            ),
          )
        : const CalendarStyle();

    final initialStart = widget.initialRangeStart;
    final initialEnd = widget.initialRangeEnd ?? initialStart;
    final focusDate = _selectedDay;

    final useRangeMode =
        widget.onRangeChanged != null && !widget.useSingleDaySelection;

    return SizedBox(
      height: widget.height,
      width: double.infinity,
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
        ),
        style: style,
        initialCalendarViewMode: widget.initialCalendarViewMode,
        showViewModeToggle: widget.showViewModeToggle,
        onMonthChanged: widget.onMonthChanged,
        onCalendarPageAnchorChanged: widget.onCalendarPageAnchorChanged,
        onViewModeChanged: widget.onViewModeChanged,
        onDaySelected: widget.onDayPicked == null
            ? null
            : (date) {
                if (!mounted) return;
                final d = DateTime(date.year, date.month, date.day);
                if (widget.useSingleDaySelection) {
                  setState(() => _selectedDay = d);
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
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: cs.outlineVariant.withValues(alpha: 0.55),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.date_range_outlined,
                          size: 18,
                          color: cs.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _rangeLabel(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: cs.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: cs.primaryContainer,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            _rangeDaysLabel(),
                            style: TextStyle(
                              fontSize: 11,
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
    );
  }
}

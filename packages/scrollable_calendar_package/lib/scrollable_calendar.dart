import 'package:flutter/material.dart';
import 'package:scrollable_calendar_package/calendar_config.dart';
import 'package:scrollable_calendar_package/calendar_style.dart';
import 'package:scrollable_calendar_package/calendar_widget.dart';
import 'package:scrollable_calendar_package/calendar_event.dart';
import 'package:scrollable_calendar_package/year_month_picker_dialog.dart';

/// 패키지화할 때 공개할 핵심 캘린더 위젯 (table_calendar 스타일)
/// - 사용자는 config와 style, 콜백만 넘기면 됨
/// - 내부에서 PageController, months, 상태 등을 모두 관리
  /// - builder 패턴으로 selectedDate를 자동으로 제공 (ListView.builder의 index처럼)
class ScrollableCalendar extends StatefulWidget {
  const ScrollableCalendar({
    super.key,
    required this.config,
    required this.builder,
    this.style = const CalendarStyle(),
    this.onDaySelected,
    this.onEventRangeChanged,
    this.onMonthChanged,
    this.onCalendarPageAnchorChanged,
    this.initialCalendarViewMode,
    this.showViewModeToggle = true,
    this.onViewModeChanged,
  });

  /// 달력 설정 (yearRange, initialDate 등)
  final CalendarConfig config;

  /// builder 콜백 - selectedDate를 자동으로 제공 (ListView.builder의 index처럼)
  /// selectedDate: 사용자가 선택한 날짜 (없으면 null)
  /// calendar: 캘린더 위젯
  final Widget Function(BuildContext context, DateTime? selectedDate, Widget calendar) builder;

  /// 스타일 옵션
  final CalendarStyle style;

  /// 날짜 선택 시 호출 (table_calendar 스타일)
  /// - [date]: 사용자가 탭한 실제 날짜
  final void Function(DateTime date)? onDaySelected;

  /// 이벤트 기간 변경 시 호출 (selectionMode가 single/range일 때)
  /// - [startDate]: 이벤트 시작일 (없으면 null)
  /// - [endDate]: 이벤트 종료일 (없으면 null)
  final void Function(DateTime? startDate, DateTime? endDate)? onEventRangeChanged;

  /// 월 변경 시 호출 (선택사항)
  final void Function(DateTime month)? onMonthChanged;

  /// 월/주 페이지가 바뀔 때 앵커일(주 모드: 페이지 시작일, 월 모드: 해당 달 1일)
  final void Function(DateTime anchor)? onCalendarPageAnchorChanged;

  /// 최초 표시 모드(기본: 월). 외부에서 [ScrollableCalendarState.setCalendarViewMode]로도 변경 가능.
  final CalendarViewMode? initialCalendarViewMode;

  /// false면 헤더의 1주/2주/월 전환 칩을 숨깁니다.
  final bool showViewModeToggle;

  /// 1주/2주/월 모드가 바뀔 때
  final void Function(CalendarViewMode mode)? onViewModeChanged;

  @override
  State<ScrollableCalendar> createState() => ScrollableCalendarState();
}

class ScrollableCalendarState extends State<ScrollableCalendar> {
  static const int _yearGridInitialPage = 1000;
  late final CalendarGeneratedData _generated;
  late final PageController _pageController;
  late final PageController _weekPageController;
  late final PageController _yearViewPageController;
  late final PageController _yearGridPageController;
  late final ValueNotifier<int> _currentMonthIndexNotifier;
  late final ValueNotifier<int> _currentWeekIndexNotifier;
  late final ValueNotifier<DateTime?> _selectedDateNotifier;
  late final ValueNotifier<DateTime?> _eventStartDateNotifier;
  late final ValueNotifier<DateTime?> _eventEndDateNotifier;
  late final ValueNotifier<List<CalendarEvent>> _registeredEventsNotifier;
  late final ValueNotifier<bool> _isYearViewModeNotifier;
  late final ValueNotifier<bool> _isYearGridModeNotifier;
  late final ValueNotifier<int> _yearGridCenterYearNotifier;
  late final ValueNotifier<CalendarViewMode> _calendarViewModeNotifier;
  late final List<DateTime> _oneWeekStarts;
  late final List<DateTime> _twoWeekStarts;
  CalendarViewMode? _lastViewModeSynced;
  VoidCallback? _weekControllerListener;

  @override
  void initState() {
    super.initState();
    _generated = widget.config.generate();
    _currentMonthIndexNotifier = ValueNotifier<int>(_generated.initialPage);
    _selectedDateNotifier = ValueNotifier<DateTime?>(widget.config.initialDate);
    _eventStartDateNotifier = ValueNotifier<DateTime?>(
      widget.config.selectionMode == CalendarSelectionMode.range
          ? widget.config.initialEventStartDate
          : null,
    );
    _eventEndDateNotifier = ValueNotifier<DateTime?>(
      widget.config.selectionMode == CalendarSelectionMode.range
          ? widget.config.initialEventEndDate
          : null,
    );
    _registeredEventsNotifier = ValueNotifier<List<CalendarEvent>>(widget.config.initialEvents);

    // viewportFraction을 설정하여 여러 달이 동시에 보이도록
    final calendarHeightFactor = widget.config.calendarHeightFactor;
    final viewportFraction = calendarHeightFactor;

    _pageController = PageController(
      initialPage: _generated.initialPage,
      viewportFraction: viewportFraction,
    );

    final minDate = DateTime(
      _generated.months.first.year,
      _generated.months.first.month,
      1,
    );
    final maxDate = DateTime(
      _generated.months.last.year,
      _generated.months.last.month + 1,
      0,
    );
    _oneWeekStarts = _buildWeekStarts(minDate: minDate, maxDate: maxDate, stepDays: 7);
    _twoWeekStarts = _buildWeekStarts(minDate: minDate, maxDate: maxDate, stepDays: 14);

    final initialTarget = _selectedDateNotifier.value ?? widget.config.initialDate;
    final initialWeekIndex = _findWeekIndex(
      starts: _oneWeekStarts,
      daysPerPage: 7,
      target: initialTarget,
    );
    _currentWeekIndexNotifier = ValueNotifier<int>(initialWeekIndex);
    _weekPageController = PageController(
      initialPage: initialWeekIndex,
      viewportFraction: viewportFraction,
    );

    // PageController.page와 notifier를 초기/스크롤 중에도 동기화(특히 1주 모드에서 포커스 누락 방지)
    _weekControllerListener = () {
      if (!_weekPageController.hasClients) return;
      final p = _weekPageController.page;
      if (p == null) return;
      final idx = p.round();
      if (idx != _currentWeekIndexNotifier.value) {
        _currentWeekIndexNotifier.value = idx;
      }
    };
    _weekPageController.addListener(_weekControllerListener!);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_weekPageController.hasClients) {
        final p = _weekPageController.page;
        if (p != null) _currentWeekIndexNotifier.value = p.round();
      }
    });

    // 연도 선택 모드용 PageController
    final initialYearIndex = widget.config.yearRange;
    _yearViewPageController = PageController(
      initialPage: initialYearIndex,
    );
    _yearGridPageController = PageController(initialPage: _yearGridInitialPage);

    _isYearViewModeNotifier = ValueNotifier<bool>(false);
    _isYearGridModeNotifier = ValueNotifier<bool>(false);
    _yearGridCenterYearNotifier = ValueNotifier<int>(widget.config.initialDate.year);
    _calendarViewModeNotifier = ValueNotifier<CalendarViewMode>(
      widget.initialCalendarViewMode ?? CalendarViewMode.month,
    );

    // 초기 이벤트 날짜가 있으면 콜백 호출 (외부 UI 업데이트용)
    if (widget.config.selectionMode == CalendarSelectionMode.range &&
        (widget.config.initialEventStartDate != null ||
            widget.config.initialEventEndDate != null)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.onEventRangeChanged != null) {
          widget.onEventRangeChanged!(
            _eventStartDateNotifier.value,
            _eventEndDateNotifier.value,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _weekPageController.dispose();
    _yearViewPageController.dispose();
    _yearGridPageController.dispose();
    _currentMonthIndexNotifier.dispose();
    _currentWeekIndexNotifier.dispose();
    _selectedDateNotifier.dispose();
    _eventStartDateNotifier.dispose();
    _eventEndDateNotifier.dispose();
    _registeredEventsNotifier.dispose();
    _isYearViewModeNotifier.dispose();
    _isYearGridModeNotifier.dispose();
    _yearGridCenterYearNotifier.dispose();
    _calendarViewModeNotifier.dispose();
    if (_weekControllerListener != null) {
      _weekPageController.removeListener(_weekControllerListener!);
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ScrollableCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);

    // External widgets rebuild with fresh events after async fetch.
    // Keep internal notifier in sync so day markers are reflected.
    if (oldWidget.config.initialEvents != widget.config.initialEvents) {
      _registeredEventsNotifier.value = widget.config.initialEvents;
    }

    // Keep selected date in sync when parent updates initial date.
    if (oldWidget.config.initialDate != widget.config.initialDate) {
      _selectedDateNotifier.value = widget.config.initialDate;
    }

    // Keep range selection in sync when external initial range changes.
    if (oldWidget.config.initialEventStartDate !=
            widget.config.initialEventStartDate ||
        oldWidget.config.initialEventEndDate != widget.config.initialEventEndDate) {
      _eventStartDateNotifier.value = widget.config.initialEventStartDate;
      _eventEndDateNotifier.value = widget.config.initialEventEndDate;
    }
  }

  void _cycleCalendarViewMode() {
    final mode = _calendarViewModeNotifier.value;
    final next = mode == CalendarViewMode.month
        ? CalendarViewMode.oneWeek
        : (mode == CalendarViewMode.oneWeek
            ? CalendarViewMode.twoWeeks
            : CalendarViewMode.month);

    _calendarViewModeNotifier.value = next;
    _syncControllersToViewMode(next, animate: false);
    widget.onViewModeChanged?.call(next);
  }

  /// 외부(예: SegmentedButton)에서 1주/2주/월 모드를 맞출 때 사용합니다.
  void setCalendarViewMode(CalendarViewMode mode) {
    if (!mounted) return;
    if (_calendarViewModeNotifier.value == mode) return;
    _calendarViewModeNotifier.value = mode;
    _syncControllersToViewMode(mode, animate: false);
    widget.onViewModeChanged?.call(mode);
  }

  void _syncControllersToViewMode(
    CalendarViewMode viewMode, {
    required bool animate,
  }) {
    final target = _selectedDateNotifier.value ?? widget.config.initialDate;

    if (viewMode == CalendarViewMode.month) {
      final monthIndex = _generated.months.indexWhere(
        (m) => m.year == target.year && m.month == target.month,
      );
      if (monthIndex < 0) return;
      _currentMonthIndexNotifier.value = monthIndex;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_pageController.hasClients) return;
        if (animate) {
          _pageController.animateToPage(
            monthIndex,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        } else {
          _pageController.jumpToPage(monthIndex);
        }
      });
      return;
    }

    final daysPerPage = viewMode == CalendarViewMode.twoWeeks ? 14 : 7;
    final starts = viewMode == CalendarViewMode.twoWeeks ? _twoWeekStarts : _oneWeekStarts;
    final targetIndex = _findWeekIndex(
      starts: starts,
      daysPerPage: daysPerPage,
      target: target,
    );
    _currentWeekIndexNotifier.value = targetIndex;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_weekPageController.hasClients) return;
      if (animate) {
        _weekPageController.animateToPage(
          targetIndex,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      } else {
        _weekPageController.jumpToPage(targetIndex);
      }
    });
  }

  String _getNextViewModeLabel(CalendarViewMode mode) {
    if (mode == CalendarViewMode.month) {
      return '1주 보기';
    }
    if (mode == CalendarViewMode.oneWeek) {
      return '2주 보기';
    }
    return '월별 보기';
  }

  IconData _getNextViewModeIcon(CalendarViewMode mode) {
    if (mode == CalendarViewMode.month) {
      return Icons.view_week_outlined;
    }
    if (mode == CalendarViewMode.oneWeek) {
      return Icons.calendar_view_week_outlined;
    }
    return Icons.calendar_view_month_outlined;
  }

  void _scrollToPage(int targetIndex) {
    if (targetIndex < 0 || targetIndex >= _generated.months.length) return;
    if (!_pageController.hasClients) return;

    _pageController.animateToPage(
      targetIndex,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _moveMonth(int delta) {
    final targetIndex = _currentMonthIndexNotifier.value + delta;
    if (targetIndex < 0 || targetIndex >= _generated.months.length) return;
    _currentMonthIndexNotifier.value = targetIndex;
    _scrollToPage(targetIndex);
  }

  void _moveWeek(int delta, CalendarViewMode viewMode) {
    final starts = viewMode == CalendarViewMode.twoWeeks ? _twoWeekStarts : _oneWeekStarts;
    final targetIndex = _currentWeekIndexNotifier.value + delta;
    if (targetIndex < 0 || targetIndex >= starts.length) return;
    if (!_weekPageController.hasClients) return;

    _currentWeekIndexNotifier.value = targetIndex;
    _weekPageController.animateToPage(
      targetIndex,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _handleDaySelected(int year, int month, int day) {
    final selected = DateTime(year, month, day);
    
    final isSelectionEnabled =
        widget.config.selectionMode != CalendarSelectionMode.none;
    final isRangeMode =
        widget.config.selectionMode == CalendarSelectionMode.range;

    // 선택 모드일 때만 선택 상태 업데이트
    if (isSelectionEnabled) {
      _selectedDateNotifier.value = selected;
    }

    // 선택 모드일 경우 날짜 선택 로직
    if (isSelectionEnabled) {
      if (!isRangeMode) {
        // 단일 선택 모드: 선택한 날짜만 유지
        _eventStartDateNotifier.value = selected;
        _eventEndDateNotifier.value = selected;
        widget.onEventRangeChanged?.call(selected, selected);
      } else {
      final currentStart = _eventStartDateNotifier.value;
      final currentEnd = _eventEndDateNotifier.value;

      // 선택된 범위가 있는 상태에서 start/end를 다시 누르면 초기화
      // - 기존: start==end(하루짜리)일 때만 해제
      // - 개선: start~end 범위가 잡혀있을 때도, start 또는 end를 누르면 해제
      final hasSelection = currentStart != null && currentEnd != null;
      final isSingleSelection = hasSelection &&
          _isSameDay(currentStart, currentEnd);

      final tappedIsStart =
          currentStart != null && _isSameDay(selected, currentStart);
      final tappedIsEnd = currentEnd != null && _isSameDay(selected, currentEnd);

      // 1) 이미 "완성된 범위(start != end)"가 있을 때:
      // - start/end를 다시 탭하면 해제
      // - 다른 날짜를 탭하면 새 범위 선택 시작(리셋)
      if (hasSelection && !isSingleSelection) {
        if (tappedIsStart || tappedIsEnd) {
          _eventStartDateNotifier.value = null;
          _eventEndDateNotifier.value = null;
        } else {
          _eventStartDateNotifier.value = selected;
          _eventEndDateNotifier.value = selected;
        }
      }
      // 2) 첫 번째 탭(아직 시작일 없음): start=end로 시작
      else if (currentStart == null) {
        // 첫 번째 날짜 선택 - 하루 단위 이벤트로 설정 (시작일과 종료일이 같음)
        _eventStartDateNotifier.value = selected;
        _eventEndDateNotifier.value = selected;
      }
      // 3) start만 있는 상태(또는 start==end로 1회 탭된 상태): 두 번째 탭으로 범위 확장
      else {
        // 같은 날짜를 다시 누르면 초기화
        if (isSingleSelection && tappedIsStart) {
          _eventStartDateNotifier.value = null;
          _eventEndDateNotifier.value = null;
        } else if (selected.isBefore(currentStart)) {
          _eventEndDateNotifier.value = currentStart;
          _eventStartDateNotifier.value = selected;
        } else {
          _eventEndDateNotifier.value = selected;
        }
        // 두 번째 날짜 선택 - 범위 이벤트로 확장
      }

      // 이벤트 범위 변경 콜백 호출
      widget.onEventRangeChanged?.call(
        _eventStartDateNotifier.value,
        _eventEndDateNotifier.value,
      );
      }
    }

    // 월 보기: 이전/다음 달 패딩 일을 탭하면 해당 월 페이지로 이동
    if (_calendarViewModeNotifier.value == CalendarViewMode.month) {
      final targetMonthIndex = _generated.months.indexWhere(
        (m) => m.year == year && m.month == month,
      );
      if (targetMonthIndex >= 0 &&
          targetMonthIndex != _currentMonthIndexNotifier.value) {
        _currentMonthIndexNotifier.value = targetMonthIndex;
        _scrollToPage(targetMonthIndex);
        widget.onMonthChanged?.call(_generated.months[targetMonthIndex]);
      }
    }

    // 뷰어 모드가 아닐 때만 onDaySelected 콜백 호출
    if (isSelectionEnabled) {
      widget.onDaySelected?.call(selected);
    }

    // 주/2주 모드에서는 선택 날짜가 현재 페이지 밖이면 해당 페이지로 이동
    final mode = _calendarViewModeNotifier.value;
    if (mode == CalendarViewMode.oneWeek || mode == CalendarViewMode.twoWeeks) {
      _ensureWeekPageVisibleForDate(selected, mode);
    }
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  /// 이벤트 범위를 초기화하는 메서드
  void resetEventRange() {
    _eventStartDateNotifier.value = null;
    _eventEndDateNotifier.value = null;
    _selectedDateNotifier.value = null;
    
    // 이벤트 범위 변경 콜백 호출
    widget.onEventRangeChanged?.call(null, null);
  }

  DateTime _startOfWeek(DateTime d) {
    final dateOnly = DateTime(d.year, d.month, d.day);
    final weekday = dateOnly.weekday % 7; // Sunday=0
    return dateOnly.subtract(Duration(days: weekday));
  }

  List<DateTime> _buildWeekStarts({
    required DateTime minDate,
    required DateTime maxDate,
    required int stepDays,
  }) {
    final starts = <DateTime>[];
    for (
      var cur = _startOfWeek(minDate);
      !cur.isAfter(maxDate);
      cur = cur.add(Duration(days: stepDays))
    ) {
      starts.add(cur);
    }
    return starts;
  }

  int _findWeekIndex({
    required List<DateTime> starts,
    required int daysPerPage,
    required DateTime target,
  }) {
    final t = DateTime(target.year, target.month, target.day);
    for (var i = 0; i < starts.length; i++) {
      final start = starts[i];
      final endExclusive = start.add(Duration(days: daysPerPage));
      if (!t.isBefore(start) && t.isBefore(endExclusive)) return i;
    }
    return 0;
  }

  void _syncMonthFromDate(DateTime date) {
    final monthIndex = _generated.months.indexWhere(
      (m) => m.year == date.year && m.month == date.month,
    );
    if (monthIndex >= 0 && monthIndex != _currentMonthIndexNotifier.value) {
      _currentMonthIndexNotifier.value = monthIndex;
      widget.onMonthChanged?.call(_generated.months[monthIndex]);
    }
  }

  void _ensureWeekPageVisibleForDate(DateTime date, CalendarViewMode viewMode) {
    final daysPerPage = viewMode == CalendarViewMode.twoWeeks ? 14 : 7;
    final starts = viewMode == CalendarViewMode.twoWeeks ? _twoWeekStarts : _oneWeekStarts;
    final targetIndex = _findWeekIndex(starts: starts, daysPerPage: daysPerPage, target: date);
    if (targetIndex == _currentWeekIndexNotifier.value) return;
    _currentWeekIndexNotifier.value = targetIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_weekPageController.hasClients) {
        _weekPageController.animateToPage(
          targetIndex,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// 년·월 선택 UI에 표시할 "현재 보고 있는" 년·월.
  ({int year, int month}) _viewedYearMonth() {
    final mode = _calendarViewModeNotifier.value;
    if (mode == CalendarViewMode.month) {
      final m = _generated.months[_currentMonthIndexNotifier.value];
      return (year: m.year, month: m.month);
    }

    final daysPerPage = mode == CalendarViewMode.twoWeeks ? 14 : 7;
    final starts =
        mode == CalendarViewMode.twoWeeks ? _twoWeekStarts : _oneWeekStarts;
    if (starts.isEmpty) {
      final fallback = _selectedDateNotifier.value ?? widget.config.initialDate;
      return (year: fallback.year, month: fallback.month);
    }

    final idx = _currentWeekIndexNotifier.value.clamp(0, starts.length - 1);
    final anchor = starts[idx];
    final rangeEnd = anchor.add(Duration(days: daysPerPage - 1));

    final selected = _selectedDateNotifier.value;
    if (selected != null) {
      final day = DateTime(selected.year, selected.month, selected.day);
      final start = DateTime(anchor.year, anchor.month, anchor.day);
      final end = DateTime(rangeEnd.year, rangeEnd.month, rangeEnd.day);
      if (!day.isBefore(start) && !day.isAfter(end)) {
        return (year: day.year, month: day.month);
      }
    }

    return (year: anchor.year, month: anchor.month);
  }

  Future<void> _handleYearHeaderTap(int year, int month) async {
    if (widget.config.yearMonthPickerUsesDialog) {
      final viewed = _viewedYearMonth();
      final result = await showYearMonthPickerDialog(
        context: context,
        selectedYear: viewed.year,
        selectedMonth: viewed.month,
        minYear: _generated.months.first.year,
        maxYear: _generated.months.last.year,
        style: widget.style,
        baseYear: widget.config.initialDate.year,
        yearRange: widget.config.yearRange,
      );
      if (result != null && mounted) {
        _applyYearMonthSelection(result.year, result.month);
      }
      return;
    }

    // 연도 선택 모드로 전환
    _isYearViewModeNotifier.value = true;
    _isYearGridModeNotifier.value = false;
    // 현재 연도로 스크롤 (PageView가 마운트된 후 실행)
    final baseYear = widget.config.initialDate.year;
    final targetYearIndex = year - (baseYear - widget.config.yearRange);
    if (targetYearIndex >= 0 && targetYearIndex < (widget.config.yearRange * 2 + 1)) {
      // PageView가 빌드되고 마운트된 후에 animateToPage 호출
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_yearViewPageController.hasClients) {
          _yearViewPageController.animateToPage(
            targetYearIndex,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _openYearGrid(int currentYear) {
    _yearGridCenterYearNotifier.value = currentYear;
    _isYearGridModeNotifier.value = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_yearGridPageController.hasClients) {
        _yearGridPageController.jumpToPage(_yearGridInitialPage);
      }
    });
  }

  void _handleYearSelectedFromGrid(int year) {
    _isYearGridModeNotifier.value = false;
    final baseYear = widget.config.initialDate.year;
    final targetYearIndex = year - (baseYear - widget.config.yearRange);
    if (targetYearIndex >= 0 && targetYearIndex < (widget.config.yearRange * 2 + 1)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_yearViewPageController.hasClients) {
          _yearViewPageController.animateToPage(
            targetYearIndex,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _handleMonthSelected(int year, int month) {
    // 연도 선택 모드 종료 (먼저 종료)
    _isYearViewModeNotifier.value = false;
    _isYearGridModeNotifier.value = false;
    _applyYearMonthSelection(
      year,
      month,
      forceMonthView: true,
      updateSelectedDate: false,
    );
  }

  void _applyYearMonthSelection(
    int year,
    int month, {
    bool forceMonthView = false,
    bool updateSelectedDate = true,
  }) {
    if (forceMonthView) {
      _calendarViewModeNotifier.value = CalendarViewMode.month;
    }

    DateTime? selected;
    if (updateSelectedDate) {
      final current = _selectedDateNotifier.value ?? widget.config.initialDate;
      final lastDay = DateTime(year, month + 1, 0).day;
      final day = current.day.clamp(1, lastDay);
      selected = DateTime(year, month, day);

      final isSelectionEnabled =
          widget.config.selectionMode != CalendarSelectionMode.none;
      if (isSelectionEnabled) {
        _selectedDateNotifier.value = selected;
        if (widget.config.selectionMode == CalendarSelectionMode.range) {
          _eventStartDateNotifier.value = selected;
          _eventEndDateNotifier.value = selected;
          widget.onEventRangeChanged?.call(selected, selected);
        } else {
          _eventStartDateNotifier.value = selected;
          _eventEndDateNotifier.value = selected;
          widget.onEventRangeChanged?.call(selected, selected);
        }
        widget.onDaySelected?.call(selected);
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final targetMonthIndex = _generated.months.indexWhere(
        (m) => m.year == year && m.month == month,
      );
      if (targetMonthIndex < 0) return;

      _currentMonthIndexNotifier.value = targetMonthIndex;
      widget.onMonthChanged?.call(_generated.months[targetMonthIndex]);
      widget.onCalendarPageAnchorChanged?.call(_generated.months[targetMonthIndex]);

      final mode = _calendarViewModeNotifier.value;
      if (mode == CalendarViewMode.month) {
        if (_pageController.hasClients) {
          _pageController.animateToPage(
            targetMonthIndex,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      } else if (selected != null) {
        _ensureWeekPageVisibleForDate(selected, mode);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DateTime?>(
      valueListenable: _selectedDateNotifier,
      builder: (context, selectedDate, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: _isYearViewModeNotifier,
          builder: (context, isYearViewMode, _) {
            return ValueListenableBuilder<CalendarViewMode>(
              valueListenable: _calendarViewModeNotifier,
              builder: (context, viewMode, _) {
                return ValueListenableBuilder<bool>(
                  valueListenable: _isYearGridModeNotifier,
                  builder: (context, isYearGridMode, _) {
                    return widget.builder(
                      context,
                      selectedDate,
                      isYearViewMode
                          ? (isYearGridMode ? _buildYearGridView() : _buildYearView())
                          : _buildCalendar(viewMode),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildCalendar(CalendarViewMode viewMode) {
    // viewMode가 바뀌는 순간에만 컨트롤러를 "선택 날짜 기준"으로 1회 동기화
    if (_lastViewModeSynced != viewMode) {
      _lastViewModeSynced = viewMode;
      final target = _selectedDateNotifier.value ?? widget.config.initialDate;

      if (viewMode == CalendarViewMode.month) {
        final monthIndex = _generated.months.indexWhere(
          (m) => m.year == target.year && m.month == target.month,
        );
        if (monthIndex >= 0) {
          _currentMonthIndexNotifier.value = monthIndex;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_pageController.hasClients) {
              _pageController.jumpToPage(monthIndex);
            }
          });
        }
      } else {
        final daysPerPage = viewMode == CalendarViewMode.twoWeeks ? 14 : 7;
        final starts = viewMode == CalendarViewMode.twoWeeks ? _twoWeekStarts : _oneWeekStarts;
        final targetIndex = _findWeekIndex(starts: starts, daysPerPage: daysPerPage, target: target);
        _currentWeekIndexNotifier.value = targetIndex;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_weekPageController.hasClients) {
            _weekPageController.jumpToPage(targetIndex);
          }
        });
      }
    }

    if (viewMode == CalendarViewMode.month) {
      final scrollDirection =
          widget.config.pageScrollDirection == CalendarPageScrollDirection.horizontal
              ? Axis.horizontal
              : Axis.vertical;

      return PageView.builder(
        controller: _pageController,
        scrollDirection: scrollDirection,
        padEnds: true,
        onPageChanged: (index) {
          _currentMonthIndexNotifier.value = index;
          final m = _generated.months[index];
          widget.onMonthChanged?.call(m);
          widget.onCalendarPageAnchorChanged?.call(m);
        },
        itemCount: _generated.months.length,
        itemBuilder: (context, index) {
          final monthDate = _generated.months[index];

          return RepaintBoundary(
            child: Align(
              alignment: Alignment.topCenter,
              child: _CalendarPageWidget(
              year: monthDate.year,
              month: monthDate.month,
              pageIndex: index,
              currentMonthIndexNotifier: _currentMonthIndexNotifier,
              selectedDateNotifier: _selectedDateNotifier,
              eventStartDateNotifier: _eventStartDateNotifier,
              eventEndDateNotifier: _eventEndDateNotifier,
              registeredEventsNotifier: _registeredEventsNotifier,
              selectionMode: widget.config.selectionMode,
              showMonthArrowButtons: widget.config.showMonthArrowButtons,
              onTap: () => _scrollToPage(index),
              onDaySelected: _handleDaySelected,
              onYearHeaderTap: _handleYearHeaderTap,
              onPreviousMonthTap: () => _moveMonth(-1),
              onNextMonthTap: () => _moveMonth(1),
              viewMode: viewMode,
              onViewModeSelected:
                  widget.showViewModeToggle ? setCalendarViewMode : null,
              style: widget.style,
            ),
            ),
          );
        },
      );
    }

    // 1주/2주 모드: 주 단위 PageView
    final scrollDirection =
        widget.config.pageScrollDirection == CalendarPageScrollDirection.horizontal
            ? Axis.horizontal
            : Axis.vertical;

    final daysPerPage = viewMode == CalendarViewMode.twoWeeks ? 14 : 7;
    final starts = viewMode == CalendarViewMode.twoWeeks ? _twoWeekStarts : _oneWeekStarts;

    return PageView.builder(
      controller: _weekPageController,
      scrollDirection: scrollDirection,
      padEnds: true,
      onPageChanged: (index) {
        _currentWeekIndexNotifier.value = index;
        final anchor = starts[index];
        _syncMonthFromDate(anchor);
        widget.onCalendarPageAnchorChanged?.call(anchor);
      },
      itemCount: starts.length,
      itemBuilder: (context, index) {
        final start = starts[index];
        return RepaintBoundary(
          child: _WeekPageWidget(
            startDate: start,
            daysPerPage: daysPerPage,
            pageIndex: index,
            currentWeekIndexNotifier: _currentWeekIndexNotifier,
            selectedDateNotifier: _selectedDateNotifier,
            eventStartDateNotifier: _eventStartDateNotifier,
            eventEndDateNotifier: _eventEndDateNotifier,
            registeredEventsNotifier: _registeredEventsNotifier,
            selectionMode: widget.config.selectionMode,
            showMonthArrowButtons: widget.config.showMonthArrowButtons,
            onTap: () {
              if (_weekPageController.hasClients) {
                _weekPageController.animateToPage(
                  index,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              }
            },
            onDaySelected: _handleDaySelected,
            onYearHeaderTap: _handleYearHeaderTap,
            onPreviousPageTap: () => _moveWeek(-1, viewMode),
            onNextPageTap: () => _moveWeek(1, viewMode),
            viewMode: viewMode,
            onViewModeSelected:
                widget.showViewModeToggle ? setCalendarViewMode : null,
            style: widget.style,
          ),
        );
      },
    );
  }

  Widget _buildYearView() {
    final baseYear = widget.config.initialDate.year;
    final yearCount = widget.config.yearRange * 2 + 1;

    return PageView.builder(
      controller: _yearViewPageController,
      scrollDirection: Axis.vertical,
      padEnds: true,
      itemCount: yearCount,
      itemBuilder: (context, yearIndex) {
        final year = baseYear - widget.config.yearRange + yearIndex;
        final currentMonth = _generated.months[_currentMonthIndexNotifier.value];
        final isCurrentYear = year == currentMonth.year;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: GestureDetector(
                onTap: () => _openYearGrid(year),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$year년',
                      style: widget.style.headerTextStyle.copyWith(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: widget.style.headerTextStyle.color ?? Colors.black,
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              // 다이얼로그/제한된 높이에서도 잘리지 않도록 "월 선택(12개)" 그리드는 스크롤 가능하게 유지
              child: GridView.builder(
                padding: const EdgeInsets.all(10),
                physics: const AlwaysScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 5,
                  mainAxisSpacing: 5,
                  childAspectRatio: 1.0,
                ),
                itemCount: 12,
                itemBuilder: (context, monthIndex) {
                  final month = monthIndex + 1;
                  final isCurrentMonth =
                      isCurrentYear && month == currentMonth.month;

                  return _buildMiniCalendar(
                    year: year,
                    month: month,
                    isCurrentMonth: isCurrentMonth,
                    onTap: () => _handleMonthSelected(year, month),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildYearGridView() {
    final minYear = _generated.months.first.year;
    final maxYear = _generated.months.last.year;

    return ValueListenableBuilder<int>(
      valueListenable: _yearGridCenterYearNotifier,
      builder: (context, centerYear, _) {
        return PageView.builder(
          controller: _yearGridPageController,
          scrollDirection: Axis.vertical,
          itemBuilder: (context, pageIndex) {
            final pageOffset = pageIndex - _yearGridInitialPage;
            final pageCenterYear = centerYear + (pageOffset * 9);
            final startYear = pageCenterYear - 4;
            final currentYear = _generated.months[_currentMonthIndexNotifier.value].year;

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '연도 선택',
                        style: widget.style.headerTextStyle.copyWith(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(12),
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1.5,
                    ),
                    itemCount: 9,
                    itemBuilder: (context, index) {
                      final year = startYear + index;
                      final isInRange = year >= minYear && year <= maxYear;
                      final isSelected = year == currentYear;

                      return GestureDetector(
                        onTap: isInRange ? () => _handleYearSelectedFromGrid(year) : null,
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected
                                ? widget.style.focusedMonthBackgroundColor
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? widget.style.focusedMonthBorderColor
                                  : Colors.grey.shade300,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '$year',
                            style: widget.style.headerTextStyle.copyWith(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: isInRange
                                  ? (isSelected
                                      ? widget.style.focusedMonthBorderColor
                                      : (widget.style.headerTextStyle.color ?? Colors.black))
                                  : Colors.grey.shade400,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildMiniCalendar({
    required int year,
    required int month,
    required bool isCurrentMonth,
    required VoidCallback onTap,
  }) {
    final firstDayOfMonth = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final firstWeekday = firstDayOfMonth.weekday % 7;
    final totalCells = firstWeekday + daysInMonth;
    final weeks = (totalCells / 7).ceil();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isCurrentMonth
              ? widget.style.focusedMonthBackgroundColor
              : Colors.transparent,
          borderRadius: widget.style.calendarBorderRadius,
          border: isCurrentMonth
              ? Border.all(color: widget.style.focusedMonthBorderColor, width: 1.5)
              : Border.all(color: Colors.grey.shade300, width: 1),
        ),
        padding: const EdgeInsets.all(5),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // 사용 가능한 공간 계산
            final availableWidth = constraints.maxWidth;
            final availableHeight = constraints.maxHeight;
            final headerHeight = 18.0;
            final spacing = 4.0;
            
            // 셀 크기 계산 (너비와 높이 중 작은 값 사용)
            final cellWidth = (availableWidth - 12) / 7; // padding 제외
            final cellHeight = (availableHeight - headerHeight - spacing) / weeks;
            final cellSize = cellWidth < cellHeight ? cellWidth : cellHeight;
            final finalCellSize = cellSize.clamp(10.0, 25.0); // 최소/최대 크기 제한

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$month월',
                  style: widget.style.headerTextStyle.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: spacing),
                // 고정 높이로 GridView 사용
                Expanded(
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      childAspectRatio: 1.0,
                      mainAxisSpacing: 1,
                      crossAxisSpacing: 1,
                    ),
                    itemCount: totalCells,
                    itemBuilder: (context, index) {
                      if (index < firstWeekday) {
                        return const SizedBox.shrink();
                      } else {
                        final day = index - firstWeekday + 1;
                        return Center(
                          child: Text(
                            day.toString(),
                            style: widget.style.dayTextStyle.copyWith(
                              fontSize: finalCellSize * 0.45,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// 각 달력 페이지를 독립적으로 관리하는 위젯
/// ValueListenableBuilder를 내부에서만 사용하여 불필요한 rebuild 방지
class _CalendarPageWidget extends StatelessWidget {
  const _CalendarPageWidget({
    required this.year,
    required this.month,
    required this.pageIndex,
    required this.currentMonthIndexNotifier,
    required this.selectedDateNotifier,
    required this.eventStartDateNotifier,
    required this.eventEndDateNotifier,
    required this.registeredEventsNotifier,
    required this.selectionMode,
    required this.showMonthArrowButtons,
    required this.onTap,
    required this.onDaySelected,
    required this.onYearHeaderTap,
    required this.onPreviousMonthTap,
    required this.onNextMonthTap,
    required this.viewMode,
    this.onViewModeSelected,
    required this.style,
  });

  final int year;
  final int month;
  final int pageIndex;
  final ValueNotifier<int> currentMonthIndexNotifier;
  final ValueNotifier<DateTime?> selectedDateNotifier;
  final ValueNotifier<DateTime?> eventStartDateNotifier;
  final ValueNotifier<DateTime?> eventEndDateNotifier;
  final ValueNotifier<List<CalendarEvent>> registeredEventsNotifier;
  final CalendarSelectionMode selectionMode;
  final bool showMonthArrowButtons;
  final VoidCallback onTap;
  final void Function(int year, int month, int day) onDaySelected;
  final void Function(int year, int month) onYearHeaderTap;
  final VoidCallback onPreviousMonthTap;
  final VoidCallback onNextMonthTap;
  final CalendarViewMode viewMode;
  final void Function(CalendarViewMode mode)? onViewModeSelected;
  final CalendarStyle style;

  @override
  Widget build(BuildContext context) {
    // 포커스 상태를 별도로 리스닝하여 필요한 페이지만 업데이트
    return ValueListenableBuilder<int>(
      valueListenable: currentMonthIndexNotifier,
      builder: (context, currentPage, _) {
        final isFocused = pageIndex == currentPage;
        
        // registeredEvents는 자주 변경되지 않으므로 별도로 처리
        return ValueListenableBuilder<List<CalendarEvent>>(
          valueListenable: registeredEventsNotifier,
          builder: (context, registeredEvents, _) {
            // 나머지 값들은 함께 처리 (더 효율적)
            return ValueListenableBuilder<DateTime?>(
              valueListenable: selectedDateNotifier,
              builder: (context, selectedDate, _) {
                return ValueListenableBuilder<DateTime?>(
                  valueListenable: eventStartDateNotifier,
                  builder: (context, eventStart, _) {
                    return ValueListenableBuilder<DateTime?>(
                      valueListenable: eventEndDateNotifier,
                      builder: (context, eventEnd, _) {
                      return BuildCalendarWidget(
                        key: ValueKey('$year-$month'), // 키로 메모이제이션
                        year: year,
                        month: month,
                        isFocused: isFocused,
                        pageIndex: pageIndex,
                        currentPage: currentPage,
                        selectedDate: selectedDate,
                        eventStartDate: eventStart,
                        eventEndDate: eventEnd,
                        registeredEvents: registeredEvents,
                        selectionMode: selectionMode,
                        showMonthArrowButtons: showMonthArrowButtons,
                        onTap: onTap,
                        onDaySelected: onDaySelected,
                        onYearHeaderTap: onYearHeaderTap,
                        onPreviousMonthTap: onPreviousMonthTap,
                        onNextMonthTap: onNextMonthTap,
                        viewMode: viewMode,
                        onViewModeSelected: onViewModeSelected,
                        style: style,
                      );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

class _WeekPageWidget extends StatelessWidget {
  const _WeekPageWidget({
    required this.startDate,
    required this.daysPerPage,
    required this.pageIndex,
    required this.currentWeekIndexNotifier,
    required this.selectedDateNotifier,
    required this.eventStartDateNotifier,
    required this.eventEndDateNotifier,
    required this.registeredEventsNotifier,
    required this.selectionMode,
    required this.showMonthArrowButtons,
    required this.onTap,
    required this.onDaySelected,
    required this.onYearHeaderTap,
    required this.onPreviousPageTap,
    required this.onNextPageTap,
    required this.viewMode,
    this.onViewModeSelected,
    required this.style,
  });

  final DateTime startDate;
  final int daysPerPage;
  final int pageIndex;
  final ValueNotifier<int> currentWeekIndexNotifier;
  final ValueNotifier<DateTime?> selectedDateNotifier;
  final ValueNotifier<DateTime?> eventStartDateNotifier;
  final ValueNotifier<DateTime?> eventEndDateNotifier;
  final ValueNotifier<List<CalendarEvent>> registeredEventsNotifier;
  final CalendarSelectionMode selectionMode;
  final bool showMonthArrowButtons;
  final VoidCallback onTap;
  final void Function(int year, int month, int day) onDaySelected;
  final void Function(int year, int month) onYearHeaderTap;
  final VoidCallback onPreviousPageTap;
  final VoidCallback onNextPageTap;
  final CalendarViewMode viewMode;
  final void Function(CalendarViewMode mode)? onViewModeSelected;
  final CalendarStyle style;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: currentWeekIndexNotifier,
      builder: (context, currentPage, _) {
        final isFocused = pageIndex == currentPage;
        return ValueListenableBuilder<List<CalendarEvent>>(
          valueListenable: registeredEventsNotifier,
          builder: (context, registeredEvents, _) {
            return ValueListenableBuilder<DateTime?>(
              valueListenable: selectedDateNotifier,
              builder: (context, selectedDate, _) {
                return ValueListenableBuilder<DateTime?>(
                  valueListenable: eventStartDateNotifier,
                  builder: (context, eventStart, _) {
                    return ValueListenableBuilder<DateTime?>(
                      valueListenable: eventEndDateNotifier,
                      builder: (context, eventEnd, _) {
                        return SizedBox.expand(
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: BuildWeekWidget(
                              key: ValueKey('week-${startDate.year}-${startDate.month}-${startDate.day}-$daysPerPage'),
                              startDate: startDate,
                              days: daysPerPage,
                              isFocused: isFocused,
                              pageIndex: pageIndex,
                              currentPage: currentPage,
                              selectedDate: selectedDate,
                              eventStartDate: eventStart,
                              eventEndDate: eventEnd,
                              registeredEvents: registeredEvents,
                              selectionMode: selectionMode,
                              showMonthArrowButtons: showMonthArrowButtons,
                              onTap: onTap,
                              onDaySelected: onDaySelected,
                              onYearHeaderTap: onYearHeaderTap,
                              onPreviousPageTap: onPreviousPageTap,
                              onNextPageTap: onNextPageTap,
                              viewMode: viewMode,
                              onViewModeSelected: onViewModeSelected,
                              style: style,
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}



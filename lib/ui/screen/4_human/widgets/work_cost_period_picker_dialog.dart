import 'package:flutter/material.dart';
import 'package:w0001/enums.dart';
import 'package:w0001/theme/app_colors.dart';
import 'package:w0001/theme/app_theme_colors.dart';
import 'package:w0001/theme/app_section_card.dart';
import 'package:w0001/ui/widget/scrollable_calendar/scrollable_calendar_widget.dart';
import 'package:w0001/util/funtions.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 인건비 탭 기간 선택 결과.
typedef WorkCostPeriodPickResult = ({
  DateTimeRange range,
  DayTpye periodType,
});

enum _PeriodPickMode { range, year, whole }

/// 기간 선택 — 모드(범위·연도·전체) + 캘린더/연도 휠.
Future<WorkCostPeriodPickResult?> showWorkCostPeriodPickerDialog(
  BuildContext context, {
  required DateTimeRange initialRange,
  required DayTpye initialPeriodType,
}) {
  return showDialog<WorkCostPeriodPickResult>(
    context: context,
    builder: (ctx) => _WorkCostPeriodPickerDialog(
      initialRange: initialRange,
      initialPeriodType: initialPeriodType,
    ),
  );
}

class _WorkCostPeriodPickerDialog extends StatefulWidget {
  const _WorkCostPeriodPickerDialog({
    required this.initialRange,
    required this.initialPeriodType,
  });

  final DateTimeRange initialRange;
  final DayTpye initialPeriodType;

  @override
  State<_WorkCostPeriodPickerDialog> createState() =>
      _WorkCostPeriodPickerDialogState();
}

class _WorkCostPeriodPickerDialogState
    extends State<_WorkCostPeriodPickerDialog> {
  late _PeriodPickMode _mode;
  late int _selectedYear;
  late FixedExtentScrollController _yearWheelController;
  DateTime? _rangeStart;
  DateTime? _rangeEnd;
  late DateTime _calendarViewMonth;

  static final _wholeRange = DateTimeRange(
    start: DateTime(2000, 1, 1),
    end: DateTime(2099, 12, 31),
  );

  static const _minYear = 2000;

  int get _maxYear => DateTime.now().year;

  int get _yearItemCount => _maxYear - _minYear + 1;

  int _indexForYear(int year) => (_maxYear - year).clamp(0, _yearItemCount - 1);

  @override
  void initState() {
    super.initState();
    _applyInitial(widget.initialPeriodType, widget.initialRange);
    _yearWheelController = FixedExtentScrollController(
      initialItem: _indexForYear(_selectedYear),
    );
  }

  @override
  void dispose() {
    _yearWheelController.dispose();
    super.dispose();
  }

  void _applyInitial(DayTpye type, DateTimeRange range) {
    _calendarViewMonth = DateTime(range.start.year, range.start.month, 1);
    switch (type) {
      case DayTpye.whole:
        _mode = _PeriodPickMode.whole;
        _selectedYear = DateTime.now().year;
        _rangeStart = null;
        _rangeEnd = null;
      case DayTpye.year:
        _mode = _PeriodPickMode.year;
        _selectedYear = range.start.year.clamp(_minYear, _maxYear);
        _rangeStart = range.start;
        _rangeEnd = range.end;
      case DayTpye.month:
      case DayTpye.range:
        _mode = _PeriodPickMode.range;
        _selectedYear = range.start.year;
        _rangeStart = range.start;
        _rangeEnd = range.end;
    }
  }

  void _setMode(_PeriodPickMode mode) {
    setState(() {
      _mode = mode;
      if (mode == _PeriodPickMode.whole) {
        _rangeStart = null;
        _rangeEnd = null;
      } else if (mode == _PeriodPickMode.year) {
        final year =
            (_rangeStart?.year ?? _selectedYear).clamp(_minYear, _maxYear);
        _syncYearWheel(year);
      }
    });
  }

  void _syncYearWheel(int year) {
    final clamped = year.clamp(_minYear, _maxYear);
    _selectedYear = clamped;
    final index = _indexForYear(clamped);
    if (_yearWheelController.hasClients) {
      _yearWheelController.animateToItem(
        index,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    } else {
      _yearWheelController.jumpToItem(index);
    }
  }

  void _onYearWheelChanged(int index) {
    final year = _maxYear - index;
    if (year == _selectedYear) return;
    setState(() => _selectedYear = year);
  }

  void _onCalendarAnchorChanged(DateTime anchor) {
    final month = DateTime(anchor.year, anchor.month, 1);
    if (_calendarViewMonth.year == month.year &&
        _calendarViewMonth.month == month.month) {
      return;
    }
    setState(() => _calendarViewMonth = month);
  }

  void _applyViewingMonth() {
    final range = getMonthDateRange(_calendarViewMonth);
    setState(() {
      _rangeStart = range.start;
      _rangeEnd = range.end;
    });
  }

  String _viewingMonthButtonLabel() =>
      '${_calendarViewMonth.year}년 ${_calendarViewMonth.month}월';

  bool _isViewingMonthApplied() {
    final start = _rangeStart;
    final end = _rangeEnd ?? start;
    if (start == null || end == null) return false;
    final monthRange = getMonthDateRange(_calendarViewMonth);
    return start.year == monthRange.start.year &&
        start.month == monthRange.start.month &&
        start.day == monthRange.start.day &&
        end.year == monthRange.end.year &&
        end.month == monthRange.end.month &&
        end.day == monthRange.end.day;
  }

  Widget _viewingMonthQueryBar(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final applied = _isViewingMonthApplied();

    return AppInsetTile(
      borderRadius: BorderRadius.circular(12),
      backgroundColor:
          applied ? cs.primaryContainer.withValues(alpha: 0.72) : null,
      child: Material(
        color: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _applyViewingMonth,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: context.rsi(14),
              vertical: context.rsi(12),
            ),
            child: Row(
              children: [
                DecoratedBox(
                  decoration: AppSectionCardStyles.iconBadgeDecoration(
                    context,
                    cs,
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(context.rsi(8)),
                    child: Icon(
                      Icons.calendar_view_month_rounded,
                      size: context.rs(22),
                      color: applied ? cs.primary : cs.onSurfaceVariant,
                    ),
                  ),
                ),
                SizedBox(width: context.rsi(12)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_viewingMonthButtonLabel()} 조회',
                        style: tt.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: applied ? cs.onPrimaryContainer : cs.onSurface,
                        ),
                      ),
                      SizedBox(height: context.rsi(2)),
                      Text(
                        applied ? '이 달 전체가 선택되었습니다' : '캘린더에서 보고 있는 달 전체',
                        style: tt.bodySmall?.copyWith(
                          color: applied
                              ? cs.onPrimaryContainer.withValues(alpha: 0.78)
                              : cs.onSurfaceVariant,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: context.rsi(8)),
                Icon(
                  applied
                      ? Icons.check_circle_rounded
                      : Icons.touch_app_rounded,
                  size: context.rs(20),
                  color: applied ? cs.primary : cs.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onCalendarRangeChanged(DateTime? start, DateTime? end) {
    if (_mode != _PeriodPickMode.range) return;
    setState(() {
      _rangeStart = start;
      _rangeEnd = end;
    });
  }

  WorkCostPeriodPickResult? _buildResult() {
    switch (_mode) {
      case _PeriodPickMode.whole:
        return (range: _wholeRange, periodType: DayTpye.whole);
      case _PeriodPickMode.year:
        return (
          range: getYearDateRange(_selectedYear),
          periodType: DayTpye.year,
        );
      case _PeriodPickMode.range:
        final s = _rangeStart;
        if (s == null) return null;

        final e = _rangeEnd ?? s;
        final normalized = s.isBefore(e) || s.isAtSameMomentAs(e)
            ? DateTimeRange(start: s, end: e)
            : DateTimeRange(start: e, end: s);

        if (isFullYearDateRange(normalized)) {
          return (range: normalized, periodType: DayTpye.year);
        }

        final start = normalized.start;
        final end = normalized.end;
        final isFullMonth = start.day == 1 &&
            end.year == start.year &&
            end.month == start.month &&
            end.day == DateTime(start.year, start.month + 1, 0).day;
        if (isFullMonth) {
          return (range: normalized, periodType: DayTpye.month);
        }

        return (range: normalized, periodType: DayTpye.range);
    }
  }

  String _summaryText() {
    final result = _buildResult();
    if (result == null) {
      return '캘린더에서 시작일을 선택하세요';
    }
    return formatDateTimeRangeToString(
      result.range,
      periodType: result.periodType,
    );
  }

  Widget _yearPicker() {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      children: [
        Text(
          '조회할 연도를 선택하세요',
          style: tt.labelLarge?.copyWith(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: context.rsi(8)),
        Expanded(
          child: AppInsetTile(
            borderRadius: BorderRadius.circular(16),
            backgroundColor: cs.appMutedFill,
            child: ListWheelScrollView.useDelegate(
              controller: _yearWheelController,
              itemExtent: context.rs(48),
              diameterRatio: 1.35,
              perspective: 0.003,
              physics: const FixedExtentScrollPhysics(),
              onSelectedItemChanged: _onYearWheelChanged,
              childDelegate: ListWheelChildBuilderDelegate(
                childCount: _yearItemCount,
                builder: (context, index) {
                  final year = _maxYear - index;
                  final selected = year == _selectedYear;
                  return Center(
                    child: Text(
                      '$year년',
                      style:
                          (selected ? tt.titleLarge : tt.bodyLarge)?.copyWith(
                        fontWeight:
                            selected ? FontWeight.w800 : FontWeight.w500,
                        color: selected ? cs.primary : cs.onSurfaceVariant,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _modeBody(BoxConstraints constraints) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    switch (_mode) {
      case _PeriodPickMode.whole:
        return Center(
          child: Padding(
            padding: EdgeInsets.all(context.rsi(20)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.all_inclusive_rounded,
                  size: context.rs(44),
                  color: cs.tertiary,
                ),
                SizedBox(height: context.rsi(12)),
                Text(
                  '등록된 모든 인건비를 조회합니다',
                  textAlign: TextAlign.center,
                  style: tt.bodyLarge?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        );
      case _PeriodPickMode.year:
        return _yearPicker();
      case _PeriodPickMode.range:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _viewingMonthQueryBar(context),
            SizedBox(height: context.rsi(8)),
            Expanded(
              child: LayoutBuilder(
                builder: (context, inner) {
                  return ScrollableCalendarWidget(
                    key: ValueKey(
                      'range-${_rangeStart?.millisecondsSinceEpoch ?? 0}-'
                      '${_rangeEnd?.millisecondsSinceEpoch ?? 0}',
                    ),
                    height: inner.maxHeight,
                    initialRangeStart: _rangeStart,
                    initialRangeEnd: _rangeEnd,
                    initialSelectedDay: _rangeStart ?? _calendarViewMonth,
                    showViewModeToggle: false,
                    showRangeSummarySection: false,
                    disableDateSelectionHighlight: true,
                    onMonthChanged: _onCalendarAnchorChanged,
                    onCalendarPageAnchorChanged: _onCalendarAnchorChanged,
                    onRangeChanged: _onCalendarRangeChanged,
                  );
                },
              ),
            ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final screenH = MediaQuery.sizeOf(context).height;
    final dialogH = (screenH * 0.72).clamp(420.0, 580.0);
    final canConfirm = _buildResult() != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: EdgeInsets.symmetric(horizontal: context.rsi(16)),
      child: SizedBox(
        width: MediaQuery.sizeOf(context).width * 0.92,
        height: dialogH,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            context.rsi(14),
            context.rsi(10),
            context.rsi(14),
            context.rsi(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '기간 선택',
                textAlign: TextAlign.center,
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              SizedBox(height: context.rsi(10)),
              _PeriodModeTabs(
                mode: _mode,
                onChanged: _setMode,
              ),
              SizedBox(height: context.rsi(10)),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => _modeBody(constraints),
                ),
              ),
              SizedBox(height: context.rsi(8)),
              AppInsetTile(
                borderRadius: BorderRadius.circular(12),
                padding: EdgeInsets.symmetric(
                  horizontal: context.rsi(12),
                  vertical: context.rsi(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.event_note_rounded,
                      size: context.rs(18),
                      color: cs.primary,
                    ),
                    SizedBox(width: context.rsi(8)),
                    Expanded(
                      child: Text(
                        _summaryText(),
                        style: tt.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: context.rsi(8)),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('취소'),
                  ),
                  FilledButton(
                    onPressed: canConfirm
                        ? () {
                            final result = _buildResult();
                            if (result == null) return;
                            Navigator.of(context).pop(result);
                          }
                        : null,
                    child: const Text('확인'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PeriodModeTabs extends StatelessWidget {
  const _PeriodModeTabs({
    required this.mode,
    required this.onChanged,
  });

  final _PeriodPickMode mode;
  final ValueChanged<_PeriodPickMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    Widget tab({
      required _PeriodPickMode value,
      required String label,
    }) {
      final selected = mode == value;
      return Expanded(
        child: AppInsetTile(
          borderRadius: BorderRadius.circular(10),
          backgroundColor: selected
              ? cs.primaryContainer.withValues(alpha: 0.72)
              : cs.appMutedFill,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onChanged(value),
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                height: context.rs(40),
                child: Center(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.fade,
                    softWrap: false,
                    style: tt.labelLarge?.copyWith(
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      color: selected
                          ? cs.onPrimaryContainer
                          : cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        tab(value: _PeriodPickMode.range, label: '기간 지정'),
        SizedBox(width: context.rsi(6)),
        tab(value: _PeriodPickMode.year, label: '연도별'),
        SizedBox(width: context.rsi(6)),
        tab(value: _PeriodPickMode.whole, label: '전체'),
      ],
    );
  }
}

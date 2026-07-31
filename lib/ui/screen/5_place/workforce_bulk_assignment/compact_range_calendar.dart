import 'package:flutter/material.dart';
import 'package:w0001/domain/process_schedule/process_schedule_models.dart';
import 'package:w0001/util/responsive_layout.dart';
import 'models.dart';

/// 커스텀 범위 캘린더 위젯 (간트차트 통합 - 월별 표시)
class CompactRangeCalendar extends StatefulWidget {
  const CompactRangeCalendar({
    super.key,
    required this.processStart,
    required this.processEnd,
    required this.initialStart,
    required this.initialEnd,
    required this.allProcessEvents,
    required this.onRangeChanged,
    this.selectedTask,
  });

  final DateTime processStart;
  final DateTime processEnd;
  final DateTime initialStart;
  final DateTime initialEnd;
  final List<ProcessEventData> allProcessEvents;
  final Function(DateTime start, DateTime end) onRangeChanged;
  final ProcessScheduleTask? selectedTask; // 선택된 공정 (강조용)

  @override
  State<CompactRangeCalendar> createState() => _CompactRangeCalendarState();
}

class _CompactRangeCalendarState extends State<CompactRangeCalendar> {
  late DateTime _rangeStart;
  late DateTime _rangeEnd;
  DateTime? _selectionStart;
  late DateTime _currentMonth;

  @override
  void initState() {
    super.initState();
    _rangeStart = widget.initialStart;
    _rangeEnd = widget.initialEnd;

    DateTime focusDate = widget.processStart;

    if (widget.selectedTask != null) {
      for (final event in widget.allProcessEvents) {
        if (_isSelectedEvent(event)) {
          focusDate = event.startDate;
          break;
        }
      }
    }

    _currentMonth = DateTime(focusDate.year, focusDate.month, 1);
  }

  /// 두 공정이 같은 행인지 비교 (이름만으로는 동일 공정으로 보지 않음).
  bool _isSameTask(ProcessScheduleTask task1, ProcessScheduleTask task2) {
    if (identical(task1, task2)) return true;
    final id1 = task1.serverId?.trim();
    final id2 = task2.serverId?.trim();
    if (id1 != null && id1.isNotEmpty && id2 != null && id2.isNotEmpty) {
      return id1 == id2;
    }
    return false;
  }

  bool _isSelectedEvent(ProcessEventData event) {
    if (widget.selectedTask == null) return false;
    if (identical(event.task, widget.selectedTask)) return true;
    return _isSameTask(event.task, widget.selectedTask!);
  }

  /// 선택 공정은 primary, 나머지는 중립 outline.
  Color _getProcessColor(BuildContext context, ProcessEventData event) {
    final cs = Theme.of(context).colorScheme;
    return _isSelectedEvent(event) ? cs.primary : cs.outlineVariant;
  }

  /// 표시할 날짜 범위 계산 (월별 - 일요일부터 시작하도록 패딩 포함)
  List<DateTime> _getDisplayDates() {
    final firstDayOfMonth =
        DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDayOfMonth =
        DateTime(_currentMonth.year, _currentMonth.month + 1, 0);

    // DateTime.weekday: 월=1 … 일=7 → 일요일 시작이면 일=0
    final firstWeekday = firstDayOfMonth.weekday % 7;
    final startDate = firstDayOfMonth.subtract(Duration(days: firstWeekday));

    // 주 끝은 토요일 — 마지막날이 토요일이 아니면 다음 월 날짜로 패딩
    final lastWeekday = lastDayOfMonth.weekday % 7;
    final endDate = lastDayOfMonth.add(Duration(days: 6 - lastWeekday));

    final dates = <DateTime>[];
    var current = startDate;
    while (!current.isAfter(endDate)) {
      dates.add(current);
      current = current.add(const Duration(days: 1));
    }

    return dates;
  }

  /// 이전 월로 이동
  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
    });
  }

  /// 다음 월로 이동
  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
    });
  }

  /// 날짜가 선택 범위 내인지
  bool _isInSelectedRange(DateTime date) {
    return !date.isBefore(_rangeStart) && !date.isAfter(_rangeEnd);
  }

  /// 날짜 탭 처리
  void _handleDateTap(DateTime date) {
    setState(() {
      if (_selectionStart == null) {
        // 첫 번째 날짜 선택
        _selectionStart = date;
        _rangeStart = date;
        _rangeEnd = date;
      } else {
        // 두 번째 날짜 선택
        if (date.isBefore(_selectionStart!)) {
          _rangeStart = date;
          _rangeEnd = _selectionStart!;
        } else {
          _rangeStart = _selectionStart!;
          _rangeEnd = date;
        }
        _selectionStart = null;

        // 콜백 호출
        widget.onRangeChanged(_rangeStart, _rangeEnd);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final dates = _getDisplayDates();

    // 공정별 간트차트 레이어 생성
    final Map<String, List<(DateTime start, DateTime end)>> processRanges = {};
    for (final event in widget.allProcessEvents) {
      final key = processTaskKey(event.task, event.taskIndex);
      processRanges.putIfAbsent(key, () => []);
      processRanges[key]!.add((event.startDate, event.endDate));
    }

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity != null) {
          if (details.primaryVelocity! > 0) {
            _previousMonth();
          } else if (details.primaryVelocity! < 0) {
            _nextMonth();
          }
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 헤더: 네비게이션
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: _previousMonth,
                icon: const Icon(Icons.chevron_left),
                iconSize: context.rs(24),
                padding: ResponsiveLayout.all(context, 8),
                constraints: BoxConstraints(
                  minWidth: context.rs(36),
                  minHeight: context.rs(36),
                ),
              ),
              Text(
                '${_currentMonth.year}년 ${_currentMonth.month}월',
                style: tt.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: context.rs(17),
                ),
                textAlign: TextAlign.center,
              ),
              IconButton(
                onPressed: _nextMonth,
                icon: const Icon(Icons.chevron_right),
                iconSize: context.rs(24),
                padding: ResponsiveLayout.all(context, 8),
                constraints: BoxConstraints(
                  minWidth: context.rs(36),
                  minHeight: context.rs(36),
                ),
              ),
            ],
          ),

          SizedBox(height: context.rsi(8)),

          // 요일 헤더 (일요일 시작: 일~토)
          Row(
            children: List.generate(7, (index) {
              return Expanded(
                child: Center(
                  child: Text(
                    _weekdayShortSundayFirst[index],
                    style: tt.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: cs.onSurfaceVariant,
                      fontSize: context.rs(11),
                    ),
                  ),
                ),
              );
            }),
          ),

          SizedBox(height: context.rsi(6)),

          // 간트차트 통합 캘린더
          _buildGanttCalendar(context, dates, processRanges),
        ],
      ),
    );
  }

  static const _weekdayShortSundayFirst = [
    '일',
    '월',
    '화',
    '수',
    '목',
    '금',
    '토',
  ];

  /// 간트차트 통합 캘린더 위젯 빌드
  Widget _buildGanttCalendar(
    BuildContext context,
    List<DateTime> dates,
    Map<String, List<(DateTime, DateTime)>> processRanges,
  ) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final daysPerWeek = 7;

    // 주별로 날짜 그룹화
    final weeks = <List<DateTime>>[];
    for (var i = 0; i < dates.length; i += daysPerWeek) {
      final end =
          (i + daysPerWeek > dates.length) ? dates.length : i + daysPerWeek;
      weeks.add(dates.sublist(i, end));
    }

    return Column(
      children: weeks.asMap().entries.map((weekEntry) {
        final weekDates = weekEntry.value;

        return Column(
          children: [
            if (weekEntry.key > 0) SizedBox(height: context.rsi(8)),

            // 날짜 행
            Row(
              children: weekDates.map((date) {
                final isInRange = _isInSelectedRange(date);
                final isStart = date.isAtSameMomentAs(_rangeStart);
                final isEnd = date.isAtSameMomentAs(_rangeEnd);
                final isCurrentMonth = date.month == _currentMonth.month &&
                    date.year == _currentMonth.year;

                return Expanded(
                  child: GestureDetector(
                    onTap: () => _handleDateTap(date),
                    child: Container(
                      margin:
                          ResponsiveLayout.symmetric(context, horizontal: 1.5),
                      padding: ResponsiveLayout.symmetric(context, vertical: 6),
                      decoration: BoxDecoration(
                        color: isInRange
                            ? (isStart || isEnd
                                ? cs.primary
                                : cs.primaryContainer)
                            : (isCurrentMonth
                                ? cs.surfaceContainerHighest
                                : cs.surfaceContainerLow),
                        borderRadius: BorderRadius.circular(context.rs(6)),
                        border: Border.all(
                          color: isInRange
                              ? cs.primary
                              : cs.outlineVariant.withValues(
                                  alpha: isCurrentMonth ? 1.0 : 0.3),
                          width: isInRange ? 1.5 : 0.8,
                        ),
                      ),
                      child: Text(
                        '${date.day}',
                        textAlign: TextAlign.center,
                        style: tt.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isInRange
                              ? (isStart || isEnd ? cs.onPrimary : cs.primary)
                              : (isCurrentMonth
                                  ? cs.onSurface
                                  : cs.onSurfaceVariant.withValues(alpha: 0.5)),
                          fontSize: context.rs(13),
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            // 간트차트 영역 (날짜 행 사이 간격)
            SizedBox(height: context.rsi(6)),

            _buildGanttBars(context, weekDates, processRanges),
          ],
        );
      }).toList(),
    );
  }

  /// 간트차트 바들 빌드
  Widget _buildGanttBars(
    BuildContext context,
    List<DateTime> weekDates,
    Map<String, List<(DateTime, DateTime)>> processRanges,
  ) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final firstDate = weekDates.first;
    final lastDate = weekDates.last;

    // 이 주에 표시할 공정들 필터링
    final visibleProcesses = <String>[];
    for (final entry in processRanges.entries) {
      for (final range in entry.value) {
        final rangeStart = range.$1;
        final rangeEnd = range.$2;

        // 공정이 이 주와 겹치는지 확인
        if (!(rangeEnd.isBefore(firstDate) || rangeStart.isAfter(lastDate))) {
          if (!visibleProcesses.contains(entry.key)) {
            visibleProcesses.add(entry.key);
          }
        }
      }
    }

    if (visibleProcesses.isEmpty) {
      return SizedBox(height: context.rsi(40));
    }

    // 공정별 간트 바 표시 (LayoutBuilder로 정확한 너비 계산)
    return Column(
      children: visibleProcesses.map((processKey) {
        final ranges = processRanges[processKey]!;
        final event = widget.allProcessEvents.firstWhere(
          (e) => processTaskKey(e.task, e.taskIndex) == processKey,
        );
        final isSelected = _isSelectedEvent(event);

        // 선택된 공정만 색상 표시, 나머지는 회색
        final processColor =
            isSelected ? _getProcessColor(context, event) : cs.outlineVariant;

        return Container(
          margin: ResponsiveLayout.only(context, bottom: 4),
          height: context.rs(isSelected ? 26 : 22),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final totalWidth = constraints.maxWidth;

              return Stack(
                children: [
                  // 배경 그리드 라인
                  Row(
                    children: weekDates.map((date) {
                      return Expanded(
                        child: Container(
                          margin: ResponsiveLayout.symmetric(context,
                              horizontal: 1.5),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: cs.outlineVariant.withValues(alpha: 0.15),
                              width: 0.3,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  // 간트 바들
                  ...ranges.map((range) {
                    final rangeStart = range.$1;
                    final rangeEnd = range.$2;

                    // 이 주의 범위로 클리핑
                    final displayStart =
                        rangeStart.isBefore(firstDate) ? firstDate : rangeStart;
                    final displayEnd =
                        rangeEnd.isAfter(lastDate) ? lastDate : rangeEnd;

                    if (displayEnd.isBefore(firstDate) ||
                        displayStart.isAfter(lastDate)) {
                      return const SizedBox.shrink();
                    }

                    // 시작/끝 인덱스 계산
                    final startIndex = weekDates.indexWhere((d) =>
                        d.year == displayStart.year &&
                        d.month == displayStart.month &&
                        d.day == displayStart.day);
                    final endIndex = weekDates.indexWhere((d) =>
                        d.year == displayEnd.year &&
                        d.month == displayEnd.month &&
                        d.day == displayEnd.day);

                    if (startIndex == -1 || endIndex == -1) {
                      return const SizedBox.shrink();
                    }

                    // 정확한 위치 계산
                    final cellWidth = totalWidth / weekDates.length;
                    final barLeft = startIndex * cellWidth;
                    final barWidth = (endIndex - startIndex + 1) * cellWidth;

                    return Positioned(
                      left: barLeft,
                      width: barWidth,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        margin: ResponsiveLayout.symmetric(context,
                            horizontal: 1.5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? processColor
                              : processColor.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(
                              context.rs(isSelected ? 5 : 4)),
                          border: Border.all(
                            color: isSelected
                                ? processColor.withValues(alpha: 0.85)
                                : processColor.withValues(alpha: 0.45),
                          ),
                        ),
                        child: Center(
                          child: Padding(
                            padding: ResponsiveLayout.symmetric(context,
                                horizontal: 2),
                            child: Text(
                              event.task.name,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: tt.labelSmall?.copyWith(
                                fontWeight: isSelected
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: isSelected
                                    ? cs.onPrimary
                                    : cs.onSurfaceVariant
                                        .withValues(alpha: 0.75),
                                fontSize: context.rs(isSelected ? 10 : 8),
                                height: 1.0,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ],
              );
            },
          ),
        );
      }).toList(),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:scrollable_calendar_package/calendar_dialog.dart';
import 'package:scrollable_calendar_package/calendar_style.dart';

/// 년·월 선택 다이얼로그. 캘린더 영역 높이와 무관하게 고정 크기로 표시합니다.
Future<({int year, int month})?> showYearMonthPickerDialog({
  required BuildContext context,
  required int selectedYear,
  required int selectedMonth,
  required int minYear,
  required int maxYear,
  required CalendarStyle style,
  required int baseYear,
  required int yearRange,
}) {
  return showDialog<({int year, int month})>(
    context: context,
    builder: (ctx) => CalendarDialog(
      title: '년·월 선택',
      child: _YearMonthPickerBody(
        selectedYear: selectedYear,
        selectedMonth: selectedMonth,
        minYear: minYear,
        maxYear: maxYear,
        style: style,
        baseYear: baseYear,
        yearRange: yearRange,
      ),
    ),
  );
}

class _YearMonthPickerBody extends StatefulWidget {
  const _YearMonthPickerBody({
    required this.selectedYear,
    required this.selectedMonth,
    required this.minYear,
    required this.maxYear,
    required this.style,
    required this.baseYear,
    required this.yearRange,
  });

  final int selectedYear;
  final int selectedMonth;
  final int minYear;
  final int maxYear;
  final CalendarStyle style;
  final int baseYear;
  final int yearRange;

  @override
  State<_YearMonthPickerBody> createState() => _YearMonthPickerBodyState();
}

class _YearMonthPickerBodyState extends State<_YearMonthPickerBody> {
  static const _yearGridInitialPage = 1000;

  late final PageController _yearViewPageController;
  late final PageController _yearGridPageController;

  var _showYearGrid = false;
  var _yearGridCenterYear = 0;

  int get _selectedYear => widget.selectedYear;
  int get _selectedMonth => widget.selectedMonth;

  Color get _selectedFillColor {
    final fromStyle = widget.style.focusedMonthBackgroundColor;
    if (fromStyle.a > 0.01) return fromStyle;
    return widget.style.headerAccentColor.withValues(alpha: 0.14);
  }

  Color get _selectedBorderColor {
    final fromStyle = widget.style.focusedMonthBorderColor;
    if (fromStyle.a > 0.01) return fromStyle;
    return widget.style.headerAccentColor;
  }

  Color get _selectedTextColor => widget.style.headerAccentColor;

  @override
  void initState() {
    super.initState();
    _yearGridCenterYear = widget.selectedYear;

    final yearCount = widget.yearRange * 2 + 1;
    final initialYearIndex = (_selectedYear - (widget.baseYear - widget.yearRange))
        .clamp(0, yearCount - 1);

    _yearViewPageController = PageController(initialPage: initialYearIndex);
    _yearGridPageController = PageController(initialPage: _yearGridInitialPage);
  }

  @override
  void dispose() {
    _yearViewPageController.dispose();
    _yearGridPageController.dispose();
    super.dispose();
  }

  void _openYearGrid(int year) {
    setState(() {
      _yearGridCenterYear = year;
      _showYearGrid = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_yearGridPageController.hasClients) {
        _yearGridPageController.jumpToPage(_yearGridInitialPage);
      }
    });
  }

  void _selectYearFromGrid(int year) {
    final yearCount = widget.yearRange * 2 + 1;
    final targetYearIndex =
        (year - (widget.baseYear - widget.yearRange)).clamp(0, yearCount - 1);

    setState(() {
      _showYearGrid = false;
    });

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

  void _selectMonth(int year, int month) {
    Navigator.pop(context, (year: year, month: month));
  }

  @override
  Widget build(BuildContext context) {
    if (_showYearGrid) {
      return _buildYearGridView();
    }
    return _buildYearView();
  }

  Widget _buildYearView() {
    final yearCount = widget.yearRange * 2 + 1;

    return PageView.builder(
      controller: _yearViewPageController,
      scrollDirection: Axis.vertical,
      padEnds: true,
      itemCount: yearCount,
      itemBuilder: (context, yearIndex) {
        final year = widget.baseYear - widget.yearRange + yearIndex;
        final isSelectedYear = year == _selectedYear;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              child: GestureDetector(
                onTap: () => _openYearGrid(year),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: isSelectedYear
                      ? BoxDecoration(
                          color: _selectedFillColor,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _selectedBorderColor,
                            width: 1.5,
                          ),
                        )
                      : null,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$year년',
                        style: widget.style.headerTextStyle.copyWith(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: isSelectedYear
                              ? _selectedTextColor
                              : widget.style.headerTextStyle.color,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: isSelectedYear
                            ? _selectedTextColor
                            : (widget.style.headerTextStyle.color ??
                                Colors.black),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(8),
                physics: const AlwaysScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1.0,
                ),
                itemCount: 12,
                itemBuilder: (context, monthIndex) {
                  final month = monthIndex + 1;
                  final isSelectedMonth =
                      year == _selectedYear && month == _selectedMonth;

                  return _MiniMonthTile(
                    year: year,
                    month: month,
                    isSelected: isSelectedMonth,
                    selectedFillColor: _selectedFillColor,
                    selectedBorderColor: _selectedBorderColor,
                    selectedTextColor: _selectedTextColor,
                    style: widget.style,
                    onTap: () => _selectMonth(year, month),
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
    return PageView.builder(
      controller: _yearGridPageController,
      scrollDirection: Axis.vertical,
      itemBuilder: (context, pageIndex) {
        final pageOffset = pageIndex - _yearGridInitialPage;
        final pageCenterYear = _yearGridCenterYear + (pageOffset * 9);
        final startYear = pageCenterYear - 4;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              child: Text(
                '연도 선택',
                style: widget.style.headerTextStyle.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
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
                  final isInRange =
                      year >= widget.minYear && year <= widget.maxYear;
                  final isSelected = year == _selectedYear;

                  return GestureDetector(
                    onTap: isInRange ? () => _selectYearFromGrid(year) : null,
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected ? _selectedFillColor : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? _selectedBorderColor
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
                                  ? _selectedTextColor
                                  : (widget.style.headerTextStyle.color ??
                                      Colors.black))
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
  }
}

class _MiniMonthTile extends StatelessWidget {
  const _MiniMonthTile({
    required this.year,
    required this.month,
    required this.isSelected,
    required this.selectedFillColor,
    required this.selectedBorderColor,
    required this.selectedTextColor,
    required this.style,
    required this.onTap,
  });

  final int year;
  final int month;
  final bool isSelected;
  final Color selectedFillColor;
  final Color selectedBorderColor;
  final Color selectedTextColor;
  final CalendarStyle style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final firstDayOfMonth = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final firstWeekday = firstDayOfMonth.weekday % 7;
    final totalCells = firstWeekday + daysInMonth;
    final weeks = (totalCells / 7).ceil();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? selectedFillColor : Colors.transparent,
          borderRadius: style.calendarBorderRadius,
          border: isSelected
              ? Border.all(color: selectedBorderColor, width: 1.5)
              : Border.all(color: Colors.grey.shade300, width: 1),
        ),
        padding: const EdgeInsets.all(5),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final availableWidth = constraints.maxWidth;
            final availableHeight = constraints.maxHeight;
            const headerHeight = 18.0;
            const spacing = 4.0;

            final cellWidth = (availableWidth - 12) / 7;
            final cellHeight = (availableHeight - headerHeight - spacing) / weeks;
            final cellSize = cellWidth < cellHeight ? cellWidth : cellHeight;
            final finalCellSize = cellSize.clamp(10.0, 25.0);

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$month월',
                  style: style.headerTextStyle.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? selectedTextColor : null,
                  ),
                ),
                const SizedBox(height: spacing),
                Expanded(
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      childAspectRatio: 1.0,
                      mainAxisSpacing: 1,
                      crossAxisSpacing: 1,
                    ),
                    itemCount: totalCells,
                    itemBuilder: (context, index) {
                      if (index < firstWeekday) {
                        return const SizedBox.shrink();
                      }
                      final day = index - firstWeekday + 1;
                      final weekdayIndex = index % 7; // 0: sun, 6: sat
                      final dayColor = weekdayIndex == 0
                          ? style.daySundayTextColor
                          : weekdayIndex == 6
                              ? style.daySaturdayTextColor
                              : (style.dayTextStyle.color ?? Colors.grey.shade700);
                      return Center(
                        child: Text(
                          day.toString(),
                          style: style.dayTextStyle.copyWith(
                            fontSize: finalCellSize * 0.45,
                            color: dayColor.withValues(alpha: 0.82),
                          ),
                        ),
                      );
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

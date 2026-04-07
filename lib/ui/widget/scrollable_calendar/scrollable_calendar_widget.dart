import 'package:flutter/material.dart';
import 'package:scrollable_calendar_package/calendar.dart';
import 'package:w0001/util/funtions.dart';

class ScrollableCalendarWidget extends StatefulWidget {
  const ScrollableCalendarWidget({
    super.key,
    this.height = 320,
  });

  final double height;

  @override
  State<ScrollableCalendarWidget> createState() =>
      _ScrollableCalendarWidgetState();
}

class _ScrollableCalendarWidgetState extends State<ScrollableCalendarWidget> {
  DateTime? _start;
  DateTime? _end;

  String _rangeLabel() {
    final start = _start;
    if (start == null) return '기간을 선택해주세요.';

    final end = _end ?? start;
    final normalizedStart = start.isBefore(end) ? start : end;
    final normalizedEnd = start.isBefore(end) ? end : start;
    final days = normalizedEnd.difference(normalizedStart).inDays + 1;

    return '${formatDateTimeRangeToString(DateTimeRange(start: normalizedStart, end: normalizedEnd), showYear: true)} ($days일)';
  }

  @override
  Widget build(BuildContext context) {
    const style = CalendarStyle(
      // 포커스 배경만 제거 (테두리는 패키지에서 그리지 않도록 수정)
      focusedMonthBackgroundColor: Colors.transparent,
      // 버튼/아이콘 색상으로도 쓰이므로 투명으로 만들면 텍스트가 안 보임
      focusedMonthBorderColor: Colors.blueAccent,
    );

    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: ScrollableCalendar(
        config: CalendarConfig(
          initialDate: DateTime.now(),
          pageScrollDirection: CalendarPageScrollDirection.horizontal,
          selectionMode: CalendarSelectionMode.range,
          showMonthArrowButtons: true,
          calendarHeightFactor: 1,
        ),
        style: style,
        onEventRangeChanged: (start, end) {
          if (!mounted) return;
          setState(() {
            _start = start;
            _end = end;
          });
        },
        builder: (context, selectedDate, calendar) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _rangeLabel(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14),
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


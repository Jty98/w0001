import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:w0001/presentation/viewmodel/calendar_view_model.dart';

class CalendarWidget extends ConsumerWidget {
  const CalendarWidget({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(calendarProvider);
    final vm = ref.read(calendarProvider.notifier);

    return TableCalendar(
      rowHeight: MediaQuery.of(context).size.height * 0.05,
      calendarStyle: CalendarStyle(
        markerDecoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.blueGrey[300],
        ),
        markersMaxCount: 3,
        weekendTextStyle: const TextStyle(color: Colors.red),
        canMarkersOverflow: false,
      ),
      locale: 'ko_KR',
      daysOfWeekStyle: const DaysOfWeekStyle(
          weekendStyle: TextStyle(color: Colors.red)),
      focusedDay: state.focusedDay,
      firstDay: DateTime(2020, 1, 1),
      lastDay: DateTime(2030, 12, 31),
      calendarFormat: state.calendarFormat,
      availableCalendarFormats: const {
        CalendarFormat.month: '1개월',
        CalendarFormat.week: '1주일',
        CalendarFormat.twoWeeks: '2주일',
      },
      onFormatChanged: vm.changeFormat,
      onDaySelected: vm.onDaySelected,
      headerStyle: const HeaderStyle(
        titleCentered: true,
        titleTextStyle: TextStyle(fontSize: 20),
      ),
      selectedDayPredicate: (DateTime date) {
        return date.year == state.selectedDay.year &&
            date.month == state.selectedDay.month &&
            date.day == state.selectedDay.day;
      },
      eventLoader: vm.getEventsForDay,
    );
  }
}

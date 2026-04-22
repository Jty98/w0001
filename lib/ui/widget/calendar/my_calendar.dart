import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollable_calendar_package/calendar.dart';
import 'package:w0001/presentation/viewmodel/calendar_view_model.dart';
import 'package:w0001/ui/widget/scrollable_calendar/scrollable_calendar_widget.dart';

class CalendarWidget extends ConsumerWidget {
  const CalendarWidget({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(calendarProvider);
    final vm = ref.read(calendarProvider.notifier);
    final events = <CalendarEvent>[];
    state.events.forEach((day, titles) {
      final date = DateTime(day.year, day.month, day.day);
      for (var i = 0; i < titles.length; i++) {
        events.add(
          CalendarEvent(
            startDate: date,
            endDate: date,
            id: '${date.toIso8601String()}_$i',
            title: titles[i],
          ),
        );
      }
    });

    return ScrollableCalendarWidget(
      height: MediaQuery.of(context).size.height * 0.42,
      useSingleDaySelection: true,
      showViewModeToggle: true,
      disableDateSelectionHighlight: true,
      initialSelectedDay: state.selectedDay,
      initialEvents: events,
      onDayPicked: (picked) async {
        await vm.onDaySelected(picked, picked);
      },
    );
  }
}

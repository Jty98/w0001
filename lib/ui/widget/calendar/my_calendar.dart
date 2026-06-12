import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

    final screenH = MediaQuery.sizeOf(context).height;
    // [height]는 1주·2주 모드 상한. 월별 높이는 주(5/6) 수에 맞춰 자동 계산.
    final calendarWeekModeMaxHeight = (screenH * 0.38).clamp(280.0, 380.0);

    return ScrollableCalendarWidget(
      adaptiveHeightForWeekModes: true,
      height: calendarWeekModeMaxHeight,
      useSingleDaySelection: true,
      showViewModeToggle: true,
      disableDateSelectionHighlight: true,
      initialSelectedDay: state.selectedDay,
      initialEvents: state.workforceDotEvents,
      onDayPicked: (picked) async {
        await vm.onDaySelected(picked, picked);
      },
    );
  }
}

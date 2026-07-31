import 'dart:async' show unawaited;

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
    // 리스트 영역 확보 — 1주·2주 모드 상한을 낮춤.
    final calendarWeekModeMaxHeight = (screenH * 0.28).clamp(220.0, 300.0);

    return ScrollableCalendarWidget(
      adaptiveHeightForWeekModes: true,
      height: calendarWeekModeMaxHeight,
      useSingleDaySelection: true,
      showViewModeToggle: true,
      disableDateSelectionHighlight: true,
      initialSelectedDay: state.selectedDay,
      initialEvents: state.workforceDotEvents,
      onMonthChanged: (monthFirst) {
        unawaited(vm.onCalendarVisibleMonthChanged(monthFirst));
      },
      onCalendarPageAnchorChanged: (anchor) {
        unawaited(vm.onCalendarVisibleMonthChanged(anchor));
      },
      onDayPicked: (picked) async {
        await vm.onDaySelected(picked, picked);
      },
    );
  }
}

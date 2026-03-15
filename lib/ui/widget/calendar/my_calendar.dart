import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:w0001/controller/calendar_controller.dart';

class CalendarWidget extends GetView<CalendarController> {
  const CalendarWidget({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return GetBuilder<CalendarController>(
      builder: (controller) => TableCalendar(
        rowHeight: MediaQuery.of(context).size.height * 0.05,
        calendarStyle:  CalendarStyle(
          markerDecoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.blueGrey[300],
          ),
          markersMaxCount: 3,
          weekendTextStyle: const TextStyle(color: Colors.red),
          canMarkersOverflow: false,
        ),
        locale: 'ko_KR',
        daysOfWeekStyle: const DaysOfWeekStyle(weekendStyle: TextStyle(color: Colors.red)),
        focusedDay: controller.focusedDay,
        firstDay: DateTime(2020, 1, 1),
        lastDay: DateTime(2030, 12, 31),
        calendarFormat: controller.calendarFormat,
        availableCalendarFormats: const {
          CalendarFormat.month: '1개월',
          CalendarFormat.week: '1주일',
          CalendarFormat.twoWeeks: '2주일',
        },
        onFormatChanged: (format) {
          controller.changeFormat(format);
        },
        onDaySelected: (selectedDay, focusedDay) {
          controller.onDaySelected(selectedDay, focusedDay);
        },
        headerStyle: const HeaderStyle(
          titleCentered: true,
          titleTextStyle: TextStyle(fontSize: 20),
        ),
        selectedDayPredicate: (DateTime date) {
          return date.year == controller.selectedDay.year &&
              date.month == controller.selectedDay.month &&
              date.day == controller.selectedDay.day;
        },
        // calendarBuilders: CalendarBuilders(
        //   markerBuilder: (context, day, events) {
        //     if (events.isNotEmpty) {
        //       return Container(
        //         decoration: BoxDecoration(
        //           shape: BoxShape.rectangle,
        //           color: Colors.green,
        //           border: Border.all(color: Colors.white,),
        //         ),
        //         width: double.maxFinite,
        //         child: Text(
        //           events.length.toString(),
        //           textAlign: TextAlign.center,
        //           style: const TextStyle(
        //             color: Colors.white,
        //             fontSize: 9,
        //             fontWeight: FontWeight.bold,
        //           ),
        //         ),
        //       );
        //     }
        //     return null;
        //   },
        // ),
        eventLoader: (day) => controller.getEventsForDay(day),
      ),
    );
  }
}

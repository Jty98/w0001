import 'package:flutter/material.dart';
import 'package:scrollable_calendar_package/calendar_config.dart';
import 'package:scrollable_calendar_package/calendar_event.dart';
import 'package:scrollable_calendar_package/calendar_style.dart';
import 'package:scrollable_calendar_package/scrollable_calendar.dart';

/// 뷰어 모드 예제 페이지 (selectionMode = none)
/// - 등록된 이벤트만 표시
/// - 편집 중인 이벤트의 파란색 배경은 표시되지 않음
class CalendarViewerPage extends StatelessWidget {
  const CalendarViewerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar Viewer Mode'),
        backgroundColor: Colors.blue,
      ),
      body: ScrollableCalendar(
        config: CalendarConfig(
          initialDate: DateTime.now(),
          yearRange: 5,
          calendarHeightFactor: 0.5,
          selectionMode: CalendarSelectionMode.none, // 뷰어 모드
          initialEvents: getDummyEvents(), // 등록된 이벤트만 표시
        ),
        style: const CalendarStyle(),
        builder: (context, selectedDate, calendar) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '뷰어 모드',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const Text(
                      '날짜 선택 불가',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '• 편집 중인 이벤트의 파란색 배경은 표시되지 않습니다\n• 날짜 선택 및 이벤트 편집 기능이 비활성화되어 있습니다',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(child: calendar),
            ],
          );
        },
        // 뷰어 모드에서는 콜백 없음
      ),
    );
  }
}

List<CalendarEvent> getDummyEvents() {
  final now = DateTime.now();
  return [
    CalendarEvent(
      startDate: DateTime(now.year, now.month, 5),
      endDate: DateTime(now.year, now.month, 7),
      title: 'Sample Event',
    ),
  ];
}

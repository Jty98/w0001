import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:scrollable_calendar_package/calendar_config.dart';
import 'package:scrollable_calendar_package/calendar_style.dart';
import 'package:scrollable_calendar_package/scrollable_calendar.dart';


/// 편집 모드 예제 페이지 (selectionMode = range)
/// - 등록된 이벤트와 편집 중인 이벤트 모두 표시
/// - 편집 중인 이벤트는 파란색 배경으로 표시
class CalendarEditorPage extends StatefulWidget {
  const CalendarEditorPage({super.key});

  @override
  State<CalendarEditorPage> createState() => _CalendarEditorPageState();
}

class _CalendarEditorPageState extends State<CalendarEditorPage> {
  late final TextEditingController _startDateController;
  late final TextEditingController _endDateController;
  String _eventRangeString = '';
  final GlobalKey<ScrollableCalendarState> _calendarKey = GlobalKey<ScrollableCalendarState>();

  @override
  void initState() {
    super.initState();
    _startDateController = TextEditingController();
    _endDateController = TextEditingController();
  }

  @override
  void dispose() {
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _getEventRangeString(DateTime startDate, DateTime endDate) {
    // 시작일과 종료일을 모두 포함하므로 +1
    final days = endDate.difference(startDate).inDays + 1;
    return '$days일';
  }

  @override
  Widget build(BuildContext context) {
    final style = const CalendarStyle();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar Editor Mode'),
        backgroundColor: Colors.green,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: TextField(
                          controller: _startDateController,
                          readOnly: true,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            labelText: '시작일',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: TextField(
                          controller: _endDateController,
                          readOnly: true,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            labelText: '종료일',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_eventRangeString.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '이벤트 기간: $_eventRangeString',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: ScrollableCalendar(
              key: _calendarKey,
              config: CalendarConfig(
                initialDate: DateTime.now(),
                yearRange: 5,
                calendarHeightFactor: 0.6,
                selectionMode: CalendarSelectionMode.range, // 기간 선택 모드
                // initialEvents: _getDummyEvents(), // 등록된 이벤트
              ),
              style: const CalendarStyle(),
              builder: (context, selectedDate, calendar) {
                return calendar;
              },
              onDaySelected: (date) {
                final y = date.year.toString().padLeft(4, '0');
                final m = date.month.toString().padLeft(2, '0');
                final d = date.day.toString().padLeft(2, '0');
                debugPrint('편집 모드 - 선택된 날짜: $y-$m-$d');
              },
              onEventRangeChanged: (startDate, endDate) {
                setState(() {
                  _startDateController.text = startDate != null
                      ? _formatDate(startDate)
                      : '';
                  _endDateController.text = endDate != null
                      ? _formatDate(endDate)
                      : '';
                  _eventRangeString = startDate != null && endDate != null && !startDate.isAfter(endDate)
                      ? _getEventRangeString(startDate, endDate)
                      : '';
                });
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Row(
              children: [
                Expanded(
                  child: CupertinoButton.filled(
                    sizeStyle: CupertinoButtonSize.large,
                    minimumSize: const Size(double.infinity, 40),
                    color: style.eventSaveButtonColor,
                    borderRadius: BorderRadius.circular(8),
                    onPressed: () {
                      debugPrint('이벤트 저장');
                      debugPrint("시작일: ${_startDateController.text}");
                      debugPrint("종료일: ${_endDateController.text}");
                      debugPrint("이벤트 기간: $_eventRangeString");
                    },
                    child: Text('이벤트 저장', style: style.eventSaveButtonTextStyle),
                  ),
                ),
                const SizedBox(width: 8),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(8),
                  onPressed: () {
                    _calendarKey.currentState?.resetEventRange();
                    setState(() {
                      _startDateController.clear();
                      _endDateController.clear();
                      _eventRangeString = '';
                    });
                  },
                  child: const Text(
                    '초기화',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

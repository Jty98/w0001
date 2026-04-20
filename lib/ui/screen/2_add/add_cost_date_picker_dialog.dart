import 'package:flutter/material.dart';
import 'package:w0001/ui/widget/scrollable_calendar/scrollable_calendar_widget.dart';
import 'package:w0001/util/funtions.dart';

class AddCostDatePickerDialog extends StatefulWidget {
  const AddCostDatePickerDialog({
    super.key,
    required this.initialRangeStart,
    required this.initialRangeEnd,
    required this.initialSelectedDay,
  });

  final DateTime? initialRangeStart;
  final DateTime? initialRangeEnd;

  /// 금액추가 탭은 단일 날짜만 필요하므로, 마지막 선택값을 보여주기 위한 값.
  final DateTime initialSelectedDay;

  @override
  State<AddCostDatePickerDialog> createState() => _AddCostDatePickerDialogState();
}

class _AddCostDatePickerDialogState extends State<AddCostDatePickerDialog> {
  DateTime? _pickedDay;

  /// 패키지/위젯이 initial range 세팅 중 콜백을 1회 이상 호출할 수 있어,
  /// 초기 콜백은 무조건 무시하고 사용자 입력 이후만 처리한다.
  bool _readyForUserInput = false;

  @override
  void initState() {
    super.initState();
    // 다이얼로그 최초 진입 시 선택/포커스는 항상 "오늘"부터 시작.
    final now = DateTime.now();
    _pickedDay = DateTime(now.year, now.month, now.day);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _readyForUserInput = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.62;
    final calHeight = MediaQuery.sizeOf(context).height * 0.45;

    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  '현장 기간 / 작업일 선택',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              ScrollableCalendarWidget(
                height: calHeight,
                initialRangeStart: widget.initialRangeStart,
                initialRangeEnd: widget.initialRangeEnd ?? widget.initialRangeStart,
                initialSelectedDay: _pickedDay,
                onDayPicked: (d) {
                  if (!_readyForUserInput) return;
                  setState(() => _pickedDay = d);
                },
              ),
              if (_pickedDay != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    '선택: ${formatDateTimeWeekDayToString(_pickedDay!)}',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop<DateTime?>(null),
                    child: const Text(
                      '취소',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                  TextButton(
                    onPressed: _pickedDay == null
                        ? null
                        : () => Navigator.of(context).pop<DateTime?>(_pickedDay),
                    child: const Text('확인'),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}


import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollable_calendar_package/calendar.dart';
import 'package:w0001/data/model/place_model.dart';
import 'package:w0001/data/model/remote/super_admin_dtos.dart';
import 'package:w0001/presentation/viewmodel/place_process_schedule_notifier.dart';
import 'package:w0001/presentation/viewmodel/super_admin_remote_providers.dart';
import 'package:w0001/ui/screen/5_place/place_workforce_schedule.dart';
import 'package:w0001/ui/widget/scrollable_calendar/scrollable_calendar_widget.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 인력투입 화면 캘린더와 동일 규칙: 공정만 회색, 투입(공정 동반 시에도) 초록 · 날짜당 점 1개.

class AddCostDatePickerDialog extends ConsumerStatefulWidget {
  const AddCostDatePickerDialog({
    super.key,
    required this.place,
    required this.initialRangeStart,
    required this.initialRangeEnd,
    required this.initialSelectedDay,
  });

  final PlaceModel place;

  final DateTime? initialRangeStart;
  final DateTime? initialRangeEnd;

  /// 금액추가 탭은 단일 날짜만 필요하므로, 마지막 선택값을 보여주기 위한 값.
  final DateTime initialSelectedDay;

  @override
  ConsumerState<AddCostDatePickerDialog> createState() =>
      _AddCostDatePickerDialogState();
}

class _AddCostDatePickerDialogState
    extends ConsumerState<AddCostDatePickerDialog> {
  DateTime? _pickedDay;

  /// 패키지/위젯이 initial range 세팅 중 콜백을 1회 이상 호출할 수 있어,
  /// 초기 콜백은 무조건 무시하고 사용자 입력 이후만 처리한다.
  bool _readyForUserInput = false;

  List<PlaceWorkDayRead> _workRowsForPlace = const [];
  var _workFetchStarted = false;

  ProcessScheduleFamilyArg get _scheduleArg => (
        pid: widget.place.pid ?? 0,
        pstart: widget.place.pstart,
        pend: widget.place.pend,
      );

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _pickedDay = DateTime(now.year, now.month, now.day);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _readyForUserInput = true);
    });
    Future.microtask(_loadPlaceWorkDays);
  }

  Future<void> _loadPlaceWorkDays() async {
    if (_workFetchStarted) return;
    _workFetchStarted = true;
    final pid = widget.place.pid ?? 0;
    if (pid == 0) return;
    try {
      final all =
          await ref.read(superAdminRemoteUseCaseProvider).placeWorkDaysList();
      if (!mounted) return;
      setState(() {
        _workRowsForPlace =
            all.where((e) => e.pid == pid).toList(growable: false);
      });
    } catch (_) {
      // 점 표시만 생략
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.sizeOf(context).height;
    final maxHeight = (screenH * 0.60).clamp(400.0, 560.0).toDouble();
    final calHeight = (screenH * 0.34).clamp(240.0, 310.0).toDouble();

    final sch = ref.watch(placeProcessScheduleProvider(_scheduleArg));

    final List<CalendarEvent> events = sch.isReady
        ? PlaceWorkforceSchedule.buildCalendarEvents(
            sch.data, _workRowsForPlace)
        : const <CalendarEvent>[];

    final (displayStart, displayEnd) = sch.isReady
        ? PlaceWorkforceSchedule.unionPlaceStringsAndScheduleCalendarRange(
            widget.place.pstart,
            widget.place.pend,
            sch.data,
          )
        : (
            widget.initialRangeStart,
            widget.initialRangeEnd ?? widget.initialRangeStart,
          );

    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Padding(
          padding: EdgeInsets.only(bottom: context.rsi(8)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(vertical: context.rsi(10)),
                child: Text(
                  '현장 기간 / 작업일 선택',
                  style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(bottom: context.rsi(6)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.circle, size: context.rsi(8), color: cs.outline),
                    SizedBox(width: context.rsi(5)),
                    Text(
                      '공정',
                      style: tt.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    SizedBox(width: context.rsi(14)),
                    Icon(Icons.circle, size: context.rsi(8), color: cs.tertiary),
                    SizedBox(width: context.rsi(5)),
                    Text(
                      '인력 투입',
                      style: tt.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              ScrollableCalendarWidget(
                key: ValueKey(
                  '${sch.isReady}-${sch.data.dayCount}-${sch.data.tasks.length}-'
                  '${_workRowsForPlace.length}',
                ),
                height: calHeight,
                initialRangeStart: displayStart,
                initialRangeEnd: displayEnd ?? displayStart,
                initialSelectedDay: _pickedDay,
                initialEvents: events,
                useSingleDaySelection: true,
                showViewModeToggle: false,
                disableDateSelectionHighlight: true,
                onDayPicked: (d) {
                  if (!_readyForUserInput) return;
                  setState(() => _pickedDay = d);
                },
              ),
              SizedBox(height: context.rsi(6)),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop<DateTime?>(null),
                    child: Text(
                      '취소',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  ),
                  TextButton(
                    onPressed: _pickedDay == null
                        ? null
                        : () =>
                            Navigator.of(context).pop<DateTime?>(_pickedDay),
                    child: Text(
                      '확인',
                      style: TextStyle(color: cs.primary),
                    ),
                  ),
                  SizedBox(width: context.rsi(8)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

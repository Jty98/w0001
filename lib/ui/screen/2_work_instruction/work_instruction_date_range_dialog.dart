import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollable_calendar_package/calendar.dart';
import 'package:w0001/data/model/place_info_model.dart';
import 'package:w0001/data/model/remote/super_admin_dtos.dart';
import 'package:w0001/presentation/viewmodel/place_process_schedule_notifier.dart';
import 'package:w0001/presentation/viewmodel/super_admin_remote_providers.dart';
import 'package:w0001/ui/screen/5_place/place_workforce_schedule.dart';
import 'package:w0001/ui/widget/scrollable_calendar/scrollable_calendar_widget.dart';
import 'package:w0001/util/funtions.dart';
import 'package:w0001/util/responsive_layout.dart';

Future<(DateTime start, DateTime end)?> showWorkInstructionDateRangeDialog({
  required BuildContext context,
  required PlaceInfoModel place,
  required DateTime start,
  required DateTime end,
}) {
  return showDialog<(DateTime, DateTime)>(
    context: context,
    builder: (ctx) => _WorkInstructionDateRangeDialog(
      place: place,
      start: DateTime(start.year, start.month, start.day),
      end: DateTime(end.year, end.month, end.day),
    ),
  );
}

class _WorkInstructionDateRangeDialog extends ConsumerStatefulWidget {
  const _WorkInstructionDateRangeDialog({
    required this.place,
    required this.start,
    required this.end,
  });

  final PlaceInfoModel place;
  final DateTime start;
  final DateTime end;

  @override
  ConsumerState<_WorkInstructionDateRangeDialog> createState() =>
      _WorkInstructionDateRangeDialogState();
}

class _WorkInstructionDateRangeDialogState
    extends ConsumerState<_WorkInstructionDateRangeDialog> {
  late DateTime _start;
  late DateTime _end;
  List<PlaceWorkDayRead> _workRows = const [];

  ProcessScheduleFamilyArg get _scheduleArg => (
        pid: widget.place.pid ?? 0,
        pstart: widget.place.pstart,
        pend: widget.place.pend,
      );

  var _readyForUserInput = false;

  @override
  void initState() {
    super.initState();
    _start = widget.start;
    _end = widget.end.isBefore(widget.start) ? widget.start : widget.end;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _readyForUserInput = true);
      _loadWorkDays();
    });
  }

  Future<void> _loadWorkDays() async {
    final pid = widget.place.pid ?? 0;
    if (pid <= 0) return;
    try {
      final all =
          await ref.read(superAdminRemoteUseCaseProvider).placeWorkDaysList();
      if (!mounted) return;
      setState(() {
        _workRows = all.where((e) => e.pid == pid).toList(growable: false);
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final screenH = MediaQuery.sizeOf(context).height;
    final dialogH = (screenH * 0.72).clamp(420.0, 580.0);
    final sch = ref.watch(placeProcessScheduleProvider(_scheduleArg));
    final events = sch.isReady
        ? PlaceWorkforceSchedule.buildCalendarEvents(sch.data, _workRows)
        : const <CalendarEvent>[];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: EdgeInsets.symmetric(horizontal: context.rsi(16)),
      child: SizedBox(
        width: MediaQuery.sizeOf(context).width * 0.92,
        height: dialogH,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            context.rsi(12),
            context.rsi(10),
            context.rsi(12),
            context.rsi(8),
          ),
          child: Column(
            children: [
              Text(
                '투입 날짜',
                style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              SizedBox(height: context.rsi(4)),
              Text(
                _start == _end
                    ? formatDateTimeWeekDayToString(_start)
                    : '${formatDateTimeWeekDayToString(_start)} ~ ${formatDateTimeWeekDayToString(_end)}',
                style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
              SizedBox(height: context.rsi(8)),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, inner) {
                    return ScrollableCalendarWidget(
                      height: inner.maxHeight,
                      initialRangeStart: widget.start,
                      initialRangeEnd: widget.end,
                      initialSelectedDay: widget.start,
                      initialEvents: events,
                      showViewModeToggle: true,
                      onRangeChanged: (s, e) {
                        if (!_readyForUserInput) return;
                        if (s == null) return;
                        final a = DateTime(s.year, s.month, s.day);
                        final b =
                            e == null ? a : DateTime(e.year, e.month, e.day);
                        setState(() {
                          if (b.isBefore(a)) {
                            _start = b;
                            _end = a;
                          } else {
                            _start = a;
                            _end = b;
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('취소'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, (_start, _end)),
                    child: const Text('확인'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:w0001/data/model/schedule_memo_model.dart';
import 'package:w0001/presentation/viewmodel/dashboard_schedule_view_model.dart';
import 'package:w0001/ui/widget/scrollable_calendar/scrollable_calendar_widget.dart';
import 'package:w0001/util/funtions.dart';

const List<int> _alarmOffsetChoices = [0, 30, 60, 180, 1440];

String _alarmOffsetLabel(int minutes) {
  switch (minutes) {
    case 0:
      return '정시';
    case 30:
      return '30분 전';
    case 60:
      return '1시간 전';
    case 180:
      return '3시간 전';
    case 1440:
      return '하루 전';
    default:
      if (minutes % 60 == 0) return '${minutes ~/ 60}시간 전';
      return '$minutes분 전';
  }
}

class DashboardMemoEditorResult {
  const DashboardMemoEditorResult({
    required this.title,
    required this.memo,
    required this.date,
    required this.time,
    required this.alarmEnabled,
    required this.alarmOffsetMinutes,
  });

  final String title;
  final String memo;
  final DateTime date;
  final TimeOfDay? time;
  final bool alarmEnabled;
  final int alarmOffsetMinutes;
}

class DashboardScheduleMemoEditorSheet extends StatefulWidget {
  const DashboardScheduleMemoEditorSheet({
    super.key,
    required this.existing,
    required this.initialDate,
    required this.initialTime,
    required this.onPickTime,
  });

  final ScheduleMemoModel? existing;
  final DateTime initialDate;
  final TimeOfDay? initialTime;
  final Future<TimeOfDay?> Function(TimeOfDay? initial) onPickTime;

  @override
  State<DashboardScheduleMemoEditorSheet> createState() =>
      _DashboardScheduleMemoEditorSheetState();
}

class _DashboardScheduleMemoEditorSheetState
    extends State<DashboardScheduleMemoEditorSheet> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _memoCtrl;
  late DateTime _picked;
  TimeOfDay? _pickedTime;
  late bool _alarmEnabled;
  late int _alarmOffsetMinutes;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.existing?.title ?? '');
    _memoCtrl = TextEditingController(text: widget.existing?.memo ?? '');
    _picked = scheduleDateOnly(widget.initialDate);
    _pickedTime = widget.initialTime;
    _alarmEnabled = widget.existing?.alarmEnabled ?? false;
    _alarmOffsetMinutes = widget.existing?.alarmOffsetMinutes ?? 60;
    if (!_alarmOffsetChoices.contains(_alarmOffsetMinutes)) {
      _alarmOffsetMinutes = 60;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _memoCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final t = _titleCtrl.text.trim();
    if (t.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('제목을 입력해 주세요.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (_alarmEnabled && _pickedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('알람을 사용하려면 먼저 시간을 지정해 주세요.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    Navigator.pop(
      context,
      DashboardMemoEditorResult(
        title: t,
        memo: _memoCtrl.text,
        date: _picked,
        time: _pickedTime,
        alarmEnabled: _alarmEnabled,
        alarmOffsetMinutes: _alarmEnabled ? _alarmOffsetMinutes : 0,
      ),
    );
  }

  Future<void> _pickDateWithScrollableCalendar() async {
    final picked = await showDialog<DateTime?>(
      context: context,
      builder: (ctx) => _DashboardScheduleDatePickerDialog(initialDay: _picked),
    );
    if (picked != null && mounted) {
      setState(() => _picked = scheduleDateOnly(picked));
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final pad = MediaQuery.paddingOf(context);

    return AnimatedPadding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + pad.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.existing == null ? '일정 추가' : '일정 수정',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('날짜'),
                subtitle: Text(scheduleDateKey(_picked)),
                trailing: const Icon(Icons.calendar_today_outlined),
                onTap: _pickDateWithScrollableCalendar,
              ),
              _TaskTimePickerField(
                pickedTime: _pickedTime,
                onTapPicker: () async {
                  final picked = await widget.onPickTime(_pickedTime);
                  if (picked != null) {
                    setState(() => _pickedTime = picked);
                  }
                },
                onClear: _pickedTime == null
                    ? null
                    : () {
                        setState(() {
                          _pickedTime = null;
                          _alarmEnabled = false;
                        });
                      },
              ),
              SwitchListTile(
                value: _alarmEnabled,
                contentPadding: EdgeInsets.zero,
                title: const Text('사전 알람'),
                subtitle: Text(
                  _pickedTime == null
                      ? '시간을 지정하면 알람을 켤 수 있어요.'
                      : '지정한 시간보다 미리 알람을 울립니다.',
                ),
                onChanged: _pickedTime == null
                    ? null
                    : (v) => setState(() => _alarmEnabled = v),
              ),
              if (_alarmEnabled) ...[
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  initialValue: _alarmOffsetMinutes,
                  decoration: const InputDecoration(
                    labelText: '알람 시점',
                    border: OutlineInputBorder(),
                  ),
                  items: _alarmOffsetChoices
                      .map(
                        (v) => DropdownMenuItem<int>(
                          value: v,
                          child: Text(_alarmOffsetLabel(v)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _alarmOffsetMinutes = v);
                    }
                  },
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  labelText: '제목',
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _memoCtrl,
                decoration: const InputDecoration(
                  labelText: '메모',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                minLines: 3,
                maxLines: 6,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('취소'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _submit,
                    child: const Text('저장'),
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

class _TaskTimePickerField extends StatelessWidget {
  const _TaskTimePickerField({
    required this.pickedTime,
    required this.onTapPicker,
    this.onClear,
  });

  final TimeOfDay? pickedTime;
  final Future<void> Function() onTapPicker;
  final VoidCallback? onClear;

  String _timeLabel() {
    if (pickedTime == null) return '시간 없음';
    return '${pickedTime!.hour.toString().padLeft(2, '0')}:'
        '${pickedTime!.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final hasTime = pickedTime != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('시간'),
          subtitle: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_timeLabel()),
              if (hasTime && onClear != null) ...[
                const SizedBox(width: 4),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: onClear,
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(Icons.close, size: 14),
                  ),
                ),
              ],
            ],
          ),
          trailing: const Icon(Icons.access_time),
          onTap: onTapPicker,
        ),
      ],
    );
  }
}

class _DashboardScheduleDatePickerDialog extends StatefulWidget {
  const _DashboardScheduleDatePickerDialog({required this.initialDay});

  final DateTime initialDay;

  @override
  State<_DashboardScheduleDatePickerDialog> createState() =>
      _DashboardScheduleDatePickerDialogState();
}

class _DashboardScheduleDatePickerDialogState
    extends State<_DashboardScheduleDatePickerDialog> {
  DateTime? _pickedDay;
  bool _readyForUserInput = false;

  @override
  void initState() {
    super.initState();
    _pickedDay = scheduleDateOnly(widget.initialDay);
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
                  '날짜 선택',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              ScrollableCalendarWidget(
                height: calHeight,
                initialRangeStart: _pickedDay,
                initialRangeEnd: _pickedDay,
                initialSelectedDay: _pickedDay,
                onDayPicked: (d) {
                  if (!_readyForUserInput) return;
                  setState(() => _pickedDay = d);
                },
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

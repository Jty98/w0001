import 'package:flutter/material.dart';
import 'package:w0001/data/model/schedule_memo_model.dart';
import 'package:w0001/presentation/viewmodel/dashboard_schedule_view_model.dart';
import 'package:w0001/ui/widget/scrollable_calendar/scrollable_calendar_widget.dart';

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
    required this.placeNameSuggestions,
  });

  final ScheduleMemoModel? existing;
  final DateTime initialDate;
  final TimeOfDay? initialTime;
  final Future<TimeOfDay?> Function(TimeOfDay? initial) onPickTime;
  final List<String> placeNameSuggestions;

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

  Future<void> _pickPlaceNameFromDialog() async {
    if (widget.placeNameSuggestions.isEmpty) return;
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) {
        var query = '';
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final filtered = widget.placeNameSuggestions
                .where((name) => name.toLowerCase().contains(query.toLowerCase()))
                .toList();
            return AlertDialog(
              title: const Text('현장 이름 선택'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: '현장 이름 검색',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (v) => setModalState(() => query = v.trim()),
                    ),
                    const SizedBox(height: 10),
                    Flexible(
                      child: filtered.isEmpty
                          ? const Center(child: Text('검색 결과가 없습니다.'))
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final name = filtered[index];
                                return ListTile(
                                  dense: true,
                                  title: Text(
                                    name,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  onTap: () => Navigator.pop(ctx, name),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('닫기'),
                ),
              ],
            );
          },
        );
      },
    );
    if (selected == null || !mounted) return;
    _titleCtrl.text = selected;
    _titleCtrl.selection = TextSelection.fromPosition(
      TextPosition(offset: _titleCtrl.text.length),
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
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withValues(alpha: 0.5),
                  border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .outlineVariant
                        .withValues(alpha: 0.7),
                  ),
                ),
                child: ListTile(
                  dense: true,
                  leading: Icon(
                    Icons.business_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: const Text(
                    '현장 이름 불러오기',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    '최근 등록된 현장 검색/정렬',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  trailing: FilledButton.tonalIcon(
                    onPressed: _pickPlaceNameFromDialog,
                    icon: const Icon(Icons.search, size: 16),
                    label: const Text('선택'),
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _memoCtrl,
                decoration: const InputDecoration(
                  labelText: '내용',
                  hintText: '작업 상세 내용, 전달사항 등을 입력하세요.',
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
    final screenH = MediaQuery.sizeOf(context).height;
    final maxHeight = (screenH * 0.60).clamp(400.0, 520.0).toDouble();
    final calHeight = (screenH * 0.34).clamp(240.0, 310.0).toDouble();

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
                showViewModeToggle: false,
                disableDateSelectionHighlight: true,
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

import 'package:flutter/material.dart';
import 'package:w0001/data/model/schedule_memo_model.dart';
import 'package:w0001/presentation/viewmodel/dashboard_schedule_view_model.dart';
import 'package:w0001/ui/widget/keyboard_aware.dart';
import 'package:w0001/ui/widget/scrollable_calendar/scrollable_calendar_widget.dart';
import 'package:w0001/util/responsive_layout.dart';
import 'package:w0001/ui/widget/app_text_field.dart';

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

const double _sheetButtonRadius = 10;

ButtonStyle _sheetOutlinedButtonStyle(ColorScheme cs) {
  return OutlinedButton.styleFrom(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(_sheetButtonRadius),
    ),
    side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.75)),
    foregroundColor: cs.onSurface,
    textStyle: const TextStyle(fontWeight: FontWeight.w700),
  );
}

ButtonStyle _sheetFilledButtonStyle(ColorScheme cs) {
  return FilledButton.styleFrom(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(_sheetButtonRadius),
    ),
    textStyle: const TextStyle(fontWeight: FontWeight.w800),
  );
}

TextStyle? _sheetLabelStyle(TextTheme tt, ColorScheme cs) {
  return tt.titleSmall?.copyWith(
    fontWeight: FontWeight.w800,
    color: cs.onSurface,
  );
}

TextStyle? _sheetValueStyle(TextTheme tt, ColorScheme cs) {
  return tt.bodyMedium?.copyWith(
    fontWeight: FontWeight.w700,
    color: cs.onSurface,
  );
}

TextStyle? _sheetHintStyle(TextTheme tt, ColorScheme cs) {
  return tt.bodySmall?.copyWith(
    fontWeight: FontWeight.w600,
    color: cs.onSurfaceVariant,
  );
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
    extends State<DashboardScheduleMemoEditorSheet>
    with KeyboardScrollIntoViewMixin {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _memoCtrl;
  final _titleFocus = FocusNode();
  final _memoFocus = FocusNode();
  final _memoFieldKey = GlobalKey();
  late DateTime _picked;
  TimeOfDay? _pickedTime;
  late bool _alarmEnabled;
  late int _alarmOffsetMinutes;

  @override
  GlobalKey? get keyboardScrollTargetKey => _memoFieldKey;

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
    _titleFocus.addListener(_onTextFieldFocusChanged);
    _memoFocus.addListener(_onTextFieldFocusChanged);
  }

  void _onTextFieldFocusChanged() {
    if (!mounted) return;
    if (_titleFocus.hasFocus || _memoFocus.hasFocus) {
      scheduleKeyboardScrollIntoView();
    }
  }

  @override
  void dispose() {
    _titleFocus.removeListener(_onTextFieldFocusChanged);
    _memoFocus.removeListener(_onTextFieldFocusChanged);
    _titleFocus.dispose();
    _memoFocus.dispose();
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
                .where(
                    (name) => name.toLowerCase().contains(query.toLowerCase()))
                .toList();
            return AlertDialog(
              title: const Text('현장 이름 선택'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppTextField(
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
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final name = filtered[index];
                                return ListTile(
                                  dense: true,
                                  title: Text(
                                    name,
                                    style: Theme.of(ctx)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
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
    final pad = MediaQuery.paddingOf(context);
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final labelStyle = _sheetLabelStyle(tt, cs);
    final valueStyle = _sheetValueStyle(tt, cs);
    final hintStyle = _sheetHintStyle(tt, cs);

    return KeyboardAwareScrollView(
      padding: EdgeInsets.fromLTRB(
        context.rsi(16),
        context.rsi(8),
        context.rsi(16),
        context.rsi(16) + pad.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.existing == null ? '일정 추가' : '일정 수정',
            style: tt.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: cs.onSurface,
            ),
          ),
          rsV(context, 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('날짜', style: labelStyle),
            subtitle: Text(scheduleDateKey(_picked), style: valueStyle),
            trailing: Icon(Icons.calendar_today_outlined, color: cs.onSurface),
            onTap: _pickDateWithScrollableCalendar,
          ),
          _TaskTimePickerField(
            pickedTime: _pickedTime,
            labelStyle: labelStyle,
            valueStyle: valueStyle,
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
            title: Text('사전 알람', style: labelStyle),
            subtitle: Text(
              _pickedTime == null
                  ? '시간을 지정하면 알람을 켤 수 있어요.'
                  : '지정한 시간보다 미리 알람을 울립니다.',
              style: hintStyle,
            ),
            onChanged: _pickedTime == null
                ? null
                : (v) => setState(() => _alarmEnabled = v),
          ),
          if (_alarmEnabled) ...[
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              initialValue: _alarmOffsetMinutes,
              decoration: InputDecoration(
                labelText: '알람 시점',
                labelStyle: labelStyle,
                border: const OutlineInputBorder(),
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
          AppTextField(
            controller: _titleCtrl,
            focusNode: _titleFocus,
            scrollPadding: keyboardScrollPadding(context),
            decoration: InputDecoration(
              labelText: '제목',
              labelStyle: labelStyle,
              border: const OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.next,
            onTap: scheduleKeyboardScrollIntoView,
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: cs.surface,
              border: Border.all(
                color: cs.outlineVariant.withValues(alpha: 0.55),
              ),
            ),
            child: ListTile(
              dense: true,
              leading: Icon(
                Icons.business_outlined,
                color: cs.primary,
              ),
              title: Text(
                '현장 이름 불러오기',
                style: tt.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface,
                ),
              ),
              subtitle: Text(
                '최근 등록된 현장 검색/정렬',
                style: hintStyle,
              ),
              trailing: OutlinedButton.icon(
                onPressed: _pickPlaceNameFromDialog,
                icon: const Icon(Icons.search, size: 16),
                label: const Text('선택'),
                style: _sheetOutlinedButtonStyle(cs).copyWith(
                  foregroundColor: WidgetStatePropertyAll(cs.primary),
                  side: WidgetStatePropertyAll(
                    BorderSide(
                      color: cs.primary.withValues(alpha: 0.55),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          KeyedSubtree(
            key: _memoFieldKey,
            child: AppTextField(
              controller: _memoCtrl,
              focusNode: _memoFocus,
              scrollPadding: keyboardScrollPadding(context, extra: 80),
              decoration: InputDecoration(
                labelText: '내용',
                hintText: '작업 상세 내용, 전달사항 등을 입력하세요.',
                labelStyle: labelStyle,
                hintStyle: hintStyle,
                border: const OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              minLines: 3,
              maxLines: 6,
              onTap: scheduleKeyboardScrollIntoView,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: _sheetOutlinedButtonStyle(cs),
                child: const Text('취소'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: _submit,
                style: _sheetFilledButtonStyle(cs),
                child: const Text('저장'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TaskTimePickerField extends StatelessWidget {
  const _TaskTimePickerField({
    required this.pickedTime,
    required this.onTapPicker,
    this.onClear,
    this.labelStyle,
    this.valueStyle,
  });

  final TimeOfDay? pickedTime;
  final Future<void> Function() onTapPicker;
  final VoidCallback? onClear;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;

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
          title: Text('시간', style: labelStyle),
          subtitle: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_timeLabel(), style: valueStyle),
              if (hasTime && onClear != null) ...[
                const SizedBox(width: 4),
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: onClear,
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(Icons.close, size: 14),
                  ),
                ),
              ],
            ],
          ),
          trailing: Icon(
            Icons.access_time,
            color: Theme.of(context).colorScheme.onSurface,
          ),
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
    final cs = Theme.of(context).colorScheme;

    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Padding(
          padding: ResponsiveLayout.only(context, bottom: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: ResponsiveLayout.symmetric(context, vertical: 10),
                child: Text(
                  '날짜 선택',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
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

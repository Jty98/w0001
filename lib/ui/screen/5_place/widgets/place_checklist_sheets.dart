import 'package:flutter/material.dart';
import 'package:w0001/data/model/place_checklist_models.dart';
import 'package:w0001/domain/process_schedule/process_schedule_editor.dart';
import 'package:w0001/domain/process_schedule/process_schedule_models.dart';
import 'package:w0001/presentation/viewmodel/dashboard_schedule_view_model.dart';
import 'package:w0001/theme/app_input_styles.dart';
import 'package:w0001/ui/screen/5_place/process_schedule/process_schedule_helpers.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 바텀시트 공정 칩 — 직접 입력 모드 라벨(저장값 아님).
const kChecklistCustomGroupChipLabel = '직접 입력';

/// 공정표 기준 해당 날짜에 예정된 공정명 목록.
List<String> processGroupsScheduledOn(
  ProcessScheduleData schedule,
  DateTime day,
) {
  final key = scheduleDateKey(scheduleDateOnly(day));
  final cols = ProcessScheduleEditor.columnDates(schedule);
  final out = <String>[];
  for (final t in schedule.tasks) {
    final name = t.name.trim();
    if (name.isEmpty) continue;
    for (final idx in t.scheduledDayIndices) {
      if (idx < 0 || idx >= cols.length) continue;
      if (scheduleDateKey(cols[idx]) == key) {
        out.add(name);
        break;
      }
    }
  }
  return out;
}

/// 체크리스트 추가·수정 시 선택 가능한 공정 — **당일 공정표 예정만**.
List<String> editorProcessGroupOptions({
  required ProcessScheduleData schedule,
  required DateTime day,
}) {
  return processGroupsScheduledOn(schedule, day);
}

String checklistItemGroupKey(PlaceChecklistItem item) {
  final g = item.processGroup.trim();
  if (g.isNotEmpty) return g;
  return item.title.trim();
}

String checklistGroupSectionTitle(String groupKey) =>
    groupKey.isEmpty ? kChecklistCustomGroupChipLabel : groupKey;

Map<String, List<PlaceChecklistItem>> groupChecklistItems(
  List<PlaceChecklistItem> items,
) {
  final map = <String, List<PlaceChecklistItem>>{};
  for (final item in items) {
    final g = checklistItemGroupKey(item);
    map.putIfAbsent(g, () => []).add(item);
  }
  for (final list in map.values) {
    list.sort((a, b) {
      final s = a.sortOrder.compareTo(b.sortOrder);
      if (s != 0) return s;
      return a.createdAtMs.compareTo(b.createdAtMs);
    });
  }
  final keys = map.keys.toList()..sort();
  return {for (final k in keys) k: map[k]!};
}

class PlaceChecklistEditorResult {
  const PlaceChecklistEditorResult({
    required this.title,
    required this.processGroup,
  });

  final String title;
  final String processGroup;
}

Future<PlaceChecklistEditorResult?> showPlaceChecklistItemEditor(
  BuildContext context, {
  required List<String> scheduledProcessGroups,
  PlaceChecklistItem? existing,
  String? initialProcessGroup,
}) {
  return showModalBottomSheet<PlaceChecklistEditorResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) => _PlaceChecklistItemEditorSheet(
      scheduledProcessGroups: scheduledProcessGroups,
      existing: existing,
      initialProcessGroup: initialProcessGroup,
    ),
  );
}

class _PlaceChecklistItemEditorSheet extends StatefulWidget {
  const _PlaceChecklistItemEditorSheet({
    required this.scheduledProcessGroups,
    this.existing,
    this.initialProcessGroup,
  });

  final List<String> scheduledProcessGroups;
  final PlaceChecklistItem? existing;
  final String? initialProcessGroup;

  @override
  State<_PlaceChecklistItemEditorSheet> createState() =>
      _PlaceChecklistItemEditorSheetState();
}

class _PlaceChecklistItemEditorSheetState
    extends State<_PlaceChecklistItemEditorSheet> {
  late final TextEditingController _titleCtrl;
  late bool _customMode;
  String? _selectedScheduled;

  @override
  void initState() {
    super.initState();
    final scheduled = widget.scheduledProcessGroups;
    final existing = widget.existing;
    final existingTitle = existing?.displayTitle ?? '';
    final existingGroup = existing?.processGroup.trim() ?? '';
    final initialGroup = widget.initialProcessGroup?.trim() ?? '';
    final prefer = existingGroup.isNotEmpty ? existingGroup : initialGroup;

    if (prefer.isNotEmpty && scheduled.contains(prefer)) {
      _customMode = false;
      _selectedScheduled = prefer;
      _titleCtrl = TextEditingController(
        text: existingTitle.isNotEmpty ? existingTitle : prefer,
      );
    } else if (prefer.isNotEmpty) {
      _customMode = true;
      _selectedScheduled = null;
      _titleCtrl = TextEditingController(
        text: existingTitle.isNotEmpty ? existingTitle : prefer,
      );
    } else if (scheduled.isNotEmpty) {
      _customMode = false;
      _selectedScheduled = scheduled.first;
      _titleCtrl = TextEditingController(text: scheduled.first);
    } else {
      _customMode = true;
      _selectedScheduled = null;
      _titleCtrl = TextEditingController(text: existingTitle);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  String _resolvedProcessGroup(String title) {
    if (_customMode) return title;
    final selected = _selectedScheduled?.trim() ?? '';
    return selected.isNotEmpty ? selected : title;
  }

  void _selectScheduled(String group) {
    final prev = _selectedScheduled;
    final current = _titleCtrl.text.trim();
    setState(() {
      _customMode = false;
      _selectedScheduled = group;
      if (current.isEmpty || current == prev) {
        _titleCtrl.text = group;
        _titleCtrl.selection = TextSelection.collapsed(offset: group.length);
      }
    });
  }

  void _selectCustom() {
    setState(() {
      _customMode = true;
      _selectedScheduled = null;
    });
  }

  void _submit() {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;
    Navigator.of(context).pop(
      PlaceChecklistEditorResult(
        title: title,
        processGroup: _resolvedProcessGroup(title),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final isEdit = widget.existing != null;
    final scheduled = widget.scheduledProcessGroups;
    final canSubmit = _titleCtrl.text.trim().isNotEmpty;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.rsi(20),
        context.rsi(8),
        context.rsi(20),
        context.rsi(20) + bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            isEdit ? '체크리스트 수정' : '체크리스트 추가',
            style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          rsV(context, 16),
          Text('공정', style: tt.labelLarge),
          rsV(context, 6),
          if (scheduled.isEmpty)
            Text(
              '당일 공정표에 예정된 공정이 없습니다. 항목만 입력하면 됩니다.',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            )
          else
            Text(
              '공정을 고르면 항목이 채워집니다. 필요하면 내용만 고치면 됩니다.',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          rsV(context, 8),
          Wrap(
            spacing: context.rsi(8),
            runSpacing: context.rsi(8),
            children: [
              for (final g in scheduled)
                FilterChip(
                  label: Text(g),
                  selected: !_customMode && _selectedScheduled == g,
                  onSelected: (_) => _selectScheduled(g),
                ),
              FilterChip(
                label: const Text(kChecklistCustomGroupChipLabel),
                selected: _customMode,
                onSelected: (_) => _selectCustom(),
              ),
            ],
          ),
          rsV(context, 16),
          TextField(
            controller: _titleCtrl,
            autofocus: true,
            style: AppInputStyles.fieldText(context),
            decoration: InputDecoration(
              labelText: '항목',
              hintText: _customMode ? '예: 덕트시공' : '예: 덕트 설치, 배관 점검',
              border: const OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _submit(),
          ),
          rsV(context, 20),
          FilledButton(
            onPressed: canSubmit ? _submit : null,
            child: Text(isEdit ? '저장' : '추가'),
          ),
          rsV(context, 8),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('취소', style: TextStyle(color: cs.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }
}

class PlaceChecklistDeferResult {
  const PlaceChecklistDeferResult({this.reason = ''});

  final String reason;
}

Future<PlaceChecklistDeferResult?> showPlaceChecklistDeferSheet(
  BuildContext context, {
  required PlaceChecklistItem item,
  required String toDateKey,
}) {
  return showModalBottomSheet<PlaceChecklistDeferResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) => _PlaceChecklistDeferSheet(
      item: item,
      toDateKey: toDateKey,
    ),
  );
}

class _PlaceChecklistDeferSheet extends StatefulWidget {
  const _PlaceChecklistDeferSheet({
    required this.item,
    required this.toDateKey,
  });

  final PlaceChecklistItem item;
  final String toDateKey;

  @override
  State<_PlaceChecklistDeferSheet> createState() =>
      _PlaceChecklistDeferSheetState();
}

class _PlaceChecklistDeferSheetState extends State<_PlaceChecklistDeferSheet> {
  final _reasonCtrl = TextEditingController();

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(context).pop(
      PlaceChecklistDeferResult(reason: _reasonCtrl.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final toDay = scheduleDateFromTaskKey(widget.toDateKey);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.rsi(20),
        context.rsi(8),
        context.rsi(20),
        context.rsi(20) + bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '다음날로 미루기',
            style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          rsV(context, 8),
          Text(
            '"${widget.item.displayTitle}" 항목을\n${periodDropdownLabel(toDay)} 체크리스트로 옮깁니다.',
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          rsV(context, 16),
          TextField(
            controller: _reasonCtrl,
            style: AppInputStyles.fieldText(context),
            decoration: const InputDecoration(
              labelText: '사유 (선택)',
              hintText: '예: 자재 미도착',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
            textInputAction: TextInputAction.done,
          ),
          rsV(context, 20),
          FilledButton.tonal(
            onPressed: _submit,
            child: const Text('미루기'),
          ),
          rsV(context, 8),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('취소', style: TextStyle(color: cs.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }
}

String deferReasonOrPlaceholder(PlaceChecklistDeferral d) {
  final r = d.reason.trim();
  return r.isEmpty ? '사유 없음' : r;
}

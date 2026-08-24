import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:w0001/data/model/place_checklist_models.dart';
import 'package:w0001/data/model/place_info_model.dart';
import 'package:w0001/presentation/viewmodel/place_checklist_notifier.dart';
import 'package:w0001/presentation/viewmodel/place_list_view_model.dart';
import 'package:w0001/presentation/viewmodel/place_process_schedule_notifier.dart';
import 'package:w0001/theme/app_colors.dart';
import 'package:w0001/theme/app_elevation.dart';
import 'package:w0001/theme/app_theme_colors.dart';
import 'package:w0001/ui/screen/5_place/process_schedule/process_schedule_helpers.dart';
import 'package:w0001/ui/screen/5_place/widgets/place_checklist_sheets.dart';
import 'package:w0001/ui/screen/1_dashboard/widgets/worker_dashboard_section_shell.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 작업자 대시보드 — 현장 선택 후 오늘 체크리스트 CRUD.
class WorkerDashboardChecklistSection extends ConsumerStatefulWidget {
  const WorkerDashboardChecklistSection({super.key});

  @override
  ConsumerState<WorkerDashboardChecklistSection> createState() =>
      _WorkerDashboardChecklistSectionState();
}

class _WorkerDashboardChecklistSectionState
    extends ConsumerState<WorkerDashboardChecklistSection> {
  int? _selectedPid;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final st = ref.read(placeListProvider);
      if (!st.hasLoadedOnce && !st.isLoading) {
        ref.read(placeListProvider.notifier).initialize();
      }
    });
  }

  List<PlaceInfoModel> _inProgressPlaces(List<PlaceInfoModel> all) {
    return all
        .where((p) => p.pcomplete == 0 && (p.pid ?? 0) > 0)
        .toList(growable: false);
  }

  PlaceInfoModel? _selectedPlace(List<PlaceInfoModel> places) {
    if (places.isEmpty) return null;
    final pid = _selectedPid;
    if (pid != null) {
      for (final p in places) {
        if (p.pid == pid) return p;
      }
    }
    return places.first;
  }

  PlaceChecklistFamilyArg _checklistArg(PlaceInfoModel place) => (
        pid: place.pid ?? 0,
        pstart: place.pstart,
        pend: place.pend,
      );

  ProcessScheduleFamilyArg _scheduleArg(PlaceInfoModel place) => (
        pid: place.pid ?? 0,
        pstart: place.pstart,
        pend: place.pend,
      );

  List<String> _scheduledGroupsFor(PlaceInfoModel place, DateTime day) {
    final schedule =
        ref.read(placeProcessScheduleProvider(_scheduleArg(place)));
    return editorProcessGroupOptions(schedule: schedule.data, day: day);
  }

  Future<void> _onAdd(PlaceInfoModel place, {String? processGroup}) async {
    final arg = _checklistArg(place);
    final checklist = ref.read(placeChecklistProvider(arg));
    final groups = _scheduledGroupsFor(place, checklist.selectedDate);
    final result = await showPlaceChecklistItemEditor(
      context,
      scheduledProcessGroups: groups,
      initialProcessGroup: processGroup,
    );
    if (result == null || !mounted) return;
    await ref.read(placeChecklistProvider(arg).notifier).addItem(
          title: result.title,
          processGroup: result.processGroup,
        );
  }

  Future<void> _onEdit(PlaceInfoModel place, PlaceChecklistItem item) async {
    final arg = _checklistArg(place);
    final checklist = ref.read(placeChecklistProvider(arg));
    final groups = _scheduledGroupsFor(place, checklist.selectedDate);
    final result = await showPlaceChecklistItemEditor(
      context,
      scheduledProcessGroups: groups,
      existing: item,
    );
    if (result == null || !mounted) return;
    await ref.read(placeChecklistProvider(arg).notifier).updateItem(
          item.copyWith(
            title: result.title,
            processGroup: result.processGroup,
          ),
        );
  }

  Future<void> _deferItem(PlaceInfoModel place, PlaceChecklistItem item) async {
    if (item.isChecked) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '완료된 항목은 미룰 수 없습니다. 체크를 해제한 뒤 다시 시도해 주세요.',
          ),
        ),
      );
      return;
    }
    final toKey = placeChecklistDefaultDeferToDate(item.workDate);
    final result = await showPlaceChecklistDeferSheet(
      context,
      item: item,
      toDateKey: toKey,
    );
    if (result == null || !mounted) return;
    await ref
        .read(placeChecklistProvider(_checklistArg(place)).notifier)
        .deferItem(
          itemId: item.id,
          reason: result.reason,
          toDate: toKey,
        );
  }

  Future<void> _confirmDelete(
    PlaceInfoModel place,
    PlaceChecklistItem item,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('항목 삭제'),
        content: Text('"${item.displayTitle}" 항목을 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await ref
        .read(placeChecklistProvider(_checklistArg(place)).notifier)
        .deleteItem(item.id);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final placeState = ref.watch(placeListProvider);
    final places = _inProgressPlaces(placeState.placeList);
    final selected = _selectedPlace(places);

    return WorkerDashboardSectionShell(
      icon: Icons.checklist_rounded,
      title: '오늘 현장별 체크리스트',
      subtitle: selected?.pname.trim().isNotEmpty == true
          ? selected!.pname.trim()
          : '진행 중 현장의 오늘 할 일',
      trailing: IconButton(
        tooltip: '항목 추가',
        visualDensity: VisualDensity.compact,
        onPressed: selected == null ? null : () => _onAdd(selected),
        icon: Icon(Icons.add_circle_outline_rounded, color: cs.primary),
      ),
      child: !placeState.hasLoadedOnce && placeState.isLoading
          ? Text(
              '현장 목록 불러오는 중…',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            )
          : placeState.loadError != null
              ? _ChecklistMessageCard(
                  message: '현장 목록을 불러오지 못했습니다.',
                  cs: cs,
                  tt: tt,
                )
              : places.isEmpty
                  ? _ChecklistMessageCard(
                      message: '진행 중인 현장이 없습니다.',
                      cs: cs,
                      tt: tt,
                    )
                  : selected == null
                      ? const SizedBox.shrink()
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _PlaceDropdown(
                              places: places,
                              selected: selected,
                              onChanged: places.length <= 1
                                  ? null
                                  : (p) => setState(() => _selectedPid = p.pid),
                            ),
                            if (places.length <= 1)
                              Padding(
                                padding: EdgeInsets.only(top: context.rsi(6)),
                                child: Text(
                                  '진행 중 현장 1곳',
                                  style: tt.labelSmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            SizedBox(height: context.rsi(10)),
                            _DashboardChecklistBody(
                              place: selected,
                              onAdd: (group) =>
                                  _onAdd(selected, processGroup: group),
                              onEdit: (item) => _onEdit(selected, item),
                              onDefer: (item) => _deferItem(selected, item),
                              onDelete: (item) =>
                                  _confirmDelete(selected, item),
                            ),
                          ],
                        ),
    );
  }
}

class _PlaceDropdown extends StatelessWidget {
  const _PlaceDropdown({
    required this.places,
    required this.selected,
    required this.onChanged,
  });

  final List<PlaceInfoModel> places;
  final PlaceInfoModel selected;
  final ValueChanged<PlaceInfoModel>? onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: context.rsi(12)),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<int>(
            isExpanded: true,
            value: selected.pid,
            items: places
                .map(
                  (p) => DropdownMenuItem(
                    value: p.pid,
                    child: Text(
                      p.pname.trim().isEmpty ? '현장 #${p.pid}' : p.pname.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: onChanged == null
                ? null
                : (pid) {
                    if (pid == null) return;
                    final match = places.where((p) => p.pid == pid).firstOrNull;
                    if (match != null) onChanged!(match);
                  },
          ),
        ),
      ),
    );
  }
}

class _DashboardChecklistBody extends ConsumerWidget {
  const _DashboardChecklistBody({
    required this.place,
    required this.onAdd,
    required this.onEdit,
    required this.onDefer,
    required this.onDelete,
  });

  final PlaceInfoModel place;
  final void Function(String? processGroup) onAdd;
  final ValueChanged<PlaceChecklistItem> onEdit;
  final ValueChanged<PlaceChecklistItem> onDefer;
  final ValueChanged<PlaceChecklistItem> onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final pid = place.pid ?? 0;
    final arg = (
      pid: pid,
      pstart: place.pstart,
      pend: place.pend,
    );
    final scheduleArg = (
      pid: pid,
      pstart: place.pstart,
      pend: place.pend,
    );
    final state = ref.watch(placeChecklistProvider(arg));
    final vm = ref.read(placeChecklistProvider(arg).notifier);
    final scheduleState = ref.watch(placeProcessScheduleProvider(scheduleArg));
    final loading = state.isLoading && state.snapshot == null;
    final dayItems = state.dayItems;
    final dayDeferrals = state.dayDeferrals;
    final grouped = groupChecklistItems(dayItems);
    final active = state.activeCount;
    final checked = state.checkedCount;
    final scheduledToday = processGroupsScheduledOn(
      scheduleState.data,
      state.selectedDate,
    );

    if (loading) {
      return _ChecklistMessageCard(
        message: '체크리스트 불러오는 중…',
        cs: cs,
        tt: tt,
      );
    }

    if (state.error != null) {
      return _ChecklistMessageCard(message: state.error!, cs: cs, tt: tt);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (active > 0)
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: checked / active,
                    minHeight: context.rs(5),
                    backgroundColor:
                        cs.surfaceContainerHighest.withValues(alpha: 0.8),
                  ),
                ),
              ),
              SizedBox(width: context.rsi(10)),
              Text(
                '$checked / $active',
                style: tt.labelMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        if (scheduledToday.isNotEmpty) ...[
          SizedBox(height: context.rsi(10)),
          _ScheduledProcessBanner(groups: scheduledToday),
        ],
        SizedBox(height: context.rsi(10)),
        if (dayItems.isEmpty)
          _ChecklistMessageCard(
            message: '오늘 등록된 체크리스트 항목이 없습니다.',
            cs: cs,
            tt: tt,
          )
        else
          ...grouped.entries.map((entry) {
            final groupKey = entry.key;
            final items = entry.value;
            final groupTitle = checklistGroupSectionTitle(groupKey);
            final onSchedule = scheduledToday.contains(groupKey);
            return Padding(
              padding: EdgeInsets.only(bottom: context.rsi(10)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          groupTitle,
                          style: tt.labelLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (onSchedule)
                        Container(
                          margin: EdgeInsets.only(right: context.rsi(4)),
                          padding: EdgeInsets.symmetric(
                            horizontal: context.rsi(8),
                            vertical: context.rsi(3),
                          ),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF6750A4).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '공정 예정',
                            style: tt.labelSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF6750A4),
                            ),
                          ),
                        ),
                      IconButton(
                        tooltip: '$groupTitle 항목 추가',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => onAdd(
                          groupKey.isEmpty ? null : groupKey,
                        ),
                        icon: Icon(
                          Icons.add_circle_outline_rounded,
                          size: context.rs(20),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: context.rsi(4)),
                  ...items.map(
                    (item) => _DashboardChecklistItemTile(
                      item: item,
                      onToggle: () => vm.toggleChecked(item),
                      onEdit: () => onEdit(item),
                      onDefer: () => onDefer(item),
                      onDelete: () => onDelete(item),
                    ),
                  ),
                ],
              ),
            );
          }),
        if (dayDeferrals.isNotEmpty) ...[
          SizedBox(height: context.rsi(4)),
          Text(
            '미루기 기록',
            style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          SizedBox(height: context.rsi(6)),
          ...dayDeferrals.map(
            (d) => Padding(
              padding: EdgeInsets.only(bottom: context.rsi(6)),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
                child: ListTile(
                  dense: true,
                  leading: Icon(
                    Icons.arrow_forward_rounded,
                    color: cs.tertiary,
                    size: context.rs(18),
                  ),
                  title: Text(
                    d.title,
                    style: tt.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${d.fromDate} → ${d.toDate}',
                    style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ScheduledProcessBanner extends StatelessWidget {
  const _ScheduledProcessBanner({required this.groups});

  final List<String> groups;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF6750A4).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: context.rsi(10),
          vertical: context.rsi(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.calendar_view_month_rounded,
              size: context.rs(16),
              color: const Color(0xFF6750A4),
            ),
            SizedBox(width: context.rsi(8)),
            Expanded(
              child: Text(
                '공정표: ${groups.join(' · ')}',
                style: tt.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardChecklistItemTile extends StatelessWidget {
  const _DashboardChecklistItemTile({
    required this.item,
    required this.onToggle,
    required this.onEdit,
    required this.onDefer,
    required this.onDelete,
  });

  final PlaceChecklistItem item;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDefer;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final deferred = item.isDeferred;
    final checked = item.isChecked;

    final tile = DecoratedBox(
      decoration: AppElevation.insetTile(
        context: context,
        backgroundColor: cs.appInsetFill,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        dense: true,
        contentPadding: EdgeInsets.symmetric(
          horizontal: context.rsi(4),
          vertical: context.rsi(0),
        ),
        leading: Checkbox(
          value: checked,
          onChanged: deferred ? null : (_) => onToggle(),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        title: Text(
          item.displayTitle,
          style: tt.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            decoration: deferred || checked ? TextDecoration.lineThrough : null,
            color: deferred || checked ? cs.onSurfaceVariant : cs.onSurface,
          ),
        ),
        subtitle: deferred
            ? Text(
                '다음날로 미룸',
                style: tt.labelSmall?.copyWith(
                  color: cs.tertiary,
                  fontWeight: FontWeight.w700,
                ),
              )
            : null,
        onTap: deferred ? null : onToggle,
        onLongPress: onEdit,
      ),
    );

    if (deferred) {
      return Padding(
        padding: EdgeInsets.only(bottom: context.rsi(6)),
        child: tile,
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: context.rsi(6)),
      child: Slidable(
        endActionPane: ActionPane(
          motion: const DrawerMotion(),
          extentRatio: checked ? 0.36 : 0.72,
          children: [
            if (!checked)
              SlidableAction(
                onPressed: (_) => onDefer(),
                backgroundColor: cs.tertiaryContainer,
                foregroundColor: cs.onTertiaryContainer,
                icon: Icons.event_available_rounded,
                label: '미루기',
              ),
            SlidableAction(
              onPressed: (_) => onDelete(),
              backgroundColor: cs.errorContainer,
              foregroundColor: cs.onErrorContainer,
              icon: Icons.delete_outline_rounded,
              label: '삭제',
            ),
          ],
        ),
        child: tile,
      ),
    );
  }
}

class _ChecklistMessageCard extends StatelessWidget {
  const _ChecklistMessageCard({
    required this.message,
    required this.cs,
    required this.tt,
  });

  final String message;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: AppElevation.insetTile(
        context: context,
        backgroundColor: cs.appMutedFill,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(context.rsi(12)),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: tt.bodySmall?.copyWith(
            color: cs.onSurfaceVariant,
            height: 1.35,
          ),
        ),
      ),
    );
  }
}

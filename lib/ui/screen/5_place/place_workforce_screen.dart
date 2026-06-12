import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/access/user_role_access.dart';
import 'package:w0001/data/model/human_model.dart';
import 'package:w0001/data/model/remote/super_admin_dtos.dart';
import 'package:w0001/domain/process_schedule/process_schedule_models.dart';
import 'package:w0001/presentation/viewmodel/auth_providers.dart';
import 'package:w0001/presentation/viewmodel/place_process_schedule_notifier.dart';
import 'package:w0001/presentation/viewmodel/place_workforce_notifier.dart';
import 'package:w0001/presentation/viewmodel/super_admin_remote_providers.dart';
import 'package:w0001/ui/screen/5_place/place_workforce_editor_sheet.dart';
import 'package:w0001/ui/screen/5_place/place_workforce_models.dart';
import 'package:w0001/ui/screen/5_place/place_workforce_person_row.dart';
import 'package:w0001/ui/screen/5_place/place_workforce_schedule.dart';
import 'package:w0001/ui/screen/5_place/place_workforce_task_card.dart';
import 'package:w0001/ui/screen/5_place/place_workforce_toolbar.dart';
import 'package:w0001/ui/widget/scrollable_calendar/scrollable_calendar_widget.dart';
import 'package:w0001/util/funtions.dart';
import 'package:w0001/util/responsive_layout.dart';
import 'package:skeletonizer/skeletonizer.dart';

export 'place_workforce_models.dart' show PlaceWorkforceRouteExtra;

/// 현장별 인력 투입(`place-work-days`) + 공정표 일정 연동.
class PlaceWorkforceScreen extends ConsumerStatefulWidget {
  const PlaceWorkforceScreen({super.key, required this.extra});

  final PlaceWorkforceRouteExtra extra;

  @override
  ConsumerState<PlaceWorkforceScreen> createState() =>
      _PlaceWorkforceScreenState();
}

class _PlaceWorkforceScreenState extends ConsumerState<PlaceWorkforceScreen> {
  var _pickedInitialDay = false;
  var _rosterListExpanded = true;

  ProcessScheduleFamilyArg get _scheduleArg => (
        pid: widget.extra.placeInfo.pid ?? 0,
        pstart: widget.extra.placeInfo.pstart,
        pend: widget.extra.placeInfo.pend,
      );

  int get _pid => widget.extra.placeInfo.pid ?? 0;

  void _ensurePickedInitialDay(PlaceProcessScheduleState sch) {
    if (!sch.isReady || _pickedInitialDay) return;
    _pickedInitialDay = true;
    final fromRoute = widget.extra.initialWorkDate;
    final base = fromRoute != null
        ? DateTime(fromRoute.year, fromRoute.month, fromRoute.day)
        : DateTime.now();
    final clamped = PlaceWorkforceSchedule.clampToGrid(base, sch.data);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(placeWorkforceProvider(_pid).notifier).setSelectedDay(clamped);
    });
  }

  String _rowDateKey(PlaceWorkDayRead r) =>
      r.workdate.length >= 10 ? r.workdate.substring(0, 10) : r.workdate;

  List<PlaceWorkDayRead> _rowsForSelectedDay(
    List<PlaceWorkDayRead> rows,
    String iso,
  ) =>
      rows.where((r) => _rowDateKey(r) == iso).toList();

  String _humanName(List<HumanModel> humans, int hid) {
    for (final h in humans) {
      if (h.hid == hid) return h.hname;
    }
    return 'hid $hid';
  }

  List<HumanModel> _activeWorkers(List<HumanModel> humans) => humans
      .where((h) => h.hid != null && h.hdelete == 0)
      .toList(growable: false);

  Future<void> _deleteRow(PlaceWorkDayRead row) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('투입 삭제'),
        content: Text(
          '${row.workdate} · ${_humanName(ref.read(placeWorkforceProvider(_pid)).humans, row.hid)}\n이 투입 기록을 삭제할까요?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              '삭제',
              style: TextStyle(color: Theme.of(ctx).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ref
          .read(superAdminRemoteUseCaseProvider)
          .placeWorkDayDelete(row.pwdid);
      await ref.read(placeWorkforceProvider(_pid).notifier).reload(silent: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('삭제했습니다.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('삭제 실패: $e')),
        );
      }
    }
  }

  Future<void> _addProcessForSelectedDay() async {
    final canEdit =
        ref.read(authSessionProvider).asData?.value?.isManagementRole ?? false;
    if (!canEdit) return;

    final notifier =
        ref.read(placeProcessScheduleProvider(_scheduleArg).notifier);
    var data = ref.read(placeProcessScheduleProvider(_scheduleArg)).data;
    final sel = ref.read(placeWorkforceProvider(_pid)).selectedDay;
    var idx = PlaceWorkforceSchedule.dayIndex(sel, data);
    if (idx == null) {
      notifier.expandGridToIncludeDay(sel);
      data = ref.read(placeProcessScheduleProvider(_scheduleArg)).data;
      idx = PlaceWorkforceSchedule.dayIndex(sel, data);
    }
    if (idx == null) return;

    final nameCtrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('이 날짜에 공정 추가'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(
            labelText: '공정 이름',
            hintText: '예: 전기, 타일, 목공',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              final t = nameCtrl.text.trim();
              if (t.isEmpty) return;
              Navigator.pop(ctx, t);
            },
            child: const Text('추가'),
          ),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      nameCtrl.dispose();
    });
    if (name == null || !mounted) return;

    notifier.addProcess(name, idx, idx);
    try {
      await notifier.persist(syncPlaceMaster: widget.extra.placeInfo);
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('공정표에 반영했습니다.')),
      );
    } catch (e) {
      ref.invalidate(placeProcessScheduleProvider(_scheduleArg));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            PlaceProcessScheduleNotifier.messageForPersistError(e),
          ),
        ),
      );
    }
  }

  /// 공정표 그리드에 없는 날이면 범위를 넓히고 서버에 반영한다.
  Future<bool> _ensureScheduleGridIncludesDay(DateTime day) async {
    final sch = ref.read(placeProcessScheduleProvider(_scheduleArg));
    if (!sch.isReady) return false;
    if (PlaceWorkforceSchedule.dayIndex(day, sch.data) != null) return true;

    final notifier =
        ref.read(placeProcessScheduleProvider(_scheduleArg).notifier);
    notifier.expandGridToIncludeDay(day);
    try {
      await notifier.persist(syncPlaceMaster: widget.extra.placeInfo);
      if (mounted) setState(() {});
      return true;
    } catch (e) {
      ref.invalidate(placeProcessScheduleProvider(_scheduleArg));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              PlaceProcessScheduleNotifier.messageForPersistError(e),
            ),
          ),
        );
      }
      return false;
    }
  }

  Future<void> _onAddWorkforceOnlyTapped() async {
    final sel = ref.read(placeWorkforceProvider(_pid)).selectedDay;
    final ok = await _ensureScheduleGridIncludesDay(sel);
    if (!ok || !mounted) return;
    await _showEditorSheet(
      context,
      initialDate: sel,
      defaultWorkrole: null,
    );
  }

  /// 공정명과 맞지 않는 날짜별 투입(기타 투입) 카드 묶음.
  List<Widget> _otherWorkforceWidgets(
    DateTime selectedDay,
    List<HumanModel> humans,
    List<PlaceWorkDayRead> otherRows,
    bool canEdit,
  ) {
    if (otherRows.isEmpty) return const [];
    return [
      const PlaceWorkforceSectionLabel(
        title: '기타 투입',
        subtitle: '공정표 공정명과 다른 역할로 등록된 인력',
        icon: Icons.badge_outlined,
      ),
      PlaceWorkforceOtherRolesCollapsibleCard(
        otherRows: otherRows,
        canEdit: canEdit,
        humanName: (hid) => _humanName(humans, hid),
        onEditRow: canEdit
            ? (r) => _showEditorSheet(
                  context,
                  initialDate: selectedDay,
                  existing: r,
                )
            : null,
        onDeleteRow:
            canEdit ? (r) => unawaited(_deleteRow(r)) : null,
      ),
    ];
  }

  String _rosterCollapseSummary({
    required int? dayIdx,
    required int taskCount,
    required int rosterRowCount,
    required int otherRowCount,
  }) {
    if (dayIdx == null) {
      if (otherRowCount == 0) return '공정 범위 밖 날짜 · 투입 없음';
      return '공정 범위 밖 · 기타 투입 $otherRowCount명';
    }
    if (taskCount == 0 && otherRowCount == 0 && rosterRowCount == 0) {
      return '이 날 등록된 투입 없음';
    }
    if (otherRowCount == 0) {
      return '$taskCount개 공정 · $rosterRowCount명 투입';
    }
    return '$taskCount개 공정 · $rosterRowCount명 (+기타 $otherRowCount명)';
  }

  Widget _rosterCollapsedStrip(ColorScheme cs, String summary) {
    final compact = MediaQuery.sizeOf(context).height < 720;
    final tt = Theme.of(context).textTheme;
    return Material(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
      child: InkWell(
        onTap: () => setState(() => _rosterListExpanded = true),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.rsi(16),
            vertical: context.rsi(compact ? 10 : 14),
          ),
          child: Row(
            children: [
              Icon(
                Icons.groups_2_outlined,
                color: cs.primary,
                size: context.rs(compact ? 22 : 26),
              ),
              SizedBox(width: context.rsi(compact ? 10 : 12)),
              Expanded(
                child: Text(
                  summary,
                  style: tt.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                    color: cs.onSurface,
                  ),
                ),
              ),
              Icon(Icons.expand_more_rounded, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showEditorSheet(
    BuildContext context, {
    required DateTime initialDate,
    PlaceWorkDayRead? existing,
    String? defaultWorkrole,
  }) async {
    final canEdit =
        ref.read(authSessionProvider).asData?.value?.isManagementRole ?? false;
    if (!canEdit) return;

    final ok = await _ensureScheduleGridIncludesDay(initialDate);
    if (!ok) return;

    final wf = ref.read(placeWorkforceProvider(_pid));
    final workers = _activeWorkers(wf.humans);

    if (!context.mounted) return;
    final wasCreate = existing == null;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(ctx).bottom,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(ctx).height * 0.88,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              ctx.rsi(20),
              ctx.rsi(4),
              ctx.rsi(20),
              ctx.rsi(20),
            ),
            child: PlaceWorkforceEditorSheet(
              placeInfo: widget.extra.placeInfo,
              initialDate: initialDate,
              existing: existing,
              workers: workers,
              defaultWorkrole: defaultWorkrole,
              pid: _pid,
              humanName: (hid) => _humanName(wf.humans, hid),
              onSuccess: ([msg]) async {
                await ref
                    .read(placeWorkforceProvider(_pid).notifier)
                    .reload(silent: true);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      msg ?? (wasCreate ? '저장했습니다.' : '수정했습니다.'),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sch = ref.watch(placeProcessScheduleProvider(_scheduleArg));
    final wf = ref.watch(placeWorkforceProvider(_pid));
    _ensurePickedInitialDay(sch);

    final p = widget.extra.placeInfo;
    final canEdit =
        ref.watch(authSessionProvider).asData?.value?.isManagementRole ??
            false;

    if (!sch.isReady || wf.initialLoading) {
      final calendarH = workforceCalendarHeight(context);
      final cs = Theme.of(context).colorScheme;
      return Scaffold(
        appBar: AppBar(title: Text('${p.pname} · 인력·투입')),
        body: Skeletonizer(
          enabled: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: calendarH,
                child: ColoredBox(
                  color: cs.surfaceContainerLow,
                  child: const Center(
                    child: Text(
                      '공정표 · 일정',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
              Divider(
                height: 1,
                thickness: 1,
                color: cs.outlineVariant.withValues(alpha: 0.5),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  14,
                  MediaQuery.sizeOf(context).height < 720 ? 6 : 10,
                  14,
                  6,
                ),
                child: Text(
                  '선택한 날짜',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    14,
                    4,
                    14,
                    16 + MediaQuery.paddingOf(context).bottom,
                  ),
                  children: [
                    for (var i = 0; i < 5; i++)
                      Padding(
                        padding: EdgeInsets.only(bottom: context.rsi(12)),
                        child: Material(
                          borderRadius: BorderRadius.circular(16),
                          color: cs.surface,
                          child: const ListTile(
                            title: Text('공정 · 인력'),
                            subtitle: Text('역할 · 금액'),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (wf.loadError != null && wf.rows.isEmpty && wf.humans.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text('${p.pname} · 인력·투입')),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(context.rsi(24)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('불러오지 못했습니다.\n${wf.loadError}'),
                SizedBox(height: context.rsi(16)),
                FilledButton(
                  onPressed: wf.refreshing
                      ? null
                      : () => ref
                          .read(placeWorkforceProvider(_pid).notifier)
                          .reload(silent: false),
                  child: const Text('다시 시도'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final selectedDay = wf.selectedDay;
    final d = sch.data;
    final selectedIso = formatDateTimeToIsoDate(selectedDay);
    final dayIdx = PlaceWorkforceSchedule.dayIndex(selectedDay, d);
    final tasksToday = dayIdx == null
        ? <(int, ProcessScheduleTask)>[]
        : PlaceWorkforceSchedule.tasksOnDay(d, dayIdx);
    final dayRows = _rowsForSelectedDay(wf.rows, selectedIso);
    final taskNames = tasksToday.map((e) => e.$2.name).toSet();
    final otherRows = dayRows
        .where((r) => !taskNames.contains(r.workrole.trim()))
        .toList();

    final (rangeA, rangeB) =
        PlaceWorkforceSchedule.unionPlaceAndScheduleCalendarRange(p, d);
    final calendarH = workforceCalendarHeight(context);
    final cs = Theme.of(context).colorScheme;

    ref.listen<PlaceWorkforceState>(
      placeWorkforceProvider(_pid),
      (previous, next) {
        if (previous == null) return;
        final a = previous.selectedDay;
        final b = next.selectedDay;
        if (a.year != b.year ||
            a.month != b.month ||
            a.day != b.day) {
          if (mounted) {
            setState(() => _rosterListExpanded = true);
          }
        }
      },
    );

    final rosterChildren = <Widget>[
      if (dayIdx == null) ...[
        if (otherRows.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: context.rsi(8),
              vertical: context.rsi(24),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.event_busy_rounded,
                  size: context.rs(48),
                  color: cs.onSurfaceVariant.withValues(alpha: 0.45),
                ),
                SizedBox(height: context.rsi(14)),
                Text(
                  '공정표 범위 밖 날짜입니다',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface.withValues(alpha: 0.88),
                      ),
                ),
                SizedBox(height: context.rsi(8)),
                Text(
                  '「공정 추가」로 이 날짜에 일정을 만든 뒤\n인력을 투입할 수 있습니다.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ..._otherWorkforceWidgets(
          selectedDay,
          wf.humans,
          otherRows,
          canEdit,
        ),
      ] else ...[
        if (tasksToday.isEmpty && otherRows.isEmpty)
          const PlaceWorkforceEmptyDay(),
        for (var ti = 0; ti < tasksToday.length; ti++) ...[
          PlaceWorkforceTaskCard(
            key: ValueKey('$selectedIso-${tasksToday[ti].$2.name}'),
            taskName: tasksToday[ti].$2.name,
            accentIndex: tasksToday[ti].$2.paletteIndex,
            rowsForTask: dayRows
                .where(
                  (r) => r.workrole.trim() == tasksToday[ti].$2.name,
                )
                .toList(),
            canEdit: canEdit,
            humanName: (hid) => _humanName(wf.humans, hid),
            onAddWorkforce: canEdit
                ? () => _showEditorSheet(
                      context,
                      initialDate: selectedDay,
                      defaultWorkrole: tasksToday[ti].$2.name,
                    )
                : null,
            onEdit: canEdit
                ? (row) => _showEditorSheet(
                      context,
                      initialDate: selectedDay,
                      existing: row,
                      defaultWorkrole: tasksToday[ti].$2.name,
                    )
                : null,
            onDelete: canEdit ? _deleteRow : null,
          ),
          if (ti < tasksToday.length - 1) const SizedBox(height: 14),
        ],
        if (tasksToday.isNotEmpty && otherRows.isNotEmpty)
          const SizedBox(height: 18),
        ..._otherWorkforceWidgets(
          selectedDay,
          wf.humans,
          otherRows,
          canEdit,
        ),
      ],
    ];

    final collapseSummary = _rosterCollapseSummary(
      dayIdx: dayIdx,
      taskCount: tasksToday.length,
      rosterRowCount: dayRows.length,
      otherRowCount: otherRows.length,
    );

    final rosterListPadding = EdgeInsets.fromLTRB(
      14,
      MediaQuery.sizeOf(context).height < 720 ? 6 : 12,
      14,
      16 + MediaQuery.paddingOf(context).bottom,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('${p.pname} · 인력·투입'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (sch.loadError != null)
            MaterialBanner(
              content: Text(sch.loadError!),
              actions: [
                TextButton(
                  onPressed: () {
                    ref
                        .read(
                          placeProcessScheduleProvider(_scheduleArg).notifier,
                        )
                        .clearLoadError();
                  },
                  child: const Text('닫기'),
                ),
              ],
            ),
          ScrollableCalendarWidget(
            key: ValueKey(
              '${d.gridStart.toIso8601String()}-${d.dayCount}-${d.tasks.length}-'
              '${wf.rows.length}',
            ),
            adaptiveHeightForWeekModes: true,
            height: calendarH,
            useSingleDaySelection: true,
            showViewModeToggle: true,
            disableDateSelectionHighlight: true,
            initialSelectedDay: selectedDay,
            initialRangeStart: rangeA,
            initialRangeEnd: rangeB,
            initialEvents:
                PlaceWorkforceSchedule.buildCalendarEvents(d, wf.rows),
            onDayPicked: (picked) {
              ref.read(placeWorkforceProvider(_pid).notifier).setSelectedDay(
                    DateTime(picked.year, picked.month, picked.day),
                  );
            },
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: cs.outlineVariant.withValues(alpha: 0.5),
          ),
          PlaceWorkforceDayToolbar(
            selectedDay: selectedDay,
            rosterListExpanded: _rosterListExpanded,
            onToggleRosterList: () =>
                setState(() => _rosterListExpanded = !_rosterListExpanded),
            canEdit: canEdit,
            onAddProcess: _addProcessForSelectedDay,
            onAddWorkforceOnly: () => unawaited(_onAddWorkforceOnlyTapped()),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref
                  .read(placeWorkforceProvider(_pid).notifier)
                  .reload(silent: false),
              child: ColoredBox(
                color: cs.surfaceContainerLow.withValues(alpha: 0.35),
                child: _rosterListExpanded
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: rosterListPadding,
                        children: rosterChildren,
                      )
                    : ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: rosterListPadding,
                        children: [
                          SizedBox(
                            height: MediaQuery.sizeOf(context).height * 0.12,
                          ),
                          Align(
                            alignment: Alignment.topCenter,
                            child: _rosterCollapsedStrip(cs, collapseSummary),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

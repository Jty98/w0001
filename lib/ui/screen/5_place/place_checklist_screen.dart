import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:scrollable_calendar_package/calendar_event.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:w0001/data/model/place_checklist_models.dart';
import 'package:w0001/data/model/place_info_model.dart';
import 'package:w0001/domain/process_schedule/process_schedule_busy_days.dart';
import 'package:w0001/navigation/place_navigation.dart';
import 'package:w0001/presentation/viewmodel/dashboard_schedule_view_model.dart';
import 'package:w0001/presentation/viewmodel/place_checklist_notifier.dart';
import 'package:w0001/presentation/viewmodel/place_process_schedule_notifier.dart';
import 'package:w0001/ui/screen/5_place/process_schedule/process_schedule_helpers.dart';
import 'package:w0001/theme/app_theme_colors.dart';
import 'package:w0001/theme/app_section_card.dart';
import 'package:w0001/ui/screen/5_place/widgets/place_checklist_sheets.dart';
import 'package:w0001/ui/widget/app_refresh_indicator.dart';
import 'package:w0001/ui/widget/scrollable_calendar/scrollable_calendar_widget.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 현장별 · 날짜별 작업 체크리스트 (로컬 저장, 서버 연동 대비).
class PlaceChecklistScreen extends ConsumerStatefulWidget {
  const PlaceChecklistScreen({super.key, required this.placeInfo});

  final PlaceInfoModel placeInfo;

  @override
  ConsumerState<PlaceChecklistScreen> createState() =>
      _PlaceChecklistScreenState();
}

class _PlaceChecklistScreenState extends ConsumerState<PlaceChecklistScreen> {
  static const _dayPageOrigin = 10000;
  static const _processOnlyDotColor = Color(0xFF9E9E9E);
  static const _processWithChecklistDotColor = Color(0xFF2E7D32);

  late final DateTime _anchorDay;
  late final PageController _dayPage;

  PlaceChecklistFamilyArg get _arg => (
        pid: widget.placeInfo.pid ?? 0,
        pstart: widget.placeInfo.pstart,
        pend: widget.placeInfo.pend,
      );

  ProcessScheduleFamilyArg get _scheduleArg => (
        pid: widget.placeInfo.pid ?? 0,
        pstart: widget.placeInfo.pstart,
        pend: widget.placeInfo.pend,
      );

  @override
  void initState() {
    super.initState();
    _anchorDay = scheduleDateOnly(DateTime.now());
    _dayPage = PageController(initialPage: _dayPageOrigin);
  }

  @override
  void dispose() {
    _dayPage.dispose();
    super.dispose();
  }

  DateTime _dayForPage(int page) =>
      _anchorDay.add(Duration(days: page - _dayPageOrigin));

  void _goToDay(DateTime day, {bool animate = true}) {
    final target = scheduleDateOnly(day);
    final page = _dayPageOrigin + target.difference(_anchorDay).inDays;
    void move() {
      if (!mounted || !_dayPage.hasClients) return;
      if (animate) {
        _dayPage.animateToPage(
          page,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      } else {
        _dayPage.jumpToPage(page);
      }
    }

    if (_dayPage.hasClients) {
      move();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => move());
    }
  }

  void _onDayPageChanged(int page) {
    ref
        .read(placeChecklistProvider(_arg).notifier)
        .selectDate(_dayForPage(page));
  }

  void _shiftDayPage(int delta) {
    if (!_dayPage.hasClients) return;
    final next = (_dayPage.page ?? _dayPageOrigin.toDouble()) + delta;
    _dayPage.animateToPage(
      next.round(),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  List<String> _scheduledGroupsFor(DateTime day) {
    final schedule = ref.read(placeProcessScheduleProvider(_scheduleArg));
    return editorProcessGroupOptions(schedule: schedule.data, day: day);
  }

  Future<void> _pickDate() async {
    final state = ref.read(placeChecklistProvider(_arg));
    final picked = await _pickDateWithScrollableCalendar(
      context,
      initialDay: state.selectedDate,
    );
    if (picked == null || !mounted) return;
    ref.read(placeChecklistProvider(_arg).notifier).selectDate(picked);
    _goToDay(picked);
  }

  List<CalendarEvent> _calendarIndicatorEvents() {
    final checklistState = ref.read(placeChecklistProvider(_arg));
    final scheduleState = ref.read(placeProcessScheduleProvider(_scheduleArg));

    final processDateKeys = processScheduleBusyDateKeysIso(scheduleState.data);
    if (processDateKeys.isEmpty) return const [];

    final checklistDateKeys = <String>{};
    final snap = checklistState.snapshot;
    if (snap != null) {
      for (final item in snap.items) {
        final key = item.workDate.trim();
        if (key.isNotEmpty) checklistDateKeys.add(key);
      }
    }

    final out = <CalendarEvent>[];
    for (final key in processDateKeys) {
      final day = scheduleDateFromTaskKey(key);
      final hasChecklist = checklistDateKeys.contains(key);
      out.add(
        CalendarEvent(
          startDate: day,
          endDate: day,
          color: hasChecklist
              ? _processWithChecklistDotColor
              : _processOnlyDotColor,
        ),
      );
    }
    return out;
  }

  Future<DateTime?> _pickDateWithScrollableCalendar(
    BuildContext context, {
    required DateTime initialDay,
  }) async {
    DateTime? pickedDay = scheduleDateOnly(initialDay);

    final screenH = MediaQuery.sizeOf(context).height;
    final maxHeight =
        (screenH * 0.60).clamp(context.rs(400), context.rs(520)).toDouble();
    final calHeight =
        (screenH * 0.34).clamp(context.rs(240), context.rs(310)).toDouble();

    return showDialog<DateTime>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(dialogCtx.rs(16)),
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: Padding(
                  padding: EdgeInsets.only(bottom: dialogCtx.rsi(8)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: dialogCtx.rsi(10),
                        ),
                        child: Text(
                          '날짜 선택',
                          style: Theme.of(dialogCtx)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      ScrollableCalendarWidget(
                        height: calHeight,
                        initialSelectedDay: pickedDay,
                        useSingleDaySelection: true,
                        showViewModeToggle: false,
                        disableDateSelectionHighlight: true,
                        initialEvents: _calendarIndicatorEvents(),
                        onDayPicked: (d) {
                          setDialogState(
                            () => pickedDay = scheduleDateOnly(d),
                          );
                        },
                      ),
                      SizedBox(height: dialogCtx.rsi(6)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(dialogCtx).pop(),
                            child: Text(
                              '취소',
                              style: TextStyle(
                                color: Theme.of(dialogCtx).colorScheme.error,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () =>
                                Navigator.of(dialogCtx).pop(pickedDay),
                            child: const Text('확인'),
                          ),
                          SizedBox(width: dialogCtx.rsi(8)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _onAdd({String? processGroup}) async {
    final checklist = ref.read(placeChecklistProvider(_arg));
    final groups = _scheduledGroupsFor(checklist.selectedDate);
    final result = await showPlaceChecklistItemEditor(
      context,
      scheduledProcessGroups: groups,
      initialProcessGroup: processGroup,
    );
    if (result == null || !mounted) return;
    await ref.read(placeChecklistProvider(_arg).notifier).addItem(
          title: result.title,
          processGroup: result.processGroup,
        );
  }

  Future<void> _onEdit(PlaceChecklistItem item) async {
    final checklist = ref.read(placeChecklistProvider(_arg));
    final groups = _scheduledGroupsFor(checklist.selectedDate);
    final result = await showPlaceChecklistItemEditor(
      context,
      scheduledProcessGroups: groups,
      existing: item,
    );
    if (result == null || !mounted) return;
    await ref.read(placeChecklistProvider(_arg).notifier).updateItem(
          item.copyWith(
            title: result.title,
            processGroup: result.processGroup,
          ),
        );
  }

  Future<void> _deferItem(PlaceChecklistItem item) async {
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
    await ref.read(placeChecklistProvider(_arg).notifier).deferItem(
          itemId: item.id,
          reason: result.reason,
          toDate: toKey,
        );
  }

  Future<void> _confirmDelete(PlaceChecklistItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('항목 삭제'),
        content: Text('"${item.title}" 항목을 삭제할까요?'),
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
    await ref.read(placeChecklistProvider(_arg).notifier).deleteItem(item.id);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(placeChecklistProvider(_arg));
    final scheduleState = ref.watch(placeProcessScheduleProvider(_scheduleArg));
    final vm = ref.read(placeChecklistProvider(_arg).notifier);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final today = scheduleDateOnly(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        leading: placeSubrouteBackLeading(context),
        title: const Text('작업 체크리스트'),
        actions: [
          IconButton(
            tooltip: '날짜 선택',
            icon: const Icon(Icons.calendar_month_rounded),
            onPressed: _pickDate,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _onAdd(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('항목 추가'),
      ),
      body: PageView.builder(
        controller: _dayPage,
        onPageChanged: _onDayPageChanged,
        itemBuilder: (context, page) {
          final day = _dayForPage(page);
          final dayKey = scheduleDateKey(day);
          final snap = state.snapshot;
          final dayItems = snap?.itemsForDate(dayKey) ?? const [];
          final dayDeferrals = snap?.deferralsForDate(dayKey) ?? const [];
          final grouped = groupChecklistItems(dayItems);
          final scheduledToday =
              processGroupsScheduledOn(scheduleState.data, day);
          final isToday = day == today;
          final checked = dayItems.where((e) => e.isChecked).length;
          final total = dayItems.where((e) => !e.isDeferred).length;

          return AppRefreshIndicator(
            enabled: !(state.isLoading && state.snapshot == null),
            onRefresh: vm.load,
            child: Skeletonizer(
              enabled: state.isLoading && state.snapshot == null,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: ResponsiveLayout.symmetric(
                        context,
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: _DateNavigatorBar(
                        day: day,
                        isToday: isToday,
                        checked: checked,
                        total: total,
                        onPrev: () => _shiftDayPage(-1),
                        onNext: () => _shiftDayPage(1),
                        onTapDate: _pickDate,
                      ),
                    ),
                  ),
                  if (scheduledToday.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: ResponsiveLayout.symmetric(
                          context,
                          horizontal: 16,
                        ),
                        child: _ScheduledProcessBanner(groups: scheduledToday),
                      ),
                    ),
                  if (state.error != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: ResponsiveLayout.symmetric(
                          context,
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Text(
                          state.error!,
                          style: tt.bodyMedium?.copyWith(color: cs.error),
                        ),
                      ),
                    ),
                  if (grouped.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyChecklistHint(
                        onAdd: () => _onAdd(),
                        hasScheduleTasks: scheduleState.data.tasks.isNotEmpty,
                      ),
                    )
                  else
                    SliverPadding(
                      padding: ResponsiveLayout.symmetric(
                        context,
                        horizontal: 12,
                        vertical: 4,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final groupKey = grouped.keys.elementAt(index);
                            final items = grouped[groupKey]!;
                            final displayName =
                                checklistGroupSectionTitle(groupKey);
                            final onSchedule =
                                scheduledToday.contains(groupKey);
                            return _ChecklistGroupSection(
                              groupName: displayName,
                              items: items,
                              onScheduleToday: onSchedule,
                              onToggle: (item) => vm.toggleChecked(item),
                              onEdit: _onEdit,
                              onDefer: _deferItem,
                              onDelete: _confirmDelete,
                              onAddUnderGroup: () => _onAdd(
                                processGroup:
                                    groupKey.isEmpty ? null : groupKey,
                              ),
                            );
                          },
                          childCount: grouped.length,
                        ),
                      ),
                    ),
                  if (dayDeferrals.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          context.rsi(16),
                          context.rsi(16),
                          context.rsi(16),
                          context.rsi(96),
                        ),
                        child: _DeferralHistorySection(
                          deferrals: dayDeferrals,
                          focusDateKey: dayKey,
                        ),
                      ),
                    )
                  else
                    const SliverToBoxAdapter(child: SizedBox(height: 96)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DateNavigatorBar extends StatelessWidget {
  const _DateNavigatorBar({
    required this.day,
    required this.isToday,
    required this.checked,
    required this.total,
    required this.onPrev,
    required this.onNext,
    required this.onTapDate,
  });

  final DateTime day;
  final bool isToday;
  final int checked;
  final int total;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onTapDate;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final progress = total <= 0 ? 0.0 : checked / total;

    return AppInsetCard(
      padding: ResponsiveLayout.symmetric(context, horizontal: 8, vertical: 10),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onPrev,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: InkWell(
                  onTap: onTapDate,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: ResponsiveLayout.symmetric(
                      context,
                      vertical: 6,
                    ),
                    child: Column(
                      children: [
                        Text(
                          periodDropdownLabel(day),
                          textAlign: TextAlign.center,
                          style: tt.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (isToday)
                          Text(
                            '오늘',
                            style: tt.labelSmall?.copyWith(
                              color: cs.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: onNext,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          rsV(context, 8),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: context.rs(6),
                    backgroundColor: cs.appMutedFill,
                  ),
                ),
              ),
              rsH(context, 12),
              Text(
                '$checked / $total',
                style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ],
      ),
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

    const accent = Color(0xFF6750A4);

    return Padding(
      padding: EdgeInsets.only(bottom: context.rsi(10)),
      child: AppInsetTile(
        padding:
            ResponsiveLayout.symmetric(context, horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: context.rs(32),
              height: context.rs(32),
              alignment: Alignment.center,
              decoration: AppSectionCardStyles.iconBadgeDecoration(context, cs),
              child: Icon(
                Icons.calendar_view_month_rounded,
                size: context.rs(18),
                color: accent,
              ),
            ),
            rsH(context, 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '공정표 내용',
                    style: tt.labelMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: accent,
                    ),
                  ),
                  rsV(context, 4),
                  Text(
                    groups.join(' · '),
                    style: tt.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: cs.onSurfaceVariant,
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
}

class _EmptyChecklistHint extends StatelessWidget {
  const _EmptyChecklistHint({
    required this.onAdd,
    required this.hasScheduleTasks,
  });

  final VoidCallback onAdd;
  final bool hasScheduleTasks;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: ResponsiveLayout.symmetric(context, horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.checklist_rounded,
              size: context.rs(56),
              color: cs.primary.withValues(alpha: 0.45),
            ),
            rsV(context, 16),
            Text(
              '체크리스트가 비어 있어요',
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            rsV(context, 8),
            Text(
              hasScheduleTasks
                  ? '공정표 공정별로 작업 항목을 추가해 진행 상황을 확인하세요.'
                  : '공정표를 먼저 만들면 공정별로 항목을 정리하기 쉬워요.',
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            rsV(context, 20),
            FilledButton.tonalIcon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('첫 항목 추가'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChecklistGroupSection extends StatelessWidget {
  const _ChecklistGroupSection({
    required this.groupName,
    required this.items,
    required this.onScheduleToday,
    required this.onToggle,
    required this.onEdit,
    required this.onDefer,
    required this.onDelete,
    required this.onAddUnderGroup,
  });

  final String groupName;
  final List<PlaceChecklistItem> items;
  final bool onScheduleToday;
  final ValueChanged<PlaceChecklistItem> onToggle;
  final ValueChanged<PlaceChecklistItem> onEdit;
  final ValueChanged<PlaceChecklistItem> onDefer;
  final ValueChanged<PlaceChecklistItem> onDelete;
  final VoidCallback onAddUnderGroup;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const scheduleAccent = Color(0xFF6750A4);

    return Padding(
      padding: EdgeInsets.only(bottom: context.rsi(12)),
      child: AppSectionCard(
        icon: Icons.folder_outlined,
        title: groupName,
        iconColor: cs.primary,
        denseHeader: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onScheduleToday)
              Container(
                padding: ResponsiveLayout.symmetric(
                  context,
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: cs.appIconBadge,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: cs.appBorder),
                ),
                child: Text(
                  '공정 예정',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: scheduleAccent,
                      ),
                ),
              ),
            IconButton(
              tooltip: '$groupName 항목 추가',
              visualDensity: VisualDensity.compact,
              onPressed: onAddUnderGroup,
              icon: Icon(
                Icons.add_circle_outline_rounded,
                size: context.rs(20),
              ),
            ),
          ],
        ),
        contentPadding: EdgeInsets.fromLTRB(
          context.rsi(12),
          context.rsi(8),
          context.rsi(12),
          context.rsi(12),
        ),
        child: Column(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) SizedBox(height: context.rsi(6)),
              _ChecklistItemTile(
                item: items[i],
                onToggle: () => onToggle(items[i]),
                onEdit: () => onEdit(items[i]),
                onDefer: () => onDefer(items[i]),
                onDelete: () => onDelete(items[i]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChecklistItemTile extends StatelessWidget {
  const _ChecklistItemTile({
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

    final tile = AppInsetTile(
      child: ListTile(
        contentPadding: ResponsiveLayout.symmetric(
          context,
          horizontal: 4,
          vertical: 2,
        ),
        leading: Checkbox(
          value: checked,
          onChanged: deferred ? null : (_) => onToggle(),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        title: Text(
          item.title,
          style: tt.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
            decoration: deferred
                ? TextDecoration.lineThrough
                : (checked ? TextDecoration.lineThrough : null),
            color: deferred
                ? cs.onSurfaceVariant
                : (checked ? cs.onSurfaceVariant : cs.onSurface),
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
      return tile;
    }

    return Slidable(
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
    );
  }
}

class _DeferralHistorySection extends StatelessWidget {
  const _DeferralHistorySection({
    required this.deferrals,
    required this.focusDateKey,
  });

  final List<PlaceChecklistDeferral> deferrals;
  final String focusDateKey;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return AppSectionCard(
      icon: Icons.history_rounded,
      title: '미루기 기록',
      denseHeader: true,
      contentPadding: EdgeInsets.fromLTRB(
        context.rsi(12),
        context.rsi(8),
        context.rsi(12),
        context.rsi(12),
      ),
      child: Column(
        children: [
          for (var i = 0; i < deferrals.length; i++) ...[
            if (i > 0) SizedBox(height: context.rsi(6)),
            Builder(
              builder: (context) {
                final d = deferrals[i];
                final isOut = d.fromDate == focusDateKey;
                final arrow =
                    '${_shortDate(d.fromDate)} → ${_shortDate(d.toDate)}';
                return AppInsetTile(
                  child: ListTile(
                    dense: true,
                    leading: Icon(
                      isOut
                          ? Icons.arrow_forward_rounded
                          : Icons.arrow_downward_rounded,
                      color: cs.tertiary,
                      size: context.rs(20),
                    ),
                    title: Text(
                      d.title,
                      style:
                          tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '$arrow · ${deferReasonOrPlaceholder(d)}',
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  String _shortDate(String key) {
    final d = scheduleDateFromTaskKey(key);
    return shortDateDotYy(d);
  }
}

import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/data/datasources/remote/list_query.dart';
import 'package:w0001/data/model/bulk_workforce_assignment.dart';
import 'package:w0001/data/model/human_model.dart';
import 'package:w0001/data/model/paged_result.dart' show mergePagedItems;
import 'package:w0001/data/model/place_info_model.dart';
import 'package:w0001/data/model/remote/super_admin_dtos.dart';
import 'package:w0001/domain/cost_place_picker_filter.dart';
import 'package:w0001/domain/place_work_period_display.dart';
import 'package:w0001/domain/process_schedule/process_schedule_editor.dart';
import 'package:w0001/domain/process_schedule/process_schedule_models.dart';
import 'package:w0001/domain/process_schedule/process_schedule_palette.dart';
import 'package:w0001/navigation/shell_back_navigation.dart';
import 'package:w0001/navigation/work_instruction_navigation.dart';
import 'package:w0001/presentation/viewmodel/auth_providers.dart';
import 'package:w0001/presentation/viewmodel/place_list_view_model.dart';
import 'package:w0001/presentation/viewmodel/place_process_schedule_notifier.dart';
import 'package:w0001/presentation/viewmodel/place_workforce_notifier.dart';
import 'package:w0001/presentation/viewmodel/work_instruction_overview_notifier.dart';
import 'package:w0001/theme/app_section_card.dart';
import 'package:w0001/ui/widget/app_sliding_segment.dart';
import 'package:w0001/ui/screen/2_add/add_cost_date_picker_dialog.dart';
import 'package:w0001/ui/screen/2_work_instruction/work_instruction_assign_sheet.dart';
import 'package:w0001/ui/screen/2_work_instruction/work_instruction_overview.dart';
import 'package:w0001/ui/screen/5_place/place_workforce_models.dart';
import 'package:w0001/ui/screen/5_place/place_workforce_schedule.dart';
import 'package:w0001/ui/screen/5_place/process_schedule/process_schedule_dialogs.dart';
import 'package:w0001/ui/screen/5_place/process_schedule/process_schedule_helpers.dart';
import 'package:w0001/ui/widget/hammer_loading_indicator.dart';
import 'package:w0001/ui/widget/paged_list_footer.dart';
import 'package:w0001/util/funtions.dart';
import 'package:w0001/util/responsive_layout.dart';
import 'package:w0001/util/worker_skills_display.dart';

class WorkInstructionHubScreen extends ConsumerStatefulWidget {
  const WorkInstructionHubScreen({super.key});

  @override
  ConsumerState<WorkInstructionHubScreen> createState() =>
      _WorkInstructionHubScreenState();
}

class _WorkInstructionHubScreenState
    extends ConsumerState<WorkInstructionHubScreen> {
  static const _pageCenter = 10000;
  static const _pageCount = 20001;

  PlaceInfoModel? _place;
  late DateTime _day;
  late final DateTime _pagerAnchor;
  late final PageController _overviewPageCtrl;
  var _overviewPage = _pageCenter;
  var _syncingPage = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _day = DateTime(now.year, now.month, now.day);
    _pagerAnchor = _day;
    _overviewPageCtrl = PageController(
      initialPage: _pageCenter,
      viewportFraction: 0.9,
    );
    workInstructionHubSystemBackHandler = _trySystemBack;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_ensureOverviewRange(_day));
    });
  }

  @override
  void dispose() {
    if (workInstructionHubSystemBackHandler == _trySystemBack) {
      workInstructionHubSystemBackHandler = null;
    }
    _overviewPageCtrl.dispose();
    super.dispose();
  }

  bool _trySystemBack() {
    if (!mounted) return false;
    // 작성 화면·인력투입 시트·다이얼로그가 위에 있으면 탭 목록으로 가지 않고 먼저 닫는다.
    if (tryPopRootNavigatorOverlay(context)) {
      consumeDedupedBackEvent();
      return true;
    }
    if (tryPopLocalNavigatorOverlay(context)) {
      consumeDedupedBackEvent();
      return true;
    }
    if (_place == null) return false;
    consumeDedupedBackEvent();
    _backToLanding();
    return true;
  }

  ProcessScheduleFamilyArg? get _scheduleArg {
    final p = _place;
    final pid = p?.pid;
    if (p == null || pid == null || pid <= 0) return null;
    return (pid: pid, pstart: p.pstart, pend: p.pend);
  }

  DateTime _ymd(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime _dayAt(int page) =>
      _pagerAnchor.add(Duration(days: page - _pageCenter));

  int _pageOf(DateTime day) {
    final idx = _pageCenter + _ymd(day).difference(_pagerAnchor).inDays;
    return idx.clamp(0, _pageCount - 1);
  }

  Map<int, String> get _placeNames => {
        for (final p in ref.read(placeListProvider).placeList)
          if (p.pid != null) p.pid!: p.pname,
      };

  Future<void> _reloadOverview({DateTime? around}) => ref
      .read(workInstructionOverviewProvider.notifier)
      .reload(around: around ?? _day);

  Future<void> _ensureOverviewRange(DateTime center) =>
      ref.read(workInstructionOverviewProvider.notifier).ensureRange(center);

  void _onOverviewPageChanged(int i) {
    if (_syncingPage) return;
    final day = _dayAt(i);
    setState(() {
      _overviewPage = i;
      _day = day;
    });
    unawaited(_ensureOverviewRange(day));
  }

  void _setDay(DateTime day) {
    final next = _ymd(day);
    final idx = _pageOf(next);
    _syncingPage = true;
    setState(() {
      _day = next;
      _overviewPage = idx;
    });
    unawaited(_ensureOverviewRange(next));
    if (!_overviewPageCtrl.hasClients) {
      _syncingPage = false;
      return;
    }
    _overviewPageCtrl
        .animateToPage(
          idx,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
        )
        .whenComplete(() => _syncingPage = false);
  }

  void _goToday() => _setDay(_ymd(DateTime.now()));

  void _backToLanding() {
    setState(() => _place = null);
    unawaited(_ensureOverviewRange(_day));
  }

  void _selectPlace(PlaceInfoModel place) {
    setState(() => _place = place);
  }

  void _selectPlaceByPid(int pid) {
    for (final p in ref.read(placeListProvider).placeList) {
      if (p.pid == pid) {
        _selectPlace(p);
        return;
      }
    }
  }

  Future<void> _pickDay() async {
    final place = _place;
    if (place == null) return;
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (ctx) => AddCostDatePickerDialog(
        place: placeModelForAddCost(place),
        initialRangeStart: parsePlaceCalendarDay(place.pstart),
        initialRangeEnd: parsePlaceCalendarDay(place.pend),
        initialSelectedDay: _day,
      ),
    );
    if (picked == null || !mounted) return;
    _setDay(picked);
  }

  Future<void> _addProcess() async {
    final arg = _scheduleArg;
    final place = _place;
    if (arg == null || place == null) return;
    final sch = ref.read(placeProcessScheduleProvider(arg));
    if (!sch.isReady || sch.data.dayCount < 1) return;
    final dates = ProcessScheduleEditor.columnDates(sch.data);
    final labels = [for (final d in dates) scheduleDateHeaderLabel(d)];
    final result = await showDialog<AddProcessDialogResult>(
      context: context,
      builder: (ctx) => AddProcessDialog(dateLabels: labels),
    );
    if (result == null || !mounted) return;
    final name = result.name.trim();
    if (name.isEmpty) return;
    final last = sch.data.dayCount - 1;
    final lo = result.startIdx.clamp(0, last);
    var hi = result.endIdx.clamp(0, last);
    if (hi < lo) hi = lo;
    final notifier = ref.read(placeProcessScheduleProvider(arg).notifier);
    notifier.upsertProcess(name, lo, hi);
    try {
      await notifier.persist(syncPlaceMaster: place);
    } catch (e) {
      await notifier.reloadFromServer();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(PlaceProcessScheduleNotifier.messageForPersistError(e)),
        ),
      );
    }
  }

  Future<void> _openAssign({ProcessScheduleTask? task}) async {
    final place = _place;
    if (place == null) return;
    var date = _day;
    if (task != null &&
        !task.scheduledDayIndices.contains(
          PlaceWorkforceSchedule.dayIndex(
                date,
                ref.read(placeProcessScheduleProvider(_scheduleArg!)).data,
              ) ??
              -1,
        )) {
      final sch = ref.read(placeProcessScheduleProvider(_scheduleArg!)).data;
      if (task.scheduledDayIndices.isNotEmpty) {
        date =
            sch.gridStart.add(Duration(days: task.scheduledDayIndices.first));
      }
    }
    final result = await showWorkInstructionAssignSheet(
      context: context,
      place: place,
      workDate: date,
      task: task,
    );
    if (!mounted) return;
    unawaited(_reloadOverview());
    if (result == null) return;
    _setDay(result.workDate);
    if (result.workers.isNotEmpty &&
        (result.endDate == null || result.endDate == result.workDate)) {
      await _offerRepeatTomorrow(result);
    }
  }

  Future<void> _openSiteInstruction({ProcessScheduleTask? task}) async {
    final place = _place;
    if (place == null) return;
    final pid = place.pid;
    final wf = pid == null ? null : ref.read(placeWorkforceProvider(pid));
    final iso = formatDateTimeToIsoDate(_day);
    final assigned = <HumanModel>[];
    if (wf != null) {
      final role = task?.name.trim() ?? '';
      final hids = {
        for (final r in wf.rows)
          if ((r.workdate.length >= 10
                  ? r.workdate.substring(0, 10)
                  : r.workdate) ==
              iso)
            if (role.isEmpty || r.workrole.trim() == role) r.hid,
      };
      for (final h in wf.humans) {
        if (h.hid != null && hids.contains(h.hid)) assigned.add(h);
      }
    }
    await showWorkInstructionAssignSheet(
      context: context,
      place: place,
      workDate: _day,
      task: task,
      startAtInstruction: true,
      initialWorkers: assigned,
    );
    if (mounted) unawaited(_reloadOverview());
  }

  Future<void> _offerRepeatTomorrow(WorkInstructionAssignResult result) async {
    if (!mounted) return;
    final next =
        (result.endDate ?? result.workDate).add(const Duration(days: 1));
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('투입했습니다'),
        content: Text(
          '${result.workers.map((e) => e.hname).join(', ')}\n'
          '${formatDateTimeWeekDayToString(next)}에도 넣을까요?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('닫기'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('내일도 투입'),
          ),
        ],
      ),
    );
    if (go != true || !mounted) return;
    await _assignSame(result.workers, next, result.taskName);
  }

  Future<void> _assignSame(
    List<HumanModel> workers,
    DateTime date,
    String? workrole,
  ) async {
    final pid = _place?.pid;
    if (pid == null || workers.isEmpty) return;
    final roles = <int, String>{
      for (final h in workers)
        if (h.hid != null)
          h.hid!: (workrole != null && workrole.isNotEmpty)
              ? workrole
              : (h.effectiveDefaultWorkRole.isNotEmpty
                  ? h.effectiveDefaultWorkRole
                  : '투입'),
    };
    final wages = <int, int>{
      for (final h in workers)
        if (h.hid != null) h.hid!: h.hdailyWage,
    };
    await ref.read(placeUseCaseProvider).bulkAssignWorkforce(
          pid: pid,
          requestBody: BulkWorkforceAssignmentRequest(
            startDate: date,
            endDate: date,
            assignments: workers
                .where((h) => h.hid != null)
                .map(
                  (h) => WorkforceAssignmentItem(
                    hid: h.hid!,
                    workrole: roles[h.hid] ?? '',
                    dailyWage: wages[h.hid] ?? h.hdailyWage,
                    workerRank: resolveHumanSiteRank(h),
                  ),
                )
                .toList(),
          ).toJson(),
        );
    await ref.read(placeWorkforceProvider(pid).notifier).reload(silent: true);
    unawaited(_reloadOverview());
  }

  String _humanName(List<HumanModel> humans, int hid) {
    for (final h in humans) {
      if (h.hid == hid) return h.hname;
    }
    return 'hid $hid';
  }

  @override
  Widget build(BuildContext context) {
    final place = _place;
    final arg = _scheduleArg;
    final sch =
        arg == null ? null : ref.watch(placeProcessScheduleProvider(arg));
    final wf = place?.pid == null
        ? null
        : ref.watch(placeWorkforceProvider(place!.pid!));
    final today = _ymd(DateTime.now());
    final overviewState = ref.watch(workInstructionOverviewProvider);
    final overviewRows = overviewState.rows;
    ref.watch(placeListProvider);
    final names = _placeNames;
    final focused = buildWorkInstructionDayOverview(
      day: _day,
      rows: overviewRows,
      placeNameByPid: names,
    );

    return BackButtonListener(
      onBackButtonPressed: () async => _trySystemBack(),
      child: PopScope(
        canPop: place == null,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          _trySystemBack();
        },
        child: Scaffold(
          appBar: AppBar(
            leading: place == null
                ? null
                : IconButton(
                    tooltip: '목록',
                    onPressed: _backToLanding,
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
            title: Text(place?.pname ?? '작업지시'),
          ),
          body: place == null
              ? Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: ResponsiveLayout.contentMaxWidth(context),
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final pagerH = workInstructionPagerHeight(
                          context,
                          constraints.maxHeight,
                        );
                        return Column(
                          children: [
                            Padding(
                              padding: EdgeInsets.fromLTRB(
                                context.rsi(10),
                                context.rsi(2),
                                context.rsi(10),
                                0,
                              ),
                              child: WorkInstructionOverviewPager(
                                controller: _overviewPageCtrl,
                                itemCount: _pageCount,
                                dayForPage: _dayAt,
                                overviewFor: (day) =>
                                    buildWorkInstructionDayOverview(
                                  day: day,
                                  rows: overviewRows,
                                  placeNameByPid: names,
                                ),
                                pageIndex: _overviewPage,
                                today: today,
                                loading: overviewState.initialLoading,
                                onPageChanged: _onOverviewPageChanged,
                                onSelectPlace: _selectPlaceByPid,
                                onJumpToday: _goToday,
                                pageHeight: pagerH,
                              ),
                            ),
                            WorkInstructionDayStatsCard(overview: focused),
                            Expanded(
                              child: _PlacePickList(onSelect: _selectPlace),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                )
              : Column(
                  children: [
                    _DayHeader(
                      day: _day,
                      isToday: _day == today,
                      onPrev: () =>
                          _setDay(_day.subtract(const Duration(days: 1))),
                      onNext: () => _setDay(_day.add(const Duration(days: 1))),
                      onPick: _pickDay,
                      onToday: _goToday,
                    ),
                    Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: context.rsi(16)),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => unawaited(_openSiteInstruction()),
                          icon: Icon(Icons.campaign_outlined,
                              size: context.rs(18)),
                          label: const Text('현장 작업지시'),
                        ),
                      ),
                    ),
                    Expanded(
                      child: (sch != null && !sch.isReady) ||
                              (wf != null && wf.initialLoading)
                          ? const Center(
                              child: HammerLoadingIndicator(size: 64))
                          : _DayBoard(
                              day: _day,
                              schedule: sch,
                              rows: wf?.rows ?? const [],
                              humanName: (hid) =>
                                  _humanName(wf?.humans ?? const [], hid),
                              onAddProcess: _addProcess,
                              onAssign: (task) =>
                                  unawaited(_openAssign(task: task)),
                              onWriteProcessInstruction: (task) => unawaited(
                                _openSiteInstruction(task: task),
                              ),
                            ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _PlacePickList extends ConsumerStatefulWidget {
  const _PlacePickList({required this.onSelect});

  final ValueChanged<PlaceInfoModel> onSelect;

  @override
  ConsumerState<_PlacePickList> createState() => _PlacePickListState();
}

class _PlacePickListState extends ConsumerState<_PlacePickList> {
  var _filter = CostPlacePickerFilter.inProgress;
  var _loading = true;
  var _loadingMore = false;
  var _hasMore = false;
  String? _nextCursor;
  List<PlaceInfoModel> _places = const [];
  final _scrollCtrl = ScrollController();
  Future<void>? _loadMoreInFlight;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _seedFromPlaceListCache();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_refresh());
    });
  }

  List<PlaceInfoModel> _cachedPlaces() {
    return ref
        .read(placeListProvider)
        .placeList
        .where((p) => _filter.matchesPlace(p.pcomplete))
        .toList(growable: false);
  }

  void _seedFromPlaceListCache() {
    final cached = _cachedPlaces();
    if (cached.isEmpty) return;
    _places = cached;
    _loading = false;
  }

  void _onScroll() {
    schedulePagedScrollNearEndCheck(_scrollCtrl, onLoadMore: _loadMore);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  ListQuery _query({String? cursor}) => ListQuery(
        pcomplete: _filter.pcompleteQuery,
        limit: kListPageSize,
        cursor: cursor,
      );

  Future<void> _refresh() async {
    _loadMoreInFlight = null;
    final cached = _cachedPlaces();
    setState(() {
      if (cached.isNotEmpty) {
        _places = cached;
        _loading = false;
      } else {
        _loading = true;
      }
      _hasMore = false;
      _nextCursor = null;
    });
    try {
      final role = ref.read(authSessionProvider).asData?.value?.role;
      final page = await ref.read(placeUseCaseProvider).fetchPlacesPage(
            query: _query(),
            role: role,
          );
      if (!mounted) return;
      setState(() {
        _places = page.items;
        _hasMore = page.canLoadMore;
        _nextCursor = page.nextCursor;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || !_hasMore) return;
    final cursor = _nextCursor?.trim();
    if (cursor == null || cursor.isEmpty) return;
    if (_loadMoreInFlight != null) return;
    setState(() => _loadingMore = true);
    final future = () async {
      try {
        final role = ref.read(authSessionProvider).asData?.value?.role;
        final page = await ref.read(placeUseCaseProvider).fetchPlacesPage(
              query: _query(cursor: cursor),
              role: role,
            );
        if (!mounted) return;
        setState(() {
          _places = mergePagedItems(_places, page.items, (p) => p.pid);
          _hasMore = page.canLoadMore;
          _nextCursor = page.nextCursor;
          _loadingMore = false;
        });
      } catch (_) {
        if (mounted) setState(() => _loadingMore = false);
      }
    }();
    _loadMoreInFlight = future;
    try {
      await future;
    } finally {
      if (identical(_loadMoreInFlight, future)) _loadMoreInFlight = null;
    }
  }

  void _setFilter(CostPlacePickerFilter next) {
    if (next == _filter) return;
    setState(() => _filter = next);
    unawaited(_refresh());
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(
      children: [
        AppSlidingSegment<CostPlacePickerFilter>(
          value: _filter,
          onChanged: _setFilter,
          children: {
            CostPlacePickerFilter.inProgress: AppSlidingSegment.tabLabel(
              context,
              '진행중',
              selected: _filter == CostPlacePickerFilter.inProgress,
            ),
            CostPlacePickerFilter.completed: AppSlidingSegment.tabLabel(
              context,
              '완료',
              selected: _filter == CostPlacePickerFilter.completed,
            ),
          },
        ),
        Expanded(
          child: _loading
              ? const Center(child: HammerLoadingIndicator(size: 56))
              : _places.isEmpty
                  ? Center(
                      child: Text(
                        _filter == CostPlacePickerFilter.completed
                            ? '완료된 현장이 없습니다'
                            : '진행중인 현장이 없습니다',
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.separated(
                      controller: _scrollCtrl,
                      padding: EdgeInsets.fromLTRB(
                        context.rsi(16),
                        context.rsi(4),
                        context.rsi(16),
                        context.rsi(20),
                      ),
                      itemCount: _places.length + 1,
                      separatorBuilder: (_, __) =>
                          SizedBox(height: context.rsi(12)),
                      itemBuilder: (context, i) {
                        if (i == _places.length) {
                          return PagedListFooter(
                            isLoading: _loadingMore,
                            hasMore: _hasMore,
                          );
                        }
                        return _PlacePickTile(
                          place: _places[i],
                          onTap: () => widget.onSelect(_places[i]),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

class _PlacePickTile extends StatelessWidget {
  const _PlacePickTile({required this.place, required this.onTap});

  final PlaceInfoModel place;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final address = place.paddress.trim();
    final accent = place.pcomplete == 1 ? cs.tertiary : cs.primary;
    final radius = AppSectionCardStyles.borderRadius(context);
    return DecoratedBox(
      decoration: AppSectionCardStyles.cardDecoration(context),
      child: ClipRRect(
        borderRadius: radius,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: context.rs(5), color: accent),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        context.rsi(14),
                        context.rsi(context.isCompactDevice ? 10 : 14),
                        context.rsi(8),
                        context.rsi(context.isCompactDevice ? 10 : 14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            place.pname,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tt.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: context.rsi(4)),
                          Text(
                            address.isEmpty ? '주소 없음' : address,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: cs.onSurfaceVariant,
                  ),
                  SizedBox(width: context.rsi(8)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({
    required this.day,
    required this.isToday,
    required this.onPrev,
    required this.onNext,
    required this.onPick,
    required this.onToday,
  });

  final DateTime day;
  final bool isToday;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onPick;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.rsi(8),
        context.rsi(4),
        context.rsi(8),
        context.rsi(8),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onPrev,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Expanded(
            child: InkWell(
              onTap: onPick,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: context.rsi(8)),
                child: Text(
                  formatDateTimeWeekDayToString(day),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ),
          ),
          if (!isToday) TextButton(onPressed: onToday, child: const Text('오늘')),
          IconButton(
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }
}

class _DayBoard extends StatelessWidget {
  const _DayBoard({
    required this.day,
    required this.schedule,
    required this.rows,
    required this.humanName,
    required this.onAddProcess,
    required this.onAssign,
    required this.onWriteProcessInstruction,
  });

  final DateTime day;
  final PlaceProcessScheduleState? schedule;
  final List<PlaceWorkDayRead> rows;
  final String Function(int hid) humanName;
  final VoidCallback onAddProcess;
  final void Function(ProcessScheduleTask? task) onAssign;
  final void Function(ProcessScheduleTask task) onWriteProcessInstruction;

  String _iso(DateTime d) => formatDateTimeToIsoDate(d);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final data = schedule?.data;
    final dayIdx =
        data == null ? null : PlaceWorkforceSchedule.dayIndex(day, data);
    final todayTasks = (data == null || dayIdx == null)
        ? <(int, ProcessScheduleTask)>[]
        : PlaceWorkforceSchedule.tasksOnDay(data, dayIdx);
    final todayIds = {for (final t in todayTasks) t.$1};
    final otherTasks = <(int, ProcessScheduleTask)>[
      if (data != null)
        for (var i = 0; i < data.tasks.length; i++)
          if (!todayIds.contains(i)) (i, data.tasks[i]),
    ];
    final iso = _iso(day);
    final dayRows = rows
        .where(
          (r) =>
              (r.workdate.length >= 10
                  ? r.workdate.substring(0, 10)
                  : r.workdate) ==
              iso,
        )
        .toList();
    final taskNames = {
      for (final t in [...todayTasks, ...otherTasks]) t.$2.name.trim(),
    };
    final other =
        dayRows.where((r) => !taskNames.contains(r.workrole.trim())).toList();

    List<Widget> processCards(List<(int, ProcessScheduleTask)> items) {
      return [
        for (final item in items)
          _ProcessDayCard(
            task: item.$2,
            gridStart: data!.gridStart,
            people: dayRows
                .where((r) => r.workrole.trim() == item.$2.name.trim())
                .toList(),
            humanName: humanName,
            onAssign: () => onAssign(item.$2),
            onWriteInstruction: () => onWriteProcessInstruction(item.$2),
          ),
      ];
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(
        context.rsi(16),
        0,
        context.rsi(16),
        context.rsi(24),
      ),
      children: [
        Row(
          children: [
            Text(
              '이 날 공정',
              style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: onAddProcess,
              icon: Icon(Icons.add_rounded, size: context.rs(18)),
              label: const Text('공정'),
            ),
          ],
        ),
        if (todayTasks.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: context.rsi(16)),
            child: Text(
              '이 날짜에 공정이 없습니다',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          )
        else
          ...processCards(todayTasks),
        if (otherTasks.isNotEmpty) ...[
          SizedBox(height: context.rsi(8)),
          Text(
            '다른 날 공정',
            style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          SizedBox(height: context.rsi(8)),
          ...processCards(otherTasks),
        ],
        if (other.isNotEmpty) ...[
          SizedBox(height: context.rsi(8)),
          Text(
            '공정 외',
            style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          SizedBox(height: context.rsi(8)),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final r in other) Chip(label: Text(humanName(r.hid))),
            ],
          ),
        ],
        SizedBox(height: context.rsi(12)),
        OutlinedButton.icon(
          onPressed: () => onAssign(null),
          icon: const Icon(Icons.person_add_alt_1_rounded),
          label: const Text('공정 없이 투입'),
        ),
      ],
    );
  }
}

class _ProcessDayCard extends StatelessWidget {
  const _ProcessDayCard({
    required this.task,
    required this.gridStart,
    required this.people,
    required this.humanName,
    required this.onAssign,
    required this.onWriteInstruction,
  });

  final ProcessScheduleTask task;
  final DateTime gridStart;
  final List<PlaceWorkDayRead> people;
  final String Function(int hid) humanName;
  final VoidCallback onAssign;
  final VoidCallback onWriteInstruction;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final color = Color(ProcessSchedulePalette.argbAt(task.paletteIndex));
    String period = '';
    if (task.scheduledDayIndices.isNotEmpty) {
      final idx = [...task.scheduledDayIndices]..sort();
      final start = gridStart.add(Duration(days: idx.first));
      final end = gridStart.add(Duration(days: idx.last));
      period = start == end
          ? formatMonthDayWeek(start)
          : '${start.month}월 ${start.day}일 ~ ${end.month}월 ${end.day}일';
    }
    return Padding(
      padding: EdgeInsets.only(bottom: context.rsi(10)),
      child: DecoratedBox(
        decoration: AppSectionCardStyles.cardDecoration(context),
        child: Padding(
          padding: EdgeInsets.all(context.rsi(14)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 28,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  SizedBox(width: context.rsi(10)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.name,
                          style: tt.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (period.isNotEmpty)
                          Text(
                            period,
                            style: tt.labelSmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: context.rsi(10)),
              if (people.isEmpty)
                Text(
                  '투입 없음',
                  style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
                )
              else
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final r in people)
                      Chip(
                        visualDensity: VisualDensity.compact,
                        label: Text(humanName(r.hid)),
                      ),
                  ],
                ),
              SizedBox(height: context.rsi(8)),
              Row(
                children: [
                  TextButton(
                    onPressed: people.isEmpty ? null : onWriteInstruction,
                    child: const Text('공정 지시'),
                  ),
                  const Spacer(),
                  FilledButton.tonalIcon(
                    onPressed: onAssign,
                    icon: Icon(Icons.person_add_alt_1_rounded,
                        size: context.rs(18)),
                    label: const Text('인력 투입'),
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

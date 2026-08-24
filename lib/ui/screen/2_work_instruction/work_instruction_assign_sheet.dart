import 'dart:async' show Timer, unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/data/datasources/remote/list_query.dart';
import 'package:w0001/data/model/bulk_workforce_assignment.dart';
import 'package:w0001/data/model/human_model.dart';
import 'package:w0001/data/model/place_info_model.dart';
import 'package:w0001/data/model/remote/super_admin_dtos.dart';
import 'package:w0001/domain/data_change_event.dart';
import 'package:w0001/domain/place_work_day_cross_place_conflict.dart';
import 'package:w0001/domain/process_schedule/process_schedule_models.dart';
import 'package:w0001/navigation/shell_back_navigation.dart';
import 'package:w0001/presentation/viewmodel/place_detail_view_model.dart'
    show workCostUseCaseProvider;
import 'package:w0001/presentation/viewmodel/place_list_view_model.dart';
import 'package:w0001/presentation/viewmodel/place_members_providers.dart';
import 'package:w0001/presentation/viewmodel/place_workforce_notifier.dart';
import 'package:w0001/presentation/viewmodel/super_admin_remote_providers.dart';
import 'package:w0001/theme/app_input_styles.dart';
import 'package:w0001/theme/app_theme_colors.dart';
import 'package:w0001/ui/screen/2_add/work_role_presets.dart';
import 'package:w0001/ui/screen/2_work_instruction/work_instruction_compose_page.dart';
import 'package:w0001/ui/screen/2_work_instruction/work_instruction_date_range_dialog.dart';
import 'package:w0001/ui/screen/5_place/widgets/cross_place_workday_conflict_dialog.dart';
import 'package:w0001/ui/screen/5_place/workforce_bulk_assignment/assignment_logic.dart';
import 'package:w0001/ui/screen/5_place/workforce_bulk_assignment/post_save_sync.dart';
import 'package:w0001/ui/widget/app_text_field.dart';
import 'package:w0001/ui/widget/hammer_loading_indicator.dart';
import 'package:w0001/util/fetch_data.dart';
import 'package:w0001/util/funtions.dart';
import 'package:w0001/util/human_work_assignability.dart';
import 'package:w0001/util/responsive_layout.dart';
import 'package:w0001/util/worker_skills_display.dart';

export 'package:w0001/ui/screen/2_work_instruction/work_instruction_compose_page.dart'
    show WorkInstructionAssignResult;

Future<WorkInstructionAssignResult?> showWorkInstructionAssignSheet({
  required BuildContext context,
  required PlaceInfoModel place,
  required DateTime workDate,
  ProcessScheduleTask? task,
  bool startAtInstruction = false,
  List<HumanModel> initialWorkers = const [],
}) {
  final day = DateTime(workDate.year, workDate.month, workDate.day);
  if (startAtInstruction) {
    return showWorkInstructionComposePage(
      context: context,
      place: place,
      startDate: day,
      endDate: day,
      task: task,
      workers: initialWorkers,
      sitePeople: initialWorkers,
      instructionOnly: true,
      scopeSite: task == null,
    );
  }
  return showModalBottomSheet<WorkInstructionAssignResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (ctx) => _WorkInstructionAssignSheet(
      place: place,
      workDate: day,
      task: task,
      initialWorkers: initialWorkers,
    ),
  );
}

class _WorkInstructionAssignSheet extends ConsumerStatefulWidget {
  const _WorkInstructionAssignSheet({
    required this.place,
    required this.workDate,
    this.task,
    this.initialWorkers = const [],
  });

  final PlaceInfoModel place;
  final DateTime workDate;
  final ProcessScheduleTask? task;
  final List<HumanModel> initialWorkers;

  @override
  ConsumerState<_WorkInstructionAssignSheet> createState() =>
      _WorkInstructionAssignSheetState();
}

class _WorkInstructionAssignSheetState
    extends ConsumerState<_WorkInstructionAssignSheet> {
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();

  var _loading = true;
  var _saving = false;
  late DateTime _startDate;
  late DateTime _endDate;
  Set<String> _blockedMemberUids = {};
  List<HumanModel> _candidates = const [];
  List<HumanModel> _siteRecent = const [];
  List<HumanModel> _allWorkersCache = const [];
  final _selected = <int, HumanModel>{};
  final _sitePeople = <int, HumanModel>{};
  List<PlaceWorkDayRead> _allWorkRows = const [];
  Timer? _searchDebounce;
  String? _specialtyFilter;

  int get _pid => widget.place.pid ?? 0;

  String get _workrole => widget.task?.name.trim() ?? '';

  List<DateTime> get _workDates {
    final out = <DateTime>[];
    var d = _startDate;
    while (!d.isAfter(_endDate)) {
      out.add(d);
      d = DateTime(d.year, d.month, d.day + 1);
    }
    return out;
  }

  bool get _isSearching =>
      _searchCtrl.text.trim().isNotEmpty || _specialtyFilter != null;

  List<String> get _specialtyOptions {
    final seen = <String>{};
    final out = <String>[];
    for (final p in kWorkRolePresets) {
      if (p == '직접입력' || p == '기타') continue;
      if (seen.add(p)) out.add(p);
    }
    for (final h in _allWorkersCache) {
      final s = humanListPrimarySpecialtyLabel(h)?.trim() ?? '';
      if (s.isNotEmpty && seen.add(s)) out.add(s);
    }
    return out;
  }

  bool _matchesSpecialty(HumanModel h) {
    final want = _specialtyFilter;
    if (want == null || want.isEmpty) return true;
    final skill =
        (humanListPrimarySpecialtyLabel(h) ?? h.displayPrimarySpecialty ?? '')
            .trim();
    return skill == want;
  }

  String get _dateLabel => formatMonthDayRange(_startDate, _endDate);

  bool _canAssign(HumanModel h) => humanCanBeAssignedToWork(
        h,
        blockedMemberUids: _blockedMemberUids,
      );

  Future<void> _pickDates() async {
    final picked = await showWorkInstructionDateRangeDialog(
      context: context,
      place: widget.place,
      start: _startDate,
      end: _endDate,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _startDate = picked.$1;
      _endDate = picked.$2;
    });
  }

  @override
  void initState() {
    super.initState();
    _startDate = widget.workDate;
    _endDate = widget.workDate;
    for (final h in widget.initialWorkers) {
      final hid = h.hid;
      if (hid == null || hid <= 0) continue;
      _selected[hid] = h;
      _sitePeople[hid] = h;
    }
    _searchFocus.addListener(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_bootstrap());
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      final uc = ref.read(humanUseCaseProvider);
      final recentWorkers = await uc.getPlaceRecentWorkers(_pid, limit: 80);
      List<HumanModel> allWorkers = const [];
      try {
        allWorkers = await uc.fetchAllWorkers(const ListQuery(hdelete: 0));
      } catch (_) {
        try {
          allWorkers = (await uc.fetchWorkersPage(
            const ListQuery(hdelete: 0, limit: 80),
          ))
              .items;
        } catch (_) {}
      }
      List<PlaceWorkDayRead> rows = const [];
      try {
        rows =
            await ref.read(superAdminRemoteUseCaseProvider).placeWorkDaysList();
      } catch (_) {}
      Set<String> blocked = {};
      try {
        blocked = await fetchNonAssignableMemberUids(
          ref.read(superAdminRemoteUseCaseProvider),
        );
      } catch (_) {}
      final dayKey = formatDateTimeToIsoDate(widget.workDate);
      final assignedHids = {
        for (final r in rows)
          if (r.pid == _pid && normalizePlaceWorkDateKey(r.workdate) == dayKey)
            r.hid,
      };
      List<HumanModel> assigned = const [];
      if (assignedHids.isNotEmpty) {
        try {
          assigned = await uc.getWorkersByHids(assignedHids);
        } catch (_) {}
      }
      final siteHids = {
        for (final r in rows)
          if (r.pid == _pid) r.hid,
      };
      List<HumanModel> siteHistory = const [];
      if (siteHids.isNotEmpty) {
        try {
          siteHistory = await uc.getWorkersByHids(siteHids);
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _siteRecent = _merge(recentWorkers, siteHistory);
        _candidates = _siteRecent;
        _allWorkersCache = allWorkers;
        for (final h in assigned) {
          final hid = h.hid;
          if (hid == null) continue;
          _sitePeople[hid] = h;
        }
        _allWorkRows = rows;
        _blockedMemberUids = blocked;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  List<HumanModel> _merge(Iterable<HumanModel> a, Iterable<HumanModel> b) {
    final map = <int, HumanModel>{};
    for (final h in [..._selected.values, ...a, ...b]) {
      final hid = h.hid;
      if (hid == null || hid <= 0 || h.hdelete != 0) continue;
      map[hid] = h;
    }
    final out = map.values.toList(growable: false)
      ..sort((x, y) {
        final ax = _selected.containsKey(x.hid) ? 0 : 1;
        final bx = _selected.containsKey(y.hid) ? 0 : 1;
        if (ax != bx) return ax - bx;
        return x.hname.compareTo(y.hname);
      });
    return out;
  }

  void _onSearch(String q) {
    setState(() {});
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 280), () {
      unawaited(_searchNow(q));
    });
  }

  Future<void> _searchNow(String q) async {
    final query = q.trim();
    try {
      final uc = ref.read(humanUseCaseProvider);
      if (query.isEmpty) {
        if (!mounted) return;
        final base = _specialtyFilter == null
            ? _siteRecent
            : _allWorkersCache.where(_matchesSpecialty);
        setState(() => _candidates = _merge(base, const []));
        return;
      }
      final page = await uc.searchWorkersPage(q: query, limit: 80);
      if (!mounted) return;
      final local = _allWorkersCache.where((h) {
        if (!_matchesSpecialty(h)) return false;
        final name = h.hname.trim();
        return name.contains(query) ||
            name.toLowerCase().contains(query.toLowerCase());
      });
      setState(
        () => _candidates = _merge(
          page.items.where(_matchesSpecialty),
          local,
        ),
      );
    } catch (_) {}
  }

  void _setSpecialty(String? skill) {
    setState(() {
      _specialtyFilter = skill;
    });
    unawaited(_searchNow(_searchCtrl.text));
  }

  void _toggle(HumanModel h) {
    final hid = h.hid;
    if (hid == null) return;
    if (!_selected.containsKey(hid) && !_canAssign(h)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            humanWorkAssignBlockMessage(
              h,
              blockedMemberUids: _blockedMemberUids,
            ),
          ),
        ),
      );
      return;
    }
    setState(() {
      if (_selected.containsKey(hid)) {
        _selected.remove(hid);
      } else {
        _selected[hid] = h;
      }
    });
  }

  List<CrossPlaceWorkDayConflict> _conflictsFor(Iterable<int> hids) {
    final places = {
      for (final p in ref.read(placeListProvider).placeList)
        if (p.pid != null) p.pid!: p.pname,
    };
    final names = <int, String>{
      for (final h in [..._candidates, ..._selected.values])
        if (h.hid != null) h.hid!: h.hname,
    };
    final out = <CrossPlaceWorkDayConflict>[];
    final seen = <String>{};
    for (final day in _workDates) {
      final found = findCrossPlaceWorkDayConflicts(
        allRows: _allWorkRows,
        targetPid: _pid,
        workdateIso: formatDateTimeToIsoDate(day),
        hids: hids,
        placeNameByPid: places,
        humanNameByHid: names,
      );
      for (final c in found) {
        final key = '${formatDateTimeToIsoDate(day)}-${c.hid}';
        if (seen.add(key)) out.add(c);
      }
    }
    return out;
  }

  Future<void> _openCompose() async {
    if (_selected.isEmpty) return;
    final result = await showWorkInstructionComposePage(
      context: context,
      place: widget.place,
      startDate: _startDate,
      endDate: _endDate,
      task: widget.task,
      workers: _selected.values.toList(growable: false),
      sitePeople: [..._sitePeople.values, ..._selected.values],
      allWorkRows: _allWorkRows,
      blockedMemberUids: _blockedMemberUids,
      instructionOnly: false,
      scopeSite: true,
    );
    if (result != null && mounted) {
      Navigator.pop(context, result);
    }
  }

  Future<void> _submit() async {
    if (_saving) return;
    if (_selected.isEmpty) return;

    final conflicts = _conflictsFor(_selected.keys);
    if (conflicts.isNotEmpty) {
      final choice = await showCrossPlaceWorkDayConflictDialog(
        context,
        workdateLabel: _dateLabel,
        currentPlaceName: widget.place.pname,
        conflicts: conflicts,
      );
      if (choice != CrossPlaceConflictChoice.proceedAll || !mounted) return;
    }

    setState(() => _saving = true);
    try {
      final workers = _selected.values.toList(growable: false);
      final roles = <int, String>{
        for (final h in workers)
          if (h.hid != null)
            h.hid!: _workrole.isNotEmpty
                ? _workrole
                : (h.effectiveDefaultWorkRole.isNotEmpty
                    ? h.effectiveDefaultWorkRole
                    : '투입'),
      };
      final wages = <int, int>{
        for (final h in workers)
          if (h.hid != null) h.hid!: h.hdailyWage,
      };
      final request = buildBulkWorkforceAssignmentRequest(
        startDate: _startDate,
        endDate: _endDate,
        selectedHumans: workers,
        humanWorkRoles: roles,
        humanWages: wages,
        fallbackWorkRole: _workrole,
      );
      final raw = await ref.read(placeUseCaseProvider).bulkAssignWorkforce(
            pid: _pid,
            requestBody: request.toJson(),
          );
      final response = BulkWorkforceAssignmentResponse.fromJson(raw);
      await runBulkAssignmentPostSaveSync(
        response: response,
        pid: _pid,
        startDate: _startDate,
        selectedHumans: workers,
        inviteAssignedWorkers: (pid, list) async {
          await ref
              .read(placeMembersUseCaseProvider)
              .inviteAssignedWorkersToPlace(pid, list);
        },
        ensureWorkCostForWorkDay: (wd) async {
          await ref.read(workCostUseCaseProvider).ensureWorkCostForPlaceWorkDay(
                pid: wd.pid,
                hid: wd.hid,
                dateKey: wd.workdate,
                wprice: wd.dailywage,
                wrole: wd.workrole,
              );
        },
        notifyWorkCostChanged: (pid, date) async {
          await FetchData.onDataChanged(
            DataChangeEvent(DataChangeKind.workCost, pid: pid, date: date),
            background: false,
          );
        },
        reloadWorkforce: () => ref
            .read(placeWorkforceProvider(_pid).notifier)
            .reload(silent: true),
        reloadProcessSchedule: () async {},
      );

      if (!mounted) return;
      Navigator.pop(
        context,
        WorkInstructionAssignResult(
          workers: workers,
          workDate: _startDate,
          endDate: _endDate == _startDate ? null : _endDate,
          taskName: widget.task?.name,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final kb = mq.viewInsets.bottom;
    final searchMode = _searchFocus.hasFocus || kb > 80;
    final handleGap = context.rs(36);
    final minSheet = context.rs(context.isCompactDevice ? 240 : 280);
    final available =
        (mq.size.height - kb - handleGap).clamp(minSheet, mq.size.height);
    final sheetFrac = context.isTabletDevice ? 0.72 : 0.88;
    final h = searchMode
        ? available
        : (mq.size.height * sheetFrac).clamp(minSheet, available);
    return BackButtonListener(
      onBackButtonPressed: () async {
        if (tryPopRootNavigatorOverlay(context)) {
          consumeDedupedBackEvent();
          return true;
        }
        consumeDedupedBackEvent();
        Navigator.pop(context);
        return true;
      },
      child: Padding(
        padding: EdgeInsets.only(bottom: kb),
        child: SizedBox(
          height: h,
          child: Column(
            children: [
              if (!searchMode) _header(context),
              if (_selected.isNotEmpty && !searchMode)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    context.rsi(16),
                    0,
                    context.rsi(16),
                    context.rsi(6),
                  ),
                  child: _selectedChips(context),
                ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  context.rsi(16),
                  searchMode ? context.rsi(4) : 0,
                  context.rsi(16),
                  0,
                ),
                child: _searchField(context),
              ),
              _specialtyBar(context),
              if (!searchMode)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    context.rsi(16),
                    context.rsi(8),
                    context.rsi(16),
                    context.rsi(6),
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _isSearching ? '검색 결과' : '이 현장 작업 인력',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                )
              else
                SizedBox(height: context.rsi(6)),
              Expanded(
                child: _loading
                    ? const Center(child: HammerLoadingIndicator(size: 56))
                    : _workerList(context),
              ),
              if (!searchMode) _footerBar(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.rsi(20),
        context.rsi(4),
        context.rsi(12),
        context.rsi(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '인력 투입',
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                SizedBox(height: context.rsi(2)),
                InkWell(
                  onTap: _pickDates,
                  borderRadius: BorderRadius.circular(context.rs(8)),
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: context.rsi(2)),
                    child: Row(
                      children: [
                        Expanded(
                          child: _workrole.isEmpty
                              ? Text(
                                  _dateLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: tt.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _workrole,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: tt.bodySmall?.copyWith(
                                        color: cs.onSurfaceVariant,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      _dateLabel,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: tt.bodySmall?.copyWith(
                                        color: cs.onSurfaceVariant,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                        SizedBox(width: context.rsi(4)),
                        Icon(
                          Icons.calendar_month_rounded,
                          size: context.rsi(16),
                          color: cs.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }

  Widget _footerBar(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          context.rsi(16),
          context.rsi(8),
          context.rsi(16),
          context.rsi(10),
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _saving || _selected.isEmpty
                    ? null
                    : () => unawaited(_openCompose()),
                child: const Text('작업지시'),
              ),
            ),
            SizedBox(width: context.rsi(8)),
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: _saving || _selected.isEmpty
                    ? null
                    : () => unawaited(_submit()),
                child: Text(
                  _saving ? '투입 중' : '${_selected.length}명 바로 투입',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _selectedChips(BuildContext context) {
    if (_selected.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final h in _selected.values)
          InputChip(
            visualDensity: VisualDensity.compact,
            label: Text(h.hname),
            onDeleted: () => _toggle(h),
          ),
      ],
    );
  }

  Widget _specialtyBar(BuildContext context) {
    final options = _specialtyOptions;
    if (options.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: context.rs(44),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.fromLTRB(
          context.rsi(16),
          context.rsi(8),
          context.rsi(16),
          0,
        ),
        children: [
          Padding(
            padding: EdgeInsets.only(right: context.rsi(6)),
            child: FilterChip(
              label: const Text('전체'),
              selected: _specialtyFilter == null,
              visualDensity: VisualDensity.compact,
              onSelected: (_) => _setSpecialty(null),
            ),
          ),
          for (final skill in options)
            Padding(
              padding: EdgeInsets.only(right: context.rsi(6)),
              child: FilterChip(
                label: Text(skill),
                selected: _specialtyFilter == skill,
                visualDensity: VisualDensity.compact,
                onSelected: (on) => _setSpecialty(on ? skill : null),
              ),
            ),
        ],
      ),
    );
  }

  Widget _workerList(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (_candidates.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: context.rsi(24)),
          child: Text(
            _isSearching ? '검색 결과가 없습니다' : '이 현장에서 작업한 인력이 없습니다',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
      );
    }
    return ListView.builder(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(
        context.rsi(16),
        0,
        context.rsi(16),
        context.rsi(12),
      ),
      itemCount: _candidates.length,
      itemBuilder: (context, i) => _workerTile(_candidates[i]),
    );
  }

  Widget _searchField(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(14);
    return AppTextField(
      controller: _searchCtrl,
      focusNode: _searchFocus,
      onChanged: _onSearch,
      textInputAction: TextInputAction.search,
      style: AppInputStyles.fieldText(context),
      decoration: InputDecoration(
        hintText: '이름으로 검색',
        isDense: true,
        filled: true,
        fillColor: cs.surface.withValues(alpha: 0.72),
        contentPadding: EdgeInsets.symmetric(
          horizontal: context.rsi(12),
          vertical: context.rsi(10),
        ),
        prefixIcon: Icon(
          Icons.search_rounded,
          size: context.rs(20),
          color: cs.onSurfaceVariant,
        ),
        suffixIcon: _isSearching
            ? IconButton(
                tooltip: '지우기',
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  Icons.close_rounded,
                  size: context.rs(18),
                  color: cs.onSurfaceVariant,
                ),
                onPressed: () {
                  _searchCtrl.clear();
                  _onSearch('');
                },
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.45),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.45),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: cs.primary.withValues(alpha: 0.55)),
        ),
      ),
    );
  }

  Widget _workerTile(HumanModel h) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final hid = h.hid;
    final checked = hid != null && _selected.containsKey(hid);
    final rank = resolveHumanSiteRank(h);
    final skill = humanListPrimarySpecialtyLabel(h);
    final conflict = hid == null ? null : _conflictsFor([hid]).firstOrNull;
    final assignable = _canAssign(h);
    return Padding(
      padding: EdgeInsets.only(bottom: context.rsi(8)),
      child: Material(
        color: checked
            ? cs.primaryContainer.withValues(alpha: 0.5)
            : cs.appInsetFill,
        borderRadius: BorderRadius.circular(context.rs(12)),
        child: InkWell(
          onTap: hid == null ? null : () => _toggle(h),
          borderRadius: BorderRadius.circular(context.rs(12)),
          child: Padding(
            padding: EdgeInsets.all(context.rsi(12)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  checked
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked,
                  color: !assignable
                      ? cs.outline
                      : (checked ? cs.primary : cs.outline),
                ),
                SizedBox(width: context.rsi(10)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              h.hname,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: tt.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: assignable ? null : cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                          if (!assignable) ...[
                            SizedBox(width: context.rsi(6)),
                            _statusChip(
                              context,
                              humanWorkAssignBlockMessage(
                                h,
                                blockedMemberUids: _blockedMemberUids,
                              ).contains('정지')
                                  ? '정지'
                                  : '투입 불가',
                              cs.errorContainer,
                              cs.onErrorContainer,
                            ),
                          ],
                        ],
                      ),
                      SizedBox(height: context.rsi(2)),
                      Text(
                        [
                          if (rank != null && rank.isNotEmpty) rank,
                          if (skill != null && skill.isNotEmpty) skill,
                          getPrice(price: h.hdailyWage),
                        ].join('  '),
                        style: tt.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      if (conflict != null) ...[
                        SizedBox(height: context.rsi(4)),
                        Text(
                          conflict.assignments.first.workrole.isNotEmpty
                              ? '같은 날 ${conflict.assignments.first.placeName} ${conflict.assignments.first.workrole}'
                              : '같은 날 ${conflict.assignments.first.placeName}',
                          style: tt.labelSmall?.copyWith(
                            color: cs.error,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusChip(
    BuildContext context,
    String label,
    Color bg,
    Color fg,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.rsi(6),
        vertical: context.rsi(2),
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(context.rs(6)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

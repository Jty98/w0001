import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/access/user_role_access.dart';
import 'package:w0001/data/model/place_info_model.dart';
import 'package:w0001/data/model/remote/super_admin_dtos.dart';
import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/data/model/worker_dashboard_models.dart';
import 'package:w0001/presentation/viewmodel/auth_providers.dart';
import 'package:w0001/presentation/viewmodel/super_admin_remote_providers.dart';
import 'package:w0001/presentation/viewmodel/worker_personal_dashboard_notifier.dart';
import 'package:w0001/util/work_instruction_blocks_resolve.dart';
import 'package:w0001/util/worker_api_user_messages.dart';
import 'package:scrollable_calendar_package/calendar.dart'
    show calendarWeekStripTitle;
import 'package:w0001/theme/app_theme_colors.dart';
import 'package:w0001/theme/app_section_card.dart';
import 'package:w0001/ui/screen/1_dashboard/widgets/assignment_instruction_detail_sheet.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:w0001/util/responsive_layout.dart';

const _weekdayKo = ['월', '화', '수', '목', '금', '토', '일'];

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// 월요일 시작 주간 계산
DateTime _startOfWeekMonday(DateTime d) {
  final dateOnly = _dateOnly(d);
  // weekday: 1=월, 2=화, ..., 7=일
  // 월요일(1)이면 0일 빼기, 화요일(2)이면 1일 빼기, ..., 일요일(7)이면 6일 빼기
  final offset = dateOnly.weekday == 7 ? 6 : dateOnly.weekday - 1;
  return dateOnly.subtract(Duration(days: offset));
}

String _ymd(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

bool _samePlaceWorkDate(PlaceWorkDayRead r, String isoDay, int pid) {
  if (r.pid != pid) return false;
  final raw = r.workdate.trim();
  final dk = raw.length >= 10 ? raw.substring(0, 10) : raw;
  return dk == isoDay;
}

/// 해당 일·현장 투입 인원 [hid]당 한 행(전체 명단).
List<PlaceWorkDayRead> _dayRosterDistinctForPlace({
  required List<PlaceWorkDayRead> allRows,
  required int pid,
  required String isoDay,
}) {
  final byHid = <int, PlaceWorkDayRead>{};
  for (final r in allRows) {
    if (!_samePlaceWorkDate(r, isoDay, pid)) continue;
    byHid.putIfAbsent(r.hid, () => r);
  }
  final list = byHid.values.toList(growable: false)
    ..sort((a, b) {
      final c = a.workrole.trim().compareTo(b.workrole.trim());
      if (c != 0) return c;
      return a.hid.compareTo(b.hid);
    });
  return list;
}

Map<int, String> _humanDirectoryNameByHid(Iterable<HumanRead> humans) {
  final m = <int, String>{};
  for (final h in humans) {
    if (h.hdelete != 0) continue;
    final n = h.hname.trim();
    if (n.isEmpty) continue;
    m[h.hid] = n;
  }
  return m;
}

String _placeWorkerDisplayNameForHid(
  int hid, {
  required Map<int, String> namesByHid,
  required int? viewerHid,
  required String viewerUnameTrimmed,
}) {
  final dn = namesByHid[hid];
  if (dn != null && dn.isNotEmpty) return dn;
  if (viewerHid != null && hid == viewerHid && viewerUnameTrimmed.isNotEmpty) {
    return viewerUnameTrimmed;
  }
  return '이름 없음';
}

class _CoworkersLoadUi {
  const _CoworkersLoadUi({
    required this.peers,
    this.errorLine,
  });

  final List<CoworkerOnSite> peers;
  final String? errorLine;
}

/// `yyyy-MM-dd` → 작업 투입된 날(점 표시).
Set<String> _assignedDayKeys({
  required List<PlaceWorkDayRead> rows,
  required int pid,
  required int? workerHid,
}) {
  final out = <String>{};
  for (final r in rows) {
    if (r.pid != pid) continue;
    if (workerHid != null && r.hid != workerHid) continue;
    final raw = r.workdate.trim();
    if (raw.length >= 10) out.add(raw.substring(0, 10));
  }
  return out;
}

/// 현장 작업 내용 바텀시트 — [WorkerScheduleScreen] 현장 배정 시트와 톤을 맞춤.
void showPlaceWorkerInstructionDaySheet({
  required BuildContext context,
  required PlaceInfoModel place,
  required DateTime day,
  required List<PlaceWorkDayRead> allRows,
  int? workerHid,
}) {
  final pid = place.pid;
  if (pid == null) return;

  final iso = _ymd(day);
  final filtered = allRows.where((r) {
    if (r.pid != pid) return false;
    final raw = r.workdate.trim();
    final dk = raw.length >= 10 ? raw.substring(0, 10) : raw;
    if (dk != iso) return false;
    if (workerHid != null && r.hid != workerHid) return false;
    return true;
  }).toList(growable: false)
    ..sort((a, b) => a.hid.compareTo(b.hid));

  const wdKo = ['월', '화', '수', '목', '금', '토', '일'];
  final weekday = wdKo[day.weekday - 1];

  final rosterDistinct = _dayRosterDistinctForPlace(
    allRows: allRows,
    pid: pid,
    isoDay: iso,
  );
  final rosterOthers = excludeSelfFromPlaceWorkDayRoster(
    rosterDistinct,
    workerHid: workerHid,
  );

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    useRootNavigator: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    clipBehavior: Clip.antiAlias,
    builder: (_) => _PlaceWorkerInstructionDaySheetBody(
      place: place,
      day: day,
      weekdayLabel: weekday,
      filtered: filtered,
      rosterOthers: rosterOthers,
      workerHid: workerHid,
    ),
  );
}

class _RosterDeps {
  const _RosterDeps._({
    required this.workerApi,
    this.humans = const [],
    this.coworkers,
  });

  factory _RosterDeps.management(List<HumanRead> h) =>
      _RosterDeps._(workerApi: false, humans: h);

  factory _RosterDeps.worker(_CoworkersLoadUi ui) =>
      _RosterDeps._(workerApi: true, coworkers: ui);

  final bool workerApi;
  final List<HumanRead> humans;
  final _CoworkersLoadUi? coworkers;
}

class _PlaceWorkerInstructionDaySheetBody extends ConsumerStatefulWidget {
  const _PlaceWorkerInstructionDaySheetBody({
    required this.place,
    required this.day,
    required this.weekdayLabel,
    required this.filtered,
    required this.rosterOthers,
    required this.workerHid,
  });

  final PlaceInfoModel place;
  final DateTime day;
  final String weekdayLabel;
  final List<PlaceWorkDayRead> filtered;
  final List<PlaceWorkDayRead> rosterOthers;
  final int? workerHid;

  @override
  ConsumerState<_PlaceWorkerInstructionDaySheetBody> createState() =>
      _PlaceWorkerInstructionDaySheetBodyState();
}

class _PlaceWorkerInstructionDaySheetBodyState
    extends ConsumerState<_PlaceWorkerInstructionDaySheetBody> {
  Future<_RosterDeps>? _rosterOnce;

  Future<_RosterDeps> _rosterFuture() {
    if (_rosterOnce != null) return _rosterOnce!;
    _rosterOnce = _loadRoster();
    return _rosterOnce!;
  }

  Future<_RosterDeps> _loadRoster() async {
    final me = ref.read(authSessionProvider).asData?.value;
    if (me == null) {
      return _RosterDeps.management(const []);
    }
    if (me.isWorker) {
      final pid = widget.place.pid;
      if (pid == null) {
        return _RosterDeps.worker(const _CoworkersLoadUi(peers: []));
      }
      try {
        final api = ref.read(workerDashboardRemoteApiProvider);
        final list = await api.fetchCoworkers(pid, _ymd(widget.day));
        return _RosterDeps.worker(_CoworkersLoadUi(peers: list));
      } on HttpClientException catch (e) {
        return _RosterDeps.worker(_CoworkersLoadUi(
          peers: const [],
          errorLine:
              workerDashboardFriendlyMessageKo(e) ?? '동료 목록을 불러오지 못했습니다.',
        ));
      } catch (_) {
        return _RosterDeps.worker(const _CoworkersLoadUi(
          peers: [],
          errorLine: '동료 목록을 불러오지 못했습니다.',
        ));
      }
    }
    if (me.isManagementRole) {
      final humans = await ref
          .read(superAdminRemoteUseCaseProvider)
          .humansList()
          .catchError((_) => const <HumanRead>[]);
      return _RosterDeps.management(humans);
    }
    return _RosterDeps.management(const []);
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final bottom = MediaQuery.paddingOf(context).bottom;

    final viewerUnameTrimmed =
        ref.watch(authSessionProvider).asData?.value?.uname.trim() ?? '';
    final rosterTitle = widget.workerHid != null ? '같은 날 투입 동료' : '이 날 투입 인원';
    final me = ref.watch(authSessionProvider).asData?.value;
    final mgmtPeerBand =
        me?.isManagementRole == true && widget.rosterOthers.isNotEmpty;
    final workerPeerBand = me?.isWorker == true;

    return FutureBuilder<_RosterDeps>(
      future: _rosterFuture(),
      builder: (context, snap) {
        final loading = snap.connectionState != ConnectionState.done;
        final deps = snap.data;
        final namesByHid = deps == null
            ? <int, String>{}
            : _humanDirectoryNameByHid(deps.humans);

        final coworkerPeersFiltered = excludeSelfFromCoworkers(
          deps?.coworkers?.peers ?? const [],
          workerHid: widget.workerHid,
          viewerUname: viewerUnameTrimmed,
        );

        final headerRole = widget.filtered.isNotEmpty
            ? widget.filtered.first.workrole.trim()
            : '';

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            context.rs(20),
            context.rs(4),
            context.rs(20),
            context.rs(20) + bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AssignmentInstructionSheetHeader(
                placeName: widget.place.pname,
                workrole: headerRole,
                dateLabel: assignmentInstructionDateLabel(widget.day),
                placeAddress: widget.place.paddress.trim(),
              ),
              rsV(context, 16),
              if (mgmtPeerBand) ...[
                AssignmentPeerHorizontalStrip(
                  sectionTitle: rosterTitle,
                  loading: loading,
                  entries: [
                    for (final r in widget.rosterOthers)
                      AssignmentPeerChipData(
                        name: _placeWorkerDisplayNameForHid(
                          r.hid,
                          namesByHid: namesByHid,
                          viewerHid: widget.workerHid,
                          viewerUnameTrimmed: viewerUnameTrimmed,
                        ),
                        roleLine: r.workrole.trim().isEmpty
                            ? '역할 미정'
                            : r.workrole.trim(),
                        tooltip: '인력 번호 · ${r.hid}',
                      ),
                  ],
                ),
                rsV(context, 16),
              ],
              if (workerPeerBand) ...[
                AssignmentPeerHorizontalStrip(
                  sectionTitle: rosterTitle,
                  loading: loading,
                  errorLine: deps?.coworkers?.errorLine,
                  entries: [
                    for (final c in coworkerPeersFiltered)
                      AssignmentPeerChipData(
                        name: c.workerName.trim().isEmpty
                            ? '이름 없음'
                            : c.workerName.trim(),
                        roleLine: c.workrole.trim().isEmpty
                            ? '역할 미정'
                            : c.workrole.trim(),
                        tooltip: '인력 번호 ${c.hid}',
                      ),
                  ],
                ),
                rsV(context, 16),
              ],
              if (widget.filtered.isEmpty)
                AppInsetTile(
                  padding: ResponsiveLayout.symmetric(
                    context,
                    horizontal: 18,
                    vertical: 22,
                  ),
                  child: Text(
                    widget.workerHid != null
                        ? '이 날짜에 나에게 배정된 투입이 없거나, 표시할 작업 내용이 없습니다.'
                        : '이 날짜에는 이 현장 투입 기록이 없습니다.',
                    textAlign: TextAlign.center,
                    style: tt.bodyLarge?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                )
              else ...[
                for (var i = 0; i < widget.filtered.length; i++) ...[
                  if (i > 0) rsV(context, 12),
                  AssignmentInstructionDetailCard.fromPlaceWorkerRow(
                    instructionBlocks: resolveAssignmentInstructionBlocks(
                      instructionBlocks:
                          widget.filtered[i].resolvedInstructionBlocks,
                    ),
                    workrole: widget.filtered[i].workrole,
                    slotLabelAboveWork: widget.filtered.length > 1
                        ? () {
                            final role = widget.filtered[i].workrole.trim();
                            final roleLabel = role.isEmpty ? '공정 미정' : role;
                            if (widget.workerHid != null) {
                              return '나의 배정 · ${i + 1}/${widget.filtered.length}';
                            }
                            final name = _placeWorkerDisplayNameForHid(
                              widget.filtered[i].hid,
                              namesByHid: namesByHid,
                              viewerHid: widget.workerHid,
                              viewerUnameTrimmed: viewerUnameTrimmed,
                            );
                            return '$name · $roleLabel';
                          }()
                        : (widget.workerHid != null ? '나의 배정' : null),
                    quillViewportHeight:
                        assignmentInstructionSheetQuillHeight(context),
                  ),
                ],
              ],
            ],
          ),
        );
      },
    );
  }
}

/// 가벼운 주간 스트립(스와이프 패키지 없음). 높이 고정 → 상위에서 잘리지 않음.
class PlaceWorkerInstructionWeekPeek extends ConsumerStatefulWidget {
  const PlaceWorkerInstructionWeekPeek({
    super.key,
    required this.place,
  });

  final PlaceInfoModel place;

  @override
  ConsumerState<PlaceWorkerInstructionWeekPeek> createState() =>
      _PlaceWorkerInstructionWeekPeekState();
}

class _PlaceWorkerInstructionWeekPeekState
    extends ConsumerState<PlaceWorkerInstructionWeekPeek> {
  Future<List<PlaceWorkDayRead>>? _load;
  late DateTime _selected;

  /// [PageView] 페이지 512가 이 주의 월요일과 매칭됨 (스와이프는 이 기준 ±7일).
  late final DateTime _anchorMonday;
  late final PageController _pageController;
  static const int _weekPageOrigin = 512;
  var _stripPageIndex = _weekPageOrigin;

  @override
  void initState() {
    super.initState();
    final today = _dateOnly(DateTime.now());
    _selected = today;
    _anchorMonday = _startOfWeekMonday(today);
    _pageController = PageController(initialPage: _weekPageOrigin);
    _kickLoad();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant PlaceWorkerInstructionWeekPeek oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.place.pid != widget.place.pid) {
      _kickLoad();
    }
  }

  void _kickLoad() {
    final pid = widget.place.pid;
    if (pid == null) return;
    setState(() {
      _load = ref.read(superAdminRemoteUseCaseProvider).placeWorkDaysList();
    });
  }

  DateTime _mondayAtPage(int page) =>
      _anchorMonday.add(Duration(days: 7 * (page - _weekPageOrigin)));

  int _pageIndexForMonday(DateTime mondayDateOnly) {
    final mon = _dateOnly(mondayDateOnly);
    final deltaDays = mon.difference(_anchorMonday).inDays;
    return _weekPageOrigin + deltaDays ~/ 7;
  }

  /// 캘린더 주 스트립·선택 일자를 오늘로 맞춤.
  void _goToToday() {
    final today = _dateOnly(DateTime.now());
    final page = _pageIndexForMonday(_startOfWeekMonday(today));
    setState(() {
      _selected = today;
      _stripPageIndex = page;
    });
    void slide() {
      if (!mounted || !_pageController.hasClients) return;
      _pageController.animateToPage(
        page,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => slide());
  }

  void _openInstructionSheet(
      DateTime day, List<PlaceWorkDayRead> rows, int? workerHid) {
    setState(() => _selected = _dateOnly(day));
    showPlaceWorkerInstructionDaySheet(
      context: context,
      place: widget.place,
      day: _dateOnly(day),
      allRows: rows,
      workerHid: workerHid,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final baseMq = MediaQuery.of(context);
    // 주간 스트립은 셀 폭이 매우 좁아 큰글씨 모드에서 두 자리 날짜가
    // 한 자리로 잘려 보일 수 있어, 이 영역만 텍스트 스케일을 고정한다.
    final weekStripMq = baseMq.copyWith(
      textScaler: const TextScaler.linear(1.0),
    );
    final pid = widget.place.pid;

    final me = ref.watch(authSessionProvider).asData?.value;
    final workerHid = me?.workerHid;

    if (pid == null) return const SizedBox.shrink();

    final scopeShort = workerHid != null ? '내 배정만' : '현장 투입';

    return AppSectionCard(
      icon: Icons.edit_note_rounded,
      title: '주간 작업 내용',
      subtitle: scopeShort,
      iconColor: cs.tertiary,
      denseHeader: true,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: '오늘로 이동',
            onPressed: _goToToday,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(
              minWidth: context.rs(34),
              minHeight: context.rs(34),
            ),
            icon: Icon(
              Icons.today_rounded,
              size: context.rsi(21),
              color: cs.primary,
            ),
          ),
          Tooltip(
            message: '좌우로 밀어 다른 주. 날 탭 시 작업 내용(내 일정과 동일).',
            child: Icon(
              Icons.swipe_rounded,
              size: context.rsi(17),
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
      contentPadding:
          ResponsiveLayout.symmetric(context, horizontal: 8, vertical: 6),
      child: FutureBuilder<List<PlaceWorkDayRead>>(
        future: _load,
        builder: (context, snap) {
          final rowsOk = snap.connectionState == ConnectionState.done &&
              snap.hasData &&
              !snap.hasError;
          final mondayShown =
              snap.connectionState == ConnectionState.done && !snap.hasError
                  ? _mondayAtPage(_stripPageIndex)
                  : null;
          final dotKeys = rowsOk
              ? _assignedDayKeys(
                  rows: snap.data ?? const [],
                  pid: pid,
                  workerHid: workerHid,
                )
              : <String>{};
          final anyDot = dotKeys.isNotEmpty;

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (mondayShown != null) ...[
                Text(
                  calendarWeekStripTitle(
                    mondayShown,
                    mondayShown.add(const Duration(days: 6)),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: cs.primary,
                    height: 1.1,
                  ),
                ),
                rsV(context, 4),
              ],
              MediaQuery(
                data: weekStripMq,
                child: SizedBox(
                  height: context.rs(86),
                  child: snap.connectionState != ConnectionState.done
                      ? Skeletonizer(
                        enabled: true,
                        child: Padding(
                          padding: ResponsiveLayout.symmetric(context,
                              horizontal: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '작업 내용',
                                style: tt.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              rsV(context, 8),
                              Text(
                                '불러오는 중입니다.',
                                style: tt.bodySmall?.copyWith(height: 1.3),
                              ),
                            ],
                          ),
                        ),
                      )
                      : snap.hasError
                          ? Center(
                            child: Text(
                              '불러오지 못했습니다.',
                              textAlign: TextAlign.center,
                              style: tt.labelSmall?.copyWith(
                                color: cs.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                          : PageView.builder(
                            controller: _pageController,
                            onPageChanged: (page) =>
                                setState(() => _stripPageIndex = page),
                            itemBuilder: (context, page) {
                              final start = _mondayAtPage(page);
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: List.generate(7, (i) {
                                  final d = start.add(Duration(days: i));
                                  final key = _ymd(d);
                                  final has = dotKeys.contains(key);
                                  final sel = _sameDay(d, _selected);
                                  // 월=1, 화=2, ..., 토=6, 일=7
                                  final isWeekend =
                                      d.weekday == 6 || d.weekday == 7;
                                  final isSaturday = d.weekday == 6;
                                  final isSunday = d.weekday == 7;
                                  // 월~금: 0~4, 토: 5, 일: 6
                                  final wd = _weekdayKo[i];

                                  return Expanded(
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () => _openInstructionSheet(
                                          d,
                                          snap.data ??
                                              const <PlaceWorkDayRead>[],
                                          workerHid,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                            context.rs(8)),
                                        child: Padding(
                                          padding: ResponsiveLayout.symmetric(
                                            context,
                                            vertical: 4,
                                          ),
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.start,
                                            children: [
                                              Text(
                                                wd,
                                                style: tt.labelSmall?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                  color: isSaturday
                                                      ? Colors.blue.shade700
                                                      : isSunday
                                                          ? Colors.red.shade700
                                                          : cs.onSurfaceVariant,
                                                ),
                                              ),
                                              rsV(context, 2),
                                              AnimatedContainer(
                                                duration: const Duration(
                                                    milliseconds: 150),
                                                width: context.rs(28),
                                                height: context.rs(28),
                                                alignment: Alignment.center,
                                                decoration: BoxDecoration(
                                                  color: has
                                                      ? cs.tertiary.withValues(
                                                          alpha: 0.2)
                                                      : sel
                                                          ? cs.primary
                                                              .withValues(
                                                                  alpha: 0.16)
                                                          : isWeekend
                                                              ? cs.appMutedFill
                                                              : Colors
                                                                  .transparent,
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: has
                                                        ? cs.tertiary
                                                        : sel
                                                            ? cs.primary
                                                            : cs.outlineVariant
                                                                .withValues(
                                                                    alpha: 0.5),
                                                    width: has
                                                        ? 1.6
                                                        : sel
                                                            ? 1.4
                                                            : 0.8,
                                                  ),
                                                ),
                                                child: FittedBox(
                                                  fit: BoxFit.scaleDown,
                                                  child: Text(
                                                    '${d.day}',
                                                    maxLines: 1,
                                                    style:
                                                        tt.bodyMedium?.copyWith(
                                                      fontWeight: has
                                                          ? FontWeight.w900
                                                          : FontWeight.w800,
                                                      height: 1.0,
                                                      color: has
                                                          ? cs.tertiary
                                                          : sel
                                                              ? cs.primary
                                                              : isSaturday
                                                                  ? Colors.blue
                                                                      .shade700
                                                                  : isSunday
                                                                      ? Colors.red
                                                                          .shade700
                                                                      : cs.onSurface,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              rsV(context, 4),
                                              Container(
                                                width: context.rs(5),
                                                height: context.rs(5),
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: has
                                                      ? cs.tertiary
                                                      : Colors.transparent,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              );
                            },
                          ),
                ),
              ),
              if (anyDot)
                Padding(
                  padding: ResponsiveLayout.only(context, top: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.circle,
                          size: context.rsi(6), color: cs.tertiary),
                      rsH(context, 5),
                      Text(
                        '내 작업 투입일',
                        style: tt.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

import 'dart:async' show unawaited;
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:scrollable_calendar_package/calendar.dart';
import 'package:w0001/access/user_role_access.dart';
import 'package:w0001/data/model/place_info_model.dart';
import 'package:w0001/data/model/remote/super_admin_dtos.dart';
import 'package:w0001/data/mappers/remote_mappers.dart';
import 'package:w0001/presentation/viewmodel/dashboard_schedule_view_model.dart';
import 'package:w0001/presentation/viewmodel/auth_providers.dart';
import 'package:w0001/presentation/viewmodel/place_list_view_model.dart';
import 'package:w0001/presentation/viewmodel/worker_schedule_notifier.dart';
import 'package:w0001/presentation/viewmodel/worker_personal_dashboard_notifier.dart';
import 'package:w0001/presentation/viewmodel/worker_supply_map_providers.dart';
import 'package:w0001/data/model/worker_dashboard_models.dart';
import 'package:w0001/enums.dart';
import 'package:w0001/ui/screen/3_calendar/worker_schedule_memo_editor.dart';
import 'package:w0001/theme/app_elevation.dart';
import 'package:w0001/ui/screen/1_dashboard/widgets/assignment_instruction_detail_sheet.dart';
import 'package:w0001/ui/screen/1_dashboard/widgets/worker_dashboard_section_shell.dart';
import 'package:w0001/ui/screen/5_place/widgets/place_worker_instruction_week_peek.dart';
import 'package:w0001/ui/widget/scrollable_calendar/scrollable_calendar_widget.dart';
import 'package:w0001/ui/widget/schedule_memo/schedule_memo_list_tile.dart';
import 'package:w0001/ui/widget/app_refresh_indicator.dart';
import 'package:w0001/ui/widget/map_route_action_buttons.dart';
import 'package:w0001/util/alarm_permission_helper.dart';
import 'package:w0001/util/fcm/fcm_pending_schedule_link.dart';
import 'package:w0001/util/map_navigation_launcher.dart';
import 'package:w0001/util/schedule_memo_alarm_sync.dart';
import 'package:w0001/util/work_instruction_blocks_resolve.dart';
import 'package:w0001/util/funtions.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:w0001/util/responsive_layout.dart';

const _weekdayKo = ['월', '화', '수', '목', '금', '토', '일'];
const _paidGreen = Color(0xFF2E7D32);

String _dayTitleLine(DateTime day) {
  final wd = _weekdayKo[day.weekday - 1];
  return '${day.year}년 ${day.month}월 ${day.day}일 ($wd)';
}

ScheduleMemoRead _workerScheduleScreenSkeletonMemo({required bool assignment}) {
  final d = scheduleDateOnly(DateTime.now());
  final k =
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  return ScheduleMemoRead(
    sid: -1,
    taskdate: k,
    tasktime: assignment ? '09:00' : '15:00',
    title: assignment ? '현장 배정' : '직접 메모',
    memo: assignment ? '' : '일정 내용 미리보기',
    done: false,
    alarmenabled: false,
    sortorder: 0,
    createdatms: 0,
    sourceType: assignment ? 'assignment' : 'manual',
    workrole: assignment ? '타일' : '',
  );
}

double _estimateWorkerMonthCalendarHeight(
  BuildContext context,
  double viewportWidth,
  DateTime monthAnchor,
) {
  // ScrollableCalendar 패키지 기본 레이아웃 근사치.
  final containerVMargin = context.rs(8);
  final containerVPadding = context.rs(16);
  final gapHeaderToGrid = context.rs(12);
  final horizontalPaddingTotal = context.rs(10);

  // 월 헤더/뷰모드 토글/요일 라벨 여유(글자 확대 대비).
  final headerAndWeekTitleApprox = 182.0;
  const crossAxisCount = 7;
  const aspect = 1.2;
  final mainAxisSpacing = context.rs(2);
  final crossAxisSpacing = context.rs(2);

  final innerW = math
      .max(0.0, viewportWidth - horizontalPaddingTotal)
      .clamp(context.rs(120), 2000.0);
  final cellW =
      (innerW - crossAxisSpacing * (crossAxisCount - 1)) / crossAxisCount;
  final cellH = cellW / aspect;

  final rows = _calendarWeekRowsForMonth(monthAnchor.year, monthAnchor.month);
  final gridH = rows * cellH + (rows - 1) * mainAxisSpacing;
  final textScale = MediaQuery.textScalerOf(context).scale(1.0);
  final textScaleSafety = (textScale - 1.0).clamp(0.0, 0.4) * 30.0;
  return containerVMargin +
      containerVPadding +
      headerAndWeekTitleApprox +
      gapHeaderToGrid +
      gridH +
      textScaleSafety;
}

/// 뷰 모드 칩·주·월 그리드가 잘리지 않도록 기기별로 높이를 잡습니다.
double _workerCalendarHeight(
  BuildContext context,
  CalendarViewMode mode,
  DateTime monthAnchor,
) {
  final size = MediaQuery.sizeOf(context);
  final portrait = size.height >= size.width;
  final w = size.width;

  // 1주/2주: 기존처럼 넉넉하게(하지만 패키지에서 adaptiveHeightForWeekModes로 줄어듦)
  if (portrait) {
    if (mode == CalendarViewMode.month) {
      final est = _estimateWorkerMonthCalendarHeight(context, w, monthAnchor);
      final hi = (size.height * 0.50).clamp(430.0, 620.0);
      return est.clamp(372.0, hi).toDouble();
    }
    return (size.height * 0.44).clamp(390.0, 640.0);
  }
  if (mode == CalendarViewMode.month) {
    final est = _estimateWorkerMonthCalendarHeight(context, w, monthAnchor);
    final hi = (size.height * 0.76).clamp(360.0, 620.0);
    return est.clamp(336.0, hi).toDouble();
  }
  return (size.height * 0.74).clamp(300.0, 480.0);
}

int _calendarWeekRowsForMonth(int year, int month) {
  final first = DateTime(year, month, 1);
  final nextFirst =
      month == 12 ? DateTime(year + 1, 1, 1) : DateTime(year, month + 1, 1);
  final daysInMonth = nextFirst.subtract(const Duration(days: 1)).day;
  // package is sunday-first header.
  final startOffset = first.weekday % 7;
  final cells = startOffset + daysInMonth;
  return ((cells + 6) ~/ 7).clamp(4, 6);
}

List<CalendarEvent> _memoCalendarDots(
  List<ScheduleMemoRead> memos,
  Color dotColor,
) {
  final seen = <String>{};
  final out = <CalendarEvent>[];
  for (final m in memos) {
    final k =
        m.taskdate.length >= 10 ? m.taskdate.substring(0, 10) : m.taskdate;
    if (k.isEmpty || seen.contains(k)) continue;
    seen.add(k);
    final p = k.split('-');
    if (p.length != 3) continue;
    final y = int.tryParse(p[0]);
    final mo = int.tryParse(p[1]);
    final d = int.tryParse(p[2]);
    if (y == null || mo == null || d == null) continue;
    final day = DateTime(y, mo, d);
    out.add(CalendarEvent(
      startDate: day,
      endDate: day,
      id: 'worker_memo_$k',
      title: '',
      color: dotColor,
    ));
  }
  out.sort((a, b) => a.startDate.compareTo(b.startDate));
  return out;
}

List<CalendarEvent> _statusHighlightDots({
  required WorkerDashboardSummary? monthSummary,
  required _PayHighlightMode mode,
  required Color color,
}) {
  if (monthSummary == null || mode == _PayHighlightMode.total) {
    return const [];
  }
  final keySet = <String>{};
  final out = <CalendarEvent>[];
  for (final row in monthSummary.workDays) {
    final match = switch (mode) {
      _PayHighlightMode.paid => row.paidComplete,
      _PayHighlightMode.unpaid => !row.paidComplete,
      _PayHighlightMode.total => false,
    };
    if (!match) continue;
    final k = row.dateKey;
    if (k.isEmpty || keySet.contains(k)) continue;
    keySet.add(k);
    final p = k.split('-');
    if (p.length != 3) continue;
    final y = int.tryParse(p[0]);
    final mo = int.tryParse(p[1]);
    final d = int.tryParse(p[2]);
    if (y == null || mo == null || d == null) continue;
    final day = DateTime(y, mo, d);
    out.add(
      CalendarEvent(
        startDate: day,
        endDate: day,
        id: 'worker_pay_${mode.name}_$k',
        title: '',
        color: color,
      ),
    );
  }
  out.sort((a, b) => a.startDate.compareTo(b.startDate));
  return out;
}

PlaceInfoModel _stubPlaceInfo({
  required int pid,
  required String pname,
  String paddress = '',
}) {
  return PlaceInfoModel(
    pid: pid,
    pname: pname.trim().isEmpty ? '현장 #$pid' : pname.trim(),
    pcomplete: 0,
    pstart: '',
    pend: '',
    paddress: paddress,
    pfirstrevenue: 0,
    pcontractTotal: 0,
    workerCount: 0,
    totalAdditionalRevenue: 0,
    mTotal: 0,
    woodTotal: 0,
    metalTotal: 0,
    electricTotal: 0,
    lightingTotal: 0,
    cleaningTotal: 0,
    filmTotal: 0,
    landscapeTotal: 0,
    hardwareTotal: 0,
    paintTotal: 0,
    facilityTotal: 0,
    tileTotal: 0,
    glassTotal: 0,
    fuelTotal: 0,
    accommodationTotal: 0,
    foodTotal: 0,
    personalExpensesTotal: 0,
    firefightingTotal: 0,
    signageTotal: 0,
    airConditioningTotal: 0,
    demolitionTotal: 0,
    customMadeTotal: 0,
    otherExpensesTotal: 0,
    wTotal: 0,
    wIncomplete: 0,
  );
}

List<PlaceWorkDayRead> _assignmentMemosToWorkDays(
  List<ScheduleMemoRead> memos, {
  required int workerHidFallback,
}) {
  final out = <PlaceWorkDayRead>[];
  for (final m in memos) {
    if (!m.isAssignment) continue;
    final pid = m.placePid;
    if (pid == null || pid <= 0) continue;
    final hid = workerHidFallback > 0 ? workerHidFallback : 0;
    out.add(
      PlaceWorkDayRead(
        pwdid: (m.pwdid != null && m.pwdid! > 0) ? m.pwdid! : m.sid,
        pid: pid,
        hid: hid,
        workdate: m.taskdate,
        dailywage: 0,
        paid: 0,
        workrole: m.workrole,
        instructionBlocks: resolveAssignmentInstructionBlocks(
          instructionBlocks: m.instructionBlocks,
          memoFallback: m.memo,
        ),
      ),
    );
  }
  return out;
}

/// 작업자 전용「내 작업 일정」— `ScrollableCalendar` + 선택일 목록, 등록은 관리자 일정·메모 시트와 동일.
class WorkerScheduleScreen extends ConsumerStatefulWidget {
  const WorkerScheduleScreen({super.key});

  @override
  ConsumerState<WorkerScheduleScreen> createState() =>
      _WorkerScheduleScreenState();
}

enum _PayHighlightMode { total, paid, unpaid }

class _WorkerScheduleScreenState extends ConsumerState<WorkerScheduleScreen> {
  late DateTime _focusedDay;
  late DateTime _calendarPageMonth;
  var _calendarMode = CalendarViewMode.month;
  TaxState _earningsTaxState = TaxState.taxOn;
  _PayHighlightMode _payHighlightMode = _PayHighlightMode.total;
  final Map<String, WorkerDashboardSummary> _monthlyEarningsCache = {};
  bool _earningsLoading = false;
  String? _earningsError;
  int _earningsRequestToken = 0;

  @override
  void initState() {
    super.initState();
    _focusedDay = scheduleDateOnly(DateTime.now());
    _calendarPageMonth = DateTime(_focusedDay.year, _focusedDay.month, 1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_primeScheduleAlarms());
      unawaited(ref.read(placeListProvider.notifier).initialize());
      unawaited(_ensureMonthlyEarnings(_calendarPageMonth));
    });
  }

  Future<void> _primeScheduleAlarms() async {
    await AlarmPermissionHelper.ensurePermissions();
    if (!mounted) return;
    _applyPeekFcmScheduleDate();
    final notifier = ref.read(workerScheduleNotifierProvider.notifier);
    if (fcmPeekPendingScheduleLink() != null) {
      await notifier.reload();
      return;
    }
    final cur = ref.read(workerScheduleNotifierProvider).asData?.value;
    if (cur != null) {
      await syncScheduleMemoLocalAlarmsFromReads(cur);
    } else {
      await notifier.reload();
    }
  }

  void _applyPeekFcmScheduleDate() {
    final link = fcmPeekPendingScheduleLink();
    if (link == null) return;
    final parsed = DateTime.tryParse(link.workdate);
    if (parsed == null) return;
    setState(() => _focusedDay = scheduleDateOnly(parsed));
  }

  String _monthKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

  String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _ensureMonthlyEarnings(
    DateTime day, {
    bool force = false,
  }) async {
    final monthDate = DateTime(day.year, day.month, 1);
    final key = _monthKey(monthDate);
    if (!force && _monthlyEarningsCache.containsKey(key)) return;

    final token = ++_earningsRequestToken;
    setState(() {
      _earningsLoading = true;
      if (force) _earningsError = null;
    });
    try {
      final api = ref.read(workerDashboardRemoteApiProvider);
      final summary = await api.fetchSummary(
        year: monthDate.year,
        month: monthDate.month,
      );
      if (!mounted || token != _earningsRequestToken) return;
      setState(() {
        _monthlyEarningsCache[key] = summary;
        _earningsError = null;
      });
    } catch (e) {
      if (!mounted || token != _earningsRequestToken) return;
      setState(() => _earningsError = e.toString());
    } finally {
      if (!mounted || token != _earningsRequestToken) return;
      setState(() => _earningsLoading = false);
    }
  }

  void _setFocusedDay(DateTime day) {
    final normalized = scheduleDateOnly(day);
    final monthChanged = normalized.year != _focusedDay.year ||
        normalized.month != _focusedDay.month;
    setState(() => _focusedDay = normalized);
    if (monthChanged) {
      _calendarPageMonth = DateTime(normalized.year, normalized.month, 1);
      unawaited(_ensureMonthlyEarnings(normalized));
    }
  }

  void _setCalendarPageMonth(DateTime monthFirst) {
    final next = DateTime(monthFirst.year, monthFirst.month, 1);
    final changed = next.year != _calendarPageMonth.year ||
        next.month != _calendarPageMonth.month;
    if (!changed) return;
    setState(() => _calendarPageMonth = next);
    unawaited(_ensureMonthlyEarnings(next));
  }

  ({int earned, int paid, int outstanding}) _totalsFromWorkDays(
    Iterable<WorkerDashboardWorkDay> days,
  ) {
    final t = workerDashboardTotalsFromWorkDays(days);
    return (
      earned: t.totalEarned,
      paid: t.totalPaid,
      outstanding: t.totalOutstanding,
    );
  }

  ({int earned, int paid, int outstanding}) _monthTotals(
    WorkerDashboardSummary summary,
  ) {
    final mt = summary.monthTotals;
    if (mt != null) {
      return (
        earned: mt.totalEarned,
        paid: mt.totalPaid,
        outstanding: mt.totalOutstanding,
      );
    }
    return _totalsFromWorkDays(summary.workDays);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(workerScheduleNotifierProvider, (prev, next) {
      next.whenData((memos) {
        final link = fcmPeekPendingScheduleLink();
        if (link == null) return;
        if (link.pwdid <= 0) {
          fcmClearPendingScheduleLink();
          return;
        }
        for (final m in memos) {
          if (m.pwdid != null && m.pwdid == link.pwdid) {
            fcmClearPendingScheduleLink();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!context.mounted) return;
              final me = ref.read(authSessionProvider).asData?.value;
              final workerHid = me?.workerHid;
              final pid = m.placePid;
              if (me?.isWorker == true &&
                  workerHid != null &&
                  workerHid > 0 &&
                  pid != null &&
                  pid > 0) {
                final rows = _assignmentMemosToWorkDays(
                  memos,
                  workerHidFallback: workerHid,
                );
                var address = '';
                for (final p in ref.read(placeListProvider).placeList) {
                  if (p.pid == pid) {
                    address = p.paddress.trim();
                    break;
                  }
                }
                final parsedDay = DateTime.tryParse(m.taskdate);
                final day = parsedDay == null
                    ? scheduleDateOnly(DateTime.now())
                    : scheduleDateOnly(parsedDay);
                showPlaceWorkerInstructionDaySheet(
                  context: context,
                  place: _stubPlaceInfo(
                    pid: pid,
                    pname: m.title,
                    paddress: address,
                  ),
                  day: day,
                  allRows: rows,
                  workerHid: workerHid,
                );
              } else {
                showAssignmentInstructionDetailSheet(context, m);
              }
            });
            return;
          }
        }
      });
    });

    final asyncMemos = ref.watch(workerScheduleNotifierProvider);
    final cs = Theme.of(context).colorScheme;
    final me = ref.watch(authSessionProvider).asData?.value;
    final workerHid = me?.workerHid ?? 0;
    final placeState = ref.watch(placeListProvider);
    final placeAddressByPid = <int, String>{
      for (final p in placeState.placeList)
        if ((p.pid ?? 0) > 0) p.pid!: p.paddress.trim(),
    };

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('내 일정'),
      ),
      body: AppRefreshIndicator(
        enabled: !(asyncMemos.isLoading && !asyncMemos.hasValue),
        onRefresh: () async {
          await ref.read(workerScheduleNotifierProvider.notifier).reload();
          await _ensureMonthlyEarnings(_calendarPageMonth, force: true);
        },
        child: asyncMemos.when(
          skipLoadingOnReload: true,
          skipLoadingOnRefresh: true,
          loading: () => Skeletonizer(
            enabled: true,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: ResponsiveLayout.only(context, bottom: 32),
              children: [
                rsV(context, 8),
                Padding(
                  padding: ResponsiveLayout.symmetric(context, horizontal: 12),
                  child: ScrollableCalendarWidget(
                    key: const ValueKey('worker_schedule_skeleton_cal'),
                    adaptiveHeightForWeekModes: false,
                    height: _workerCalendarHeight(
                      context,
                      _calendarMode,
                      _calendarPageMonth,
                    ),
                    useSingleDaySelection: true,
                    initialSelectedDay: _focusedDay,
                    initialEvents: const [],
                    showViewModeToggle: true,
                    onViewModeChanged: (m) => setState(() => _calendarMode = m),
                    onDayPicked: _setFocusedDay,
                    onMonthChanged: _setCalendarPageMonth,
                  ),
                ),
                rsV(context, 16),
                _WorkerMonthlyTotalCompactBar(
                  focusedDay: _calendarPageMonth,
                  taxState: _earningsTaxState,
                  monthTotals: null,
                  highlightMode: _payHighlightMode,
                  isLoading: true,
                  errorMessage: null,
                  onTaxStateChanged: (next) =>
                      setState(() => _earningsTaxState = next),
                  onOpenYearly: () => context.push('/settings/earnings'),
                  onHighlightPaid: () {
                    setState(() {
                      _payHighlightMode = _PayHighlightMode.paid;
                    });
                  },
                  onHighlightUnpaid: () {
                    setState(() {
                      _payHighlightMode = _PayHighlightMode.unpaid;
                    });
                  },
                  onHighlightTotal: () {
                    setState(() {
                      _payHighlightMode = _PayHighlightMode.total;
                    });
                  },
                  onRetry: () =>
                      _ensureMonthlyEarnings(_calendarPageMonth, force: true),
                ),
                rsV(context, 14),
                _WorkerDayScheduleSection(
                  day: _focusedDay,
                  child: Column(
                    children: [
                      _memoCard(
                        context,
                        _workerScheduleScreenSkeletonMemo(assignment: true),
                        allAssignmentRows: const [],
                        workerHid: null,
                        assignmentAddress: '',
                        wageInfo: null,
                        isTaxApply: _earningsTaxState == TaxState.taxOn,
                      ),
                      _memoCard(
                        context,
                        _workerScheduleScreenSkeletonMemo(assignment: false),
                        allAssignmentRows: const [],
                        workerHid: null,
                        assignmentAddress: '',
                        wageInfo: null,
                        isTaxApply: _earningsTaxState == TaxState.taxOn,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          error: (e, _) => ListView(
            children: [
              rsV(context, 80),
              Padding(
                padding: ResponsiveLayout.symmetric(context, horizontal: 24),
                child: Text('$e', textAlign: TextAlign.center),
              ),
            ],
          ),
          data: (memos) {
            final key = _ymd(_focusedDay);
            final dayMemos = memos.where((m) {
              final d = m.taskdate.length >= 10
                  ? m.taskdate.substring(0, 10)
                  : m.taskdate;
              return d == key;
            }).toList()
              ..sort((a, b) {
                /// 관리자가 현장 등에서 배정한 일정은 항상 목록 최상단.
                if (a.isAssignment != b.isAssignment) {
                  return a.isAssignment ? -1 : 1;
                }
                return a.sortorder.compareTo(b.sortorder);
              });

            final assignmentRowsForSheets = _assignmentMemosToWorkDays(
              memos,
              workerHidFallback: workerHid,
            );
            final monthSummary =
                _monthlyEarningsCache[_monthKey(_calendarPageMonth)];
            final monthTotals =
                monthSummary == null ? null : _monthTotals(monthSummary);
            final statusDots = _statusHighlightDots(
              monthSummary: monthSummary,
              mode: _payHighlightMode,
              color: _payHighlightMode == _PayHighlightMode.unpaid
                  ? cs.error
                  : _paidGreen,
            );
            final dotEvents = [
              ..._memoCalendarDots(memos, cs.primary),
              ...statusDots,
            ];
            final calKeyBase =
                memos.fold<int>(17, (a, m) => 37 * a + m.sid + m.createdatms);
            // 월 전환 시 키까지 바꾸면 캘린더가 리마운트되어 슬라이드/화살표 전환이 끊긴다.
            final calKey = '$calKeyBase-${_payHighlightMode.name}';
            final workDayByPwdid = <int, WorkerDashboardWorkDay>{};
            for (final wd
                in monthSummary?.workDays ?? const <WorkerDashboardWorkDay>[]) {
              if (wd.pwdid <= 0) continue;
              workDayByPwdid.putIfAbsent(wd.pwdid, () => wd);
            }

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: ResponsiveLayout.only(context, bottom: 32),
              children: [
                Padding(
                  padding: ResponsiveLayout.symmetric(context, horizontal: 12),
                  child: ScrollableCalendarWidget(
                    key: ValueKey('worker_schedule_cal_$calKey'),
                    adaptiveHeightForWeekModes: false,
                    height: _workerCalendarHeight(
                      context,
                      _calendarMode,
                      _calendarPageMonth,
                    ),
                    useSingleDaySelection: true,
                    initialSelectedDay: _focusedDay,
                    initialEvents: dotEvents,
                    showViewModeToggle: true,
                    onViewModeChanged: (m) => setState(() => _calendarMode = m),
                    onDayPicked: _setFocusedDay,
                    onMonthChanged: _setCalendarPageMonth,
                  ),
                ),
                rsV(context, 16),
                _WorkerMonthlyTotalCompactBar(
                  focusedDay: _calendarPageMonth,
                  taxState: _earningsTaxState,
                  monthTotals: monthTotals,
                  highlightMode: _payHighlightMode,
                  isLoading: _earningsLoading,
                  errorMessage: _earningsError,
                  onTaxStateChanged: (next) =>
                      setState(() => _earningsTaxState = next),
                  onOpenYearly: () => context.push('/settings/earnings'),
                  onHighlightPaid: () {
                    setState(() {
                      _payHighlightMode = _PayHighlightMode.paid;
                    });
                  },
                  onHighlightUnpaid: () {
                    setState(() {
                      _payHighlightMode = _PayHighlightMode.unpaid;
                    });
                  },
                  onHighlightTotal: () {
                    setState(() {
                      _payHighlightMode = _PayHighlightMode.total;
                    });
                  },
                  onRetry: () =>
                      _ensureMonthlyEarnings(_calendarPageMonth, force: true),
                ),
                rsV(context, 14),
                _WorkerDayScheduleSection(
                  day: _focusedDay,
                  child: dayMemos.isEmpty
                      ? Padding(
                          padding: ResponsiveLayout.all(context, 20),
                          child: Text(
                            '이 날짜에 일정이 없습니다.\n우측 하단 + 버튼으로 일정을 추가할 수 있어요.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: cs.onSurfaceVariant,
                              height: 1.45,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        )
                      : Column(
                          children: dayMemos
                              .map(
                                (m) => _memoCard(
                                  context,
                                  m,
                                  allAssignmentRows: assignmentRowsForSheets,
                                  workerHid: workerHid > 0 ? workerHid : null,
                                  assignmentAddress:
                                      placeAddressByPid[m.placePid ?? -1] ?? '',
                                  wageInfo: m.pwdid == null
                                      ? null
                                      : workDayByPwdid[m.pwdid!],
                                  isTaxApply:
                                      _earningsTaxState == TaxState.taxOn,
                                ),
                              )
                              .toList(),
                        ),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => openWorkerScheduleMemoEditor(
          context,
          ref,
          existing: null,
          initialDateOverride: _focusedDay,
        ),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _memoCard(
    BuildContext context,
    ScheduleMemoRead m, {
    required List<PlaceWorkDayRead> allAssignmentRows,
    required int? workerHid,
    required String assignmentAddress,
    required WorkerDashboardWorkDay? wageInfo,
    required bool isTaxApply,
  }) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(18);

    if (m.isAssignment) {
      final pid = m.placePid;
      final canOpenPlaceSheet =
          pid != null && pid > 0 && workerHid != null && workerHid > 0;

      return Padding(
        padding: ResponsiveLayout.only(context, left: 8, right: 8, bottom: 10),
        child: DecoratedBox(
          decoration: AppElevation.insetTile(
            context: context,
            backgroundColor: cs.surface,
            borderRadius: radius,
          ),
          child: InkWell(
            onTap: () {
              if (canOpenPlaceSheet) {
                final parsed = DateTime.tryParse(m.taskdate);
                final day = parsed == null
                    ? scheduleDateOnly(DateTime.now())
                    : scheduleDateOnly(parsed);
                showPlaceWorkerInstructionDaySheet(
                  context: context,
                  place: _stubPlaceInfo(
                    pid: pid,
                    pname: m.title,
                    paddress: assignmentAddress,
                  ),
                  day: day,
                  allRows: allAssignmentRows,
                  workerHid: workerHid,
                );
                return;
              }
              showAssignmentInstructionDetailSheet(context, m);
            },
            child: Padding(
              padding: ResponsiveLayout.only(context,
                  left: 14, top: 12, right: 8, bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: ResponsiveLayout.only(context, top: 2),
                    child: Icon(
                      Icons.work_outline_rounded,
                      color: cs.primary,
                      size: context.rsi(22),
                    ),
                  ),
                  rsH(context, 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    m.title.trim().isEmpty
                                        ? '현장 배정'
                                        : m.title.trim(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: tt.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w900,
                                      height: 1.25,
                                    ),
                                  ),
                                  if (m.workrole.trim().isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      '역할 [${m.workrole.trim()}]',
                                      style: tt.labelLarge?.copyWith(
                                        color: cs.onSurfaceVariant,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (m.tasktime.trim().isNotEmpty ||
                                wageInfo != null)
                              Padding(
                                padding:
                                    ResponsiveLayout.only(context, left: 8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    if (m.tasktime.trim().isNotEmpty)
                                      Text(
                                        m.tasktime.trim(),
                                        textAlign: TextAlign.right,
                                        style: tt.titleMedium?.copyWith(
                                          fontWeight: FontWeight.w900,
                                          color: cs.primary,
                                          height: 1.0,
                                        ),
                                      ),
                                    if (wageInfo != null) ...[
                                      SizedBox(height: context.rsi(6)),
                                      _statusPill(
                                        context: context,
                                        isPaid: wageInfo.paidComplete,
                                      ),
                                      SizedBox(height: context.rsi(4)),
                                      Text(
                                        '일당 ${getPrice(price: wageInfo.displayDailyRate, isTaxApply: isTaxApply, isContainWon: false)}',
                                        style: tt.labelMedium?.copyWith(
                                          color: cs.onSurfaceVariant,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                          ],
                        ),
                        if (assignmentAddress.trim().isNotEmpty) ...[
                          SizedBox(height: context.rsi(10)),
                          Container(
                            padding: EdgeInsets.fromLTRB(
                              context.rsi(10),
                              context.rsi(9),
                              context.rsi(10),
                              context.rsi(9),
                            ),
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerLowest,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: cs.outlineVariant),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.location_on_outlined,
                                      size: context.rsi(16),
                                      color: cs.primary,
                                    ),
                                    SizedBox(width: context.rsi(6)),
                                    Expanded(
                                      child: Text(
                                        assignmentAddress.trim(),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: tt.bodySmall?.copyWith(
                                          color: cs.onSurface,
                                          fontWeight: FontWeight.w700,
                                          height: 1.3,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: context.rsi(8)),
                                MapRouteActionButtons(
                                  compact: true,
                                  onCopyAddress: () async {
                                    await Clipboard.setData(
                                      ClipboardData(
                                        text: assignmentAddress.trim(),
                                      ),
                                    );
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('현장 주소를 복사했습니다.'),
                                      ),
                                    );
                                  },
                                  onKakao: () async {
                                    final query = navigablePlaceAddress(
                                      assignmentAddress,
                                    );
                                    if (query.isEmpty) return;
                                    final kakaoLocal =
                                        ref.read(kakaoLocalMapApiProvider);
                                    final resolved =
                                        await kakaoLocal.resolveBestMatch(
                                      address: query,
                                    );
                                    if (resolved != null) {
                                      await MapNavigationLauncher
                                          .openKakaoNaviRoute(
                                        destinationName: query,
                                        latitude: resolved.latitude,
                                        longitude: resolved.longitude,
                                      );
                                      return;
                                    }
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          '경로 좌표를 찾지 못해 카카오내비 안내를 시작할 수 없습니다.',
                                        ),
                                      ),
                                    );
                                  },
                                  onTmap: () async {
                                    final query = navigablePlaceAddress(
                                      assignmentAddress,
                                    );
                                    if (query.isEmpty) return;
                                    await MapNavigationLauncher.openTmapSearch(
                                      query,
                                    );
                                  },
                                ),
                                SizedBox(height: context.rsi(4)),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: cs.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final model = scheduleMemoReadToModel(m);
    return Padding(
      padding: ResponsiveLayout.only(context, left: 8, right: 8, bottom: 10),
      child: ScheduleMemoListTile(
        memo: model,
        showDayHeading: false,
        onDoneChanged: (v) async {
          await ref.read(workerScheduleNotifierProvider.notifier).updateMemo(
                m,
                done: v ?? false,
              );
        },
        onEdit: () => openWorkerScheduleMemoEditor(
          context,
          ref,
          existing: m,
        ),
        onDelete: () async {
          await ref
              .read(workerScheduleNotifierProvider.notifier)
              .deleteMemo(m.sid);
        },
      ),
    );
  }

  Widget _statusPill({
    required BuildContext context,
    required bool isPaid,
  }) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final bg = isPaid
        ? cs.primaryContainer.withValues(alpha: 0.6)
        : cs.errorContainer.withValues(alpha: 0.55);
    final fg = isPaid ? cs.onPrimaryContainer : cs.error;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isPaid ? cs.primary.withValues(alpha: 0.35) : cs.error,
          width: 0.9,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: context.rsi(9),
          vertical: context.rsi(5),
        ),
        child: Text(
          isPaid ? '지급완료' : '미지급',
          style: tt.labelSmall?.copyWith(
            fontWeight: FontWeight.w900,
            color: fg,
          ),
        ),
      ),
    );
  }
}

class _WorkerMonthlyTotalCompactBar extends StatelessWidget {
  const _WorkerMonthlyTotalCompactBar({
    required this.focusedDay,
    required this.taxState,
    required this.monthTotals,
    required this.highlightMode,
    required this.isLoading,
    required this.errorMessage,
    required this.onTaxStateChanged,
    required this.onOpenYearly,
    required this.onHighlightTotal,
    required this.onHighlightPaid,
    required this.onHighlightUnpaid,
    required this.onRetry,
  });

  final DateTime focusedDay;
  final TaxState taxState;
  final ({int earned, int paid, int outstanding})? monthTotals;
  final _PayHighlightMode highlightMode;
  final bool isLoading;
  final String? errorMessage;
  final ValueChanged<TaxState> onTaxStateChanged;
  final VoidCallback onOpenYearly;
  final VoidCallback onHighlightTotal;
  final VoidCallback onHighlightPaid;
  final VoidCallback onHighlightUnpaid;
  final VoidCallback onRetry;

  bool get _isTaxApply => taxState == TaxState.taxOn;

  String _currency(int amount) =>
      getPrice(price: amount, isTaxApply: _isTaxApply, isContainWon: false);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final titleMonth = '${focusedDay.year}년 ${focusedDay.month}월';
    final selectedLabel = switch (highlightMode) {
      _PayHighlightMode.total => '토탈',
      _PayHighlightMode.paid => '지급',
      _PayHighlightMode.unpaid => '미지급',
    };
    final selectedAmount = monthTotals == null
        ? 0
        : switch (highlightMode) {
            _PayHighlightMode.total => monthTotals!.earned,
            _PayHighlightMode.paid => monthTotals!.paid,
            _PayHighlightMode.unpaid => monthTotals!.outstanding,
          };
    final selectedColor = switch (highlightMode) {
      _PayHighlightMode.total => cs.onSurface,
      _PayHighlightMode.paid => _paidGreen,
      _PayHighlightMode.unpaid => cs.error,
    };

    return Padding(
      padding: ResponsiveLayout.symmetric(context, horizontal: 12),
      child: DecoratedBox(
        decoration: AppElevation.insetTile(
          context: context,
          backgroundColor: cs.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: ResponsiveLayout.only(
            context,
            left: 10,
            top: 8,
            right: 10,
            bottom: 8,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$titleMonth 합계',
                      style: tt.labelLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: context.rsi(4)),
                    if (monthTotals == null)
                      Text(
                        isLoading
                            ? '월 합계 불러오는 중...'
                            : (errorMessage != null
                                ? '월 합계 조회 실패'
                                : '집계 내역 없음'),
                        style: tt.labelSmall?.copyWith(
                          color: errorMessage != null
                              ? cs.error
                              : cs.onSurfaceVariant,
                        ),
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$selectedLabel ${_currency(selectedAmount)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tt.titleSmall?.copyWith(
                              color: selectedColor,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.only(top: context.rsi(4)),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _filterChip(
                                    context: context,
                                    label: '토탈',
                                    selected: highlightMode ==
                                        _PayHighlightMode.total,
                                    activeBg: cs.primaryContainer,
                                    activeFg: cs.onPrimaryContainer,
                                    onPressed: onHighlightTotal,
                                  ),
                                ),
                                SizedBox(width: context.rsi(6)),
                                Expanded(
                                  child: _filterChip(
                                    context: context,
                                    label: '지급',
                                    selected:
                                        highlightMode == _PayHighlightMode.paid,
                                    activeBg: cs.primaryContainer,
                                    activeFg: _paidGreen,
                                    onPressed: onHighlightPaid,
                                  ),
                                ),
                                SizedBox(width: context.rsi(6)),
                                Expanded(
                                  child: _filterChip(
                                    context: context,
                                    label: '미지급',
                                    selected: highlightMode ==
                                        _PayHighlightMode.unpaid,
                                    activeBg: cs.errorContainer,
                                    activeFg: cs.onErrorContainer,
                                    onPressed: onHighlightUnpaid,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              rsH(context, 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _taxSegment(context, taxState, onTaxStateChanged),
                  SizedBox(height: context.rsi(6)),
                  InkWell(
                    onTap: onOpenYearly,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: context.rsi(4),
                        vertical: context.rsi(2),
                      ),
                      child: Text(
                        '연도별 보기',
                        style: tt.labelMedium?.copyWith(
                          color: cs.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (errorMessage != null) ...[
                rsH(context, 6),
                IconButton(
                  onPressed: onRetry,
                  visualDensity: VisualDensity.compact,
                  iconSize: context.rsi(18),
                  tooltip: '월 합계 다시 시도',
                  icon: Icon(Icons.refresh_rounded, color: cs.error),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _filterChip({
    required BuildContext context,
    required String label,
    required bool selected,
    required Color activeBg,
    required Color activeFg,
    required VoidCallback onPressed,
  }) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Material(
      color: selected ? activeBg.withValues(alpha: 0.95) : cs.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(
            horizontal: context.rsi(9),
            vertical: context.rsi(5),
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? activeBg : cs.outlineVariant,
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              style: tt.labelMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: selected ? activeFg : cs.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _taxSegment(
    BuildContext context,
    TaxState taxState,
    ValueChanged<TaxState> onChanged,
  ) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isTaxOn = taxState == TaxState.taxOn;
    return CupertinoSlidingSegmentedControl<TaxState>(
      groupValue: taxState,
      thumbColor: isTaxOn
          ? cs.errorContainer.withValues(alpha: 0.72)
          : cs.primaryContainer.withValues(alpha: 0.72),
      backgroundColor: cs.surfaceContainerHigh,
      children: {
        TaxState.taxOff: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.rsi(10),
            vertical: context.rsi(5),
          ),
          child: Text(
            '세전',
            style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        TaxState.taxOn: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.rsi(10),
            vertical: context.rsi(5),
          ),
          child: Text(
            '세후',
            style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
      },
      onValueChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

/// 캘린더 아래 — 선택일 일정을 대시보드 섹션과 동일한 카드 스타일로 보여준다.
class _WorkerDayScheduleSection extends StatelessWidget {
  const _WorkerDayScheduleSection({
    required this.day,
    required this.child,
  });

  final DateTime day;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: ResponsiveLayout.symmetric(context, horizontal: 12),
      child: WorkerDashboardSectionShell(
        icon: Icons.event_note_outlined,
        title: '선택한 날 일정 / 수당',
        subtitle: _dayTitleLine(day),
        child: child,
      ),
    );
  }
}

import 'dart:async' show unawaited;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollable_calendar_package/calendar.dart';
import 'package:w0001/access/user_role_access.dart';
import 'package:w0001/data/model/place_info_model.dart';
import 'package:w0001/data/model/remote/super_admin_dtos.dart';
import 'package:w0001/data/mappers/remote_mappers.dart';
import 'package:w0001/presentation/viewmodel/dashboard_schedule_view_model.dart';
import 'package:w0001/presentation/viewmodel/auth_providers.dart';
import 'package:w0001/presentation/viewmodel/worker_schedule_notifier.dart';
import 'package:w0001/ui/screen/3_calendar/worker_schedule_memo_editor.dart';
import 'package:w0001/ui/screen/1_dashboard/widgets/assignment_instruction_detail_sheet.dart';
import 'package:w0001/ui/screen/5_place/widgets/place_worker_instruction_week_peek.dart';
import 'package:w0001/ui/widget/scrollable_calendar/scrollable_calendar_widget.dart';
import 'package:w0001/ui/widget/schedule_memo/schedule_memo_list_tile.dart';
import 'package:w0001/util/alarm_permission_helper.dart';
import 'package:w0001/util/fcm/fcm_pending_schedule_link.dart';
import 'package:w0001/util/schedule_memo_alarm_sync.dart';
import 'package:w0001/util/work_instruction_blocks_resolve.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:w0001/util/responsive_layout.dart';

const _weekdayKo = ['월', '화', '수', '목', '금', '토', '일'];

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
) {
  // ScrollableCalendar 패키지 기본 레이아웃 근사치.
  final containerVMargin = context.rs(8);
  final containerVPadding = context.rs(16);
  final gapHeaderToGrid = context.rs(12);
  final horizontalPaddingTotal = context.rs(10);

  final headerAndWeekTitleApprox = context.rs(148);
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

  // 월별은 6줄 기준(달력은 종종 6주 표시).
  const rows = 6;
  final gridH = rows * cellH + (rows - 1) * mainAxisSpacing;
  return containerVMargin +
      containerVPadding +
      headerAndWeekTitleApprox +
      gapHeaderToGrid +
      gridH;
}

/// 뷰 모드 칩·주·월 그리드가 잘리지 않도록 기기별로 높이를 잡습니다.
double _workerCalendarHeight(BuildContext context, CalendarViewMode mode) {
  final size = MediaQuery.sizeOf(context);
  final portrait = size.height >= size.width;
  final w = size.width;

  // 1주/2주: 기존처럼 넉넉하게(하지만 패키지에서 adaptiveHeightForWeekModes로 줄어듦)
  if (portrait) {
    if (mode == CalendarViewMode.month) {
      final est = _estimateWorkerMonthCalendarHeight(context, w);
      final hi = (size.height * 0.40).clamp(context.rs(360), context.rs(520));
      return est.clamp(context.rs(340), hi).toDouble();
    }
    return (size.height * 0.44).clamp(context.rs(408), context.rs(640));
  }
  if (mode == CalendarViewMode.month) {
    final est = _estimateWorkerMonthCalendarHeight(context, w);
    final hi = (size.height * 0.66).clamp(context.rs(320), context.rs(520));
    return est.clamp(context.rs(300), hi).toDouble();
  }
  return (size.height * 0.74).clamp(context.rs(304), context.rs(480));
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

PlaceInfoModel _stubPlaceInfo({required int pid, required String pname}) {
  return PlaceInfoModel(
    pid: pid,
    pname: pname.trim().isEmpty ? '현장 #$pid' : pname.trim(),
    pcomplete: 0,
    pstart: '',
    pend: '',
    paddress: '',
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

class _WorkerScheduleScreenState extends ConsumerState<WorkerScheduleScreen> {
  late DateTime _focusedDay;
  var _calendarMode = CalendarViewMode.month;

  @override
  void initState() {
    super.initState();
    _focusedDay = scheduleDateOnly(DateTime.now());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_primeScheduleAlarms());
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

  String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

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
                final parsedDay = DateTime.tryParse(m.taskdate);
                final day = parsedDay == null
                    ? scheduleDateOnly(DateTime.now())
                    : scheduleDateOnly(parsedDay);
                showPlaceWorkerInstructionDaySheet(
                  context: context,
                  place: _stubPlaceInfo(pid: pid, pname: m.title),
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('내 작업 일정'),
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(workerScheduleNotifierProvider.notifier).reload(),
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
                      padding: ResponsiveLayout.only(context, left: 8, top: 8, right: 8, bottom: 4),
                      child: ScrollableCalendarWidget(
                        key: const ValueKey('worker_schedule_skeleton_cal'),
                        adaptiveHeightForWeekModes: true,
                        height: _workerCalendarHeight(context, _calendarMode),
                        useSingleDaySelection: true,
                        initialSelectedDay: _focusedDay,
                        initialEvents: const [],
                        showViewModeToggle: true,
                        onViewModeChanged: (m) =>
                            setState(() => _calendarMode = m),
                        onDayPicked: (day) {
                          setState(
                            () => _focusedDay = scheduleDateOnly(day),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: ResponsiveLayout.only(context, left: 16, top: 16, right: 16, bottom: 8),
                      child: Text(
                        _dayTitleLine(_focusedDay),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                    _memoCard(
                      context,
                      _workerScheduleScreenSkeletonMemo(assignment: true),
                      allAssignmentRows: const [],
                      workerHid: null,
                    ),
                    _memoCard(
                      context,
                      _workerScheduleScreenSkeletonMemo(assignment: false),
                      allAssignmentRows: const [],
                      workerHid: null,
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

            final dotEvents = _memoCalendarDots(memos, cs.primary);
            final calKey =
                memos.fold<int>(17, (a, m) => 37 * a + m.sid + m.createdatms);
            final assignmentRowsForSheets = _assignmentMemosToWorkDays(
              memos,
              workerHidFallback: workerHid,
            );

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: ResponsiveLayout.only(context, bottom: 32),
              children: [
                Padding(
                  padding: ResponsiveLayout.only(context, left: 8, top: 8, right: 8, bottom: 4),
                  child: ScrollableCalendarWidget(
                    key: ValueKey('worker_schedule_cal_$calKey'),
                    adaptiveHeightForWeekModes: true,
                    height: _workerCalendarHeight(context, _calendarMode),
                    useSingleDaySelection: true,
                    initialSelectedDay: _focusedDay,
                    initialEvents: dotEvents,
                    showViewModeToggle: true,
                    onViewModeChanged: (m) =>
                        setState(() => _calendarMode = m),
                    onDayPicked: (d) {
                      setState(() => _focusedDay = scheduleDateOnly(d));
                    },
                  ),
                ),
                Padding(
                  padding: ResponsiveLayout.only(context, left: 16, top: 16, right: 16, bottom: 8),
                  child: Text(
                    _dayTitleLine(_focusedDay),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface,
                    ),
                  ),
                ),
                if (dayMemos.isEmpty)
                  Padding(
                    padding: ResponsiveLayout.all(context, 24),
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
                else
                  ...dayMemos.map(
                    (m) => _memoCard(
                      context,
                      m,
                      allAssignmentRows: assignmentRowsForSheets,
                      workerHid: workerHid > 0 ? workerHid : null,
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
  }) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(18);

    if (m.isAssignment) {
      final pid = m.placePid;
      final canOpenPlaceSheet =
          pid != null && pid > 0 && workerHid != null && workerHid > 0;
      
      return Padding(
        padding: ResponsiveLayout.only(context, left: 16, right: 16, bottom: 10),
        child: Material(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.42),
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              if (canOpenPlaceSheet) {
                final parsed = DateTime.tryParse(m.taskdate);
                final day = parsed == null
                    ? scheduleDateOnly(DateTime.now())
                    : scheduleDateOnly(parsed);
                showPlaceWorkerInstructionDaySheet(
                  context: context,
                  place: _stubPlaceInfo(pid: pid, pname: m.title),
                  day: day,
                  allRows: allAssignmentRows,
                  workerHid: workerHid,
                );
                return;
              }
              showAssignmentInstructionDetailSheet(context, m);
            },
            child: Padding(
              padding: ResponsiveLayout.only(context, left: 14, top: 12, right: 8, bottom: 12),
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
                                        color: cs.tertiary,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (m.tasktime.trim().isNotEmpty) ...[
                              rsH(context, 10),
                              Text(
                                m.tasktime.trim(),
                                textAlign: TextAlign.right,
                                style: tt.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: cs.primary,
                                  height: 1.0,
                                ),
                              ),
                            ],
                          ],
                        ),
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
      padding: ResponsiveLayout.only(context, left: 16, right: 16, bottom: 10),
      child: ScheduleMemoListTile(
        memo: model,
        showDayHeading: false,
        onTap: () => openWorkerScheduleMemoEditor(
          context,
          ref,
          existing: m,
        ),
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
          await ref.read(workerScheduleNotifierProvider.notifier).deleteMemo(m.sid);
        },
      ),
    );
  }
}

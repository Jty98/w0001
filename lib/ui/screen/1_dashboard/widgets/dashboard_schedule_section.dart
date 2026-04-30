import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:dio/dio.dart';
import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/data/model/place_info_model.dart';
import 'package:w0001/data/model/schedule_memo_model.dart';
import 'package:w0001/domain/user_role_capabilities.dart';
import 'package:w0001/presentation/viewmodel/auth_providers.dart';
import 'package:w0001/presentation/viewmodel/dashboard_remote_providers.dart';
import 'package:w0001/presentation/viewmodel/dashboard_schedule_view_model.dart';
import 'package:w0001/ui/screen/1_dashboard/widgets/dashboard_schedule_editor_sheet.dart';
import 'package:share_plus/share_plus.dart';

part 'dashboard_schedule_full_screen.part.dart';

const _weekdayKo = ['월', '화', '수', '목', '금', '토', '일'];

const _saturdayBlue = Color(0xFF1565C0);
const _saturdayBlueOnAccent = Color(0xFF0D47A1);
const _sundayRed = Color(0xFFD32F2F);
const _sundayRedOnAccent = Color(0xFFB71C1C);

DateTime _parseTaskDateKey(String k) => scheduleDateFromTaskKey(k);

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

String _weekRangeLine(DateTime weekStart) {
  final end = weekStart.add(const Duration(days: 6));
  return '${weekStart.month}월 ${weekStart.day}일 - '
      '${end.month}월 ${end.day}일';
}

/// 2주 보기: 첫째 주 월요일부터 14일간을 한 줄로.
String _twoWeekSingleRangeLine(DateTime weekStartMonday) {
  final a = scheduleDateOnly(scheduleStartOfWeekMonday(weekStartMonday));
  final b = a.add(const Duration(days: 13));
  return '${a.month}월 ${a.day}일 - ${b.month}월 ${b.day}일';
}

/// 해당 월과 겹치는 주의 월요일들(월~일 주 단위, 최대 6주).
List<DateTime> _mondaysOverlappingMonth(DateTime monthFirst) {
  final y = monthFirst.year;
  final m = monthFirst.month;
  final first = DateTime(y, m, 1);
  final last = DateTime(y, m + 1, 0);
  var mon = scheduleStartOfWeekMonday(first);
  final out = <DateTime>[];
  for (var k = 0; k < 6; k++) {
    final weekEnd = mon.add(const Duration(days: 6));
    if (!weekEnd.isBefore(first) && !mon.isAfter(last)) {
      out.add(mon);
    }
    mon = mon.add(const Duration(days: 7));
    if (mon.isAfter(last.add(const Duration(days: 7)))) break;
  }
  return out;
}

/// 1990-01(0) … 2049-12(719). [전체 일정] 1달 모드 월 스와이프용.
const int _scheduleMonthPageCount = 720;

int _monthPageIndexFromDate(DateTime monthFirst) {
  final m = DateTime(monthFirst.year, monthFirst.month, 1);
  final raw = (m.year - 1990) * 12 + (m.month - 1);
  return raw.clamp(0, _scheduleMonthPageCount - 1);
}

DateTime _monthDateFromPageIndex(int page) {
  final p = page.clamp(0, _scheduleMonthPageCount - 1);
  return DateTime(1990 + p ~/ 12, p % 12 + 1, 1);
}

bool _scheduleIsSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _dayTitleLine(DateTime day) {
  final wd = _weekdayKo[day.weekday - 1];
  return '${day.year}년 ${day.month}월 ${day.day}일 ($wd)';
}

/// 주 범위 텍스트 + 7칸 요일 (한 주). [weekMonday] 기준으로 표시.
class DashboardScheduleWeekCalendarStrip extends ConsumerWidget {
  const DashboardScheduleWeekCalendarStrip({
    super.key,
    required this.weekMonday,
    this.useFullMemosForDots = false,
    this.showWeekRangeHeader = true,
    this.dense = false,
    this.onDayTap,
  });

  final DateTime weekMonday;
  final bool useFullMemosForDots;
  final bool showWeekRangeHeader;

  /// true면 패딩·글자를 줄여 2주 보기 등에서 세로 공간을 덜 씁니다.
  final bool dense;
  final ValueChanged<DateTime>? onDayTap;

  bool _dotForDay(DashboardScheduleState state, DateTime day) {
    final key = scheduleDateKey(scheduleDateOnly(day));
    if (useFullMemosForDots && state.fullMemos != null) {
      return state.fullMemos!.any((m) => m.taskDate == key);
    }
    final mon = scheduleDateOnly(scheduleStartOfWeekMonday(weekMonday));
    final weekKey = scheduleDateKey(mon);
    final cached = state.weekMemosByWeekKey[weekKey];
    if (cached != null) {
      return cached.any((m) => m.taskDate == key);
    }
    if (scheduleDateOnly(mon) == scheduleDateOnly(state.weekStart)) {
      return state.weekMemos.any((m) => m.taskDate == key);
    }
    return false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final state = ref.watch(dashboardScheduleProvider);
    final vm = ref.read(dashboardScheduleProvider.notifier);
    final today = scheduleDateOnly(DateTime.now());
    final mon = scheduleDateOnly(scheduleStartOfWeekMonday(weekMonday));

    final hdrFs = dense ? 10.0 : 12.0;
    final hdrGap = dense ? 4.0 : 6.0;
    final cellPadV = dense ? 4.0 : 8.0;
    final wkFs = dense ? 9.0 : 10.0;
    final dayFs = dense ? 13.0 : 15.0;
    final dotSz = dense ? 4.0 : 5.0;
    final gapAfterDay = dense ? 2.0 : 4.0;
    final radius = dense ? 8.0 : 10.0;
    final hzPad = dense ? 1.0 : 2.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showWeekRangeHeader) ...[
          Text(
            _weekRangeLine(mon),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: hdrFs,
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
            ),
          ),
          SizedBox(height: hdrGap),
        ],
        Row(
          children: List.generate(7, (i) {
            final day = mon.add(Duration(days: i));
            final selected = _scheduleIsSameDay(day, state.selectedDay);
            final isToday = _scheduleIsSameDay(day, today);
            final hasTask = _dotForDay(state, day);
            final isSat = day.weekday == DateTime.saturday;
            final isSun = day.weekday == DateTime.sunday;

            Color weekdayLabelColor;
            Color dayNumberColor;
            if (isSun) {
              weekdayLabelColor = _sundayRed;
              dayNumberColor = selected ? _sundayRedOnAccent : _sundayRed;
            } else if (isSat) {
              weekdayLabelColor = _saturdayBlue;
              dayNumberColor = selected ? _saturdayBlueOnAccent : _saturdayBlue;
            } else {
              weekdayLabelColor = cs.onSurfaceVariant;
              dayNumberColor = selected ? cs.onPrimaryContainer : cs.onSurface;
            }

            return Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: hzPad),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      vm.selectDay(day);
                      onDayTap?.call(day);
                    },
                    borderRadius: BorderRadius.circular(radius),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      curve: Curves.easeOut,
                      padding: EdgeInsets.symmetric(vertical: cellPadV),
                      decoration: BoxDecoration(
                        color: selected
                            ? cs.primaryContainer
                            : cs.surfaceContainerHighest.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(radius),
                        border: Border.all(
                          color: isToday
                              ? cs.primary
                              : cs.outlineVariant.withValues(alpha: 0.45),
                          width: isToday ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _weekdayKo[day.weekday - 1],
                            style: TextStyle(
                              fontSize: wkFs,
                              fontWeight: FontWeight.w700,
                              color: weekdayLabelColor,
                            ),
                          ),
                          SizedBox(height: dense ? 1 : 2),
                          Text(
                            '${day.day}',
                            style: TextStyle(
                              fontSize: dayFs,
                              fontWeight: FontWeight.w900,
                              color: dayNumberColor,
                            ),
                          ),
                          SizedBox(height: gapAfterDay),
                          Container(
                            width: dotSz,
                            height: dotSz,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: hasTask ? cs.tertiary : Colors.transparent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

/// 일정이 있는 요일만 접기/펼치기 블록으로 나열.
class _ScheduleWeekDaySections extends ConsumerWidget {
  const _ScheduleWeekDaySections({
    required this.weekMonday,
    required this.memos,
    this.onDayTap,
    this.daySectionKeys,
  });

  final DateTime weekMonday;
  final List<ScheduleMemoModel> memos;
  final ValueChanged<DateTime>? onDayTap;
  final Map<String, GlobalKey>? daySectionKeys;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mon = scheduleDateOnly(scheduleStartOfWeekMonday(weekMonday));
    final byDay = <String, List<ScheduleMemoModel>>{};
    for (final m in memos) {
      byDay.putIfAbsent(m.taskDate, () => []).add(m);
    }
    for (final list in byDay.values) {
      list.sort((a, b) => a.taskTime.compareTo(b.taskTime));
    }

    final tiles = <Widget>[];
    for (var i = 0; i < 7; i++) {
      final day = mon.add(Duration(days: i));
      final dayMemos =
          byDay[scheduleDateKey(day)] ?? const <ScheduleMemoModel>[];
      if (dayMemos.isEmpty) continue;
      if (tiles.isNotEmpty) {
        tiles.add(const SizedBox(height: 8));
      }
      final dayKey = scheduleDateKey(day);
      final sectionKey = daySectionKeys == null
          ? null
          : daySectionKeys!.putIfAbsent(dayKey, GlobalKey.new);
      tiles.add(
        _DaySchedulePane(
          day: day,
          memos: dayMemos,
          onDayTap: onDayTap,
          sectionKey: sectionKey,
        ),
      );
    }

    if (tiles.isEmpty) {
      final cs = Theme.of(context).colorScheme;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(
            '이 주에는 등록된 일정이 없습니다.',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: tiles,
    );
  }
}

class _DaySchedulePane extends ConsumerWidget {
  const _DaySchedulePane({
    required this.day,
    required this.memos,
    this.onDayTap,
    this.sectionKey,
  });

  final DateTime day;
  final List<ScheduleMemoModel> memos;
  final ValueChanged<DateTime>? onDayTap;
  final GlobalKey? sectionKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    assert(memos.isNotEmpty);
    final cs = Theme.of(context).colorScheme;
    final selectedDay = ref.watch(
      dashboardScheduleProvider.select((s) => s.selectedDay),
    );
    final isSelected = _scheduleIsSameDay(day, selectedDay);
    final isSat = day.weekday == DateTime.saturday;
    final isSun = day.weekday == DateTime.sunday;

    Color titleColor;
    if (isSun) {
      titleColor = _sundayRed;
    } else if (isSat) {
      titleColor = _saturdayBlue;
    } else {
      titleColor = cs.onSurface;
    }

    final borderColor =
        isSelected ? cs.primary : cs.outlineVariant.withValues(alpha: 0.65);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: borderColor, width: isSelected ? 1.6 : 1),
    );

    return Theme(
      key: sectionKey,
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: Material(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          shape: shape,
          collapsedShape: shape,
          title: Text(
            _dayTitleLine(day),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: titleColor,
            ),
          ),
          onExpansionChanged: (_) => onDayTap?.call(day),
          children: [
            for (final m in memos)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _memoTile(
                  context,
                  ref,
                  m,
                  showDayHeading: false,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 이전/다음 주 + (선택) 7칸 요일.
class DashboardScheduleWeekPicker extends ConsumerWidget {
  const DashboardScheduleWeekPicker({
    super.key,
    this.useFullMemosForDots = false,
    this.showChevronNav = true,
    this.showDayStrip = true,
  });

  /// true면 [DashboardScheduleState.fullMemos]까지 보고 일정 점 표시.
  final bool useFullMemosForDots;

  /// false면 좌우 화살표 숨김(PageView 등으로 주 이동할 때).
  final bool showChevronNav;

  /// false면 요일 칸(미니 캘린더) 없이 주 범위 텍스트만 표시.
  final bool showDayStrip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final state = ref.watch(dashboardScheduleProvider);
    final vm = ref.read(dashboardScheduleProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (showChevronNav)
              IconButton(
                tooltip: '이전 주',
                onPressed: state.isWeekLoading ? null : () => vm.goWeek(-1),
                icon: const Icon(Icons.chevron_left),
                visualDensity: VisualDensity.compact,
              )
            else
              const SizedBox(width: 48),
            Expanded(
              child: Text(
                _weekRangeLine(state.weekStart),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface,
                ),
              ),
            ),
            if (showChevronNav)
              IconButton(
                tooltip: '다음 주',
                onPressed: state.isWeekLoading ? null : () => vm.goWeek(1),
                icon: const Icon(Icons.chevron_right),
                visualDensity: VisualDensity.compact,
              )
            else
              const SizedBox(width: 48),
          ],
        ),
        if (showDayStrip) ...[
          const SizedBox(height: 6),
          DashboardScheduleWeekCalendarStrip(
            weekMonday: state.weekStart,
            useFullMemosForDots: useFullMemosForDots,
            showWeekRangeHeader: false,
          ),
        ],
      ],
    );
  }
}

/// 주간 미니 캘린더 + 주별(좌우 스와이프) 일정 — 기본은 이번 주.
class DashboardScheduleCompactCard extends ConsumerStatefulWidget {
  const DashboardScheduleCompactCard({super.key});

  @override
  ConsumerState<DashboardScheduleCompactCard> createState() =>
      _DashboardScheduleCompactCardState();
}

class _DashboardScheduleCompactCardState
    extends ConsumerState<DashboardScheduleCompactCard> {
  PageController? _pageController;
  var _pageControllerReady = false;
  var _syncingPageFromVm = false;
  final Map<String, ScrollController> _weekScrollControllers = {};
  final Map<String, Map<String, GlobalKey>> _weekDaySectionKeys = {};

  String _weekKeyOf(DateTime day) =>
      scheduleDateKey(scheduleStartOfWeekMonday(scheduleDateOnly(day)));

  void _scrollToDaySection(DateTime day) {
    final weekKey = _weekKeyOf(day);
    final dayKey = scheduleDateKey(scheduleDateOnly(day));
    final ctx = _weekDaySectionKeys[weekKey]?[dayKey]?.currentContext;
    final ctrl = _weekScrollControllers[weekKey];
    if (ctx == null || ctrl == null || !ctrl.hasClients) return;

    final renderObject = ctx.findRenderObject();
    if (renderObject == null) return;
    final viewport = RenderAbstractViewport.of(renderObject);

    final targetOffset = viewport.getOffsetToReveal(renderObject, 0.06).offset;
    final position = ctrl.position;
    final clamped = targetOffset.clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    ctrl.animateTo(
      clamped.toDouble(),
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _shareSelectedDay(
    BuildContext context,
    DashboardScheduleState state,
    DateTime day,
  ) async {
    final selected = scheduleDateOnly(day);
    final selectedKey = scheduleDateKey(selected);
    final dayMemos = state.weekMemos
        .where((m) => m.taskDate == selectedKey)
        .toList()
      ..sort((a, b) {
        final aTime = a.taskTime.trim();
        final bTime = b.taskTime.trim();
        final aHasTime = aTime.isNotEmpty;
        final bHasTime = bTime.isNotEmpty;
        if (aHasTime != bHasTime) return aHasTime ? -1 : 1; // 시간이 없는 항목은 아래로
        if (aTime != bTime) return aTime.compareTo(bTime);
        return a.title.compareTo(b.title);
      });

    final text = _buildDailyShareText(selected, dayMemos);

    if (!context.mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    await Share.share(
      text,
      sharePositionOrigin:
          box == null ? null : box.localToGlobal(Offset.zero) & box.size,
    );
  }

  String _buildDailyShareText(DateTime day, List<ScheduleMemoModel> memos) {
    final dateLabel =
        '${day.year}년 ${day.month}월 ${day.day}일 (${_weekdayKo[day.weekday - 1]})';
    final header = '## 일정표\n### $dateLabel\n';
    String toKoTime(String raw) {
      final t = raw.trim();
      if (t.isEmpty) return '시간 미정';
      final parts = t.split(':');
      if (parts.length != 2) return t;
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h == null || m == null) return t;
      return '${h}시 ${m.toString().padLeft(2, '0')}분';
    }

    if (memos.isEmpty) {
      return '$header\n==========\n# [등록된 일정 없음] - 시간 미정\n- 메모 없음';
    }
    final lines = memos.map((m) {
      final title = m.title.trim().isEmpty ? '일정' : m.title.trim();
      final timeKo = toKoTime(m.taskTime);
      final memoBullets = m.memo.trim().isEmpty ? '- 메모 없음' : m.memo.trim();
      return '# [$title]\n($timeKo)\n$memoBullets';
    }).join('\n\n');
    return '$header\n==========\n$lines';
  }

  Future<DateTime?> _pickDayForShare(
    BuildContext context,
    DashboardScheduleState state,
  ) async {
    final weekStart = scheduleDateOnly(state.weekStart);
    final selected = scheduleDateOnly(state.selectedDay);
    return showModalBottomSheet<DateTime>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final sheetHeight =
            (MediaQuery.sizeOf(ctx).height * 0.62).clamp(320.0, 520.0).toDouble();
        return SizedBox(
          height: sheetHeight,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '공유할 날짜 선택',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.builder(
                    itemCount: 7,
                    itemBuilder: (context, i) {
                      final day = weekStart.add(Duration(days: i));
                      final key = scheduleDateKey(day);
                      final count =
                          state.weekMemos.where((m) => m.taskDate == key).length;
                      final isSelected = _scheduleIsSameDay(day, selected);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => Navigator.pop(ctx, day),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: isSelected
                                  ? cs.primaryContainer
                                  : cs.surfaceContainerHighest.withValues(
                                      alpha: 0.4,
                                    ),
                              border: Border.all(
                                color: isSelected
                                    ? cs.primary
                                    : cs.outlineVariant.withValues(alpha: 0.55),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _dayTitleLine(day),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: isSelected
                                          ? cs.onPrimaryContainer
                                          : cs.onSurface,
                                    ),
                                  ),
                                ),
                                Text(
                                  count == 0 ? '일정 없음' : '$count개',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected
                                        ? cs.onPrimaryContainer
                                        : cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_pageControllerReady) return;
    final vm = ref.read(dashboardScheduleProvider.notifier);
    final st = ref.read(dashboardScheduleProvider);
    final idx = vm.weekPageIndexFor(st.weekStart);
    _pageController = PageController(initialPage: idx);
    _pageControllerReady = true;
  }

  @override
  void dispose() {
    for (final c in _weekScrollControllers.values) {
      c.dispose();
    }
    _pageController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final state = ref.watch(dashboardScheduleProvider);
    final vm = ref.read(dashboardScheduleProvider.notifier);
    final today = scheduleDateOnly(DateTime.now());
    final mediaH = MediaQuery.sizeOf(context).height;
    final pageHeight = (mediaH * 0.44).clamp(340.0, 480.0);

    ref.listen<DashboardScheduleState>(dashboardScheduleProvider, (prev, next) {
      if (prev?.weekStart == next.weekStart) return;
      final c = _pageController;
      if (c == null || !c.hasClients) return;
      final target = vm.weekPageIndexFor(next.weekStart);
      final cur = c.page?.round() ?? c.initialPage;
      if (cur == target) return;
      _syncingPageFromVm = true;
      c
          .animateToPage(
        target,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      )
          .whenComplete(() {
        if (mounted) _syncingPageFromVm = false;
      });
    });

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: cs.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Container(
        color: Theme.of(context).cardColor,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.event_note_outlined, size: 20, color: cs.primary),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    '일정 · 메모',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.share_outlined, size: 20),
                  onPressed: () async {
                    try {
                      final day = await _pickDayForShare(context, state);
                      if (day == null || !context.mounted) return;
                      await _shareSelectedDay(context, state, day);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('공유 중 오류가 발생했습니다: $e')),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: pageHeight,
              child: _pageController == null
                  ? const Center(child: CircularProgressIndicator())
                  : PageView.builder(
                      controller: _pageController,
                      itemCount: DashboardScheduleViewModel.weekPageCount,
                      onPageChanged: (i) {
                        if (_syncingPageFromVm) return;
                        ref
                            .read(dashboardScheduleProvider.notifier)
                            .setWeekPageIndex(i);
                      },
                      itemBuilder: (context, i) {
                        final mon = vm.weekMondayAtPageIndex(i);
                        final weekKey = _weekKeyOf(mon);
                        final scrollCtrl = _weekScrollControllers.putIfAbsent(
                          weekKey,
                          ScrollController.new,
                        );
                        final daySectionKeys =
                            _weekDaySectionKeys.putIfAbsent(weekKey, () => {});
                        final list = state.memosForWeekMondayCached(mon);
                        final isActivePage =
                            vm.weekPageIndexFor(state.weekStart) == i;
                        final loading =
                            state.isWeekLoading && isActivePage && list.isEmpty;
                        if (loading) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            DashboardScheduleWeekCalendarStrip(
                              weekMonday: mon,
                              showWeekRangeHeader: true,
                              useFullMemosForDots: false,
                              onDayTap: _scrollToDaySection,
                            ),
                            Divider(
                              height: 20,
                              thickness: 1,
                              color: cs.outlineVariant.withValues(alpha: 0.45),
                            ),
                            Expanded(
                              child: SingleChildScrollView(
                                controller: scrollCtrl,
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding:
                                    const EdgeInsets.only(top: 4, bottom: 8),
                                child: _ScheduleWeekDaySections(
                                  weekMonday: mon,
                                  memos: list,
                                  onDayTap: _scrollToDaySection,
                                  daySectionKeys: daySectionKeys,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      final idx = vm.weekPageIndexFor(
                        scheduleStartOfWeekMonday(today),
                      );
                      vm.setWeekPageIndex(idx);
                      vm.selectDay(today);
                      final c = _pageController;
                      if (c != null && c.hasClients) {
                        _syncingPageFromVm = true;
                        c.jumpToPage(idx);
                        _syncingPageFromVm = false;
                      }
                    },
                    child: const Text('오늘'),
                  ),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: state.isFullLoading
                        ? null
                        : () async {
                            await ref
                                .read(dashboardScheduleProvider.notifier)
                                .loadFullMemosIfNeeded();
                            if (!context.mounted) return;
                            context.push('/dashboard/schedule-full');
                          },
                    child: const Text('전체보기'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FullWeekBlock extends ConsumerWidget {
  const _FullWeekBlock({
    required this.weekStart,
    required this.memos,
    required this.weekRangeLabel,
    this.onDayTap,
    this.daySectionKeys,
  });

  final DateTime weekStart;
  final List<ScheduleMemoModel> memos;
  final String weekRangeLabel;
  final ValueChanged<DateTime>? onDayTap;
  final Map<String, GlobalKey>? daySectionKeys;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              weekRangeLabel,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            _ScheduleWeekDaySections(
              weekMonday: weekStart,
              memos: memos,
              onDayTap: onDayTap,
              daySectionKeys: daySectionKeys,
            ),
          ],
        ),
      ),
    );
  }
}

String _dayHeading(String taskDateKey) {
  final d = _parseTaskDateKey(taskDateKey);
  final wd = _weekdayKo[d.weekday - 1];
  return '${d.month}/${d.day} ($wd)';
}

Widget _memoTile(
  BuildContext context,
  WidgetRef ref,
  ScheduleMemoModel m, {
  required bool showDayHeading,
}) {
  final cs = Theme.of(context).colorScheme;
  final vm = ref.read(dashboardScheduleProvider.notifier);
  final d = _parseTaskDateKey(m.taskDate);
  final isSat = d.weekday == DateTime.saturday;
  final isSun = d.weekday == DateTime.sunday;

  Color dayAccent;
  if (isSun) {
    dayAccent = _sundayRed;
  } else if (isSat) {
    dayAccent = _saturdayBlue;
  } else {
    dayAccent = cs.onSurfaceVariant;
  }

  return Slidable(
    key: ValueKey(m.sid ?? '${m.taskDate}-${m.createdAtMs}-${m.title}'),
    closeOnScroll: true,
    startActionPane: ActionPane(
      motion: const DrawerMotion(),
      extentRatio: 0.28,
      children: [
        SlidableAction(
          onPressed: (_) => openDashboardMemoEditor(context, ref, existing: m),
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          icon: Icons.edit_outlined,
          label: '수정',
          borderRadius: BorderRadius.circular(12),
        ),
      ],
    ),
    endActionPane: ActionPane(
      motion: const DrawerMotion(),
      extentRatio: 0.28,
      children: [
        SlidableAction(
          onPressed: (_) => _confirmDelete(context, ref, m),
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          icon: Icons.delete_outline,
          label: '삭제',
          borderRadius: BorderRadius.circular(12),
        ),
      ],
    ),
    child: Material(
      color: cs.surface.withValues(alpha: 0.65),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: m.done,
              onChanged: (v) {
                if (m.sid != null) {
                  vm.setDone(m.sid!, v ?? false);
                }
              },
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            Expanded(
              child: InkWell(
                onTap: () => openDashboardMemoEditor(context, ref, existing: m),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 2,
                    horizontal: 2,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (showDayHeading) ...[
                        Text(
                          _dayHeading(m.taskDate),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: dayAccent,
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  m.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                    decoration: m.done
                                        ? TextDecoration.lineThrough
                                        : null,
                                    color: m.done
                                        ? cs.onSurfaceVariant
                                        : cs.onSurface,
                                  ),
                                ),
                                if (m.memo.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    m.memo,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: cs.onSurfaceVariant,
                                      height: 1.25,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (m.taskTime.trim().isNotEmpty ||
                              m.alarmEnabled) ...[
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 110,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  if (m.taskTime.trim().isNotEmpty)
                                    Text(
                                      m.taskTime.trim(),
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                        color: cs.primary,
                                        height: 1.0,
                                      ),
                                    ),
                                  if (m.alarmEnabled) ...[
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: cs.primaryContainer
                                            .withValues(alpha: 0.9),
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        '알람 ${_alarmOffsetLabel(m.alarmOffsetMinutes)}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: cs.onPrimaryContainer,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _confirmDelete(
  BuildContext context,
  WidgetRef ref,
  ScheduleMemoModel m,
) async {
  if (m.sid == null) return;
  final vm = ref.read(dashboardScheduleProvider.notifier);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('일정 삭제'),
      content: const Text('이 일정을 삭제할까요?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('삭제'),
        ),
      ],
    ),
  );
  if (ok == true && context.mounted) {
    await vm.deleteMemo(m.sid!);
  }
}

TimeOfDay? _parseTaskTime(String value) {
  final v = value.trim();
  if (v.isEmpty) return null;
  final p = v.split(':');
  if (p.length != 2) return null;
  final hour = int.tryParse(p[0]);
  final minute = int.tryParse(p[1]);
  if (hour == null || minute == null) return null;
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
  return TimeOfDay(hour: hour, minute: minute);
}

String _timeToKey(TimeOfDay t) {
  return '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}';
}

Future<TimeOfDay?> _pickTaskTime(
  BuildContext context,
  TimeOfDay? initial,
) async {
  final now = DateTime.now();
  final init = initial ?? TimeOfDay.now();
  var selected = DateTime(
    now.year,
    now.month,
    now.day,
    init.hour,
    init.minute,
  );

  final picked = await showModalBottomSheet<DateTime>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setModalState) {
          var pickerResetKey = 0;
          void applyQuickMinute(int minute) {
            final base = selected;
            setModalState(() {
              selected = DateTime(
                base.year,
                base.month,
                base.day,
                base.hour,
                minute,
              );
              pickerResetKey++;
            });
          }

          return SizedBox(
            height: 360,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('취소'),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, selected),
                        child: const Text('확인'),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: FilledButton.tonal(
                            onPressed: () => applyQuickMinute(0),
                            style: FilledButton.styleFrom(
                              elevation: 0,
                              backgroundColor: selected.minute == 0
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.transparent,
                              foregroundColor: selected.minute == 0
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text('정각'),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: FilledButton.tonal(
                            onPressed: () => applyQuickMinute(30),
                            style: FilledButton.styleFrom(
                              elevation: 0,
                              backgroundColor: selected.minute == 30
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.transparent,
                              foregroundColor: selected.minute == 30
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text('반'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: CupertinoDatePicker(
                    key: ValueKey(
                      '${selected.hour}-${selected.minute}-$pickerResetKey',
                    ),
                    mode: CupertinoDatePickerMode.time,
                    use24hFormat: true,
                    initialDateTime: selected,
                    onDateTimeChanged: (value) => selected = value,
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
  if (picked == null) return null;
  return TimeOfDay(hour: picked.hour, minute: picked.minute);
}

Future<void> openDashboardMemoEditor(
  BuildContext context,
  WidgetRef ref, {
  required ScheduleMemoModel? existing,
  DateTime? initialDateOverride,
}) async {
  final st = ref.read(dashboardScheduleProvider);
  final vm = ref.read(dashboardScheduleProvider.notifier);

  final initialDate = existing != null
      ? _parseTaskDateKey(existing.taskDate)
      : (initialDateOverride ?? st.selectedDay);
  final initialTime =
      existing != null ? _parseTaskTime(existing.taskTime) : null;

  List<PlaceInfoModel> places = const [];
  final me = ref.read(authSessionProvider).maybeWhen(
        data: (u) => u,
        orElse: () => null,
      );
  if (me != null && me.role.canAccessDashboardPlacesInfo) {
    try {
      places = await ref.read(dashboardRemoteUseCaseProvider).placesInfo();
    } on DioException catch (e) {
      final code = e.response?.statusCode ?? e.httpClientError?.statusCode;
      places = const [];
      if (context.mounted && code == 403) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '현장 목록을 불러올 권한이 없습니다. 제목·메모는 그대로 입력할 수 있습니다.',
            ),
          ),
        );
      }
    }
  }
  if (!context.mounted) return;
  places.sort((a, b) => (b.pid ?? 0).compareTo(a.pid ?? 0)); // 최근 등록 순
  final seen = <String>{};
  final placeNameSuggestions = <String>[];
  for (final p in places) {
    final name = p.pname.trim();
    if (name.isEmpty || seen.contains(name)) continue;
    seen.add(name);
    placeNameSuggestions.add(name);
  }

  final result = await showModalBottomSheet<DashboardMemoEditorResult?>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) => DashboardScheduleMemoEditorSheet(
      existing: existing,
      initialDate: initialDate,
      initialTime: initialTime,
      onPickTime: (initial) => _pickTaskTime(context, initial),
      placeNameSuggestions: placeNameSuggestions,
    ),
  );

  if (result == null || !context.mounted) return;

  final taskTime = result.time == null ? '' : _timeToKey(result.time!);
  final normalizedMemo = _normalizeMemoAsBullets(result.memo);
  if (existing == null) {
    await vm.addMemo(
      date: result.date,
      taskTime: taskTime,
      title: result.title,
      memo: normalizedMemo,
      alarmEnabled: result.alarmEnabled,
      alarmOffsetMinutes: result.alarmOffsetMinutes,
    );
  } else if (existing.sid != null) {
    await vm.updateMemo(
      existing.copyWith(
        taskDate: scheduleDateKey(result.date),
        taskTime: taskTime,
        title: result.title,
        memo: normalizedMemo,
        alarmEnabled: result.alarmEnabled,
        alarmOffsetMinutes: result.alarmOffsetMinutes,
      ),
    );
  }
}

String _normalizeMemoAsBullets(String raw) {
  final lines = raw
      .split('\n')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .map((e) => e.startsWith('- ') ? e : '- $e')
      .toList();
  return lines.join('\n');
}

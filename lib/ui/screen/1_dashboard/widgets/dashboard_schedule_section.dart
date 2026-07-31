import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/data/model/place_info_model.dart';
import 'package:w0001/data/model/schedule_memo_model.dart';
import 'package:w0001/access/user_role_capabilities.dart';
import 'package:w0001/presentation/viewmodel/auth_providers.dart';
import 'package:w0001/presentation/viewmodel/dashboard_remote_providers.dart';
import 'package:w0001/presentation/viewmodel/dashboard_schedule_view_model.dart';
import 'package:w0001/ui/screen/1_dashboard/widgets/dashboard_schedule_editor_sheet.dart';
import 'package:w0001/theme/app_segmented_button.dart';
import 'package:w0001/ui/screen/1_dashboard/widgets/schedule_memo_editor_shared.dart';
import 'package:w0001/ui/widget/schedule_memo/schedule_memo_list_tile.dart';
import 'package:share_plus/share_plus.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:w0001/util/responsive_layout.dart';

part 'dashboard_schedule_full_screen.part.dart';

const _weekdayKo = ['월', '화', '수', '목', '금', '토', '일'];

Color _scheduleWeekdayTextColor(
  ColorScheme cs,
  DateTime day, {
  required bool selected,
}) {
  if (day.weekday == DateTime.sunday) {
    return selected
        ? cs.error.withValues(alpha: 0.92)
        : cs.error.withValues(alpha: 0.72);
  }
  if (day.weekday == DateTime.saturday) {
    return selected ? cs.onSurface : cs.onSurfaceVariant;
  }
  return selected ? cs.onSurface : cs.onSurfaceVariant;
}

Color _scheduleDayNumberColor(
  ColorScheme cs,
  DateTime day, {
  required bool selected,
}) {
  if (selected) return cs.onSurface;
  return _scheduleWeekdayTextColor(cs, day, selected: false);
}

DateTime _parseTaskDateKey(String k) => scheduleDateFromTaskKey(k);

String _weekRangeLine(DateTime weekStart) {
  final end = weekStart.add(const Duration(days: 6));
  return '${weekStart.month}월 ${weekStart.day}일 - '
      '${end.month}월 ${end.day}일';
}

/// 주간 일정 영역 초기·로딩 시 스켈레톤 (스피너 대신).
Widget _scheduleWeekPageSkeleton({
  required BuildContext context,
  required DateTime weekMonday,
  required ColorScheme cs,
  required double pageHeight,
}) {
  return Skeletonizer(
    enabled: true,
    child: SizedBox(
      height: pageHeight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DashboardScheduleWeekCalendarStrip(
            weekMonday: weekMonday,
            showWeekRangeHeader: true,
            useFullMemosForDots: false,
          ),
          Divider(
            height: context.rs(20),
            thickness: 1,
            color: cs.outlineVariant.withValues(alpha: 0.45),
          ),
          Expanded(
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              padding: ResponsiveLayout.only(context, top: 4, bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < 4; i++)
                    Padding(
                      padding: EdgeInsets.only(
                        bottom: i < 3 ? context.rs(10) : 0,
                      ),
                      child: Material(
                        color: cs.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(context.rs(16)),
                        child: Padding(
                          padding: EdgeInsets.all(context.rs(14)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '일정 제목',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              rsV(context, 8),
                              Text(
                                '메모 본문이 여기에 표시됩니다.',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(height: 1.35),
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
        ],
      ),
    ),
  );
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
    final tt = Theme.of(context).textTheme;
    final state = ref.watch(dashboardScheduleProvider);
    final vm = ref.read(dashboardScheduleProvider.notifier);
    final today = scheduleDateOnly(DateTime.now());
    final mon = scheduleDateOnly(scheduleStartOfWeekMonday(weekMonday));

    final cellPadV = dense ? context.rs(4) : context.rs(8);
    final dotSz = dense ? context.rs(4) : context.rs(5);
    final gapAfterDay = dense ? context.rs(2) : context.rs(4);
    final radius = dense ? context.rs(8) : context.rs(10);
    final hzPad = dense ? context.rs(1) : context.rs(2);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showWeekRangeHeader) ...[
          Text(
            _weekRangeLine(mon),
            textAlign: TextAlign.center,
            style: (dense ? tt.labelSmall : tt.labelMedium)?.copyWith(
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
            ),
          ),
          SizedBox(height: dense ? context.rs(4) : context.rs(6)),
        ],
        Row(
          children: List.generate(7, (i) {
            final day = mon.add(Duration(days: i));
            final selected = _scheduleIsSameDay(day, state.selectedDay);
            final isToday = _scheduleIsSameDay(day, today);
            final hasTask = _dotForDay(state, day);
            final weekdayLabelColor = _scheduleWeekdayTextColor(
              cs,
              day,
              selected: selected,
            );
            final dayNumberColor = _scheduleDayNumberColor(
              cs,
              day,
              selected: selected,
            );

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
                            ? cs.surfaceContainerHigh.withValues(alpha: 0.72)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(radius),
                        border: Border.all(
                          color: isToday
                              ? cs.primary.withValues(alpha: 0.85)
                              : selected
                                  ? cs.outline.withValues(alpha: 0.55)
                                  : cs.outlineVariant.withValues(alpha: 0.35),
                          width: isToday || selected ? 1.25 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _weekdayKo[day.weekday - 1],
                            style: (dense ? tt.labelSmall : tt.labelMedium)
                                ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: weekdayLabelColor,
                            ),
                          ),
                          SizedBox(
                              height: dense ? context.rs(1) : context.rs(2)),
                          Text(
                            '${day.day}',
                            style: (dense ? tt.titleSmall : tt.titleMedium)
                                ?.copyWith(
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
                              color: hasTask
                                  ? cs.primary.withValues(alpha: 0.82)
                                  : Colors.transparent,
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
      final tt = Theme.of(context).textTheme;
      return Padding(
        padding: ResponsiveLayout.symmetric(context, vertical: 20),
        child: Center(
          child: Text(
            '이 주에는 등록된 일정이 없습니다.',
            style: tt.bodySmall?.copyWith(
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
    final tt = Theme.of(context).textTheme;
    final selectedDay = ref.watch(
      dashboardScheduleProvider.select((s) => s.selectedDay),
    );
    final isSelected = _scheduleIsSameDay(day, selectedDay);

    final titleColor =
        (day.weekday == DateTime.saturday || day.weekday == DateTime.sunday)
            ? _scheduleWeekdayTextColor(cs, day, selected: isSelected)
            : cs.onSurface;

    final borderColor =
        isSelected ? cs.primary : cs.outlineVariant.withValues(alpha: 0.65);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: borderColor, width: isSelected ? 1.6 : 1),
    );

    return KeyedSubtree(
      key: sectionKey,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: Material(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
          shape: shape,
          clipBehavior: Clip.antiAlias,
          child: ExpansionTile(
            key: PageStorageKey<String>('schedule_day_${scheduleDateKey(day)}'),
            initiallyExpanded: true,
            tilePadding: ResponsiveLayout.symmetric(context,
                horizontal: 10, vertical: 2),
            childrenPadding:
                ResponsiveLayout.only(context, left: 8, right: 8, bottom: 8),
            shape: shape,
            collapsedShape: shape,
            title: Text(
              _dayTitleLine(day),
              style: tt.bodySmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: titleColor,
              ),
            ),
            onExpansionChanged: (_) => onDayTap?.call(day),
            children: [
              for (final m in memos)
                Padding(
                  padding: ResponsiveLayout.only(context, bottom: 8),
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
    final tt = Theme.of(context).textTheme;
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
                style: tt.labelMedium?.copyWith(
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
  const DashboardScheduleCompactCard({super.key, this.embedded = false});

  /// [ManagementDashboardSectionShell] 안에 넣을 때 헤더·카드 테두리 생략.
  final bool embedded;

  @override
  ConsumerState<DashboardScheduleCompactCard> createState() =>
      _DashboardScheduleCompactCardState();
}

/// 섹션 셸 안에서 쓰는 일정 본문.
class DashboardScheduleCompactBody extends DashboardScheduleCompactCard {
  const DashboardScheduleCompactBody({super.key}) : super(embedded: true);
}

class _DashboardScheduleCompactCardState
    extends ConsumerState<DashboardScheduleCompactCard> {
  PageController? _pageController;
  var _pageControllerReady = false;
  var _syncingPageFromVm = false;
  final Map<String, ScrollController> _weekScrollControllers = {};
  final Map<String, Map<String, GlobalKey>> _weekDaySectionKeys = {};

  // dispose()에서 안전하게 사용하기 위해 notifier를 필드로 저장
  DashboardScheduleViewModel? _notifier;

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
        final tt = Theme.of(ctx).textTheme;
        final sheetHeight = (MediaQuery.sizeOf(ctx).height * 0.62)
            .clamp(context.rs(320), context.rs(520))
            .toDouble();
        return SizedBox(
          height: sheetHeight,
          child: Padding(
            padding: ResponsiveLayout.only(ctx,
                left: 14, top: 4, right: 14, bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '공유할 날짜 선택',
                  style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
                rsV(ctx, 10),
                Expanded(
                  child: ListView.builder(
                    itemCount: 7,
                    itemBuilder: (context, i) {
                      final day = weekStart.add(Duration(days: i));
                      final key = scheduleDateKey(day);
                      final count = state.weekMemos
                          .where((m) => m.taskDate == key)
                          .length;
                      final isSelected = _scheduleIsSameDay(day, selected);
                      return Padding(
                        padding: ResponsiveLayout.only(ctx, bottom: 8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(context.rs(12)),
                          onTap: () => Navigator.pop(ctx, day),
                          child: Container(
                            padding: ResponsiveLayout.symmetric(
                              ctx,
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
                                    style: tt.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: isSelected
                                          ? cs.onPrimaryContainer
                                          : cs.onSurface,
                                    ),
                                  ),
                                ),
                                Text(
                                  count == 0 ? '일정 없음' : '$count개',
                                  style: tt.labelMedium?.copyWith(
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
    _notifier = vm; // dispose()에서 사용하기 위해 저장
    final st = ref.read(dashboardScheduleProvider);
    final idx = vm.weekPageIndexFor(st.weekStart);
    _pageController = PageController(initialPage: idx);
    _pageControllerReady = true;
  }

  @override
  void dispose() {
    // ref 대신 저장해둔 notifier 필드 사용 (dispose에서 ref 사용은 안전하지 않음)
    _notifier?.flushPendingDonePatches();
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
    final pageHeight = (mediaH * 0.38).clamp(context.rs(300), context.rs(420));
    final tt = Theme.of(context).textTheme;

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

    final scheduleContent = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.embedded)
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              tooltip: '일정 공유',
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.ios_share_rounded, size: context.rsi(18)),
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
          ),
        SizedBox(
          height: pageHeight,
          child: _pageController == null
              ? _scheduleWeekPageSkeleton(
                  context: context,
                  weekMonday: vm.weekMondayAtPageIndex(
                    vm.weekPageIndexFor(state.weekStart),
                  ),
                  cs: cs,
                  pageHeight: pageHeight,
                )
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
                      return _scheduleWeekPageSkeleton(
                        context: context,
                        weekMonday: mon,
                        cs: cs,
                        pageHeight: pageHeight,
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
                          height: context.rs(16),
                          thickness: 1,
                          color: cs.outlineVariant.withValues(alpha: 0.32),
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            controller: scrollCtrl,
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: ResponsiveLayout.only(
                              context,
                              top: 2,
                              bottom: 6,
                            ),
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
        rsV(context, 4),
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
    );

    if (widget.embedded) return scheduleContent;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(context.rs(14)),
        side: BorderSide(
          color: cs.outlineVariant.withValues(alpha: 0.42),
        ),
      ),
      child: Container(
        color: Theme.of(context).cardColor,
        padding: ResponsiveLayout.only(
          context,
          left: 12,
          top: 12,
          right: 12,
          bottom: 10,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.event_note_outlined,
                    size: context.rsi(18), color: cs.onSurfaceVariant),
                rsH(context, 8),
                Expanded(
                  child: Text(
                    '일정 · 메모',
                    style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.ios_share_rounded, size: context.rsi(18)),
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
            rsV(context, 10),
            scheduleContent,
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
    final tt = Theme.of(context).textTheme;
    return Material(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(context.rs(14)),
      child: Padding(
        padding: ResponsiveLayout.all(context, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              weekRangeLabel,
              style: tt.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: cs.onSurface,
              ),
            ),
            rsV(context, 10),
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

Widget _memoTile(
  BuildContext context,
  WidgetRef ref,
  ScheduleMemoModel m, {
  required bool showDayHeading,
}) {
  final vm = ref.read(dashboardScheduleProvider.notifier);
  return ScheduleMemoListTile(
    memo: m,
    showDayHeading: showDayHeading,
    onDoneChanged: (v) {
      if (m.sid != null) {
        vm.setDone(m.sid!, v ?? false);
      }
    },
    onEdit: () => openDashboardMemoEditor(context, ref, existing: m),
    onDelete: () => _confirmDelete(context, ref, m),
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
      existing != null ? parseScheduleMemoTaskTime(existing.taskTime) : null;

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
  final placeList = List<PlaceInfoModel>.from(places);
  placeList.sort((a, b) => (b.pid ?? 0).compareTo(a.pid ?? 0)); // 최근 등록 순
  final seen = <String>{};
  final placeNameSuggestions = <String>[];
  for (final p in placeList) {
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
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: DashboardScheduleMemoEditorSheet(
        existing: existing,
        initialDate: initialDate,
        initialTime: initialTime,
        onPickTime: (initial) => pickScheduleMemoTaskTime(context, initial),
        placeNameSuggestions: placeNameSuggestions,
      ),
    ),
  );

  if (result == null || !context.mounted) return;

  final taskTime =
      result.time == null ? '' : scheduleMemoTimeToKey(result.time!);
  final normalizedMemo = normalizeScheduleMemoBulletText(result.memo);
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

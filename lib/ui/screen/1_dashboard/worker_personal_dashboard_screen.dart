import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/enums.dart';
import 'package:w0001/data/model/remote/super_admin_dtos.dart';
import 'package:w0001/data/model/worker_announcement_models.dart';
import 'package:w0001/data/model/worker_dashboard_models.dart';
import 'package:w0001/presentation/viewmodel/auth_providers.dart';
import 'package:w0001/presentation/viewmodel/dashboard_schedule_view_model.dart';
import 'package:w0001/presentation/viewmodel/worker_personal_dashboard_notifier.dart';
import 'package:w0001/presentation/viewmodel/worker_schedule_notifier.dart';
import 'package:w0001/ui/screen/1_dashboard/widgets/dashboard_line_charts.dart';
import 'package:w0001/ui/screen/1_dashboard/widgets/schedule_memo_editor_shared.dart';
import 'package:w0001/ui/screen/announcements/worker_announcement_blocks_display.dart';
import 'package:w0001/ui/screen/announcements/worker_global_announcement_entry_tile.dart';
import 'package:w0001/ui/screen/announcements/worker_announcement_quill_codec.dart';
import 'package:w0001/util/funtions.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:w0001/presentation/viewmodel/user_notifications_providers.dart';
import 'package:w0001/ui/widget/notification_bell_button.dart';
import 'package:w0001/ui/screen/0_auth/widgets/worker_private_info_entry.dart';
import 'package:w0001/util/responsive_layout.dart';

const _weekdayKo = ['월', '화', '수', '목', '금', '토', '일'];

String _todayTitleLine() {
  final d = DateTime.now();
  return '${d.year}년 ${d.month}월 ${d.day}일 (${_weekdayKo[d.weekday - 1]})';
}

ScheduleMemoRead _workerDashSkeletonMemo({required bool assignment}) {
  final d = DateTime.now();
  final k = scheduleDateKey(scheduleDateOnly(d));
  return ScheduleMemoRead(
    sid: -1,
    taskdate: k,
    tasktime: assignment ? '09:00' : '14:00',
    title: assignment ? '현장 배정' : '직접 일정',
    memo: assignment ? '' : '오늘 메모 내용이 여기에 표시됩니다.',
    done: false,
    alarmenabled: false,
    sortorder: 0,
    createdatms: 0,
    sourceType: assignment ? 'assignment' : 'manual',
    workrole: assignment ? '목공' : '',
  );
}

List<WorkerAnnouncementBlock> _dashMemoRichBlocks(ScheduleMemoRead m) {
  if (m.instructionBlocks.isNotEmpty) return m.instructionBlocks;
  final memo = m.memo.trim();
  if (memo.isNotEmpty &&
      WorkerAnnouncementQuillCodec.isQuillEnvelopeText(memo)) {
    return [WorkerAnnouncementTextBlock(memo)];
  }
  return const [];
}

bool _dashMemoHasPlain(ScheduleMemoRead m) {
  final memo = m.memo.trim();
  if (memo.isEmpty) return false;
  return !WorkerAnnouncementQuillCodec.isQuillEnvelopeText(memo);
}

bool _dashMemoPlainVisible(
    ScheduleMemoRead m, List<WorkerAnnouncementBlock> rich) {
  if (!_dashMemoHasPlain(m)) return false;
  if (m.isAssignment && rich.isNotEmpty) return false;
  return true;
}

/// 작업자 전용 — `GET /worker/dashboard/summary` 기반(관리자 상황판과 별도).
class WorkerPersonalDashboardScreen extends ConsumerStatefulWidget {
  const WorkerPersonalDashboardScreen({super.key});

  @override
  ConsumerState<WorkerPersonalDashboardScreen> createState() =>
      _WorkerPersonalDashboardScreenState();
}

class _WorkerPersonalDashboardScreenState
    extends ConsumerState<WorkerPersonalDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSessionIfNeeded();
      ref.invalidate(userNotificationInboxProvider);
    });
  }

  void _loadSessionIfNeeded() {
    if (!mounted) return;
    final s = ref.read(authSessionProvider);
    if (s.isLoading) return;
    if (s.maybeWhen(data: (u) => u != null, orElse: () => false)) return;
    ref.read(authSessionProvider.notifier).loadCurrentUser();
  }

  Future<void> _pickPeriod(BuildContext context) async {
    final mq = ref.read(workerDashboardQueryProvider);
    var pickYear = mq.year;
    var pickMonth = mq.month;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSt) {
            final years = List.generate(11, (i) => DateTime.now().year - 5 + i);
            final monthlyMode = pickMonth != null;

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  ctx.rsi(20),
                  ctx.rsi(4),
                  ctx.rsi(20),
                  ctx.rsi(22),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '조회 구간',
                      style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    SizedBox(height: ctx.rsi(12)),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('월 단위 보기'),
                      value: monthlyMode,
                      onChanged: (v) => setSt(() {
                        pickMonth =
                            v ? (pickMonth ?? DateTime.now().month) : null;
                      }),
                    ),
                    Row(
                      children: [
                        const Text('연도'),
                        SizedBox(width: ctx.rsi(12)),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: pickYear,
                            items: years
                                .map(
                                  (y) => DropdownMenuItem(
                                    value: y,
                                    child: Text('$y년'),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) =>
                                setSt(() => pickYear = v ?? pickYear),
                          ),
                        ),
                      ],
                    ),
                    if (monthlyMode) ...[
                      SizedBox(height: ctx.rsi(8)),
                      Row(
                        children: [
                          const Text('월'),
                          SizedBox(width: ctx.rsi(12)),
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              initialValue:
                                  (pickMonth ?? DateTime.now().month).clamp(
                                1,
                                12,
                              ),
                              items: List.generate(
                                12,
                                (i) => DropdownMenuItem(
                                  value: i + 1,
                                  child: Text('${i + 1}월'),
                                ),
                              ),
                              onChanged: (v) =>
                                  setSt(() => pickMonth = v ?? pickMonth),
                            ),
                          ),
                        ],
                      ),
                    ],
                    SizedBox(height: ctx.rsi(18)),
                    FilledButton(
                      onPressed: () {
                        if (pickMonth != null) {
                          ref
                              .read(workerDashboardQueryProvider.notifier)
                              .setMonth(pickYear, pickMonth!);
                        } else {
                          ref
                              .read(workerDashboardQueryProvider.notifier)
                              .setYearOnly(pickYear);
                        }
                        Navigator.pop(ctx);
                      },
                      child: const Text('적용'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _personalDashboardSkeletonList(
    ThemeData theme,
    ColorScheme cs,
    TextTheme tt,
  ) {
    final chartH = _chartHeight(context);
    const rollup = WorkerDashboardPlaceRollup(
      pid: 0,
      placeName: '현장 이름',
      workedTotal: 2400000,
      settledTotal: 1800000,
      unsettledTotal: 120000,
    );
    return Skeletonizer(
      enabled: true,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          context.rsi(16),
          context.rsi(12),
          context.rsi(16),
          context.rsi(32),
        ),
        children: [
          Material(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.38),
            clipBehavior: Clip.antiAlias,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
              side:
                  BorderSide(color: cs.outlineVariant.withValues(alpha: 0.45)),
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                context.rsi(18),
                context.rsi(16),
                context.rsi(18),
                context.rsi(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.wb_sunny_outlined,
                          color: cs.tertiary, size: context.rs(26)),
                      SizedBox(width: context.rsi(12)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '오늘',
                              style: tt.labelMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: cs.primary,
                                letterSpacing: 0.2,
                              ),
                            ),
                            Text(
                              _todayTitleLine(),
                              style: tt.titleMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: context.rsi(14)),
                  Divider(
                    height: 1,
                    color: cs.outlineVariant.withValues(alpha: 0.45),
                  ),
                  SizedBox(height: context.rsi(14)),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _TodayMemoTile(
                        memo: _workerDashSkeletonMemo(assignment: true),
                        cs: cs,
                        tt: tt,
                      ),
                      SizedBox(height: context.rsi(12)),
                      _TodayMemoTile(
                        memo: _workerDashSkeletonMemo(assignment: false),
                        cs: cs,
                        tt: tt,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: context.rsi(20)),
          Text(
            '표시 이름',
            style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  '조회 구간',
                  style: tt.labelLarge?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: null,
                icon: Icon(Icons.tune, size: context.rs(18)),
                label: Text(
                  '연간',
                  style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          SizedBox(height: context.rsi(12)),
          Text(
            '합계',
            style: tt.labelMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: cs.primary,
            ),
          ),
          SizedBox(height: context.rsi(8)),
          const _TotalsRow(
            earned: 12500000,
            paid: 9200000,
            outstanding: 3300000,
            isTaxApply: true,
          ),
          SizedBox(height: context.rsi(14)),
          Row(
            children: [
              Icon(Icons.maps_home_work_outlined,
                  color: cs.primary, size: context.rs(22)),
              SizedBox(width: context.rsi(8)),
              Text(
                '현장별 투입 금액',
                style: tt.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                ),
              ),
              const Spacer(),
              Text(
                '2곳',
                style: tt.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
          SizedBox(height: context.rsi(6)),
          Text(
            '연도 기준',
            style: tt.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.3,
            ),
          ),
          SizedBox(height: context.rsi(12)),
          _PlaceRollupCard(
            rollup: rollup,
            cs: cs,
            tt: tt,
            isTaxApply: true,
          ),
          Padding(
            padding: EdgeInsets.only(top: context.rsi(11)),
            child: _PlaceRollupCard(
              rollup: const WorkerDashboardPlaceRollup(
                pid: 1,
                placeName: '다른 현장',
                workedTotal: 800000,
                settledTotal: 400000,
                unsettledTotal: 0,
              ),
              cs: cs,
              tt: tt,
              isTaxApply: true,
            ),
          ),
          Text(
            '월별 근무 건수',
            style: tt.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: context.rsi(8)),
          _ChartCard(
            height: chartH,
            child: DashboardCountBarChart(
              bottomLabels: const [
                '1월',
                '2월',
                '3월',
                '4월',
                '5월',
                '6월',
                '7월',
                '8월',
                '9월',
                '10월',
                '11월',
                '12월',
              ],
              values: [2, 4, 3, 5, 6, 4, 3, 5, 7, 6, 4, 5]
                  .map((e) => e.toDouble())
                  .toList(),
              barColor: cs.tertiary,
              valueLabel: '근무 건수',
            ),
          ),
          SizedBox(height: context.rsi(8)),
        ],
      ),
    );
  }

  Widget _buildTodayScheduleCard(ThemeData theme, ColorScheme cs) {
    final tt = theme.textTheme;
    final asyncMemos = ref.watch(workerScheduleNotifierProvider);
    final todayKey = scheduleDateKey(scheduleDateOnly(DateTime.now()));

    return Material(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.38),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.45)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          context.rsi(18),
          context.rsi(16),
          context.rsi(18),
          context.rsi(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.wb_sunny_outlined,
                    color: cs.tertiary, size: context.rs(26)),
                SizedBox(width: context.rsi(12)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '오늘',
                        style: tt.labelMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: cs.primary,
                          letterSpacing: 0.2,
                        ),
                      ),
                      Text(
                        _todayTitleLine(),
                        style: tt.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: context.rsi(14)),
            Divider(
              height: 1,
              color: cs.outlineVariant.withValues(alpha: 0.45),
            ),
            SizedBox(height: context.rsi(14)),
            asyncMemos.when(
              loading: () => Skeletonizer(
                enabled: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TodayMemoTile(
                      memo: _workerDashSkeletonMemo(assignment: true),
                      cs: cs,
                      tt: tt,
                    ),
                    SizedBox(height: context.rsi(12)),
                    _TodayMemoTile(
                      memo: _workerDashSkeletonMemo(assignment: false),
                      cs: cs,
                      tt: tt,
                    ),
                  ],
                ),
              ),
              error: (e, _) => Text(
                '오늘 일정을 불러오지 못했습니다.\n$e',
                style: tt.bodySmall?.copyWith(color: cs.error, height: 1.35),
              ),
              data: (memos) {
                final items = memos.where((m) {
                  final d = m.taskdate.length >= 10
                      ? m.taskdate.substring(0, 10)
                      : m.taskdate;
                  return d == todayKey;
                }).toList()
                  ..sort((a, b) {
                    if (a.isAssignment != b.isAssignment) {
                      return a.isAssignment ? -1 : 1;
                    }
                    return a.sortorder.compareTo(b.sortorder);
                  });

                if (items.isEmpty) {
                  return Text(
                    '오늘 등록된 일정이 없습니다.\n내 일정 탭에서 추가하거나 배정 내역을 확인하세요.',
                    style: tt.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < items.length; i++) ...[
                      if (i > 0) SizedBox(height: context.rsi(12)),
                      _TodayMemoTile(memo: items[i], cs: cs, tt: tt),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tt = theme.textTheme;
    final cs = theme.colorScheme;
    final auth = ref.watch(authSessionProvider);
    final query = ref.watch(workerDashboardQueryProvider);
    final taxState = ref.watch(workerDashboardTaxStateProvider);
    final isTaxApply = taxState.isTaxApply;
    final asyncData = ref.watch(workerPersonalDashboardProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('내 근로 현황'),
        actions: const [NotificationBellButton()],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            ref.read(workerPersonalDashboardProvider.notifier).reload(),
            ref.read(workerScheduleNotifierProvider.notifier).reload(),
          ]);
        },
        child: auth.isLoading
            ? _personalDashboardSkeletonList(theme, cs, tt)
            : asyncData.when(
                loading: () => _personalDashboardSkeletonList(theme, cs, tt),
                error: (e, _) => ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.all(context.rsi(24)),
                  children: [
                    Text(
                      e.toString(),
                      style: tt.bodyLarge,
                    ),
                  ],
                ),
                data: (data) {
                  if (data.skippedNonWorker) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.all(context.rsi(24)),
                      children: [
                        Text(
                          '작업자 계정에서만 이용할 수 있습니다.',
                          style: tt.bodyLarge?.copyWith(color: cs.error),
                        ),
                      ],
                    );
                  }

                  final monthly = query.isMonthly;
                  final mt = data.displayMonthTotals;
                  final yt = data.displayYearTotals;
                  final rollups = data.placeRollups;

                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      context.rsi(16),
                      context.rsi(12),
                      context.rsi(16),
                      context.rsi(32),
                    ),
                    children: [
                      const WorkerPrivateInfoEntry(compact: true),
                      if (data.summary.workerDisplayName.trim().isNotEmpty)
                        Padding(
                          padding: EdgeInsets.only(bottom: context.rsi(8)),
                          child: Text(
                            '${data.summary.workerDisplayName.trim()}님 오늘도 안전한 하루 되세요!',
                            style: tt.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      _buildTodayScheduleCard(theme, cs),
                      SizedBox(height: context.rsi(12)),
                      const WorkerGlobalAnnouncementEntryTile(),
                      SizedBox(height: context.rsi(20)),
                      if (data.missingHumanLink) ...[
                        Material(
                          color: cs.secondaryContainer.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(14),
                          child: Padding(
                            padding: EdgeInsets.all(context.rsi(14)),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.info_outline, color: cs.primary),
                                SizedBox(width: context.rsi(10)),
                                Expanded(
                                  child: Text(
                                    '관리자의 계정 연동이 필요합니다.',
                                    style: tt.bodyMedium?.copyWith(
                                      height: 1.35,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: context.rsi(16)),
                      ],
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              data.periodCaption,
                              style: tt.labelLarge?.copyWith(
                                color: cs.onSurfaceVariant,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => _pickPeriod(context),
                            icon: Icon(Icons.tune, size: context.rs(18)),
                            label: Text(
                              monthly ? '월별' : '연간',
                              style: tt.labelLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: context.rsi(12)),
                      Align(
                        alignment: Alignment.centerRight,
                        child: _WorkerDashboardTaxSegment(
                          taxState: taxState,
                          onChanged: ref
                              .read(workerDashboardTaxStateProvider.notifier)
                              .setTaxState,
                        ),
                      ),
                      SizedBox(height: context.rsi(6)),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          isTaxApply
                              ? '표시: 세후 (3.3% 원천징수 반영)'
                              : '표시: 세전 (계약·등록 일당 기준)',
                          style: tt.labelSmall?.copyWith(
                            color: isTaxApply ? cs.error : cs.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      SizedBox(height: context.rsi(12)),
                      if (mt != null) ...[
                        Text(
                          monthly ? '선택한 달 합계' : '합계',
                          style: tt.labelMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: cs.primary,
                          ),
                        ),
                        SizedBox(height: context.rsi(8)),
                        _TotalsRow(
                          earned: mt.totalEarned,
                          paid: mt.totalPaid,
                          outstanding: mt.totalOutstanding,
                          isTaxApply: isTaxApply,
                        ),
                        SizedBox(height: context.rsi(14)),
                      ],
                      if (monthly && yt != null) ...[
                        Text(
                          '같은 연도 누적',
                          style: tt.labelMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: cs.tertiary,
                          ),
                        ),
                        SizedBox(height: context.rsi(8)),
                        _TotalsRow(
                          earned: yt.totalEarned,
                          paid: yt.totalPaid,
                          outstanding: yt.totalOutstanding,
                          isTaxApply: isTaxApply,
                        ),
                        SizedBox(height: context.rsi(14)),
                      ],
                      if (!monthly && yt != null) ...[
                        _TotalsRow(
                          earned: yt.totalEarned,
                          paid: yt.totalPaid,
                          outstanding: yt.totalOutstanding,
                          isTaxApply: isTaxApply,
                        ),
                        SizedBox(height: context.rsi(14)),
                      ],
                      Row(
                        children: [
                          Icon(Icons.maps_home_work_outlined,
                              color: cs.primary, size: context.rs(22)),
                          SizedBox(width: context.rsi(8)),
                          Text(
                            '현장별 투입 금액',
                            style: tt.titleSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${rollups.length}곳',
                            style: tt.labelMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: context.rsi(6)),
                      Text(
                        data.placeRollupsPeriodLabel,
                        style: tt.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          height: 1.3,
                        ),
                      ),
                      SizedBox(height: context.rsi(12)),
                      if (rollups.isEmpty && !data.missingHumanLink)
                        Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: context.rsi(28),
                          ),
                          child: Center(
                            child: Text(
                              '${data.summary.year}년에 집계할 현장 투입 내역이 없습니다.',
                              textAlign: TextAlign.center,
                              style: tt.bodyMedium?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                        )
                      else
                        ...rollups.map(
                          (r) => Padding(
                            padding: EdgeInsets.only(bottom: context.rsi(11)),
                            child: _PlaceRollupCard(
                              rollup: r,
                              cs: cs,
                              tt: tt,
                              isTaxApply: isTaxApply,
                            ),
                          ),
                        ),
                      Text(
                        '월별 근무 건수',
                        style: tt.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: context.rsi(8)),
                      _ChartCard(
                        height: _chartHeight(context),
                        child: DashboardCountBarChart(
                          bottomLabels: data.chartLabels,
                          values: data.chartEntryCounts,
                          barColor: cs.tertiary,
                          valueLabel: '근무 건수',
                        ),
                      ),
                      SizedBox(height: context.rsi(8)),
                    ],
                  );
                },
              ),
      ),
    );
  }

  double _chartHeight(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return (w * 0.48).clamp(context.rs(220), context.rs(320));
  }
}

class _TodayMemoTile extends StatelessWidget {
  const _TodayMemoTile({
    required this.memo,
    required this.cs,
    required this.tt,
  });

  final ScheduleMemoRead memo;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    if (memo.isAssignment) {
      final rich = _dashMemoRichBlocks(memo);
      return Material(
        color: cs.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            context.rsi(14),
            context.rsi(12),
            context.rsi(14),
            context.rsi(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.work_outline_rounded, color: cs.primary),
                  SizedBox(width: context.rsi(10)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        scheduleMemoListTitleRow(
                          context,
                          title: memo.title.trim().isEmpty
                              ? '현장 배정'
                              : memo.title.trim(),
                          tasktimeRaw: memo.tasktime,
                          titleStyle: tt.titleSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            height: 1.25,
                          ),
                        ),
                        if (memo.workrole.trim().isNotEmpty) ...[
                          SizedBox(height: context.rsi(6)),
                          Text(
                            '역할 [${memo.workrole.trim()}]',
                            style: tt.bodySmall?.copyWith(
                              color: cs.tertiary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (rich.isNotEmpty) ...[
                SizedBox(height: context.rsi(10)),
                Text(
                  '작업 내용',
                  style: tt.labelMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                SizedBox(height: context.rsi(6)),
                Container(
                  padding: EdgeInsets.fromLTRB(
                    context.rsi(10),
                    context.rsi(8),
                    context.rsi(10),
                    context.rsi(8),
                  ),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLow.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: SizedBox(
                    height: context.rs(120),
                    child: WorkerAnnouncementBlocksDisplay(
                      blocks: rich,
                      suppressInteractiveImageMenu: true,
                      quillViewportMaxHeight: 118,
                    ),
                  ),
                ),
              ] else if (_dashMemoPlainVisible(memo, rich)) ...[
                SizedBox(height: context.rsi(8)),
                Text(
                  memo.memo.trim(),
                  style: tt.bodyMedium?.copyWith(height: 1.35),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Material(
      color: cs.surface.withValues(alpha: 0.94),
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          context.rsi(14),
          context.rsi(12),
          context.rsi(14),
          context.rsi(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.edit_note_outlined, color: cs.tertiary),
                SizedBox(width: context.rsi(10)),
                Expanded(
                  child: scheduleMemoListTitleRow(
                    context,
                    title: memo.title.trim().isEmpty
                        ? '(제목 없음)'
                        : memo.title.trim(),
                    tasktimeRaw: memo.tasktime,
                    titleStyle:
                        tt.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            if (memo.memo.trim().isNotEmpty) ...[
              SizedBox(height: context.rsi(8)),
              Text(
                memo.memo.trim(),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: tt.bodyMedium?.copyWith(height: 1.35),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WorkerDashboardTaxSegment extends StatelessWidget {
  const _WorkerDashboardTaxSegment({
    required this.taxState,
    required this.onChanged,
  });

  final TaxState taxState;
  final ValueChanged<TaxState?> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isTaxApply = taxState == TaxState.taxOn;
    return CupertinoSlidingSegmentedControl<TaxState>(
      groupValue: taxState,
      thumbColor: isTaxApply
          ? cs.errorContainer.withValues(alpha: 0.65)
          : cs.primaryContainer.withValues(alpha: 0.65),
      children: {
        TaxState.taxOff: Text(
          '세전',
          style: Theme.of(context).textTheme.labelMedium,
        ),
        TaxState.taxOn: Text(
          '세후',
          style: Theme.of(context).textTheme.labelMedium,
        ),
      },
      onValueChanged: onChanged,
    );
  }
}

class _PlaceRollupCard extends StatelessWidget {
  const _PlaceRollupCard({
    required this.rollup,
    required this.cs,
    required this.tt,
    required this.isTaxApply,
  });

  final WorkerDashboardPlaceRollup rollup;
  final ColorScheme cs;
  final TextTheme tt;
  final bool isTaxApply;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [
            cs.primaryContainer.withValues(alpha: 0.22),
            cs.surfaceContainerLow.withValues(alpha: 0.65),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          context.rsi(18),
          context.rsi(16),
          context.rsi(18),
          context.rsi(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.business_outlined,
                    color: cs.primary, size: context.rs(22)),
                SizedBox(width: context.rsi(10)),
                Expanded(
                  child: Text(
                    rollup.placeName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: tt.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: context.rsi(14)),
            Row(
              children: [
                Expanded(
                  child: _PlaceAmtPill(
                    label: '일한 금액',
                    value: rollup.workedTotal,
                    isTaxApply: isTaxApply,
                    emphasized: cs.onSurface,
                    tt: tt,
                    subtle: cs.onSurfaceVariant,
                  ),
                ),
                Expanded(
                  child: _PlaceAmtPill(
                    label: '정산 금액',
                    value: rollup.settledTotal,
                    isTaxApply: isTaxApply,
                    emphasized: cs.primary,
                    tt: tt,
                    subtle: cs.onSurfaceVariant,
                  ),
                ),
                Expanded(
                  child: _PlaceAmtPill(
                    label: '미정산 금액',
                    value: rollup.unsettledTotal,
                    isTaxApply: isTaxApply,
                    emphasized:
                        rollup.unsettledTotal > 0 ? cs.error : cs.onSurface,
                    tt: tt,
                    subtle: cs.onSurfaceVariant,
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

class _PlaceAmtPill extends StatelessWidget {
  const _PlaceAmtPill({
    required this.label,
    required this.value,
    required this.isTaxApply,
    required this.emphasized,
    required this.tt,
    required this.subtle,
  });

  final String label;
  final int value;
  final bool isTaxApply;
  final Color emphasized;
  final TextTheme tt;
  final Color subtle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.rsi(5)),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Theme.of(context)
                .colorScheme
                .outlineVariant
                .withValues(alpha: 0.42),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(context.rsi(10)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: tt.labelSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: subtle,
                  height: 1.15,
                ),
              ),
              SizedBox(height: context.rsi(6)),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  getPrice(price: value, isTaxApply: isTaxApply),
                  textAlign: TextAlign.center,
                  style: tt.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: emphasized,
                    letterSpacing: -0.2,
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

class _TotalsRow extends StatelessWidget {
  const _TotalsRow({
    required this.earned,
    required this.paid,
    required this.outstanding,
    required this.isTaxApply,
  });

  final int earned;
  final int paid;
  final int outstanding;
  final bool isTaxApply;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: _SummaryTile(
            label: '일한 금액',
            valueStr: getPrice(price: earned, isTaxApply: isTaxApply),
            tone: cs.onSurface,
          ),
        ),
        SizedBox(width: context.rsi(8)),
        Expanded(
          child: _SummaryTile(
            label: '정산 금액',
            valueStr: getPrice(price: paid, isTaxApply: isTaxApply),
            tone: cs.primary,
          ),
        ),
        SizedBox(width: context.rsi(8)),
        Expanded(
          child: _SummaryTile(
            label: '미정산 금액',
            valueStr: getPrice(price: outstanding, isTaxApply: isTaxApply),
            tone: cs.tertiary,
          ),
        ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.valueStr,
    required this.tone,
  });

  final String label;
  final String valueStr;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: context.rsi(10),
          vertical: context.rsi(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 2,
              style: tt.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                height: 1.15,
              ),
            ),
            SizedBox(height: context.rsi(6)),
            Text(
              valueStr,
              style: tt.titleSmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: tone,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerLow.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          context.rsi(10),
          context.rsi(12),
          context.rsi(10),
          context.rsi(8),
        ),
        child: SizedBox(height: height, child: child),
      ),
    );
  }
}

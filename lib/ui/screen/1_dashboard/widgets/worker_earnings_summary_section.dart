import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:w0001/data/model/worker_dashboard_models.dart';
import 'package:w0001/enums.dart';
import 'package:w0001/presentation/viewmodel/worker_personal_dashboard_notifier.dart';
import 'package:w0001/theme/app_elevation.dart';
import 'package:w0001/theme/app_theme_colors.dart';
import 'package:w0001/theme/app_section_card.dart';
import 'package:w0001/ui/screen/1_dashboard/widgets/dashboard_line_charts.dart';
import 'package:w0001/util/funtions.dart';
import 'package:w0001/util/responsive_layout.dart';

String _earningsAmount(int price, {required bool isTaxApply}) {
  return getPrice(
    price: price,
    isTaxApply: isTaxApply,
    isContainWon: false,
  );
}

/// 근로·정산 화면 금액 공통 — 숫자만 표시, 단위는 섹션 상단 안내.
class _EarningsUnitCaption extends StatelessWidget {
  const _EarningsUnitCaption();

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerRight,
      child: Text(
        '(단위: 원)',
        style: tt.labelSmall?.copyWith(
          color: cs.onSurfaceVariant.withValues(alpha: 0.88),
          fontWeight: FontWeight.w600,
          letterSpacing: -0.1,
        ),
      ),
    );
  }
}

/// 설정 탭 — 근로·정산 요약 (기간별 합계, 현장별 투입, 월별 근무 건수).
class WorkerEarningsSummarySection extends ConsumerStatefulWidget {
  const WorkerEarningsSummarySection({super.key});

  @override
  ConsumerState<WorkerEarningsSummarySection> createState() =>
      _WorkerEarningsSummarySectionState();
}

class _WorkerEarningsSummarySectionState
    extends ConsumerState<WorkerEarningsSummarySection> {
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

  double _chartHeight(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return (w * 0.48).clamp(context.rs(220), context.rs(320));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tt = theme.textTheme;
    final cs = theme.colorScheme;
    final query = ref.watch(workerDashboardQueryProvider);
    final taxState = ref.watch(workerDashboardTaxStateProvider);
    final isTaxApply = taxState.isTaxApply;
    final asyncData = ref.watch(workerPersonalDashboardProvider);

    return asyncData.when(
      loading: () =>
          _EarningsSkeleton(cs: cs, tt: tt, chartHeight: _chartHeight(context)),
      error: (e, _) => Padding(
        padding: EdgeInsets.symmetric(vertical: context.rsi(12)),
        child: Text(
          e.toString(),
          style: tt.bodyMedium?.copyWith(color: cs.error),
        ),
      ),
      data: (data) {
        if (data.skippedNonWorker) {
          return const SizedBox.shrink();
        }

        final monthly = query.isMonthly;
        final mt = data.displayMonthTotals;
        final yt = data.displayYearTotals;
        final rollups = data.placeRollups;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (data.missingHumanLink) ...[
              AppInsetTile(
                backgroundColor: cs.appIconBadge,
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
              SizedBox(height: context.rsi(16)),
            ],
            AppSectionCard(
              icon: Icons.payments_outlined,
              title: '근로·정산',
              subtitle: data.periodCaption,
              trailing: TextButton.icon(
                onPressed: () => _pickPeriod(context),
                icon: Icon(Icons.tune, size: context.rs(18)),
                label: Text(
                  monthly ? '월별' : '연간',
                  style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: isTaxApply
                            ? cs.errorContainer.withValues(alpha: 0.45)
                            : cs.primaryContainer.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: context.rsi(10),
                          vertical: context.rsi(5),
                        ),
                        child: Text(
                          isTaxApply ? '세후 표시 (3.3% 반영)' : '세전 표시 (계약 일당 기준)',
                          style: tt.labelSmall?.copyWith(
                            color: isTaxApply
                                ? cs.onErrorContainer
                                : cs.onPrimaryContainer,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: context.rsi(12)),
                  const _EarningsUnitCaption(),
                  SizedBox(height: context.rsi(8)),
                  if (mt != null) ...[
                    _EarningsTopSummaryStrip(
                      label: monthly ? '이번 달 예상 수령' : '누적 예상 수령',
                      amount: mt.totalEarned,
                      isTaxApply: isTaxApply,
                    ),
                    SizedBox(height: context.rsi(10)),
                    Text(
                      monthly ? '선택한 달 합계' : '합계',
                      style: tt.labelMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: cs.onSurfaceVariant,
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
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    SizedBox(height: context.rsi(8)),
                    _TotalsRow(
                      earned: yt.totalEarned,
                      paid: yt.totalPaid,
                      outstanding: yt.totalOutstanding,
                      isTaxApply: isTaxApply,
                    ),
                  ],
                  if (!monthly && yt != null)
                    _TotalsRow(
                      earned: yt.totalEarned,
                      paid: yt.totalPaid,
                      outstanding: yt.totalOutstanding,
                      isTaxApply: isTaxApply,
                    ),
                ],
              ),
            ),
            SizedBox(height: context.rsi(16)),
            AppSectionCard(
              icon: Icons.maps_home_work_outlined,
              title: '현장별 투입 금액',
              subtitle: data.placeRollupsPeriodLabel,
              trailing: Text(
                '${rollups.length}곳',
                style: tt.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.onSurfaceVariant,
                ),
              ),
              child: rollups.isEmpty && !data.missingHumanLink
                  ? Padding(
                      padding: EdgeInsets.symmetric(vertical: context.rsi(20)),
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
                  : Column(
                      children: rollups
                          .map(
                            (r) => Padding(
                              padding: EdgeInsets.only(bottom: context.rsi(10)),
                              child: _PlaceRollupCard(
                                rollup: r,
                                cs: cs,
                                tt: tt,
                                isTaxApply: isTaxApply,
                              ),
                            ),
                          )
                          .toList(),
                    ),
            ),
            SizedBox(height: context.rsi(16)),
            AppSectionCard(
              icon: Icons.bar_chart_rounded,
              title: '월별 근무 건수',
              child: _ChartCard(
                height: _chartHeight(context),
                child: DashboardCountBarChart(
                  bottomLabels: data.chartLabels,
                  values: data.chartEntryCounts,
                  barColor: cs.tertiary,
                  valueLabel: '근무 건수',
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _EarningsSkeleton extends StatelessWidget {
  const _EarningsSkeleton({
    required this.cs,
    required this.tt,
    required this.chartHeight,
  });

  final ColorScheme cs;
  final TextTheme tt;
  final double chartHeight;

  @override
  Widget build(BuildContext context) {
    const rollup = WorkerDashboardPlaceRollup(
      pid: 0,
      placeName: '현장 이름',
      workedTotal: 2400000,
      settledTotal: 1800000,
      unsettledTotal: 120000,
    );
    return Skeletonizer(
      enabled: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '조회 구간',
                  style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              TextButton.icon(
                onPressed: null,
                icon: Icon(Icons.tune, size: context.rs(18)),
                label: const Text('연간'),
              ),
            ],
          ),
          SizedBox(height: context.rsi(12)),
          const _TotalsRow(
            earned: 12500000,
            paid: 9200000,
            outstanding: 3300000,
            isTaxApply: true,
          ),
          SizedBox(height: context.rsi(14)),
          _PlaceRollupCard(
            rollup: rollup,
            cs: cs,
            tt: tt,
            isTaxApply: true,
          ),
          SizedBox(height: context.rsi(14)),
          _ChartCard(
            height: chartHeight,
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
        ],
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

class _EarningsTopSummaryStrip extends StatelessWidget {
  const _EarningsTopSummaryStrip({
    required this.label,
    required this.amount,
    required this.isTaxApply,
  });

  final String label;
  final int amount;
  final bool isTaxApply;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return AppInsetTile(
      borderRadius: BorderRadius.circular(14),
      padding: EdgeInsets.fromLTRB(
        context.rsi(12),
        context.rsi(10),
        context.rsi(12),
        context.rsi(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: tt.labelMedium?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            _earningsAmount(amount, isTaxApply: isTaxApply),
            style: tt.titleMedium?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.2,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
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
    return AppInsetTile(
      borderRadius: BorderRadius.circular(18),
      padding: EdgeInsets.fromLTRB(
        context.rsi(16),
        context.rsi(14),
        context.rsi(16),
        context.rsi(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.business_outlined,
                  color: cs.primary, size: context.rs(20)),
              SizedBox(width: context.rsi(10)),
              Expanded(
                child: Text(
                  rollup.placeName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: tt.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: context.rsi(12)),
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
              SizedBox(width: context.rsi(8)),
              Expanded(
                child: _PlaceAmtPill(
                  label: '정산액',
                  value: rollup.settledTotal,
                  isTaxApply: isTaxApply,
                  emphasized: cs.primary,
                  tt: tt,
                  subtle: cs.onSurfaceVariant,
                ),
              ),
              SizedBox(width: context.rsi(8)),
              Expanded(
                child: _PlaceAmtPill(
                  label: '미정산액',
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
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.rsi(5)),
      child: DecoratedBox(
        decoration: AppElevation.insetTile(
          context: context,
          backgroundColor: cs.appMutedFill,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.rsi(8),
            vertical: context.rsi(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                style: tt.labelSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: subtle,
                  height: 1.1,
                  letterSpacing: -0.2,
                ),
              ),
              SizedBox(height: context.rsi(6)),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _earningsAmount(value, isTaxApply: isTaxApply),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: tt.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: emphasized,
                    letterSpacing: -0.35,
                    height: 1.0,
                    fontFeatures: const [FontFeature.tabularFigures()],
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
            value: earned,
            isTaxApply: isTaxApply,
            tone: cs.onSurface,
          ),
        ),
        SizedBox(width: context.rsi(8)),
        Expanded(
          child: _SummaryTile(
            label: '정산액',
            value: paid,
            isTaxApply: isTaxApply,
            tone: cs.primary,
          ),
        ),
        SizedBox(width: context.rsi(8)),
        Expanded(
          child: _SummaryTile(
            label: '미정산액',
            value: outstanding,
            isTaxApply: isTaxApply,
            tone: outstanding > 0 ? cs.error : cs.onSurface,
          ),
        ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.value,
    required this.isTaxApply,
    required this.tone,
  });

  final String label;
  final int value;
  final bool isTaxApply;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return AppInsetTile(
      borderRadius: BorderRadius.circular(16),
      padding: EdgeInsets.symmetric(
        horizontal: context.rsi(8),
        vertical: context.rsi(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            maxLines: 1,
            textAlign: TextAlign.center,
            style: tt.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              height: 1.1,
              letterSpacing: -0.2,
            ),
          ),
          SizedBox(height: context.rsi(6)),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              _earningsAmount(value, isTaxApply: isTaxApply),
              maxLines: 1,
              textAlign: TextAlign.center,
              style: tt.titleSmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: tone,
                letterSpacing: -0.35,
                height: 1.0,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
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
    return AppInsetTile(
      borderRadius: BorderRadius.circular(12),
      padding: EdgeInsets.fromLTRB(
        context.rsi(10),
        context.rsi(12),
        context.rsi(10),
        context.rsi(8),
      ),
      child: SizedBox(height: height, child: child),
    );
  }
}

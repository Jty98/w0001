import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:w0001/data/model/dashboard_models.dart';
import 'package:w0001/data/model/monthly_summary_model.dart';
import 'package:w0001/presentation/viewmodel/place_list_view_model.dart';
import 'package:w0001/ui/screen/1_dashboard/widgets/dashboard_legend.dart';
import 'package:w0001/ui/screen/1_dashboard/widgets/dashboard_line_charts.dart';
import 'package:w0001/util/funtions.dart';

/// 영업이익(선·면) — 청록 / 이익률(선) — 딥퍼플 (primary·indigo와 겹쳐 보이지 않게 구분)
/// 영업이익 차트: 막대·범례용(밝은 배경에서도 식별 용이)
const Color _kProfitMoneyChartColor = Color(0xFF00897B);
const Color _kProfitMarginChartColor = Color(0xFF8E24AA);

/// 요약 카드에서 열 수 있는 지표별 차트 종류.
enum DashboardMetricKind {
  /// 공사금액(총액) 추이 — 데이터상 `contract` 집계와 동일.
  construction,
  cost,
  collection,

  /// 완료 공사만: Σ(공사금액−현장원가) 추이 + 공사금액 대비 이익률.
  profitAndMargin,
  siteCounts,
}

enum DashboardPlaceBreakdownFilter { all, inProgress, completed }

Future<void> showDashboardMetricChartSheet(
  BuildContext context, {
  required DashboardMetricKind kind,
  required int selectedYear,
  required List<MonthlySummaryModel> monthly,
  required List<YearlyDashboardPoint> yearly,
  required List<DashboardPlaceRow> places,
  DashboardPlaceBreakdownFilter initialPlaceFilter =
      DashboardPlaceBreakdownFilter.all,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) {
      return _DashboardMetricChartSheetBody(
        kind: kind,
        selectedYear: selectedYear,
        monthly: monthly,
        yearly: yearly,
        places: places,
        initialPlaceFilter: initialPlaceFilter,
      );
    },
  );
}

class _DashboardMetricChartSheetBody extends ConsumerStatefulWidget {
  const _DashboardMetricChartSheetBody({
    required this.kind,
    required this.selectedYear,
    required this.monthly,
    required this.yearly,
    required this.places,
    required this.initialPlaceFilter,
  });

  final DashboardMetricKind kind;
  final int selectedYear;
  final List<MonthlySummaryModel> monthly;
  final List<YearlyDashboardPoint> yearly;
  final List<DashboardPlaceRow> places;
  final DashboardPlaceBreakdownFilter initialPlaceFilter;

  @override
  ConsumerState<_DashboardMetricChartSheetBody> createState() =>
      _DashboardMetricChartSheetBodyState();
}

enum _SheetPeriod { monthly, yearly }

class _DashboardMetricChartSheetBodyState
    extends ConsumerState<_DashboardMetricChartSheetBody> {
  _SheetPeriod _period = _SheetPeriod.monthly;
  late DashboardPlaceBreakdownFilter _placeFilter;

  @override
  void initState() {
    super.initState();
    _placeFilter = widget.initialPlaceFilter;
  }

  double _chartHeight(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return (w * 0.52).clamp(240.0, 380.0);
  }

  String get _titleBase {
    switch (widget.kind) {
      case DashboardMetricKind.construction:
        return '공사금액 추이';
      case DashboardMetricKind.collection:
        return '수금액 추이';
      case DashboardMetricKind.cost:
        return '공사원가 추이';
      case DashboardMetricKind.profitAndMargin:
        return '영업이익(공사금액-공사원가) · 이익률';
      case DashboardMetricKind.siteCounts:
        return '현장 현황 (진행중·완료)';
    }
  }

  List<Widget> _chartsForPeriod(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final monthLabels = List<String>.generate(12, (i) => '${i + 1}');
    final yearLabels = widget.yearly.map((e) => '${e.year}').toList();
    final m = widget.monthly;
    final y = widget.yearly;
    final h = _chartHeight(context);

    if (_period == _SheetPeriod.monthly) {
      switch (widget.kind) {
        case DashboardMetricKind.construction:
          return [
            DashboardLegend(
              items: [
                DashboardLegendItem(label: '공사금액', color: cs.tertiary),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: h,
              child: DashboardLineChart(
                bottomLabels: monthLabels,
                series: [
                  DashboardLineSeries(
                    label: '공사금액',
                    color: cs.tertiary,
                    values: m.map((e) => e.contractAmount.toDouble()).toList(),
                  ),
                ],
              ),
            ),
          ];
        case DashboardMetricKind.collection:
          return [
            DashboardLegend(
              items: [
                DashboardLegendItem(
                  label: '수금액',
                  color: Colors.teal[700]!,
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: h,
              child: DashboardLineChart(
                bottomLabels: monthLabels,
                series: [
                  DashboardLineSeries(
                    label: '수금액',
                    color: Colors.teal[700]!,
                    values:
                        m.map((e) => e.collectionAmount.toDouble()).toList(),
                  ),
                ],
              ),
            ),
          ];
        case DashboardMetricKind.cost:
          return [
            DashboardLegend(
              items: [
                DashboardLegendItem(
                  label: '공사원가',
                  color: Colors.orange[700]!,
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: h,
              child: DashboardLineChart(
                bottomLabels: monthLabels,
                series: [
                  DashboardLineSeries(
                    label: '공사원가',
                    color: Colors.orange[700]!,
                    values: m.map((e) => e.costAmount.toDouble()).toList(),
                  ),
                ],
              ),
            ),
          ];
        case DashboardMetricKind.profitAndMargin:
          return [
            DashboardLegend(
              items: [
                DashboardLegendItem(
                  label: '영업이익',
                  color: _kProfitMoneyChartColor,
                ),
                DashboardLegendItem(
                  label: '이익률',
                  color: _kProfitMarginChartColor,
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: h,
              child: DashboardLineChartMoneyAndPercent(
                bottomLabels: monthLabels,
                moneyValues:
                    m.map((e) => e.completedProfitAmount.toDouble()).toList(),
                percentValues:
                    m.map((e) => e.completedContractMarginPct).toList(),
                moneyColor: _kProfitMoneyChartColor,
                percentColor: _kProfitMarginChartColor,
              ),
            ),
          ];
        case DashboardMetricKind.siteCounts:
          return [
            DashboardLegend(
              items: [
                DashboardLegendItem(
                  label: '진행중 현장(건)',
                  color: cs.primaryContainer,
                ),
                DashboardLegendItem(
                  label: '완료 현장(건)',
                  color: cs.secondaryContainer,
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: h,
              child: DashboardLineChart(
                bottomLabels: monthLabels,
                integerYAxis: true,
                series: [
                  DashboardLineSeries(
                    label: '진행중',
                    color: cs.primaryContainer,
                    values: m
                        .map((e) =>
                            (e.newProjectCount - e.completedProjectCount)
                                .clamp(0, 1 << 20)
                                .toDouble())
                        .toList(),
                  ),
                  DashboardLineSeries(
                    label: '완료',
                    color: cs.secondaryContainer,
                    values: m
                        .map((e) => e.completedProjectCount.toDouble())
                        .toList(),
                  ),
                ],
              ),
            ),
          ];
      }
    }

    switch (widget.kind) {
      case DashboardMetricKind.construction:
        return [
          DashboardLegend(
            items: [
              DashboardLegendItem(label: '공사금액', color: cs.tertiary),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: h,
            child: DashboardLineChart(
              bottomLabels: yearLabels,
              series: [
                DashboardLineSeries(
                  label: '공사금액',
                  color: cs.tertiary,
                  values: y.map((e) => e.contractTotal.toDouble()).toList(),
                ),
              ],
            ),
          ),
        ];
      case DashboardMetricKind.collection:
        return [
          DashboardLegend(
            items: [
              DashboardLegendItem(
                label: '수금액',
                color: Colors.teal[700]!,
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: h,
            child: DashboardLineChart(
              bottomLabels: yearLabels,
              series: [
                DashboardLineSeries(
                  label: '수금액',
                  color: Colors.teal[700]!,
                  values: y.map((e) => e.collectionTotal.toDouble()).toList(),
                ),
              ],
            ),
          ),
        ];
      case DashboardMetricKind.cost:
        return [
          DashboardLegend(
            items: [
              DashboardLegendItem(
                label: '공사원가',
                color: Colors.orange[700]!,
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: h,
            child: DashboardLineChart(
              bottomLabels: yearLabels,
              series: [
                DashboardLineSeries(
                  label: '공사원가',
                  color: Colors.orange[700]!,
                  values: y.map((e) => e.costTotal.toDouble()).toList(),
                ),
              ],
            ),
          ),
        ];
      case DashboardMetricKind.profitAndMargin:
        return [
          DashboardLegend(
            items: [
              DashboardLegendItem(
                label: '영업이익',
                color: _kProfitMoneyChartColor,
              ),
              DashboardLegendItem(
                label: '이익률',
                color: _kProfitMarginChartColor,
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: h,
            child: DashboardLineChartMoneyAndPercent(
              bottomLabels: yearLabels,
              moneyValues:
                  y.map((e) => e.completedProfitTotal.toDouble()).toList(),
              percentValues: y.map((e) => e.completedContractMarginPct).toList(),
              moneyColor: _kProfitMoneyChartColor,
              percentColor: _kProfitMarginChartColor,
            ),
          ),
        ];
      case DashboardMetricKind.siteCounts:
        return [
          DashboardLegend(
            items: [
              DashboardLegendItem(
                label: '진행중 현장(건)',
                color: cs.primaryContainer,
              ),
              DashboardLegendItem(
                label: '완료 현장(건)',
                color: cs.secondaryContainer,
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: h,
            child: DashboardLineChart(
              bottomLabels: yearLabels,
              integerYAxis: true,
              series: [
                DashboardLineSeries(
                  label: '진행중',
                  color: cs.primaryContainer,
                  values: y
                      .map((e) => (e.newProjectCount - e.completedProjectCount)
                          .clamp(0, 1 << 20)
                          .toDouble())
                      .toList(),
                ),
                DashboardLineSeries(
                  label: '완료',
                  color: cs.secondaryContainer,
                  values:
                      y.map((e) => e.completedProjectCount.toDouble()).toList(),
                ),
              ],
            ),
          ),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final placeState = ref.watch(placeListProvider);
    final placeByPid = <int, dynamic>{};
    for (final p in placeState.placeList) {
      if (p.pid != null) {
        placeByPid[p.pid!] = p;
      }
    }
    final placeCompleteByPid = <int, int>{};
    for (final p in placeState.placeList) {
      if (p.pid != null) {
        placeCompleteByPid[p.pid!] = p.pcomplete;
      }
    }
    final visibleRows = widget.places.where((row) {
      final complete = placeCompleteByPid[row.pid] ?? 0;
      switch (_placeFilter) {
        case DashboardPlaceBreakdownFilter.all:
          return true;
        case DashboardPlaceBreakdownFilter.inProgress:
          return complete == 0;
        case DashboardPlaceBreakdownFilter.completed:
          return complete == 1;
      }
    }).toList()
      ..sort((a, b) => _metricValue(b).compareTo(_metricValue(a)));
    final inProgressRows = visibleRows
        .where((r) => (placeCompleteByPid[r.pid] ?? 0) == 0)
        .toList();
    final completedRows = visibleRows
        .where((r) => (placeCompleteByPid[r.pid] ?? 0) == 1)
        .toList();
    final yearLabels = widget.yearly.map((e) => '${e.year}').toList();
    final periodNote = _period == _SheetPeriod.monthly
        ? '${widget.selectedYear}년 월별'
        : '선택 연도를 끝으로 최근 ${yearLabels.length}년';
    final showCharts = widget.kind != DashboardMetricKind.siteCounts &&
        widget.kind != DashboardMetricKind.collection;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.paddingOf(context).bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _titleBase,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
            ),
            if (showCharts) ...[
              const SizedBox(height: 4),
              Text(
                periodNote,
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              SegmentedButton<_SheetPeriod>(
                segments: const [
                  ButtonSegment<_SheetPeriod>(
                    value: _SheetPeriod.monthly,
                    label: Text('월별'),
                    icon: Icon(Icons.calendar_view_month, size: 18),
                  ),
                  ButtonSegment<_SheetPeriod>(
                    value: _SheetPeriod.yearly,
                    label: Text('연도별'),
                    icon: Icon(Icons.timeline, size: 18),
                  ),
                ],
                selected: {_period},
                style: SegmentedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onSelectionChanged: (Set<_SheetPeriod> next) {
                  if (next.isEmpty) return;
                  setState(() => _period = next.first);
                },
              ),
              const SizedBox(height: 12),
              ..._chartsForPeriod(context),
            ],
            const SizedBox(height: 16),
            Text(
              '현장별 상세',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<DashboardPlaceBreakdownFilter>(
              segments: const [
                ButtonSegment(
                  value: DashboardPlaceBreakdownFilter.all,
                  label: Text('전체'),
                ),
                ButtonSegment(
                  value: DashboardPlaceBreakdownFilter.inProgress,
                  label: Text('진행중'),
                ),
                ButtonSegment(
                  value: DashboardPlaceBreakdownFilter.completed,
                  label: Text('완료'),
                ),
              ],
              selected: {_placeFilter},
              style: SegmentedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onSelectionChanged: (next) {
                if (next.isEmpty) return;
                setState(() => _placeFilter = next.first);
              },
            ),
            const SizedBox(height: 8),
            if (visibleRows.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  '조건에 맞는 현장이 없습니다.',
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else ...[
              if (_placeFilter == DashboardPlaceBreakdownFilter.all) ...[
                if (inProgressRows.isNotEmpty)
                  _buildPlaceSection(
                    context,
                    title: '진행중',
                    rows: inProgressRows,
                    placeByPid: placeByPid,
                  ),
                if (inProgressRows.isNotEmpty && completedRows.isNotEmpty)
                  const SizedBox(height: 10),
                if (completedRows.isNotEmpty)
                  _buildPlaceSection(
                    context,
                    title: '완료',
                    rows: completedRows,
                    placeByPid: placeByPid,
                  ),
              ] else
                _buildPlaceSection(
                  context,
                  title:
                      _placeFilter == DashboardPlaceBreakdownFilter.inProgress
                          ? '진행중'
                          : '완료',
                  rows: visibleRows,
                  placeByPid: placeByPid,
                ),
            ],
          ],
        ),
      ),
    );
  }

  int _metricValue(DashboardPlaceRow row) {
    switch (widget.kind) {
      case DashboardMetricKind.construction:
        return row.contractTotal;
      case DashboardMetricKind.cost:
        return row.costTotal;
      case DashboardMetricKind.collection:
        return row.collected;
      case DashboardMetricKind.profitAndMargin:
        return row.profitOnContract;
      case DashboardMetricKind.siteCounts:
        return 0;
    }
  }

  String _rowSubtitle(DashboardPlaceRow row) {
    switch (widget.kind) {
      case DashboardMetricKind.construction:
        return '공사 ${getPrice(price: row.contractTotal)}';
      case DashboardMetricKind.cost:
        return '원가 ${getPrice(price: row.costTotal)}';
      case DashboardMetricKind.collection:
        return '';
      case DashboardMetricKind.profitAndMargin:
        return '영업이익 ${getPrice(price: row.profitOnContract)} · '
            '이익률 ${row.marginOnContractPct.toStringAsFixed(1)}%';
      case DashboardMetricKind.siteCounts:
        return '공사 ${getPrice(price: row.contractTotal)} · '
            '원가 ${getPrice(price: row.costTotal)} · '
            '영업이익 ${getPrice(price: row.profitOnContract)}';
    }
  }

  /// 차트·범례와 동일한 톤으로 부제목 줄 앞 점 색을 맞춤.
  Color _subtitleBulletColor(ColorScheme cs, String lineText) {
    final t = lineText.trim();
    if (t.startsWith('이익률')) return _kProfitMarginChartColor;
    if (t.startsWith('영업이익')) return _kProfitMoneyChartColor;
    if (t.startsWith('원가')) return Colors.orange[700]!;
    if (t.startsWith('공사')) return cs.tertiary;
    switch (widget.kind) {
      case DashboardMetricKind.construction:
        return cs.tertiary;
      case DashboardMetricKind.cost:
        return Colors.orange[700]!;
      case DashboardMetricKind.profitAndMargin:
        return _kProfitMoneyChartColor;
      case DashboardMetricKind.siteCounts:
        return cs.tertiary;
      case DashboardMetricKind.collection:
        return cs.primary;
    }
  }

  Widget _rowSubtitleWidget(DashboardPlaceRow row, ColorScheme cs) {
    if (widget.kind != DashboardMetricKind.collection) {
      final items = _rowSubtitle(row)
          .split(' · ')
          .where((e) => e.trim().isNotEmpty)
          .toList();

      final metricPriceText = getPrice(price: _metricValue(row));
      final isDuplicatedSingleMetric =
          items.length == 1 && items.first.contains(metricPriceText);
      if (isDuplicatedSingleMetric) {
        return const SizedBox.shrink();
      }

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
        ),
        child: Column(
          children: items.asMap().entries.map((entry) {
            final i = entry.key;
            final text = entry.value;
            return Padding(
              padding: EdgeInsets.only(bottom: i == items.length - 1 ? 0 : 6),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: _subtitleBulletColor(cs, text),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      text,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      );
    }

    final detailRows = row.balanceBreakdown
        .split('\n')
        .where((e) => e.trim().isNotEmpty)
        .map(_toCollectionDetail)
        .whereType<_CollectionDetail>()
        .toList()
      ..sort((a, b) {
        final ao = _kindOrder(a.kind);
        final bo = _kindOrder(b.kind);
        if (ao != bo) return ao.compareTo(bo);
        final ad = parseFlexibleDateString(a.date);
        final bd = parseFlexibleDateString(b.date);
        final dc = ad.compareTo(bd);
        if (dc != 0) return dc;
        return a.amount.compareTo(b.amount);
      });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _summaryStatTile(
                cs,
                label: '공사원금',
                value: getPrice(price: row.contractTotal),
                backgroundColor: Colors.indigo.withValues(alpha: 0.14),
                labelColor: Colors.indigo[800],
                valueColor: Colors.indigo[900],
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _summaryStatTile(
                cs,
                label: '선수금',
                value: getPrice(price: row.advanceCollected),
                backgroundColor: Colors.teal.withValues(alpha: 0.14),
                labelColor: Colors.teal[800],
                valueColor: Colors.teal[900],
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _summaryStatTile(
                cs,
                label: '미수금',
                value: getPrice(price: row.outstanding),
                backgroundColor: Colors.deepOrange.withValues(alpha: 0.14),
                labelColor: Colors.deepOrange[800],
                valueColor: Colors.deepOrange[900],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (detailRows.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '잔금 내역 없음',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: cs.onSurfaceVariant,
              ),
            ),
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(8),
              border:
                  Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
            ),
            child: Column(
              children: detailRows.asMap().entries.map((entry) {
                final i = entry.key;
                final d = entry.value;
                return Padding(
                  padding: EdgeInsets.only(
                      bottom: i == detailRows.length - 1 ? 0 : 6),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 34,
                        child: Text(
                          '${i + 1}차',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: cs.primary,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          _formatMonthDay(d.date),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Text(
                        getPrice(price: d.amount),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: cs.onSurface,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _summaryStatTile(
    ColorScheme cs, {
    required String label,
    required String value,
    Color? backgroundColor,
    Color? labelColor,
    Color? valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor ?? cs.secondaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color:
                  labelColor ?? cs.onSecondaryContainer.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: valueColor ?? cs.onSecondaryContainer,
            ),
          ),
        ],
      ),
    );
  }

  int _kindOrder(String kind) {
    final k = kind.trim();
    final n = RegExp(r'(\d+)').firstMatch(k);
    if (n != null) {
      return int.tryParse(n.group(1) ?? '') ?? 9999;
    }
    if (k.contains('잔금')) return 9000;
    return 9500;
  }

  String _formatMonthDay(String isoDate) {
    if (isoDate.trim().isEmpty) return '-';
    final d = parseFlexibleDateString(isoDate);
    return '${d.year}년 ${d.month}월 ${d.day}일';
  }

  _CollectionDetail? _toCollectionDetail(String raw) {
    final parts = raw.split('|');
    if (parts.length < 3) return null;
    final amount = int.tryParse(parts[2].trim());
    if (amount == null) return null;
    final kind = parts[1].trim().isEmpty ? '잔금' : parts[1].trim();
    return _CollectionDetail(
      date: parts[0].trim(),
      kind: kind,
      amount: amount,
    );
  }

  Widget _buildPlaceSection(
    BuildContext context, {
    required String title,
    required List<DashboardPlaceRow> rows,
    required Map<int, dynamic> placeByPid,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.45)),
      ),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '$title (${rows.length}곳)',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          ...rows.take(30).map(
                (row) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Material(
                    color: cs.surface.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () =>
                          _openPlaceDetail(context, placeByPid, row.pid),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          row.pname,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      if (widget.kind !=
                                          DashboardMetricKind.siteCounts)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(left: 8),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: cs.primaryContainer,
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: Text(
                                              getPrice(price: _metricValue(row)),
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w800,
                                                color: cs.onPrimaryContainer,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  _rowSubtitleWidget(row, cs),
                                ],
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
                              color: cs.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  void _openPlaceDetail(
    BuildContext context,
    Map<int, dynamic> placeByPid,
    int pid,
  ) {
    final info = placeByPid[pid];
    Navigator.of(context).pop();
    if (info != null) {
      final targetPath = widget.kind == DashboardMetricKind.collection
          ? '/place/detail/revenue'
          : '/place/detail';
      context.push(targetPath, extra: info);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('현장 목록을 불러온 뒤 다시 시도해 주세요.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

class _CollectionDetail {
  final String date;
  final String kind;
  final int amount;

  const _CollectionDetail({
    required this.date,
    required this.kind,
    required this.amount,
  });
}

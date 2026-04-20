import 'package:flutter/material.dart';
import 'package:w0001/data/model/dashboard_models.dart';
import 'package:w0001/data/model/monthly_summary_model.dart';
import 'package:w0001/ui/screen/1_dashboard/widgets/dashboard_legend.dart';
import 'package:w0001/ui/screen/1_dashboard/widgets/dashboard_line_charts.dart';

/// 요약 카드에서 열 수 있는 지표별 차트 종류.
enum DashboardMetricKind {
  /// 공사금액(총액) 추이 — 데이터상 `contract` 집계와 동일.
  construction,
  collection,
  /// 완료 공사만: Σ(공사금액−현장원가) 추이 + 공사금액 대비 이익률.
  profitAndMargin,
  siteCounts,
}

Future<void> showDashboardMetricChartSheet(
  BuildContext context, {
  required DashboardMetricKind kind,
  required int selectedYear,
  required List<MonthlySummaryModel> monthly,
  required List<YearlyDashboardPoint> yearly,
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
      );
    },
  );
}

class _DashboardMetricChartSheetBody extends StatefulWidget {
  const _DashboardMetricChartSheetBody({
    required this.kind,
    required this.selectedYear,
    required this.monthly,
    required this.yearly,
  });

  final DashboardMetricKind kind;
  final int selectedYear;
  final List<MonthlySummaryModel> monthly;
  final List<YearlyDashboardPoint> yearly;

  @override
  State<_DashboardMetricChartSheetBody> createState() =>
      _DashboardMetricChartSheetBodyState();
}

enum _SheetPeriod { monthly, yearly }

class _DashboardMetricChartSheetBodyState
    extends State<_DashboardMetricChartSheetBody> {
  _SheetPeriod _period = _SheetPeriod.monthly;

  double _chartHeight(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return (w * 0.52).clamp(240.0, 380.0);
  }

  double _marginChartHeight(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return (w * 0.32).clamp(152.0, 220.0);
  }

  String get _titleBase {
    switch (widget.kind) {
      case DashboardMetricKind.construction:
        return '공사금액 추이';
      case DashboardMetricKind.collection:
        return '수금액 추이';
      case DashboardMetricKind.profitAndMargin:
        return '완료 공사 영업이익 · 이익률';
      case DashboardMetricKind.siteCounts:
        return '현장 건수 (신규·완료)';
    }
  }

  List<Widget> _chartsForPeriod(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final monthLabels = List<String>.generate(12, (i) => '${i + 1}');
    final yearLabels = widget.yearly.map((e) => '${e.year}').toList();
    final m = widget.monthly;
    final y = widget.yearly;
    final h = _chartHeight(context);
    final hMargin = _marginChartHeight(context);

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
        case DashboardMetricKind.profitAndMargin:
          return [
            DashboardLegend(
              items: [
                DashboardLegendItem(
                  label: '완료 공사 영업이익',
                  color: cs.primary,
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
                    label: '완료 공사 영업이익',
                    color: cs.primary,
                    values:
                        m.map((e) => e.completedProfitAmount.toDouble()).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            DashboardLegend(
              items: [
                DashboardLegendItem(
                  label: '이익률',
                  color: Colors.indigo[700]!,
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: hMargin,
              child: DashboardLineChart(
                bottomLabels: monthLabels,
                yAxisIsPercent: true,
                series: [
                  DashboardLineSeries(
                    label: '이익률',
                    color: Colors.indigo[700]!,
                    values: m.map((e) => e.completedContractMarginPct).toList(),
                  ),
                ],
              ),
            ),
          ];
        case DashboardMetricKind.siteCounts:
          return [
            DashboardLegend(
              items: [
                DashboardLegendItem(
                  label: '신규 공사(건)',
                  color: cs.primaryContainer,
                ),
                DashboardLegendItem(
                  label: '완료(건)',
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
                    label: '신규 공사',
                    color: cs.primaryContainer,
                    values: m.map((e) => e.newProjectCount.toDouble()).toList(),
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
      case DashboardMetricKind.profitAndMargin:
        return [
          DashboardLegend(
            items: [
              DashboardLegendItem(
                label: '완료 공사 영업이익',
                color: cs.primary,
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
                  label: '완료 공사 영업이익',
                  color: cs.primary,
                  values:
                      y.map((e) => e.completedProfitTotal.toDouble()).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          DashboardLegend(
            items: [
              DashboardLegendItem(
                label: '이익률',
                color: Colors.indigo[700]!,
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: hMargin,
            child: DashboardLineChart(
              bottomLabels: yearLabels,
              yAxisIsPercent: true,
              series: [
                DashboardLineSeries(
                  label: '이익률',
                  color: Colors.indigo[700]!,
                  values: y.map((e) => e.completedContractMarginPct).toList(),
                ),
              ],
            ),
          ),
        ];
      case DashboardMetricKind.siteCounts:
        return [
          DashboardLegend(
            items: [
              DashboardLegendItem(
                label: '신규 공사(건)',
                color: cs.primaryContainer,
              ),
              DashboardLegendItem(
                label: '완료(건)',
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
                  label: '신규 공사',
                  color: cs.primaryContainer,
                  values: y.map((e) => e.newProjectCount.toDouble()).toList(),
                ),
                DashboardLineSeries(
                  label: '완료',
                  color: cs.secondaryContainer,
                  values: y.map((e) => e.completedProjectCount.toDouble()).toList(),
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
    final yearLabels = widget.yearly.map((e) => '${e.year}').toList();
    final periodNote = _period == _SheetPeriod.monthly
        ? '${widget.selectedYear}년 월별'
        : '선택 연도를 끝으로 최근 ${yearLabels.length}년';

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
              onSelectionChanged: (Set<_SheetPeriod> next) {
                if (next.isEmpty) return;
                setState(() => _period = next.first);
              },
            ),
            const SizedBox(height: 12),
            ..._chartsForPeriod(context),
            const SizedBox(height: 12),
            Text(
              _footnoteForKind(widget.kind),
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  String _footnoteForKind(DashboardMetricKind k) {
    switch (k) {
      case DashboardMetricKind.profitAndMargin:
        return '금액 곡선: 해당 달·해에 공사완료 처리된 현장만 합산한 Σ(공사금액−현장원가)입니다. 이익률은 같은 집단에 대해 Σ(공사금액−원가)/Σ(공사금액)×100입니다.';
      case DashboardMetricKind.siteCounts:
        return '신규: 공사금액 확정일(미입력 시 공사 시작일) 기준. 완료: 완료 처리일이 속한 달·연도입니다.';
      case DashboardMetricKind.construction:
        return '공사금액은 확정일(또는 공사 시작일)이 속한 달·연도 기준 합계입니다.';
      case DashboardMetricKind.collection:
        return '수금은 실제 입금일이 속한 달·연도 기준 합계입니다.';
    }
  }
}

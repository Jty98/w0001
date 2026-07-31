import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/presentation/viewmodel/dashboard_view_model.dart';
import 'package:w0001/ui/screen/1_dashboard/widgets/dashboard_kpi_display.dart';
import 'package:w0001/ui/screen/1_dashboard/widgets/dashboard_metric_chart_sheet.dart';
import 'package:w0001/ui/screen/1_dashboard/widgets/dashboard_summary_card.dart';
import 'package:w0001/ui/widget/app_sliding_segment.dart';
import 'package:w0001/util/funtions.dart';
import 'package:w0001/util/responsive_layout.dart';

typedef DashboardMetricChartOpener = void Function(
  BuildContext context,
  WidgetRef ref,
  DashboardMetricKind kind,
  DashboardPlaceBreakdownFilter placeFilter,
);

typedef DashboardOutstandingOpener = void Function(
  BuildContext context,
  WidgetRef ref,
);

class DashboardKpiSection extends ConsumerWidget {
  const DashboardKpiSection({
    super.key,
    required this.onMetricChart,
    required this.onOutstanding,
    this.horizontalPadding,
  });

  final DashboardMetricChartOpener onMetricChart;
  final DashboardOutstandingOpener onOutstanding;
  final double? horizontalPadding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardProvider);
    final vm = ref.read(dashboardProvider.notifier);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final padH = horizontalPadding ?? context.rs(12);
    final gap = context.rs(7);
    final sectionGap = context.rs(10);
    final values = resolveDashboardKpiCardValues(state);
    final years = availableKpiYears(state);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: padH),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppSlidingSegment<DashboardKpiPeriodMode>(
                value: state.kpiPeriodMode,
                padding: EdgeInsets.zero,
                onChanged: vm.setKpiPeriodMode,
                children: const {
                  DashboardKpiPeriodMode.monthly: Text('월별'),
                  DashboardKpiPeriodMode.yearly: Text('연도별'),
                },
              ),
              SizedBox(height: sectionGap),
              Row(
                children: [
                  Expanded(
                    child: _KpiDropdown<int>(
                      label: '연도',
                      value: state.selectedYear,
                      items: years
                          .map(
                            (y) => DropdownMenuItem(
                              value: y,
                              child: Text(
                                '$y년',
                                style: TextStyle(fontSize: context.rsi(12)),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (y) {
                        if (y == null) return;
                        vm.setYear(y);
                      },
                    ),
                  ),
                  if (state.kpiPeriodMode ==
                      DashboardKpiPeriodMode.monthly) ...[
                    SizedBox(width: context.rs(8)),
                    Expanded(
                      child: _KpiDropdown<int>(
                        label: '월',
                        value: state.kpiSelectedMonth,
                        items: List.generate(
                          12,
                          (i) => DropdownMenuItem(
                            value: i + 1,
                            child: Text(
                              '${i + 1}월',
                              style: TextStyle(fontSize: context.rsi(12)),
                            ),
                          ),
                        ),
                        onChanged: (m) {
                          if (m == null) return;
                          vm.setKpiSelectedMonth(m);
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: sectionGap),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: padH),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${values.periodLabel} 기준',
                style: tt.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: cs.onSurfaceVariant,
                ),
              ),
              SizedBox(height: context.rs(6)),
              LayoutBuilder(
                builder: (context, constraints) {
                  final w = (constraints.maxWidth - gap) / 2;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      SizedBox(
                        width: w,
                        child: DashboardSummaryCard(
                          title: '공사금액',
                          value: getPrice(price: values.contract),
                          icon: Icons.description_outlined,
                          onTap: () => onMetricChart(
                            context,
                            ref,
                            DashboardMetricKind.construction,
                            DashboardPlaceBreakdownFilter.all,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: w,
                        child: DashboardSummaryCard(
                          title: '공사원가',
                          value: getPrice(price: values.cost),
                          icon: Icons.payments_outlined,
                          onTap: () => onMetricChart(
                            context,
                            ref,
                            DashboardMetricKind.cost,
                            DashboardPlaceBreakdownFilter.all,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: w,
                        child: DashboardSummaryCard(
                          title: '수금액',
                          value: getPrice(price: values.collection),
                          icon: Icons.account_balance_wallet_outlined,
                          onTap: () => onMetricChart(
                            context,
                            ref,
                            DashboardMetricKind.collection,
                            DashboardPlaceBreakdownFilter.all,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: w,
                        child: DashboardSummaryCard(
                          title: '미수금 잔액',
                          value: getPrice(price: values.outstanding),
                          icon: Icons.request_quote_outlined,
                          onTap: () => onOutstanding(context, ref),
                        ),
                      ),
                      SizedBox(
                        width: w,
                        child: DashboardSummaryCard(
                          title: '영업이익',
                          value: getPrice(price: values.profit),
                          valueSecondary: values.showProfitMargin
                              ? '${values.marginPct.toStringAsFixed(1)}%'
                              : '—',
                          valueSecondaryCaption: '이익률',
                          icon: Icons.trending_up_rounded,
                          onTap: () => onMetricChart(
                            context,
                            ref,
                            DashboardMetricKind.profitAndMargin,
                            DashboardPlaceBreakdownFilter.all,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: w,
                        child: DashboardSummaryCard(
                          title: '현장 현황',
                          valueCaption: values.sitePrimaryCaption,
                          value: '${values.sitePrimaryCount}곳',
                          valueSecondaryCaption: values.siteSecondaryCaption,
                          valueSecondary: '${values.siteSecondaryCount}곳',
                          icon: Icons.construction_outlined,
                          onTap: () => onMetricChart(
                            context,
                            ref,
                            DashboardMetricKind.siteCounts,
                            DashboardPlaceBreakdownFilter.all,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _KpiDropdown<T> extends StatelessWidget {
  const _KpiDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        contentPadding: EdgeInsets.symmetric(
          horizontal: context.rsi(10),
          vertical: context.rsi(3),
        ),
        filled: true,
        fillColor: cs.surfaceContainerLow.withValues(alpha: 0.55),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(context.rs(8)),
          borderSide: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(context.rs(8)),
          borderSide: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          isDense: true,
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

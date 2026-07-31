import 'package:w0001/data/model/dashboard_models.dart';
import 'package:w0001/data/model/monthly_summary_model.dart';
import 'package:w0001/presentation/viewmodel/dashboard_view_model.dart';

/// 상황판 KPI 카드에 표시할 집계값 (월별·연도별 필터 반영).
class DashboardKpiCardValues {
  const DashboardKpiCardValues({
    required this.periodLabel,
    required this.contract,
    required this.cost,
    required this.collection,
    required this.outstanding,
    required this.profit,
    required this.marginPct,
    required this.sitePrimaryCount,
    required this.siteSecondaryCount,
    required this.sitePrimaryCaption,
    required this.siteSecondaryCaption,
    required this.showProfitMargin,
  });

  final String periodLabel;
  final int contract;
  final int cost;
  final int collection;
  final int outstanding;
  final int profit;
  final double marginPct;
  final int sitePrimaryCount;
  final int siteSecondaryCount;
  final String sitePrimaryCaption;
  final String siteSecondaryCaption;
  final bool showProfitMargin;
}

DashboardKpiCardValues resolveDashboardKpiCardValues(DashboardState state) {
  final kpi = state.kpi;

  switch (state.kpiPeriodMode) {
    case DashboardKpiPeriodMode.monthly:
      final m = _monthlyFor(state);
      if (m != null) {
        final isCurrentMonth = m.year == kpi.year && m.month == kpi.month;
        return DashboardKpiCardValues(
          periodLabel: '${m.year}년 ${m.month}월',
          contract: m.contractAmount,
          cost: m.costAmount,
          collection: m.collectionAmount,
          outstanding: kpi.outstandingReceivable,
          profit: m.completedProfitAmount,
          marginPct: m.completedContractMarginPct,
          sitePrimaryCount:
              isCurrentMonth ? kpi.inProgressPlaces : m.newProjectCount,
          siteSecondaryCount:
              isCurrentMonth ? kpi.completedPlaces : m.completedProjectCount,
          sitePrimaryCaption: isCurrentMonth ? '진행' : '신규',
          siteSecondaryCaption: '완료',
          showProfitMargin: m.completedProjectCount > 0,
        );
      }
      return DashboardKpiCardValues(
        periodLabel: '${state.selectedYear}년 ${state.kpiSelectedMonth}월',
        contract: 0,
        cost: 0,
        collection: 0,
        outstanding: kpi.outstandingReceivable,
        profit: 0,
        marginPct: 0,
        sitePrimaryCount: 0,
        siteSecondaryCount: 0,
        sitePrimaryCaption: '신규',
        siteSecondaryCaption: '완료',
        showProfitMargin: false,
      );

    case DashboardKpiPeriodMode.yearly:
      final y = _yearlyFor(state);
      if (y != null) {
        final isCurrentYear = y.year == kpi.year;
        return DashboardKpiCardValues(
          periodLabel: '${y.year}년',
          contract: y.contractTotal,
          cost: y.costTotal,
          collection: y.collectionTotal,
          outstanding: kpi.outstandingReceivable,
          profit: y.completedProfitTotal,
          marginPct: y.completedContractMarginPct,
          sitePrimaryCount:
              isCurrentYear ? kpi.inProgressPlaces : y.newProjectCount,
          siteSecondaryCount:
              isCurrentYear ? kpi.completedPlaces : y.completedProjectCount,
          sitePrimaryCaption: isCurrentYear ? '진행' : '신규',
          siteSecondaryCaption: '완료',
          showProfitMargin: y.completedProjectCount > 0,
        );
      }
      return DashboardKpiCardValues(
        periodLabel: '${state.selectedYear}년',
        contract: 0,
        cost: 0,
        collection: 0,
        outstanding: kpi.outstandingReceivable,
        profit: 0,
        marginPct: 0,
        sitePrimaryCount: 0,
        siteSecondaryCount: 0,
        sitePrimaryCaption: '신규',
        siteSecondaryCaption: '완료',
        showProfitMargin: false,
      );
  }
}

MonthlySummaryModel? _monthlyFor(DashboardState state) {
  for (final m in state.monthly) {
    if (m.year == state.selectedYear && m.month == state.kpiSelectedMonth) {
      return m;
    }
  }
  return null;
}

YearlyDashboardPoint? _yearlyFor(DashboardState state) {
  for (final y in state.yearly) {
    if (y.year == state.selectedYear) {
      return y;
    }
  }
  return null;
}

List<int> availableKpiYears(DashboardState state) {
  final years = <int>{
    state.selectedYear,
    DateTime.now().year,
    ...state.monthly.map((m) => m.year),
    ...state.yearly.map((y) => y.year),
  };
  final list = years.toList()..sort((a, b) => b.compareTo(a));
  return list;
}

import 'package:w0001/data/model/monthly_summary_model.dart';

/// 상단 KPI (기본: 이번 달 기준).
class DashboardKpiSnapshot {
  final int year;
  final int month;
  final int monthlyContract;
  final int monthlyCollection;
  final int monthlyCost;
  final int inProgressPlaces;
  final int completedPlaces;
  final int outstandingReceivable;

  /// 이번 달 KPI 연·월에 **완료 처리된** 현장 수(pend 기준).
  final int completedSitesInKpiMonth;

  /// 완료 현장만: Σ(공사금액−현장원가) / Σ(공사금액) × 100. 해당 월 완료 없으면 0.
  final double completedContractMarginPct;

  /// 당월 **완료 처리된 공사만**: Σ(공사금액 − 인건비·자재 등 현장 원가).
  final int completedContractProfitTotal;

  const DashboardKpiSnapshot({
    required this.year,
    required this.month,
    required this.monthlyContract,
    required this.monthlyCollection,
    required this.monthlyCost,
    required this.inProgressPlaces,
    required this.completedPlaces,
    required this.outstandingReceivable,
    required this.completedSitesInKpiMonth,
    required this.completedContractMarginPct,
    required this.completedContractProfitTotal,
  });

  /// 달력 월 기준 수금 − 달력 월 기준 원가 (현금 흐름). 상단 영업이익 카드에는 사용하지 않음.
  int get profitOnCash => monthlyCollection - monthlyCost;

  factory DashboardKpiSnapshot.fromJson(Map<String, dynamic> j) {
    return DashboardKpiSnapshot(
      year: (j['year'] as num?)?.toInt() ?? 0,
      month: (j['month'] as num?)?.toInt() ?? 1,
      monthlyContract: (j['monthlyContract'] as num?)?.toInt() ?? 0,
      monthlyCollection: (j['monthlyCollection'] as num?)?.toInt() ?? 0,
      monthlyCost: (j['monthlyCost'] as num?)?.toInt() ?? 0,
      inProgressPlaces: (j['inProgressPlaces'] as num?)?.toInt() ?? 0,
      completedPlaces: (j['completedPlaces'] as num?)?.toInt() ?? 0,
      outstandingReceivable: (j['outstandingReceivable'] as num?)?.toInt() ?? 0,
      completedSitesInKpiMonth:
          (j['completedSitesInKpiMonth'] as num?)?.toInt() ?? 0,
      completedContractMarginPct:
          (j['completedContractMarginPct'] as num?)?.toDouble() ?? 0,
      completedContractProfitTotal:
          (j['completedContractProfitTotal'] as num?)?.toInt() ?? 0,
    );
  }
}

/// 연도별 집계 (대시보드 년도별 선차트용).
class YearlyDashboardPoint {
  final int year;
  final int contractTotal;
  final int collectionTotal;
  final int costTotal;
  final int newProjectCount;
  final int completedProjectCount;

  /// 그 해 **완료된** 현장만: Σ(공사금액−현장원가) / Σ(공사금액) × 100.
  final double completedContractMarginPct;

  /// 그 해 **완료 처리된 현장만**(pend 연도 기준): Σ(공사금액 − 현장 원가).
  final int completedProfitTotal;

  const YearlyDashboardPoint({
    required this.year,
    required this.contractTotal,
    required this.collectionTotal,
    required this.costTotal,
    required this.newProjectCount,
    required this.completedProjectCount,
    required this.completedContractMarginPct,
    required this.completedProfitTotal,
  });

  int get profitOnCash => collectionTotal - costTotal;

  factory YearlyDashboardPoint.fromJson(Map<String, dynamic> j) {
    return YearlyDashboardPoint(
      year: (j['year'] as num?)?.toInt() ?? 0,
      contractTotal: (j['contractTotal'] as num?)?.toInt() ?? 0,
      collectionTotal: (j['collectionTotal'] as num?)?.toInt() ?? 0,
      costTotal: (j['costTotal'] as num?)?.toInt() ?? 0,
      newProjectCount: (j['newProjectCount'] as num?)?.toInt() ?? 0,
      completedProjectCount: (j['completedProjectCount'] as num?)?.toInt() ?? 0,
      completedContractMarginPct:
          (j['completedContractMarginPct'] as num?)?.toDouble() ?? 0,
      completedProfitTotal: (j['completedProfitTotal'] as num?)?.toInt() ?? 0,
    );
  }
}

/// 현장별 수익성 요약 (테이블).
class DashboardPlaceRow {
  final int pid;
  final String pname;
  final int contractTotal;
  final int collected;
  final int costTotal;
  final int outstanding;
  final int advanceCollected;
  final String balanceBreakdown;

  const DashboardPlaceRow({
    required this.pid,
    required this.pname,
    required this.contractTotal,
    required this.collected,
    required this.costTotal,
    required this.outstanding,
    this.advanceCollected = 0,
    this.balanceBreakdown = '',
  });

  int get profitOnContract => contractTotal - outstanding - costTotal;
  int get profitOnCash => collected - costTotal;

  double get marginOnContractPct =>
      contractTotal <= 0 ? 0 : (profitOnContract / contractTotal) * 100;

  factory DashboardPlaceRow.fromJson(Map<String, dynamic> j) {
    return DashboardPlaceRow(
      pid: (j['pid'] as num?)?.toInt() ?? 0,
      pname: j['pname'] as String? ?? '',
      contractTotal: (j['contractTotal'] as num?)?.toInt() ?? 0,
      collected: (j['collected'] as num?)?.toInt() ?? 0,
      costTotal: (j['costTotal'] as num?)?.toInt() ?? 0,
      outstanding: (j['outstanding'] as num?)?.toInt() ?? 0,
      advanceCollected: (j['advanceCollected'] as num?)?.toInt() ?? 0,
      balanceBreakdown: j['balanceBreakdown'] as String? ?? '',
    );
  }
}

/// 대시보드 데이터 일괄 로드.
class DashboardDataBundle {
  final DashboardKpiSnapshot kpi;
  final List<MonthlySummaryModel> monthly;
  final List<YearlyDashboardPoint> yearly;
  final List<DashboardPlaceRow> places;

  const DashboardDataBundle({
    required this.kpi,
    required this.monthly,
    required this.yearly,
    required this.places,
  });

  factory DashboardDataBundle.fromJson(Map<String, dynamic> j) {
    return DashboardDataBundle(
      kpi: DashboardKpiSnapshot.fromJson(
        _asMap(j['kpi']) ?? <String, dynamic>{},
      ),
      monthly: _mapList(j['monthly'], MonthlySummaryModel.fromJson),
      yearly: _mapList(j['yearly'], YearlyDashboardPoint.fromJson),
      places: _mapList(j['places'], DashboardPlaceRow.fromJson),
    );
  }
}

Map<String, dynamic>? _asMap(Object? o) {
  if (o is Map) return Map<String, dynamic>.from(o);
  return null;
}

List<T> _mapList<T>(
  Object? data,
  T Function(Map<String, dynamic>) f,
) {
  if (data is! List) return const [];
  return data
      .map(
        (e) => f(
              Map<String, dynamic>.from(e as Map<dynamic, dynamic>),
            ),
      )
      .toList();
}

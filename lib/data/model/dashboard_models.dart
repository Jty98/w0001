import 'package:w0001/data/model/dashboard_json_helpers.dart';
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

  /// 상단 KPI, 해당 연·월 **완료**만: Σ(이익) ÷ Σ(공사금액) × 100 (`completedContractMarginPct`).
  final double completedContractMarginPct;

  /// 해당 `year`/`month` **완료** 공사만, Σ(수금−원가) (`completedContractProfitTotal`).
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
      year: dashReadInt(j, 'year'),
      month: dashReadInt(j, 'month').clamp(1, 12),
      monthlyContract: dashReadInt(j, 'monthlyContract'),
      monthlyCollection: dashReadInt(j, 'monthlyCollection'),
      monthlyCost: dashReadInt(j, 'monthlyCost'),
      inProgressPlaces: dashReadInt(j, 'inProgressPlaces'),
      completedPlaces: dashReadInt(j, 'completedPlaces'),
      outstandingReceivable: dashReadInt(j, 'outstandingReceivable'),
      completedSitesInKpiMonth: dashReadInt(j, 'completedSitesInKpiMonth'),
      completedContractMarginPct:
          dashReadDouble(j, 'completedContractMarginPct'),
      completedContractProfitTotal:
          dashReadInt(j, 'completedContractProfitTotal'),
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

  /// pend 연도 **완료**만: Σ(이익) ÷ Σ(공사금액) × 100 (`completedContractMarginPct`).
  final double completedContractMarginPct;

  /// 그 해 **완료** 현장만, Σ(수금−원가) (pend 연도, `completedProfitTotal`).
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
      year: dashReadInt(j, 'year'),
      contractTotal: dashReadInt(j, 'contractTotal'),
      collectionTotal: dashReadInt(j, 'collectionTotal'),
      costTotal: dashReadInt(j, 'costTotal'),
      newProjectCount: dashReadInt(j, 'newProjectCount'),
      completedProjectCount: dashReadInt(j, 'completedProjectCount'),
      completedContractMarginPct:
          dashReadDouble(j, 'completedContractMarginPct'),
      completedProfitTotal: dashReadInt(j, 'completedProfitTotal'),
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

  /// `0` 진행중 · `1` 완료. bundle에 없으면 `-1`(미확인).
  final int pcomplete;

  const DashboardPlaceRow({
    required this.pid,
    required this.pname,
    required this.contractTotal,
    required this.collected,
    required this.costTotal,
    required this.outstanding,
    this.advanceCollected = 0,
    this.balanceBreakdown = '',
    this.pcomplete = -1,
  });

  bool get isInProgress => pcomplete == 0;
  bool get isCompleted => pcomplete == 1;

  int get profitOnContract => contractTotal - outstanding - costTotal;
  int get profitOnCash => collected - costTotal;

  double get marginOnContractPct =>
      contractTotal <= 0 ? 0 : (profitOnContract / contractTotal) * 100;

  factory DashboardPlaceRow.fromJson(Map<String, dynamic> j) {
    return DashboardPlaceRow(
      pid: dashReadInt(j, 'pid'),
      pname: dashReadString(j, 'pname'),
      contractTotal: dashReadInt(j, 'contractTotal'),
      collected: dashReadInt(j, 'collected'),
      costTotal: dashReadInt(j, 'costTotal'),
      outstanding: dashReadInt(j, 'outstanding'),
      advanceCollected: dashReadInt(j, 'advanceCollected'),
      balanceBreakdown: dashReadString(j, 'balanceBreakdown'),
      pcomplete: j.containsKey('pcomplete') ||
              j.containsKey('p_complete') ||
              j.containsKey('pComplete')
          ? dashReadInt(j, 'pcomplete')
          : -1,
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
    var kpi = DashboardKpiSnapshot.fromJson(
      _asMap(j['kpi']) ?? <String, dynamic>{},
    );
    final monthly = _mapList(j['monthly'], MonthlySummaryModel.fromJson);
    kpi = _kpiAlignWithMonthlyWhenZero(kpi, monthly);
    kpi = _kpiFillTopLineFromMonthlyWhenZeros(kpi, monthly);
    return DashboardDataBundle(
      kpi: kpi,
      monthly: monthly,
      yearly: _mapList(j['yearly'], YearlyDashboardPoint.fromJson),
      places: _mapList(j['places'], DashboardPlaceRow.fromJson),
    );
  }
}

/// KPI `completedContractProfit*` 키 누락(0)인데, 같은 달 [monthly]에만 올 수 있는 응답용 보강.
DashboardKpiSnapshot _kpiAlignWithMonthlyWhenZero(
  DashboardKpiSnapshot kpi,
  List<MonthlySummaryModel> monthly,
) {
  if (kpi.completedContractProfitTotal != 0 ||
      kpi.completedContractMarginPct != 0) {
    return kpi;
  }
  MonthlySummaryModel? pick;
  for (final m in monthly) {
    if (m.year == kpi.year && m.month == kpi.month) {
      pick = m;
      break;
    }
  }
  if (pick == null && (kpi.year == 0) && monthly.isNotEmpty) {
    final now = DateTime.now();
    for (final m in monthly) {
      if (m.year == now.year && m.month == now.month) {
        pick = m;
        break;
      }
    }
    pick ??= monthly.last;
  }
  if (pick == null) return kpi;
  if (pick.completedProfitAmount == 0 && pick.completedContractMarginPct == 0) {
    return kpi;
  }
  final y = (kpi.year == 0) ? pick.year : kpi.year;
  final mon = (kpi.year == 0) ? pick.month : kpi.month;
  return DashboardKpiSnapshot(
    year: y,
    month: mon,
    monthlyContract: kpi.monthlyContract,
    monthlyCollection: kpi.monthlyCollection,
    monthlyCost: kpi.monthlyCost,
    inProgressPlaces: kpi.inProgressPlaces,
    completedPlaces: kpi.completedPlaces,
    outstandingReceivable: kpi.outstandingReceivable,
    completedSitesInKpiMonth: pick.completedProjectCount,
    completedContractMarginPct: pick.completedContractMarginPct,
    completedContractProfitTotal: pick.completedProfitAmount,
  );
}

/// KPI `monthlyContract` / `monthlyCollection` / `monthlyCost`가 0인데 같은 달 [monthly] 행에만
/// 들어있는 번들 응답을 맞춤 (키·쿼리 불일치 시 상단 카드만 0으로 보이는 현상 완화).
DashboardKpiSnapshot _kpiFillTopLineFromMonthlyWhenZeros(
  DashboardKpiSnapshot kpi,
  List<MonthlySummaryModel> monthly,
) {
  MonthlySummaryModel? pick;
  for (final m in monthly) {
    if (m.year == kpi.year && m.month == kpi.month) {
      pick = m;
      break;
    }
  }
  if (pick == null && kpi.year == 0 && monthly.isNotEmpty) {
    final now = DateTime.now();
    for (final m in monthly) {
      if (m.year == now.year && m.month == now.month) {
        pick = m;
        break;
      }
    }
    pick ??= monthly.last;
  }
  if (pick == null) return kpi;

  final contract =
      kpi.monthlyContract == 0 ? pick.contractAmount : kpi.monthlyContract;
  final collection = kpi.monthlyCollection == 0
      ? pick.collectionAmount
      : kpi.monthlyCollection;
  final cost = kpi.monthlyCost == 0 ? pick.costAmount : kpi.monthlyCost;

  if (contract == kpi.monthlyContract &&
      collection == kpi.monthlyCollection &&
      cost == kpi.monthlyCost) {
    return kpi;
  }
  return DashboardKpiSnapshot(
    year: kpi.year,
    month: kpi.month,
    monthlyContract: contract,
    monthlyCollection: collection,
    monthlyCost: cost,
    inProgressPlaces: kpi.inProgressPlaces,
    completedPlaces: kpi.completedPlaces,
    outstandingReceivable: kpi.outstandingReceivable,
    completedSitesInKpiMonth: kpi.completedSitesInKpiMonth,
    completedContractMarginPct: kpi.completedContractMarginPct,
    completedContractProfitTotal: kpi.completedContractProfitTotal,
  );
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

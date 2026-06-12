import 'package:w0001/data/model/dashboard_json_helpers.dart';

class MonthlySummaryModel {
  final int year;
  final int month; // 1-12

  /// 해당 월에 **공사금액 확정일 기준**(미입력 시 공사 시작일)으로 잡힌 공사금액 합계.
  final int contractAmount;

  /// 해당 월 **실제 입금일** 기준 수금 합계.
  final int collectionAmount;

  /// 해당 월 발생 원가(인건비 PlaceWorkDay + 자재비).
  final int costAmount;

  /// 해당 월에 공사금액 확정일이 속한 신규 현장 건수.
  final int newProjectCount;

  /// 해당 월에 공사완료 처리된 현장 건수(pend 월 기준).
  final int completedProjectCount;

  /// 그 달 pend 기준 **완료** 현장만: Σ(이익) ÷ Σ(공사금액) × 100. (`completedContractMarginPct`)
  final double completedContractMarginPct;

  /// 그 달 **완료** 현장만, DB 기준 Σ(수금−원가) (pend 월, `completedProfitAmount`).
  final int completedProfitAmount;

  const MonthlySummaryModel({
    required this.year,
    required this.month,
    required this.contractAmount,
    required this.collectionAmount,
    required this.costAmount,
    required this.newProjectCount,
    required this.completedProjectCount,
    required this.completedContractMarginPct,
    required this.completedProfitAmount,
  });

  /// 수금 − 원가 (현금 관점 월별, 대시보드 상단 KPI와 무관).
  int get profitOnCash => collectionAmount - costAmount;

  /// 공사금액 − 원가 (공사 관점, 참고용).
  int get profitOnContract => contractAmount - costAmount;

  String get ymKey =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';

  /// 서버: `response_model_by_alias=True` → JSON 키는 camelCase.
  factory MonthlySummaryModel.fromJson(Map<String, dynamic> j) {
    return MonthlySummaryModel(
      year: dashReadInt(j, 'year'),
      month: dashReadInt(j, 'month').clamp(1, 12),
      contractAmount: dashReadInt(j, 'contractAmount'),
      collectionAmount: dashReadInt(j, 'collectionAmount'),
      costAmount: dashReadInt(j, 'costAmount'),
      newProjectCount: dashReadInt(j, 'newProjectCount'),
      completedProjectCount: dashReadInt(j, 'completedProjectCount'),
      completedContractMarginPct:
          dashReadDouble(j, 'completedContractMarginPct'),
      completedProfitAmount: dashReadInt(j, 'completedProfitAmount'),
    );
  }
}

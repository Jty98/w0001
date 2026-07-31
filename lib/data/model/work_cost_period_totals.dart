import 'package:w0001/data/model/work_cost_worker_summary.dart';
import 'package:w0001/data/model/total_workcost_model.dart';

/// 기간·필터 기준 인건비 집계 — 목록(페이지)과 분리해 하단 총액에 사용.
///
/// 서버 `GET /work-costs/totals` 응답 또는 로드된 전체 목록에서 계산.
class WorkCostPeriodTotals {
  const WorkCostPeriodTotals({
    required this.totalAmount,
    required this.unpaidAmount,
    required this.paidAmount,
    required this.itemCount,
    required this.workerCount,
  });

  final int totalAmount;
  final int unpaidAmount;
  final int paidAmount;
  final int itemCount;
  final int workerCount;

  factory WorkCostPeriodTotals.fromJson(Map<String, dynamic> json) {
    int pickInt(String snake, String camel) {
      final v = json[snake] ?? json[camel];
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v.trim()) ?? 0;
      return 0;
    }

    return WorkCostPeriodTotals(
      totalAmount: pickInt('total_amount', 'totalAmount'),
      unpaidAmount: pickInt('unpaid_amount', 'unpaidAmount'),
      paidAmount: pickInt('paid_amount', 'paidAmount'),
      itemCount: pickInt('item_count', 'itemCount'),
      workerCount: pickInt('worker_count', 'workerCount'),
    );
  }

  /// 서버 집계 API 미구현 시 — 로드된 전체 항목에서 계산(폴백).
  factory WorkCostPeriodTotals.fromItems(List<TotalWorkCostModel> items) {
    var total = 0;
    var unpaid = 0;
    var paid = 0;
    final workers = <String>{};
    for (final e in items) {
      total += e.price;
      if (e.wcomplete == 0) {
        unpaid += e.price;
      } else {
        paid += e.price;
      }
      workers.add('${e.hid}|${e.hname}|${e.hnumber}');
    }
    return WorkCostPeriodTotals(
      totalAmount: total,
      unpaidAmount: unpaid,
      paidAmount: paid,
      itemCount: items.length,
      workerCount: workers.length,
    );
  }

  /// 서버 totals 미구현·로딩 중 1페이지 요약으로 대략적 footer (폴백).
  factory WorkCostPeriodTotals.fromSummaries(
    List<WorkCostWorkerSummary> summaries,
  ) {
    var unpaid = 0;
    var paid = 0;
    var unpaidCount = 0;
    var paidCount = 0;
    for (final s in summaries) {
      unpaid += s.unpaidAmount;
      paid += s.paidAmount;
      unpaidCount += s.unpaidCount;
      paidCount += s.paidCount;
    }
    return WorkCostPeriodTotals(
      totalAmount: unpaid + paid,
      unpaidAmount: unpaid,
      paidAmount: paid,
      itemCount: unpaidCount + paidCount,
      workerCount: summaries.length,
    );
  }

  /// 검색 필터 적용 후 하단 총액(클라이언트 전용).
  factory WorkCostPeriodTotals.fromFilteredItems(
    List<TotalWorkCostModel> items,
  ) =>
      WorkCostPeriodTotals.fromItems(items);
}

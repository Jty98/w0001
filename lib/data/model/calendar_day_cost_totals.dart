import 'package:w0001/data/model/total_cost_model.dart';

/// `GET /dashboard/calendar-day-costs` 일자 집계 — 목록 페이지와 분리.
class CalendarDayCostTotals {
  const CalendarDayCostTotals({
    required this.totalAmount,
    required this.workAmount,
    required this.materialAmount,
    required this.unpaidAmount,
  });

  final int totalAmount;
  final int workAmount;
  final int materialAmount;
  final int unpaidAmount;

  factory CalendarDayCostTotals.fromJson(Map<String, dynamic> json) {
    int pick(String snake, String camel) {
      final v = json[snake] ?? json[camel];
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v.trim()) ?? 0;
      return 0;
    }

    final work = pick('work_amount', 'workAmount');
    final material = pick('material_amount', 'materialAmount');
    final unpaid = pick('unpaid_amount', 'unpaidAmount');
    final total = pick('total_amount', 'totalAmount');
    return CalendarDayCostTotals(
      totalAmount: total != 0 ? total : work + material,
      workAmount: work,
      materialAmount: material,
      unpaidAmount: unpaid,
    );
  }

  factory CalendarDayCostTotals.fromItems(List<TotalCostModel> items) {
    var work = 0;
    var material = 0;
    var unpaid = 0;
    for (final e in items) {
      if (e.category == 'w') {
        work += e.price;
        if (e.wcomplete == 0) unpaid += e.price;
      } else {
        material += e.price;
      }
    }
    return CalendarDayCostTotals(
      totalAmount: work + material,
      workAmount: work,
      materialAmount: material,
      unpaidAmount: unpaid,
    );
  }
}

/// cursor 페이지 + (선택) 일자 집계.
class CalendarDayCostPageResult {
  const CalendarDayCostPageResult({
    required this.items,
    this.nextCursor,
    this.hasMore = false,
    this.totalCount,
    this.totals,
  });

  final List<TotalCostModel> items;
  final String? nextCursor;
  final bool hasMore;
  final int? totalCount;
  final CalendarDayCostTotals? totals;

  bool get canLoadMore =>
      hasMore && nextCursor != null && nextCursor!.trim().isNotEmpty;
}

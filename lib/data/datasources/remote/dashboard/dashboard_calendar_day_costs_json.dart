import 'package:w0001/data/datasources/remote/super_admin/super_admin_api_common.dart';
import 'package:w0001/data/model/calendar_day_cost_totals.dart';
import 'package:w0001/data/model/total_cost_model.dart';

/// `GET /dashboard/calendar-day-costs` 응답 → [TotalCostModel] 목록.
List<TotalCostModel> parseDashboardCalendarDayCosts(dynamic data) {
  final rawItems = _extractItems(data);
  if (rawItems == null) return const [];

  final out = <TotalCostModel>[];
  for (final e in rawItems) {
    if (e is! Map) continue;
    try {
      out.add(TotalCostModel.fromMap(Map<String, dynamic>.from(e)));
    } catch (_) {}
  }
  _sortDayCosts(out);
  return out;
}

/// cursor 페이지 + totals 파싱. 레거시 배열 응답도 1페이지로 처리.
CalendarDayCostPageResult parseDashboardCalendarDayCostsPage(dynamic data) {
  if (data is List) {
    final items = parseDashboardCalendarDayCosts(data);
    return CalendarDayCostPageResult(
      items: items,
      hasMore: false,
      totals: items.isEmpty ? null : CalendarDayCostTotals.fromItems(items),
    );
  }

  if (data is Map) {
    final root = Map<String, dynamic>.from(data);
    final items = parseDashboardCalendarDayCosts(root);
    final page = saParsePagedList(root, TotalCostModel.fromMap);
    final mergedItems = page.items.isNotEmpty ? page.items : items;

    CalendarDayCostTotals? totals;
    final totalsRaw = root['totals'] ?? root['summary'];
    if (totalsRaw is Map) {
      totals = CalendarDayCostTotals.fromJson(
        Map<String, dynamic>.from(totalsRaw),
      );
    } else if (mergedItems.isNotEmpty && !page.canLoadMore) {
      totals = CalendarDayCostTotals.fromItems(mergedItems);
    }

    return CalendarDayCostPageResult(
      items: mergedItems,
      nextCursor: page.nextCursor,
      hasMore: page.hasMore,
      totalCount: page.totalCount,
      totals: totals,
    );
  }

  return const CalendarDayCostPageResult(items: []);
}

void _sortDayCosts(List<TotalCostModel> out) {
  if (out.length <= 1) return;
  out.sort((a, b) {
    final c = a.category.compareTo(b.category);
    if (c != 0) return c;
    return a.name.compareTo(b.name);
  });
}

List<dynamic>? _extractItems(dynamic data) {
  if (data is List) return data;
  if (data is! Map) return null;
  final m = Map<String, dynamic>.from(data);
  for (final key in ['items', 'costs', 'rows', 'data']) {
    final v = m[key];
    if (v is List) return v;
  }
  final inner = m['result'] ?? m['payload'];
  if (inner is Map) {
    return _extractItems(inner);
  }
  return null;
}

import 'package:w0001/data/model/dashboard_calendar_workforce_dots.dart';
import 'package:w0001/util/funtions.dart' show normalizeToIsoDateString;

/// `/dashboard/calendar-workforce-dots` 응답 파싱.
///
/// 지원 형태:
/// * `{ "dots": { "yyyy-MM-dd": { "sch", "work", "cost" } } }`
/// * `{ "days": [ { "date", "sch", "work", "cost" } ] }`
/// * 루트가 `yyyy-MM-dd` → 플래그 맵
DashboardCalendarWorkforceDots parseDashboardCalendarWorkforceDots(
    dynamic data) {
  final byDay = <String, ({bool sch, bool work})>{};
  final costDayKeys = <String>{};

  void mergeDay(
    String rawKey,
    Map<String, dynamic> flags,
  ) {
    final key = _dayKey(rawKey);
    if (key == null) return;
    final sch = _readBool(flags, const [
      'sch',
      'schedule',
      'has_schedule',
      'hasSchedule',
      'process',
    ]);
    final work = _readBool(flags, const [
      'work',
      'workforce',
      'has_work',
      'hasWork',
      'work_day',
      'workDay',
    ]);
    final cost = _readBool(flags, const [
      'cost',
      'has_cost',
      'hasCost',
      'has_expense',
      'hasExpense',
    ]);
    if (sch || work) {
      final prev = byDay[key] ?? (sch: false, work: false);
      byDay[key] = (sch: prev.sch || sch, work: prev.work || work);
    }
    if (cost) costDayKeys.add(key);
  }

  if (data is List) {
    for (final e in data) {
      if (e is! Map) continue;
      final m = Map<String, dynamic>.from(e);
      final date = m['date'] ?? m['dateString'] ?? m['day'];
      if (date is! String || date.isEmpty) continue;
      mergeDay(date, m);
    }
    return DashboardCalendarWorkforceDots(
        byDay: byDay, costDayKeys: costDayKeys);
  }

  if (data is! Map) {
    return const DashboardCalendarWorkforceDots(byDay: {}, costDayKeys: {});
  }

  final root = Map<String, dynamic>.from(data);
  final inner = root['dots'] ??
      root['workforceDots'] ??
      root['workforce_dots'] ??
      root['days'];
  if (inner is List) {
    for (final e in inner) {
      if (e is! Map) continue;
      final m = Map<String, dynamic>.from(e);
      final date = m['date'] ?? m['dateString'] ?? m['day'];
      if (date is! String || date.isEmpty) continue;
      mergeDay(date, m);
    }
  } else if (inner is Map) {
    for (final e in Map<String, dynamic>.from(inner).entries) {
      final v = e.value;
      if (v is Map) {
        mergeDay(e.key, Map<String, dynamic>.from(v));
      } else if (v is bool) {
        final key = _dayKey(e.key);
        if (key != null && v) costDayKeys.add(key);
      }
    }
  }

  final costsOnly = root['costDays'] ?? root['cost_days'] ?? root['costs'];
  if (costsOnly is List) {
    for (final c in costsOnly) {
      final key = _dayKey('$c');
      if (key != null) costDayKeys.add(key);
    }
  }

  // 루트가 날짜 키 맵인 경우 (`{ "2025-06-01": { ... } }`)
  if (byDay.isEmpty && costDayKeys.isEmpty) {
    for (final e in root.entries) {
      if (e.value is! Map) continue;
      if (!_looksLikeDateKey(e.key)) continue;
      mergeDay(e.key, Map<String, dynamic>.from(e.value as Map));
    }
  }

  return DashboardCalendarWorkforceDots(byDay: byDay, costDayKeys: costDayKeys);
}

String? _dayKey(String raw) {
  final k = raw.trim();
  if (k.length < 10) return null;
  return normalizeToIsoDateString(k.substring(0, 10));
}

bool _looksLikeDateKey(String key) =>
    RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(key.trim());

bool _readBool(Map<String, dynamic> m, List<String> keys) {
  for (final k in keys) {
    final v = m[k];
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final t = v.trim().toLowerCase();
      if (t == 'true' || t == '1') return true;
      if (t == 'false' || t == '0') return false;
    }
  }
  return false;
}

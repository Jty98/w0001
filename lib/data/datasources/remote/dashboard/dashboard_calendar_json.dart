/// `/dashboard/calendar-events` 응답을 [getAllEvents]와 동일한 맵으로 변환.
///
/// 지원 형태:
/// * 루트가 `yyyy-MM-dd` → `placeNames` 배열 인 맵
/// * `{ "events": { ... } }` / `{ "calendarEvents": { ... } }`
Map<DateTime, List<String>> parseDashboardCalendarEvents(dynamic data) {
  if (data is List) {
    final out = <DateTime, List<String>>{};
    for (final e in data) {
      if (e is! Map) continue;
      final m = Map<String, dynamic>.from(e);
      final key = m['date'] ?? m['dateString'] ?? m['day'];
      if (key is! String || key.isEmpty) continue;
      final names = m['placeNames'] ?? m['names'];
      if (names is! List) continue;
      final day = _dateOnlyFromKeyString(key);
      if (day == null) continue;
      out[day] = names.map((x) => '$x').toList();
    }
    return out;
  }

  Map<String, dynamic>? raw;
  if (data is Map) {
    final m = Map<String, dynamic>.from(data);
    final inner = m['events'] ?? m['calendarEvents'];
    if (inner is Map) {
      raw = Map<String, dynamic>.from(inner);
    } else {
      raw = m;
    }
  }
  if (raw == null) return {};

  DateTime? dateOnlyFromKey(String key) => _dateOnlyFromKeyString(key);

  final out = <DateTime, List<String>>{};
  for (final e in raw.entries) {
    final day = dateOnlyFromKey(e.key);
    if (day == null) continue;
    final v = e.value;
    if (v is! List) continue;
    out[day] = v.map((x) => '$x').toList();
  }
  return out;
}

DateTime? _dateOnlyFromKeyString(String key) {
  final k = key.trim();
  if (k.length >= 10) {
    final ymd = k.substring(0, 10).split('-');
    if (ymd.length == 3) {
      final y = int.tryParse(ymd[0]);
      final mo = int.tryParse(ymd[1]);
      final d = int.tryParse(ymd[2]);
      if (y != null && mo != null && d != null) {
        return DateTime(y, mo, d);
      }
    }
  }
  final p = DateTime.tryParse(k);
  if (p == null) return null;
  return DateTime(p.year, p.month, p.day);
}

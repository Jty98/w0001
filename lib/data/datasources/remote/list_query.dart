import 'package:w0001/util/funtions.dart' show formatDateTimeToIsoDate;

/// 목록 API `limit` — 서버 cursor 페이징과 맞춤 (앱·서버 공통 기본값).
const int kListPageSize = 30;

/// 캘린더 마커 API(`/dashboard/calendar-events`, `calendar-workforce-dots`) 기간 상한.
const int kCalendarMarkersMaxDays = 400;

/// 목록 API 공통 쿼리 (`limit`, `cursor`, 스코프 필터).
class ListQuery {
  const ListQuery({
    this.pid,
    this.hid,
    this.from,
    this.to,
    this.q,
    this.hdelete,
    this.pcomplete,
    this.photoType,
    this.wcomplete,
    this.limit = kListPageSize,
    this.cursor,
  });

  final int? pid;
  final int? hid;
  final String? from;
  final String? to;
  final String? q;
  final int? hdelete;
  final int? pcomplete;
  final String? photoType;
  final int? wcomplete;
  final int limit;
  final String? cursor;

  bool get hasScopeFilter =>
      pid != null ||
      hid != null ||
      from != null ||
      to != null ||
      (q != null && q!.trim().isNotEmpty) ||
      hdelete != null ||
      pcomplete != null ||
      photoType != null ||
      wcomplete != null;

  ListQuery copyWith({
    int? pid,
    int? hid,
    String? from,
    String? to,
    String? q,
    int? hdelete,
    int? pcomplete,
    String? photoType,
    int? wcomplete,
    int? limit,
    String? cursor,
    bool clearCursor = false,
  }) {
    return ListQuery(
      pid: pid ?? this.pid,
      hid: hid ?? this.hid,
      from: from ?? this.from,
      to: to ?? this.to,
      q: q ?? this.q,
      hdelete: hdelete ?? this.hdelete,
      pcomplete: pcomplete ?? this.pcomplete,
      photoType: photoType ?? this.photoType,
      wcomplete: wcomplete ?? this.wcomplete,
      limit: limit ?? this.limit,
      cursor: clearCursor ? null : (cursor ?? this.cursor),
    );
  }

  Map<String, dynamic> toQueryParameters() {
    final m = <String, dynamic>{'limit': limit};
    if (pid != null) m['pid'] = pid;
    if (hid != null) m['hid'] = hid;
    final f = from?.trim();
    if (f != null && f.isNotEmpty) m['from'] = f;
    final t = to?.trim();
    if (t != null && t.isNotEmpty) m['to'] = t;
    final qq = q?.trim();
    if (qq != null && qq.isNotEmpty) m['q'] = qq;
    if (hdelete != null) m['hdelete'] = hdelete;
    if (pcomplete != null) m['pcomplete'] = pcomplete;
    final pt = photoType?.trim();
    if (pt != null && pt.isNotEmpty) m['photo_type'] = pt;
    if (wcomplete != null) m['wcomplete'] = wcomplete;
    final c = cursor?.trim();
    if (c != null && c.isNotEmpty) m['cursor'] = c;
    return m;
  }
}

ListQuery listQueryForDateRange(
  DateTime start,
  DateTime end, {
  int? pid,
  int? hid,
  int limit = kListPageSize,
}) {
  return ListQuery(
    pid: pid,
    hid: hid,
    from: formatDateTimeToIsoDate(start),
    to: formatDateTimeToIsoDate(end),
    limit: limit,
  );
}

/// 단일 일자 스코프 조회. 서버 `to`가 exclusive(`[from, to)`)여도 해당 일이 포함되도록
/// `to`는 다음 날 00:00 기준으로 보낸다.
ListQuery listQueryForSingleDay(
  DateTime day, {
  int? pid,
  int? hid,
  int limit = kListPageSize,
}) {
  final start = DateTime(day.year, day.month, day.day);
  final endExclusive = start.add(const Duration(days: 1));
  return ListQuery(
    pid: pid,
    hid: hid,
    from: formatDateTimeToIsoDate(start),
    to: formatDateTimeToIsoDate(endExclusive),
    limit: limit,
  );
}

/// 캘린더 마커 조회 — 보이는 달 기준 이전·다음 달 포함(약 3개월).
({String from, String to}) calendarMarkerRangeAroundMonth(DateTime anchor) {
  final month = DateTime(anchor.year, anchor.month, 1);
  final from = DateTime(month.year, month.month - 1, 1);
  final toInclusive = DateTime(month.year, month.month + 2, 0);
  return (
    from: formatDateTimeToIsoDate(from),
    to: formatDateTimeToIsoDate(toInclusive),
  );
}

/// 레거시·FCM 등 — 넓은 기간 `[from, to)` (상한 [kCalendarMarkersMaxDays]일).
({String from, String to}) calendarMarkersDateRange([DateTime? anchor]) {
  final today = anchor ?? DateTime.now();
  final day = DateTime(today.year, today.month, today.day);
  final back = kCalendarMarkersMaxDays ~/ 2;
  final from = day.subtract(Duration(days: back));
  final to = from.add(const Duration(days: kCalendarMarkersMaxDays));
  return (
    from: formatDateTimeToIsoDate(from),
    to: formatDateTimeToIsoDate(to),
  );
}

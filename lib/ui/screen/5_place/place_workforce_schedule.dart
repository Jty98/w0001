import 'package:flutter/material.dart';
import 'package:scrollable_calendar_package/calendar.dart';
import 'package:w0001/data/model/place_info_model.dart';
import 'package:w0001/data/model/remote/super_admin_dtos.dart';
import 'package:w0001/domain/process_schedule/process_schedule_models.dart';
import 'package:w0001/util/funtions.dart';

/// 공정표 그리드·캘린더 이벤트 계산 ([PlaceWorkforceScreen] 전용).
abstract final class PlaceWorkforceSchedule {
  PlaceWorkforceSchedule._();

  /// 캘린더 하단 점: 공정만 있는 날(날짜당 점 1개).
  static const Color _scheduleDayDot = Color(0xFF6B7280);

  /// 캘린더 하단 점: 인력 투입이 있는 날 — 공정만 함께 있어도 이 색 점 1개만.
  static const Color _workforceDayDot = Color(0xFF16A34A);

  /// 공정 점/범례 공용 색.
  static Color get scheduleDayDotColor => _scheduleDayDot;

  /// 인력 투입 점/범례 공용 색.
  static Color get workforceDayDotColor => _workforceDayDot;

  /// 전역 캘린더 탭: 현장 일정(공정·투입)만 있는 날.
  static const Color _siteDayDot = Color(0xFF6B7280);

  /// 전역 캘린더 탭: 해당 일자에 비용(인건·자재)이 있는 날 — 현장만 있는 날보다 우선.
  static const Color _costDayDot = Color(0xFF16A34A);

  static DateTime gridEnd(ProcessScheduleData d) => DateTime(
        d.gridStart.year,
        d.gridStart.month,
        d.gridStart.day,
      ).add(Duration(days: d.dayCount - 1));

  static DateTime clampToGrid(DateTime day, ProcessScheduleData d) {
    final x = DateTime(day.year, day.month, day.day);
    final start =
        DateTime(d.gridStart.year, d.gridStart.month, d.gridStart.day);
    final end = gridEnd(d);
    if (x.isBefore(start)) return start;
    if (x.isAfter(end)) return end;
    return x;
  }

  static int? dayIndex(DateTime day, ProcessScheduleData d) {
    final x = DateTime(day.year, day.month, day.day);
    final start =
        DateTime(d.gridStart.year, d.gridStart.month, d.gridStart.day);
    final idx = x.difference(start).inDays;
    if (idx < 0 || idx >= d.dayCount) return null;
    return idx;
  }

  static (DateTime?, DateTime?) placeCalendarRange(PlaceInfoModel p) =>
      placeCalendarRangeFromPstartPend(p.pstart, p.pend);

  /// 현장 마스터 `pstart`/`pend` 문자열로 표시 구간 계산 ([PlaceModel] 등 공통).
  static (DateTime?, DateTime?) placeCalendarRangeFromPstartPend(
    String pstart,
    String pend,
  ) {
    final a = DateTime.tryParse(pstart.trim());
    final b = DateTime.tryParse(pend.trim());
    if (a == null) return (null, null);
    final s = DateTime(a.year, a.month, a.day);
    if (b == null) return (s, null);
    final e = DateTime(b.year, b.month, b.day);
    return (s, e.isBefore(s) ? s : e);
  }

  /// [unionPlaceAndScheduleCalendarRange] 와 동일하되 마스터 날짜만 문자열로 받는다.
  static (DateTime?, DateTime?) unionPlaceStringsAndScheduleCalendarRange(
    String pstart,
    String pend,
    ProcessScheduleData d,
  ) {
    final a = placeCalendarRangeFromPstartPend(pstart, pend);
    final b = scheduleCalendarRange(d);
    DateTime? minD(DateTime? x, DateTime? y) {
      if (x == null) return y;
      if (y == null) return x;
      return x.isBefore(y) ? x : y;
    }

    DateTime? maxD(DateTime? x, DateTime? y) {
      if (x == null) return y;
      if (y == null) return x;
      return x.isAfter(y) ? x : y;
    }

    final start = minD(a.$1, b.$1);
    var end = maxD(a.$2, b.$2);
    if (start != null && end != null && end.isBefore(start)) {
      end = start;
    }
    return (start, end);
  }

  /// 공정표 그리드 첫 열~마지막 열(포함) 날짜.
  static (DateTime?, DateTime?) scheduleCalendarRange(ProcessScheduleData d) {
    final s = DateTime(d.gridStart.year, d.gridStart.month, d.gridStart.day);
    if (d.dayCount < 1) return (s, s);
    final e = DateTime(
      d.gridStart.year,
      d.gridStart.month,
      d.gridStart.day + d.dayCount - 1,
    );
    return (s, e);
  }

  /// 현장 마스터 기간과 공정표 그리드를 한 범위로 합쳐 캘린더에 동일하게 쓴다.
  static (DateTime?, DateTime?) unionPlaceAndScheduleCalendarRange(
    PlaceInfoModel p,
    ProcessScheduleData d,
  ) =>
      unionPlaceStringsAndScheduleCalendarRange(p.pstart, p.pend, d);

  static List<CalendarEvent> buildCalendarEvents(
    ProcessScheduleData d,
    Iterable<PlaceWorkDayRead> placeRows,
  ) {
    final byDay = <String, ({bool sch, bool work})>{};
    mergeSchWorkFlagsFromSchedule(d, byDay);
    mergeSchWorkFlagsFromPlaceRows(placeRows, byDay);
    return calendarDotEventsFromSchWorkMap(byDay);
  }

  static void mergeSchWorkFlagsFromSchedule(
    ProcessScheduleData d,
    Map<String, ({bool sch, bool work})> byDay,
  ) {
    for (var ti = 0; ti < d.tasks.length; ti++) {
      final t = d.tasks[ti];
      for (final di in t.scheduledDayIndices) {
        if (di < 0 || di >= d.dayCount) continue;
        final date = DateTime(
          d.gridStart.year,
          d.gridStart.month,
          d.gridStart.day + di,
        );
        final k = formatDateTimeToIsoDate(date);
        final prev = byDay[k] ?? (sch: false, work: false);
        byDay[k] = (sch: true, work: prev.work);
      }
    }
  }

  static void mergeSchWorkFlagsFromPlaceRows(
    Iterable<PlaceWorkDayRead> placeRows,
    Map<String, ({bool sch, bool work})> byDay,
  ) {
    for (final r in placeRows) {
      if (r.workdate.length < 10) continue;
      final k = normalizeToIsoDateString(r.workdate.substring(0, 10));
      final prev = byDay[k] ?? (sch: false, work: false);
      byDay[k] = (sch: prev.sch, work: true);
    }
  }

  /// [eventIdPrefix]: 여러 소스 합칠 때 캘린더 이벤트 id 충돌 방지.
  static List<CalendarEvent> calendarDotEventsFromSchWorkMap(
    Map<String, ({bool sch, bool work})> byDay, {
    String eventIdPrefix = '',
  }) {
    final events = <CalendarEvent>[];
    for (final e in byDay.entries) {
      final date = DateTime.tryParse(e.key);
      if (date == null) continue;
      final day = DateTime(date.year, date.month, date.day);
      final v = e.value;
      if (v.work) {
        events.add(CalendarEvent(
          startDate: day,
          endDate: day,
          id: '$eventIdPrefix${e.key}_day',
          title: v.sch ? '공정·투입' : '투입',
          color: _workforceDayDot,
        ));
      } else if (v.sch) {
        events.add(CalendarEvent(
          startDate: day,
          endDate: day,
          id: '$eventIdPrefix${e.key}_day',
          title: '공정',
          color: _scheduleDayDot,
        ));
      }
    }
    return events;
  }

  /// 전역 캘린더: 날짜당 점 1개. 비용이 있으면 초록, 없고 현장 일정만 있으면 회색.
  static List<CalendarEvent> calendarDotEventsFromSiteAndCosts({
    required Map<String, ({bool sch, bool work})> byDay,
    required Set<String> costDayKeys,
    String eventIdPrefix = '',
  }) {
    String dayKey(String raw) => normalizeToIsoDateString(
          raw.length >= 10 ? raw.substring(0, 10) : raw,
        );

    final merged = <String, ({bool sch, bool work})>{};
    for (final e in byDay.entries) {
      final key = dayKey(e.key);
      if (key.isEmpty) continue;
      final prev = merged[key] ?? (sch: false, work: false);
      merged[key] = (
        sch: prev.sch || e.value.sch,
        work: prev.work || e.value.work,
      );
    }

    final costs = <String>{};
    for (final c in costDayKeys) {
      final key = dayKey(c);
      if (key.isNotEmpty) costs.add(key);
    }

    final events = <CalendarEvent>[];
    final allKeys = {...merged.keys, ...costs}.toList()..sort();
    for (final key in allKeys) {
      final parsed = DateTime.tryParse(key);
      if (parsed == null) continue;
      final day = DateTime(parsed.year, parsed.month, parsed.day);
      final flags = merged[key] ?? (sch: false, work: false);
      final hasSite = flags.sch || flags.work;
      final hasCost = costs.contains(key);
      if (!hasSite && !hasCost) continue;

      events.add(
        CalendarEvent(
          startDate: day,
          endDate: day,
          id: '$eventIdPrefix${key}_dot',
          title: hasCost ? '비용' : '현장',
          color: hasCost ? _costDayDot : _siteDayDot,
        ),
      );
    }
    return events;
  }

  static List<(int index, ProcessScheduleTask task)> tasksOnDay(
    ProcessScheduleData d,
    int dayIndex,
  ) {
    final out = <(int, ProcessScheduleTask)>[];
    for (var i = 0; i < d.tasks.length; i++) {
      final t = d.tasks[i];
      if (t.scheduledDayIndices.contains(dayIndex)) {
        out.add((i, t));
      }
    }
    return out;
  }
}

/// 작업지시 화면 캘린더 — 기본 2주 모드에 맞춘 높이 상한 힌트.
double workforceCalendarHeight(BuildContext context) {
  final h = MediaQuery.sizeOf(context).height;
  if (h < 720) {
    return (h * 0.28).clamp(200.0, 280.0);
  }
  return (h * 0.32).clamp(240.0, 340.0);
}

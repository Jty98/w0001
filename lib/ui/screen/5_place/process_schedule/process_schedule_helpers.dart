import 'dart:math' as math;

import 'package:w0001/data/model/place_info_model.dart';
import 'package:w0001/domain/process_schedule/process_schedule_editor.dart';
import 'package:w0001/domain/process_schedule/process_schedule_models.dart';

String formatDateDotKo(DateTime d) =>
    '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';

/// 공정표 그리드 기간 한 줄 — 현장 설정과 동일하게 맞춘 열 기준.
String compactGridPeriodLine(ProcessScheduleData d) {
  if (d.dayCount < 1) return '';
  final s = ProcessScheduleEditor.dayAtGridIndex(d, 0);
  final e = ProcessScheduleEditor.dayAtGridIndex(d, d.dayCount - 1);
  return '${s.month}.${s.day} ~ ${e.month}.${e.day} [${d.dayCount}일]';
}

/// 현장 마스터(`PlaceInfoModel`)에 저장된 공사 기간 — 표시용.
(DateTime?, DateTime?) savedPlacePeriodDates(PlaceInfoModel element) {
  try {
    if (element.pstart.trim().isEmpty) return (null, null);
    final s = DateTime.parse(element.pstart);
    final dStart = DateTime(s.year, s.month, s.day);
    final pendRaw = element.pend.trim();
    if (pendRaw.isEmpty || pendRaw == '0') {
      return (dStart, dStart);
    }
    final p = DateTime.parse(element.pend);
    final dEnd = DateTime(p.year, p.month, p.day);
    return (dStart, dEnd);
  } catch (_) {
    return (null, null);
  }
}

String periodDropdownLabel(DateTime d) {
  const w = ['월', '화', '수', '목', '금', '토', '일'];
  return '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')} (${w[d.weekday - 1]})';
}

/// 현재 표 구간을 중심으로 앞뒤 날짜를 두어 선택지 생성(약 541일).
List<DateTime> placePeriodDatePool(DateTime anchorStart, DateTime anchorEnd) {
  final a = DateTime(anchorStart.year, anchorStart.month, anchorStart.day);
  final b = DateTime(anchorEnd.year, anchorEnd.month, anchorEnd.day);
  final spanDays = b.difference(a).inDays;
  final mid = a.add(Duration(days: math.max(0, spanDays ~/ 2)));
  final poolStart =
      DateTime(mid.year, mid.month, mid.day).subtract(const Duration(days: 270));
  return List.generate(541, (i) => poolStart.add(Duration(days: i)));
}

int indexNearestDay(List<DateTime> dates, DateTime d) {
  final t = DateTime(d.year, d.month, d.day);
  for (var i = 0; i < dates.length; i++) {
    final x = dates[i];
    if (x.year == t.year && x.month == t.month && x.day == t.day) return i;
  }
  var best = 0;
  var bestD = 1 << 30;
  for (var i = 0; i < dates.length; i++) {
    final diff = dates[i].difference(t).inDays.abs();
    if (diff < bestD) {
      bestD = diff;
      best = i;
    }
  }
  return best;
}

String weekdayKoShort(int weekday) {
  const w = ['월', '화', '수', '목', '금', '토', '일'];
  return w[weekday - 1];
}

String scheduleDateHeaderLabel(DateTime d) {
  return '${d.month}/${d.day}(${weekdayKoShort(d.weekday)})';
}

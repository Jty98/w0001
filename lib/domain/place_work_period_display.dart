import 'package:w0001/data/model/place_info_model.dart';
import 'package:w0001/data/model/remote/super_admin_dtos.dart';
import 'package:w0001/util/funtions.dart';

DateTime? parsePlaceCalendarDay(String? raw) {
  final t = raw?.trim() ?? '';
  if (t.isEmpty || t == '0') return null;
  final d = DateTime.tryParse(t);
  if (d == null) return null;
  return DateTime(d.year, d.month, d.day);
}

/// 슬라이드로 '완료'로 바꿀 때 **기본**으로 쓰는 `pend` (다이얼로그 "기존 종료일" 표시에도 사용).
/// `pend`가 비어 있거나 `0`이면 `pstart`로 보정한다.
String pendWhenTogglingToComplete(PlaceInfoModel p) {
  final pend = p.pend.trim();
  if (pend.isNotEmpty && pend != '0') {
    return pend;
  }
  final s = p.pstart.trim();
  if (s.isNotEmpty && s != '0') {
    return s;
  }
  return '0';
}

String _ymdKey(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// 계약 마감일 **이후** 실제 작업 투입(`place-work-days`)이 있는 날짜 수.
Map<int, int> buildContractOverWorkDayCounts({
  required List<PlaceInfoModel> places,
  required Map<int, String> contractPendByPid,
  required List<PlaceWorkDayRead> workRows,
}) {
  final contractEndByPid = <int, DateTime>{};
  for (final p in places) {
    final pid = p.pid;
    if (pid == null) continue;
    final end = parsePlaceCalendarDay(
      resolveContractPendIso(
        place: p,
        contractPendIso: contractPendByPid[pid],
      ),
    );
    if (end != null) contractEndByPid[pid] = end;
  }

  final daysByPid = <int, Set<String>>{};
  for (final row in workRows) {
    final contractEnd = contractEndByPid[row.pid];
    if (contractEnd == null) continue;
    final workDay = parsePlaceCalendarDay(row.workdate);
    if (workDay == null || !workDay.isAfter(contractEnd)) continue;
    daysByPid.putIfAbsent(row.pid, () => {}).add(_ymdKey(workDay));
  }

  return {for (final e in daysByPid.entries) e.key: e.value.length};
}

String? contractOverWorkDaysLabel(int? dayCount) {
  if (dayCount == null || dayCount <= 0) return null;
  return '계약 외 $dayCount일';
}

/// 현장 리스트·요약에 쓸 계약 기간 / 계약 외 일수 / D-day 라벨.
class PlaceListPeriodLabels {
  const PlaceListPeriodLabels({
    required this.contractPeriodLine,
    this.additionalWorkLine,
    this.ddayLabel,
  });

  /// 계약(마감) 기준 `시작 ~ 종료`.
  final String contractPeriodLine;

  /// 계약 종료일 이후 연장 일수 (`계약 외 N일`).
  final String? additionalWorkLine;

  /// `D-3`, `D-Day` 등. 완료·기한 경과(진행중)면 null.
  final String? ddayLabel;
}

PlaceListPeriodLabels buildPlaceListPeriodLabels({
  required PlaceInfoModel place,
  String? contractPendIso,
  int? contractOverWorkDayCount,
  DateTime? today,

  /// 관리자만 `계약 외 N일` 표시. 작업자는 계약 마감 기간만.
  bool includeAdditionalWork = true,
}) {
  final now = today ?? DateTime.now();
  final todayOnly = DateTime(now.year, now.month, now.day);

  final contractPend = resolveContractPendIso(
    place: place,
    contractPendIso: contractPendIso,
  );

  final contractPeriodLine = formatDuration(place.pstart, contractPend);

  final contractEnd = parsePlaceCalendarDay(contractPend);

  final additionalWorkLine = includeAdditionalWork
      ? contractOverWorkDaysLabel(contractOverWorkDayCount)
      : null;

  String? ddayLabel;
  if (place.pcomplete != 1 && contractEnd != null) {
    final days = contractEnd.difference(todayOnly).inDays;
    if (days >= 0) {
      ddayLabel = days == 0 ? 'D-Day' : 'D-$days';
    }
  }

  return PlaceListPeriodLabels(
    contractPeriodLine: contractPeriodLine,
    additionalWorkLine: additionalWorkLine,
    ddayLabel: ddayLabel,
  );
}

/// 계약 마감일 ISO — 로컬 보관값과 현장 `pend` 중 **이른 쪽**을 쓴다.
/// (공정표 연장으로 `pend`만 길어진 경우 로컬 마감이 실제 계약일이다.)
String resolveContractPendIso({
  required PlaceInfoModel place,
  String? contractPendIso,
}) {
  final local = parsePlaceCalendarDay(contractPendIso);
  final masterRaw = pendWhenTogglingToComplete(place);
  final master = parsePlaceCalendarDay(masterRaw);

  if (local != null && master != null) {
    return local.isBefore(master) ? contractPendIso!.trim() : masterRaw;
  }
  if (local != null) return contractPendIso!.trim();
  return masterRaw;
}

import 'package:w0001/data/model/remote/super_admin_json.dart';
import 'package:w0001/data/model/worker_announcement_models.dart';
import 'package:w0001/domain/place_archive.dart';
import 'package:w0001/util/work_instruction_layers_merge.dart';

/// 공통 월·연 합계 블록
class WorkerDashboardTotals {
  const WorkerDashboardTotals({
    required this.totalEarned,
    required this.totalPaid,
    required this.totalOutstanding,
  });

  factory WorkerDashboardTotals.fromJson(Map<String, dynamic> j) {
    return WorkerDashboardTotals(
      totalEarned: _firstInt(j, ['total_earned', 'totalEarned', 'earned']) ?? 0,
      totalPaid: _firstInt(j, ['total_paid', 'totalPaid', 'paid']) ?? 0,
      totalOutstanding: _firstInt(j, [
            'total_outstanding',
            'totalOutstanding',
            'outstanding',
          ]) ??
          0,
    );
  }

  final int totalEarned;
  final int totalPaid;
  final int totalOutstanding;
}

/// 투입 일별 행
class WorkerDashboardWorkDay {
  const WorkerDashboardWorkDay({
    required this.pwdid,
    required this.pid,
    required this.placeName,
    required this.workdate,
    required this.workrole,
    required this.dailywage,
    required this.paid,
    required this.earnedAmount,
    required this.outstandingAmount,
    required this.instructionPreview,
    this.instructionBlocks = const [],
    this.placeComplete = -1,
  });

  factory WorkerDashboardWorkDay.fromJson(Map<String, dynamic> j) {
    final rawPreview = j['instruction_preview'] ?? j['instructionPreview'];
    final dailywage = _firstInt(j, ['dailywage', 'daily_wage', 'wage']) ?? 0;
    final paid = _parsePaidFlag(j);
    final earned = _firstInt(j, ['earned_amount', 'earnedAmount']) ?? 0;
    final outstanding =
        _firstInt(j, ['outstanding_amount', 'outstandingAmount']) ?? 0;
    final hasExplicitIndividual =
        j.containsKey('individual_instruction_blocks') ||
            j.containsKey('individualInstructionBlocks');
    final site = parseSiteInstructionBlocks(j);
    final process = parseProcessInstructionBlocks(j);
    final individual = hasExplicitIndividual
        ? parseIndividualInstructionBlocks(j)
        : const <WorkerAnnouncementBlock>[];
    final mergedRaw = parseWorkerAnnouncementBlockList(
      j['instruction_blocks'] ??
          j['work_instruction_blocks'] ??
          j['instructionBlocks'],
    );
    final resolved = mergeWorkInstructionLayers(
      site: site,
      process: process,
      individual: individual,
      mergedFallback: mergedRaw,
    );
    final placeComplete = _firstInt(j, [
          'pcomplete',
          'place_pcomplete',
          'placePcomplete',
          'place_complete',
        ]) ??
        -1;
    final rawName = _firstString(j, ['place_name', 'placeName', 'pname']) ?? '';
    final displayName = placeComplete >= 0
        ? formatPlaceDisplayName(rawName, pcomplete: placeComplete)
        : rawName;
    return WorkerDashboardWorkDay(
      pwdid: _firstInt(j, ['pwdid', 'pwd_id', 'place_work_day_id']) ?? 0,
      pid: _firstInt(j, ['pid', 'place_id', 'placeId']) ?? 0,
      placeName: displayName,
      workdate: _firstString(j, ['workdate', 'work_date', 'taskdate']) ?? '',
      workrole: _firstString(j, ['workrole', 'work_role', 'wrole']) ?? '',
      dailywage: dailywage,
      paid: paid,
      earnedAmount: earned,
      outstandingAmount: outstanding,
      instructionPreview: rawPreview == null ? '' : rawPreview.toString(),
      instructionBlocks: resolved,
      placeComplete: placeComplete,
    );
  }

  /// 일정 카드용 일당(요율). 같은 날 다른 현장과 합산하지 않음.
  int get displayDailyRate => dailywage > 0 ? dailywage : earnedAmount;

  /// 서버가 `earned_amount`를 안 내려줄 때 투입 일당으로 표시.
  /// 합계에는 쓰지 말고 [workerDashboardTotalsFromWorkDays]를 쓴다.
  int get effectiveWorkedAmount => earnedAmount > 0 ? earnedAmount : dailywage;

  int get effectiveUnsettledAmount {
    if (outstandingAmount > 0) return outstandingAmount;
    if (!paidComplete && dailywage > 0) return dailywage;
    return 0;
  }

  int get effectiveSettledAmount =>
      paidComplete ? (dailywage > 0 ? dailywage : earnedAmount) : 0;

  final int pwdid;
  final int pid;
  final String placeName;
  final String workdate;
  final String workrole;
  final int dailywage;

  /// 1 → 지급 완료 등(서버 정의와 동일)
  final int paid;
  final int earnedAmount;
  final int outstandingAmount;
  final String instructionPreview;
  final List<WorkerAnnouncementBlock> instructionBlocks;

  /// 현장 `pcomplete`. 모르면 -1.
  final int placeComplete;

  bool get paidComplete => paid == 1;

  /// `YYYY-MM-DD` 접두만
  String get dateKey {
    final t = workdate.trim();
    return t.length >= 10 ? t.substring(0, 10) : t;
  }
}

class WorkerDashboardSummary {
  const WorkerDashboardSummary({
    required this.hid,
    required this.workerDisplayName,
    required this.year,
    required this.month,
    required this.workDays,
    this.placeRollups = const [],
    required this.monthTotals,
    required this.yearTotals,
  });

  factory WorkerDashboardSummary.fromJson(Map<String, dynamic> j) {
    final days = _parseWorkDaysList(
      j['work_days'] ?? j['workDays'] ?? j['assignments'],
    );
    final rollups = _parsePlaceRollupsList(
      j['place_rollups'] ?? j['placeRollups'],
    );

    WorkerDashboardTotals? mt;
    final mtot = j['month_totals'];
    if (mtot is Map) {
      mt = WorkerDashboardTotals.fromJson(Map<String, dynamic>.from(mtot));
    }

    WorkerDashboardTotals? yt;
    final ytot = j['year_totals'];
    if (ytot is Map) {
      yt = WorkerDashboardTotals.fromJson(Map<String, dynamic>.from(ytot));
    }

    return WorkerDashboardSummary(
      hid: _asInt(j['hid']),
      workerDisplayName: (j['worker_display_name'] ?? '').toString(),
      year: _asInt(j['year']) ?? DateTime.now().year,
      month: _asInt(j['month']),
      workDays: days,
      placeRollups: rollups,
      monthTotals: mt,
      yearTotals: yt,
    );
  }

  final int? hid;
  final String workerDisplayName;
  final int year;

  /// 응답에 없으면 null (연간-only 조회 등)
  final int? month;

  final List<WorkerDashboardWorkDay> workDays;

  /// 서버가 내려주면 클라이언트 재집계 대신 사용.
  final List<WorkerDashboardPlaceRollup> placeRollups;
  final WorkerDashboardTotals? monthTotals;
  final WorkerDashboardTotals? yearTotals;

  bool get humanLinked => hid != null && hid! > 0;
}

/// 선택 구간 내 [work_days]를 현장(pid)별 집계(대시보드 하단 카드용).
class WorkerDashboardPlaceRollup {
  const WorkerDashboardPlaceRollup({
    required this.pid,
    required this.placeName,
    required this.workedTotal,
    required this.settledTotal,
    required this.unsettledTotal,
  });

  final int pid;
  final String placeName;

  /// `earned_amount` 합계
  final int workedTotal;

  /// 지급 완료 행의 `dailywage` 합계
  final int settledTotal;

  /// `outstanding_amount` 합계
  final int unsettledTotal;

  factory WorkerDashboardPlaceRollup.fromJson(Map<String, dynamic> j) {
    final placeComplete = _firstInt(j, [
          'pcomplete',
          'place_pcomplete',
          'placePcomplete',
          'place_complete',
        ]) ??
        -1;
    final rawName = _firstString(j, ['place_name', 'placeName', 'pname']) ?? '';
    final displayName = placeComplete >= 0
        ? formatPlaceDisplayName(rawName, pcomplete: placeComplete)
        : rawName;
    return WorkerDashboardPlaceRollup(
      pid: _firstInt(j, ['pid', 'place_id']) ?? 0,
      placeName: displayName,
      workedTotal: _firstInt(j, [
            'worked_total',
            'workedTotal',
            'total_earned',
            'earned_total',
          ]) ??
          0,
      settledTotal: _firstInt(j, [
            'settled_total',
            'settledTotal',
            'total_paid',
            'paid_total',
          ]) ??
          0,
      unsettledTotal: _firstInt(j, [
            'unsettled_total',
            'unsettledTotal',
            'total_outstanding',
            'outstanding_total',
          ]) ??
          0,
    );
  }
}

/// GET `/worker/places/:pid/coworkers-by-date`
class CoworkerOnSite {
  const CoworkerOnSite({
    required this.workerName,
    required this.workrole,
    required this.hid,
  });

  factory CoworkerOnSite.fromJson(Map<String, dynamic> j) {
    return CoworkerOnSite(
      workerName: (j['worker_name'] ?? '').toString(),
      workrole: (j['workrole'] ?? '').toString(),
      hid: _asInt(j['hid']) ?? 0,
    );
  }

  final String workerName;
  final String workrole;
  final int hid;
}

int? _asInt(dynamic v) => saInt(v);

int? _firstInt(Map<String, dynamic> m, List<String> keys) {
  for (final k in keys) {
    final v = _asInt(m[k]);
    if (v != null) return v;
  }
  return null;
}

String? _firstString(Map<String, dynamic> m, List<String> keys) {
  for (final k in keys) {
    final v = saString(m[k]);
    if (v != null && v.trim().isNotEmpty) return v.trim();
  }
  return null;
}

int _parsePaidFlag(Map<String, dynamic> j) {
  final b = saBool(j['paid']);
  if (b != null) return b ? 1 : 0;
  return _firstInt(j, ['paid', 'is_paid']) ?? 0;
}

List<WorkerDashboardWorkDay> _parseWorkDaysList(Object? raw) {
  if (raw is! List) return const [];
  final out = <WorkerDashboardWorkDay>[];
  for (final e in raw) {
    if (e is! Map) continue;
    final m = e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e);
    final row = WorkerDashboardWorkDay.fromJson(m);
    if (row.pid <= 0 &&
        row.pwdid <= 0 &&
        row.placeName.trim().isEmpty &&
        row.dailywage <= 0) {
      continue;
    }
    out.add(row);
  }
  return out;
}

List<WorkerDashboardPlaceRollup> _parsePlaceRollupsList(Object? raw) {
  if (raw is! List) return const [];
  final out = <WorkerDashboardPlaceRollup>[];
  for (final e in raw) {
    if (e is! Map) continue;
    final m = e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e);
    final row = WorkerDashboardPlaceRollup.fromJson(m);
    if (row.pid <= 0 && row.placeName.isEmpty) continue;
    out.add(row);
  }
  out.sort((a, b) => a.placeName.compareTo(b.placeName));
  return out;
}

Map<String, List<WorkerDashboardWorkDay>> _groupWorkDaysByDate(
  Iterable<WorkerDashboardWorkDay> days,
) {
  final byDate = <String, List<WorkerDashboardWorkDay>>{};
  for (final w in days) {
    final k = w.dateKey;
    if (k.isEmpty) continue;
    byDate.putIfAbsent(k, () => []).add(w);
  }
  return byDate;
}

int _dayEarnedAmount(List<WorkerDashboardWorkDay> rows) {
  for (final r in rows) {
    if (r.earnedAmount > 0) return r.earnedAmount;
  }
  for (final r in rows) {
    if (r.dailywage > 0) return r.dailywage;
  }
  return 0;
}

int _daySettledAmount(List<WorkerDashboardWorkDay> rows) {
  if (!rows.any((r) => r.paidComplete)) return 0;
  for (final r in rows) {
    if (r.paidComplete && r.earnedAmount > 0) return r.earnedAmount;
  }
  return _dayEarnedAmount(rows);
}

int _dayUnsettledAmount(List<WorkerDashboardWorkDay> rows) {
  if (!rows.any((r) => !r.paidComplete)) return 0;
  for (final r in rows) {
    if (!r.paidComplete && r.outstandingAmount > 0) return r.outstandingAmount;
  }
  return _dayEarnedAmount(rows);
}

WorkerDashboardWorkDay? _canonicalWorkDayForPay(
  List<WorkerDashboardWorkDay> rows,
) {
  for (final r in rows) {
    if (r.earnedAmount > 0) return r;
  }
  if (rows.isEmpty) return null;
  final copy = [...rows]..sort((a, b) {
      final c = a.pwdid.compareTo(b.pwdid);
      if (c != 0) return c;
      return a.pid.compareTo(b.pid);
    });
  return copy.first;
}

int _workDayPidKey(WorkerDashboardWorkDay w) {
  if (w.pid > 0) return w.pid;
  final name = w.placeName.trim();
  if (name.isEmpty) return 0;
  return -name.hashCode;
}

/// 같은 날 여러 현장이어도 금액은 1공수만 합산.
WorkerDashboardTotals workerDashboardTotalsFromWorkDays(
  Iterable<WorkerDashboardWorkDay> days,
) {
  var earned = 0;
  var paid = 0;
  var outstanding = 0;
  for (final rows in _groupWorkDaysByDate(days).values) {
    earned += _dayEarnedAmount(rows);
    paid += _daySettledAmount(rows);
    outstanding += _dayUnsettledAmount(rows);
  }
  return WorkerDashboardTotals(
    totalEarned: earned,
    totalPaid: paid,
    totalOutstanding: outstanding,
  );
}

/// 현장별 카드. 같은 날 1공수는 금액이 있는 현장(없으면 첫 현장)에만 더한다.
List<WorkerDashboardPlaceRollup> workerDashboardPlaceRollupsFromWorkDays(
  Iterable<WorkerDashboardWorkDay> days,
) {
  final byPid =
      <int, ({String name, int worked, int settled, int unsettled})>{};
  ({String name, int worked, int settled, int unsettled}) ensure(int pid) {
    return byPid.putIfAbsent(
      pid,
      () => (name: '', worked: 0, settled: 0, unsettled: 0),
    );
  }

  void touchName(int pid, String placeName) {
    final prev = ensure(pid);
    if (prev.name.isNotEmpty || placeName.trim().isEmpty) return;
    byPid[pid] = (
      name: placeName.trim(),
      worked: prev.worked,
      settled: prev.settled,
      unsettled: prev.unsettled,
    );
  }

  for (final rows in _groupWorkDaysByDate(days).values) {
    for (final w in rows) {
      final pid = _workDayPidKey(w);
      if (pid == 0) continue;
      touchName(pid, w.placeName);
    }
    final canonical = _canonicalWorkDayForPay(rows);
    if (canonical == null) continue;
    final pid = _workDayPidKey(canonical);
    if (pid == 0) continue;
    final prev = ensure(pid);
    byPid[pid] = (
      name: prev.name.isNotEmpty ? prev.name : canonical.placeName.trim(),
      worked: prev.worked + _dayEarnedAmount(rows),
      settled: prev.settled + _daySettledAmount(rows),
      unsettled: prev.unsettled + _dayUnsettledAmount(rows),
    );
  }

  final out = byPid.entries
      .map(
        (e) => WorkerDashboardPlaceRollup(
          pid: e.key,
          placeName: e.value.name.isEmpty ? '현장 #${e.key}' : e.value.name,
          workedTotal: e.value.worked,
          settledTotal: e.value.settled,
          unsettledTotal: e.value.unsettled,
        ),
      )
      .toList(growable: false)
    ..sort((a, b) => a.placeName.compareTo(b.placeName));
  return out;
}

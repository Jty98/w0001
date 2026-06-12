import 'package:w0001/data/model/remote/super_admin_json.dart';
import 'package:w0001/data/model/worker_announcement_models.dart';

/// 공통 월·연 합계 블록
class WorkerDashboardTotals {
  const WorkerDashboardTotals({
    required this.totalEarned,
    required this.totalPaid,
    required this.totalOutstanding,
  });

  factory WorkerDashboardTotals.fromJson(Map<String, dynamic> j) {
    return WorkerDashboardTotals(
      totalEarned:
          _firstInt(j, ['total_earned', 'totalEarned', 'earned']) ?? 0,
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
  });

  factory WorkerDashboardWorkDay.fromJson(Map<String, dynamic> j) {
    final rawPreview =
        j['instruction_preview'] ?? j['instructionPreview'];
    final dailywage = _firstInt(j, ['dailywage', 'daily_wage', 'wage']) ?? 0;
    final paid = _parsePaidFlag(j);
    final earned = _firstInt(j, ['earned_amount', 'earnedAmount']) ?? 0;
    final outstanding =
        _firstInt(j, ['outstanding_amount', 'outstandingAmount']) ?? 0;
    return WorkerDashboardWorkDay(
      pwdid: _firstInt(j, ['pwdid', 'pwd_id', 'place_work_day_id']) ?? 0,
      pid: _firstInt(j, ['pid', 'place_id', 'placeId']) ?? 0,
      placeName: _firstString(j, ['place_name', 'placeName', 'pname']) ?? '',
      workdate: _firstString(j, ['workdate', 'work_date', 'taskdate']) ?? '',
      workrole: _firstString(j, ['workrole', 'work_role']) ?? '',
      dailywage: dailywage,
      paid: paid,
      earnedAmount: earned,
      outstandingAmount: outstanding,
      instructionPreview: rawPreview == null ? '' : rawPreview.toString(),
      instructionBlocks: parseWorkerAnnouncementBlockList(
        j['instruction_blocks'] ??
            j['work_instruction_blocks'] ??
            j['instructionBlocks'],
      ),
    );
  }

  /// 서버가 `earned_amount`를 안 내려줄 때 투입 일당으로 표시.
  int get effectiveWorkedAmount =>
      earnedAmount > 0 ? earnedAmount : dailywage;

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
      mt = WorkerDashboardTotals.fromJson(
          Map<String, dynamic>.from(mtot));
    }

    WorkerDashboardTotals? yt;
    final ytot = j['year_totals'];
    if (ytot is Map) {
      yt = WorkerDashboardTotals.fromJson(
          Map<String, dynamic>.from(ytot));
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
    return WorkerDashboardPlaceRollup(
      pid: _firstInt(j, ['pid', 'place_id']) ?? 0,
      placeName:
          _firstString(j, ['place_name', 'placeName', 'pname']) ?? '',
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
    final m = e is Map<String, dynamic>
        ? e
        : Map<String, dynamic>.from(e);
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
    final m = e is Map<String, dynamic>
        ? e
        : Map<String, dynamic>.from(e);
    final row = WorkerDashboardPlaceRollup.fromJson(m);
    if (row.pid <= 0 && row.placeName.isEmpty) continue;
    out.add(row);
  }
  out.sort((a, b) => a.placeName.compareTo(b.placeName));
  return out;
}

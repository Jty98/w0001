/// 일괄 인력투입 요청 모델
class BulkWorkforceAssignmentRequest {
  const BulkWorkforceAssignmentRequest({
    required this.startDate,
    required this.endDate,
    required this.assignments,
    this.siteInstructionBlocks,
    this.processInstructionBlocks,
  });

  final DateTime startDate;
  final DateTime endDate;
  final List<WorkforceAssignmentItem> assignments;
  final List<Map<String, dynamic>>? siteInstructionBlocks;
  final Map<String, List<Map<String, dynamic>>>? processInstructionBlocks;

  Map<String, dynamic> toJson() {
    return {
      'startDate': _formatDate(startDate), // ✅ camelCase
      'endDate': _formatDate(endDate), // ✅ camelCase
      'assignments': assignments.map((a) => a.toJson()).toList(),
      if (siteInstructionBlocks != null)
        'siteInstructionBlocks': siteInstructionBlocks, // ✅ camelCase
      if (processInstructionBlocks != null)
        'processInstructionBlocks': processInstructionBlocks, // ✅ camelCase
    };
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  int get dayCount {
    return endDate.difference(startDate).inDays + 1;
  }

  int get totalAssignments {
    return dayCount * assignments.length;
  }
}

/// 투입할 인력 항목
class WorkforceAssignmentItem {
  const WorkforceAssignmentItem({
    required this.hid,
    required this.workrole,
    required this.dailyWage,
    this.workerRank,
  });

  final int hid;
  final String workrole;
  final int dailyWage;
  final String? workerRank;

  Map<String, dynamic> toJson() {
    return {
      'hid': hid,
      'workrole': workrole,
      'dailyWage': dailyWage, // ✅ camelCase
      if (workerRank != null && workerRank!.isNotEmpty)
        'workerRank': workerRank,
    };
  }
}

/// 일괄 투입 응답
class BulkWorkforceAssignmentResponse {
  const BulkWorkforceAssignmentResponse({
    required this.createdCount,
    required this.dateRange,
    required this.assignmentsPerDay,
    required this.workDays,
  });

  final int createdCount;
  final DateRangeInfo dateRange;
  final int assignmentsPerDay;
  final List<PlaceWorkDaySimple> workDays;

  factory BulkWorkforceAssignmentResponse.fromJson(Map<String, dynamic> json) {
    return BulkWorkforceAssignmentResponse(
      createdCount: json['createdCount'] as int, // ✅ camelCase
      dateRange: DateRangeInfo.fromJson(
          json['dateRange'] as Map<String, dynamic>), // ✅ camelCase
      assignmentsPerDay: json['assignmentsPerDay'] as int, // ✅ camelCase
      workDays: (json['workDays'] as List) // ✅ camelCase
          .map((e) => PlaceWorkDaySimple.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class DateRangeInfo {
  const DateRangeInfo({
    required this.start,
    required this.end,
    required this.days,
  });

  final String start;
  final String end;
  final int days;

  factory DateRangeInfo.fromJson(Map<String, dynamic> json) {
    return DateRangeInfo(
      start: json['start'] as String,
      end: json['end'] as String,
      days: json['days'] as int,
    );
  }
}

class PlaceWorkDaySimple {
  const PlaceWorkDaySimple({
    required this.pwdid,
    required this.pid,
    required this.hid,
    required this.workdate,
    required this.workrole,
    required this.dailywage,
  });

  final int pwdid;
  final int pid;
  final int hid;
  final String workdate;
  final String workrole;
  final int dailywage;

  factory PlaceWorkDaySimple.fromJson(Map<String, dynamic> json) {
    return PlaceWorkDaySimple(
      pwdid: json['pwdid'] as int,
      pid: json['pid'] as int,
      hid: json['hid'] as int,
      workdate: json['workdate'] as String,
      workrole: json['workrole'] as String,
      dailywage: json['dailywage'] as int,
    );
  }
}

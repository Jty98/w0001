import 'package:w0001/data/model/remote/super_admin_json.dart';

/// 현장 멤버 정보.
class PlaceMemberRead {
  const PlaceMemberRead({
    required this.uid,
    required this.uname,
    required this.role,
    required this.addedAt,
    this.addedByUid,
    this.autoAdded = false,
  });

  final String uid;
  final String uname;
  final String role;
  final DateTime addedAt;
  final String? addedByUid;
  final bool autoAdded;

  factory PlaceMemberRead.fromJson(Map<String, dynamic> m) {
    DateTime parseDateTime(Object? v) {
      final s = saString(v)?.trim();
      if (s == null || s.isEmpty) return DateTime.now();
      return DateTime.tryParse(s) ?? DateTime.now();
    }

    return PlaceMemberRead(
      uid: saString(m['uid']) ?? '',
      uname: saString(m['uname']) ?? '',
      role: saString(m['role']) ?? 'worker',
      addedAt: parseDateTime(m['added_at'] ?? m['addedAt']),
      addedByUid: saString(m['added_by_uid'] ?? m['addedByUid']),
      autoAdded: m['auto_added'] == true || m['autoAdded'] == true,
    );
  }

  bool get isAdmin =>
      role == 'admin' || role == 'super_admin' || role == 'tax_admin';
  bool get isWorker => role == 'worker';
}

/// 작업자 초대 응답.
class PlaceMemberAddResponse {
  const PlaceMemberAddResponse({
    required this.pid,
    required this.uid,
    required this.addedAt,
    this.addedByUid,
    this.autoAdded = false,
    this.message,
  });

  final int pid;
  final String uid;
  final DateTime addedAt;
  final String? addedByUid;
  final bool autoAdded;
  final String? message;

  factory PlaceMemberAddResponse.fromJson(Map<String, dynamic> m) {
    DateTime parseDateTime(Object? v) {
      final s = saString(v)?.trim();
      if (s == null || s.isEmpty) return DateTime.now();
      return DateTime.tryParse(s) ?? DateTime.now();
    }

    return PlaceMemberAddResponse(
      pid: saInt(m['pid']) ?? 0,
      uid: saString(m['uid']) ?? '',
      addedAt: parseDateTime(m['added_at'] ?? m['addedAt']),
      addedByUid: saString(m['added_by_uid'] ?? m['addedByUid']),
      autoAdded: m['auto_added'] == true || m['autoAdded'] == true,
      message: saString(m['message']),
    );
  }
}

/// 작업자 제거 응답. 서버가 `warning`을 함께 내려줄 수 있습니다.
class PlaceMemberRemoveResponse {
  const PlaceMemberRemoveResponse({
    required this.pid,
    required this.workerUid,
    required this.accessRevoked,
    this.message,
    this.warning,
  });

  final int pid;
  final String workerUid;
  final bool accessRevoked;
  final String? message;
  final PlaceMemberRemoveWarning? warning;

  bool get hasWorkdayWarning {
    final w = warning;
    if (w == null) return false;
    if (w.workdayCount > 0) return true;
    if (w.code == 'WORKDAY_ASSIGNMENTS_EXIST') return true;
    return w.message.trim().isNotEmpty;
  }

  factory PlaceMemberRemoveResponse.fromJson(Map<String, dynamic> m) {
    return PlaceMemberRemoveResponse(
      pid: saInt(m['pid']) ?? 0,
      workerUid:
          saString(m['worker_uid'] ?? m['workerUid'] ?? m['uid']) ?? '',
      accessRevoked: m['access_revoked'] == true || m['accessRevoked'] == true,
      message: saString(m['message']),
      warning: _parseRemoveWarning(m),
    );
  }

  static PlaceMemberRemoveWarning? _parseRemoveWarning(Map<String, dynamic> m) {
    final w = m['warning'];
    if (w is Map) {
      return PlaceMemberRemoveWarning.fromJson(Map<String, dynamic>.from(w));
    }
    final count = saInt(m['workday_count'] ?? m['workdayCount']);
    final code = saString(m['warning_code'] ?? m['code']);
    if ((count ?? 0) > 0 || code == 'WORKDAY_ASSIGNMENTS_EXIST') {
      return PlaceMemberRemoveWarning(
        code: code ?? 'WORKDAY_ASSIGNMENTS_EXIST',
        message: saString(m['warning_message'] ?? m['message']) ?? '',
        workdayCount: count ?? 0,
        recommendation: saString(m['recommendation']),
      );
    }
    return null;
  }
}

class PlaceMemberRemoveWarning {
  const PlaceMemberRemoveWarning({
    required this.code,
    required this.message,
    required this.workdayCount,
    this.recommendation,
  });

  final String code;
  final String message;
  final int workdayCount;
  final String? recommendation;

  factory PlaceMemberRemoveWarning.fromJson(Map<String, dynamic> m) {
    return PlaceMemberRemoveWarning(
      code: saString(m['code']) ?? '',
      message: saString(m['message']) ?? '',
      workdayCount: saInt(m['workday_count'] ?? m['workdayCount']) ?? 0,
      recommendation: saString(m['recommendation']),
    );
  }
}

import 'package:w0001/data/datasources/remote/list_query.dart';
import 'package:w0001/data/datasources/remote/remote_list_pages.dart';
import 'package:w0001/data/model/auth_models.dart';
import 'package:w0001/data/model/human_model.dart';
import 'package:w0001/domain/use_case/super_admin_remote_use_case.dart';

/// 연결된 앱 계정 상태 (`GET /humans` 응답에 포함될 수 있음).
({bool isActive, UserApprovalStatus approval}) parseLinkedUserAccountFromMap(
  Map<String, dynamic> m,
) {
  final uid = _trimStr(m['uid'] ?? m['user_uid']);
  if (uid == null || uid.isEmpty) {
    return (isActive: true, approval: UserApprovalStatus.approved);
  }

  final approvalRaw = m['linked_user_approval_status'] ??
      m['linkedUserApprovalStatus'] ??
      m['user_approval_status'] ??
      m['userApprovalStatus'] ??
      m['approval_status'] ??
      m['approvalStatus'];

  final activeRaw = m['linked_user_is_active'] ??
      m['linkedUserIsActive'] ??
      m['user_is_active'] ??
      m['userIsActive'];

  final nested = m['linked_user'] ?? m['linkedUser'];
  final nestedMap = nested is Map ? Map<String, dynamic>.from(nested) : null;

  final approval = UserApprovalStatus.parse(
    approvalRaw is String
        ? approvalRaw
        : (nestedMap?['approval_status'] ?? nestedMap?['approvalStatus'])
            as String?,
  );

  var isActive = true;
  final raw = activeRaw ?? nestedMap?['is_active'] ?? nestedMap?['isActive'];
  if (raw is bool) {
    isActive = raw;
  } else if (raw is num) {
    isActive = raw != 0;
  } else if (raw is String) {
    final s = raw.toLowerCase();
    isActive = s == 'true' || s == '1';
  }

  return (isActive: isActive, approval: approval);
}

String? _trimStr(Object? v) {
  final s = v?.toString().trim() ?? '';
  return s.isEmpty ? null : s;
}

/// 작업 투입 가능 여부 (비회원·활동 중 승인 회원만).
bool humanCanBeAssignedToWork(
  HumanModel human, {
  Set<String>? blockedMemberUids,
}) {
  final uid = human.uid?.trim() ?? '';
  if (uid.isEmpty) return true;

  if (human.linkedUserApprovalStatus != UserApprovalStatus.approved) {
    return false;
  }
  if (!human.linkedUserIsActive) return false;

  if (blockedMemberUids != null && blockedMemberUids.contains(uid)) {
    return false;
  }

  return true;
}

String humanWorkAssignBlockMessage(
  HumanModel human, {
  Set<String>? blockedMemberUids,
}) {
  final uid = human.uid?.trim() ?? '';
  if (uid.isEmpty) return '작업에 투입할 수 없는 인력입니다.';

  switch (human.linkedUserApprovalStatus) {
    case UserApprovalStatus.pending:
      return '승인 대기 중인 회원은 작업에 투입할 수 없습니다.';
    case UserApprovalStatus.rejected:
      return '거절된 회원은 작업에 투입할 수 없습니다.';
    case UserApprovalStatus.approved:
      break;
  }

  if (!human.linkedUserIsActive ||
      (blockedMemberUids?.contains(uid) ?? false)) {
    return '활동 정지된 회원은 작업에 투입할 수 없습니다.';
  }

  return '작업에 투입할 수 없는 회원입니다.';
}

/// `GET /users/search` — 투입 불가 회원 uid 집합 (서버가 humans에 상태를 안 줄 때 폴백).
Future<Set<String>> fetchNonAssignableMemberUids(
  SuperAdminRemoteUseCase uc,
) async {
  final blocked = <String>{};

  Future<void> collect({
    String? approvalStatus,
    bool? isActive,
  }) async {
    try {
      final users = await fetchAllListPages<UserRead>(
        (q) => uc.usersSearchPage(
          approvalStatus: approvalStatus,
          isActive: isActive,
          limit: q.limit,
          cursor: q.cursor,
        ),
        const ListQuery(limit: 100),
      );
      for (final u in users) {
        if (u.approvalStatus != UserApprovalStatus.approved || !u.isActive) {
          blocked.add(u.uid);
        }
      }
    } catch (_) {}
  }

  await collect(approvalStatus: 'approved', isActive: false);
  await collect(approvalStatus: 'pending');
  await collect(approvalStatus: 'rejected');

  return blocked;
}

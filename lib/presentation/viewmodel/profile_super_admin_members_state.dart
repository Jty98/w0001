import 'package:flutter/foundation.dart';
import 'package:w0001/access/user_role_access.dart';
import 'package:w0001/data/model/auth_models.dart';
import 'package:w0001/ui/screen/0_auth/super_admin_profile/profile_super_admin_members_limits.dart';

/// 회원 관리에서 정지·권한 변경·삭제 대상에서 제외할 관리자 계정.
bool isProtectedAdminUser(UserRead u) => u.role.isAdmin;

@immutable
class ProfileSuperAdminMembersState {
  const ProfileSuperAdminMembersState({
    this.activeMembers = const [],
    this.pendingMembers = const [],
    this.suspendedMembers = const [],
    this.rejectedMembers = const [],
    this.errorActive,
    this.errorPending,
    this.errorSuspended,
    this.errorRejected,
    this.busyActive = false,
    this.busyQueue = false,
    this.appliedActiveTrim = '',
    this.activeVisibleCount = ProfileSuperAdminMembersLimits.activePageSize,
  });

  final List<UserRead> activeMembers;
  final List<UserRead> pendingMembers;
  final List<UserRead> suspendedMembers;
  final List<UserRead> rejectedMembers;

  final Object? errorActive;
  final Object? errorPending;
  final Object? errorSuspended;
  final Object? errorRejected;

  final bool busyActive;
  final bool busyQueue;

  /// 마지막으로 활동 회원 조회에 성공한 검색어(trim).
  final String appliedActiveTrim;

  /// 화면에 그릴 활동 회원 수 상한 ([loadMoreActiveMembers]로 증가).
  final int activeVisibleCount;

  static const _u = Object();

  ProfileSuperAdminMembersState copyWith({
    List<UserRead>? activeMembers,
    List<UserRead>? pendingMembers,
    List<UserRead>? suspendedMembers,
    List<UserRead>? rejectedMembers,
    Object? errorActive = _u,
    Object? errorPending = _u,
    Object? errorSuspended = _u,
    Object? errorRejected = _u,
    bool? busyActive,
    bool? busyQueue,
    String? appliedActiveTrim,
    int? activeVisibleCount,
  }) {
    return ProfileSuperAdminMembersState(
      activeMembers: activeMembers ?? this.activeMembers,
      pendingMembers: pendingMembers ?? this.pendingMembers,
      suspendedMembers: suspendedMembers ?? this.suspendedMembers,
      rejectedMembers: rejectedMembers ?? this.rejectedMembers,
      errorActive: identical(errorActive, _u) ? this.errorActive : errorActive,
      errorPending:
          identical(errorPending, _u) ? this.errorPending : errorPending,
      errorSuspended:
          identical(errorSuspended, _u) ? this.errorSuspended : errorSuspended,
      errorRejected:
          identical(errorRejected, _u) ? this.errorRejected : errorRejected,
      busyActive: busyActive ?? this.busyActive,
      busyQueue: busyQueue ?? this.busyQueue,
      appliedActiveTrim: appliedActiveTrim ?? this.appliedActiveTrim,
      activeVisibleCount: activeVisibleCount ?? this.activeVisibleCount,
    );
  }
}

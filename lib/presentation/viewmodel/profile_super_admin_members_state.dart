import 'package:flutter/foundation.dart';
import 'package:w0001/access/user_role_access.dart';
import 'package:w0001/data/model/auth_models.dart';

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
    this.activeHasMore = false,
    this.activeLoadingMore = false,
    this.activeNextCursor,
    this.activeTotalCount,
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

  final bool activeHasMore;
  final bool activeLoadingMore;
  final String? activeNextCursor;
  final int? activeTotalCount;

  int get activeDisplayCount => activeTotalCount ?? activeMembers.length;

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
    bool? activeHasMore,
    bool? activeLoadingMore,
    String? activeNextCursor,
    bool clearActiveNextCursor = false,
    int? activeTotalCount,
    bool clearActiveTotalCount = false,
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
      activeHasMore: activeHasMore ?? this.activeHasMore,
      activeLoadingMore: activeLoadingMore ?? this.activeLoadingMore,
      activeNextCursor: clearActiveNextCursor
          ? null
          : (activeNextCursor ?? this.activeNextCursor),
      activeTotalCount: clearActiveTotalCount
          ? null
          : (activeTotalCount ?? this.activeTotalCount),
    );
  }
}

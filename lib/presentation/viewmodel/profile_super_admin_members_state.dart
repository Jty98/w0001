import 'package:flutter/foundation.dart';
import 'package:w0001/data/model/auth_models.dart';

bool isSuperAdminUser(UserRead u) => u.role == UserRole.superAdmin;

@immutable
class ProfileSuperAdminMembersState {
  const ProfileSuperAdminMembersState({
    this.bootstrapDone = false,
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
  });

  final bool bootstrapDone;

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

  static const _u = Object();

  ProfileSuperAdminMembersState copyWith({
    bool? bootstrapDone,
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
  }) {
    return ProfileSuperAdminMembersState(
      bootstrapDone: bootstrapDone ?? this.bootstrapDone,
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
    );
  }
}

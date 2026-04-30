import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/data/model/auth_models.dart';
import 'package:w0001/domain/use_case/super_admin_remote_use_case.dart';
import 'package:w0001/presentation/viewmodel/profile_super_admin_members_state.dart';
import 'package:w0001/presentation/viewmodel/super_admin_remote_providers.dart';

/// 슈퍼관리자 프로필의 회원 목록·검색어 반영 상태. UI는 검색만 컨트롤러로 두고 나머지는 여기서 갱신.
final profileSuperAdminMembersProvider = NotifierProvider.autoDispose<
    ProfileSuperAdminMembersNotifier, ProfileSuperAdminMembersState>(
  ProfileSuperAdminMembersNotifier.new,
);

class ProfileSuperAdminMembersNotifier
    extends Notifier<ProfileSuperAdminMembersState> {
  int _activeFetchGen = 0;
  var _scheduledBootstrap = false;

  SuperAdminRemoteUseCase get _uc =>
      ref.read(superAdminRemoteUseCaseProvider);

  List<UserRead> _noSuper(List<UserRead> xs) =>
      xs.where((u) => !isSuperAdminUser(u)).toList();

  @override
  ProfileSuperAdminMembersState build() {
    if (!_scheduledBootstrap) {
      _scheduledBootstrap = true;
      Future.microtask(_initialLoad);
    }
    return const ProfileSuperAdminMembersState();
  }

  Future<void> _initialLoad() async {
    await Future.wait([
      fetchActiveMembers(''),
      _fetchQueueBundle(),
    ]);
    if (ref.mounted) {
      state = state.copyWith(bootstrapDone: true);
    }
  }

  /// 당김 새로고침 등.
  Future<void> reload() async {
    await Future.wait([
      fetchActiveMembers(state.appliedActiveTrim),
      _fetchQueueBundle(),
    ]);
  }

  Future<void> fetchActiveMembers(String trimForQuery) async {
    final gen = ++_activeFetchGen;
    final qTrim = trimForQuery.trim();
    final q = qTrim.isEmpty ? null : qTrim;

    state = state.copyWith(
      busyActive: true,
      errorActive: null,
    );

    try {
      final raw = await _uc.usersSearch(
        approvalStatus: 'approved',
        isActive: true,
        q: q,
      );
      if (!ref.mounted || gen != _activeFetchGen) return;
      state = state.copyWith(
        activeMembers: _noSuper(raw),
        appliedActiveTrim: qTrim,
        busyActive: false,
      );
    } catch (e, st) {
      if (!ref.mounted || gen != _activeFetchGen) return;
      debugPrint('_fetchActiveMembers: $e\n$st');
      state = state.copyWith(
        errorActive: e,
        busyActive: false,
      );
    }
  }

  Future<void> _fetchQueueBundle() async {
    state = state.copyWith(
      busyQueue: true,
      errorPending: null,
      errorSuspended: null,
      errorRejected: null,
    );
    try {
      await Future.wait([
        _loadPending(),
        _loadSuspended(),
        _loadRejected(),
      ]);
    } finally {
      if (ref.mounted) {
        state = state.copyWith(busyQueue: false);
      }
    }
  }

  Future<void> _loadPending() async {
    try {
      final raw = await _uc.usersPendingList();
      if (!ref.mounted) return;
      state = state.copyWith(pendingMembers: _noSuper(raw));
    } catch (e, st) {
      debugPrint('_loadPending: $e\n$st');
      if (!ref.mounted) return;
      state = state.copyWith(errorPending: e);
    }
  }

  Future<void> _loadSuspended() async {
    try {
      final raw = await _uc.usersSearch(
        approvalStatus: 'approved',
        isActive: false,
      );
      if (!ref.mounted) return;
      state = state.copyWith(suspendedMembers: _noSuper(raw));
    } catch (e, st) {
      debugPrint('_loadSuspended: $e\n$st');
      if (!ref.mounted) return;
      state = state.copyWith(errorSuspended: e);
    }
  }

  Future<void> _loadRejected() async {
    try {
      final raw = await _uc.usersSearch(approvalStatus: 'rejected');
      if (!ref.mounted) return;
      state = state.copyWith(rejectedMembers: _noSuper(raw));
    } catch (e, st) {
      debugPrint('_loadRejected: $e\n$st');
      if (!ref.mounted) return;
      state = state.copyWith(errorRejected: e);
    }
  }

  Future<void> userApprove(String uid, {String? note}) async {
    await _uc.userApprove(uid, note: note);
    await reload();
  }

  Future<void> userReject(String uid, {String? note}) async {
    await _uc.userReject(uid, note: note);
    await reload();
  }

  Future<void> userSuspend(
    String uid, {
    String? reason,
    required String adminActionToken,
  }) async {
    await _uc.userSuspend(
      uid,
      reason: reason,
      adminActionToken: adminActionToken,
    );
    await reload();
  }

  Future<void> userActivate(String uid) async {
    await _uc.userActivate(uid);
    await reload();
  }

  Future<void> userChangeRole(
    String uid,
    UserRole role, {
    required String adminActionToken,
  }) async {
    await _uc.userChangeRole(uid, role, adminActionToken: adminActionToken);
    await reload();
  }

  Future<void> userDelete(String uid) async {
    await _uc.userDelete(uid);
    await reload();
  }
}

Future<void> reloadProfileSuperAdminMembers(WidgetRef ref) =>
    ref.read(profileSuperAdminMembersProvider.notifier).reload();

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/data/model/auth_models.dart';
import 'package:w0001/domain/use_case/super_admin_remote_use_case.dart';
import 'package:w0001/presentation/viewmodel/profile_super_admin_members_state.dart';
import 'package:w0001/presentation/viewmodel/super_admin_remote_providers.dart';
import 'package:w0001/presentation/viewmodel/worker_mgmt_view_model.dart';
import 'package:w0001/presentation/viewmodel/worker_rank_wage_settings_providers.dart';

/// 슈퍼관리자 프로필의 회원 목록·검색어 반영 상태. UI는 검색만 컨트롤러로 두고 나머지는 여기서 갱신.
final profileSuperAdminMembersProvider = NotifierProvider.autoDispose<
    ProfileSuperAdminMembersNotifier, ProfileSuperAdminMembersState>(
  ProfileSuperAdminMembersNotifier.new,
);

class ProfileSuperAdminMembersNotifier
    extends Notifier<ProfileSuperAdminMembersState> {
  int _activeFetchGen = 0;
  var _scheduledBootstrap = false;
  Future<void>? _activeLoadMoreInFlight;

  SuperAdminRemoteUseCase get _uc => ref.read(superAdminRemoteUseCaseProvider);

  List<UserRead> _noProtectedAdmins(List<UserRead> xs) =>
      xs.where((u) => !isProtectedAdminUser(u)).toList();

  List<UserRead> _mergeUsersByUid(
      List<UserRead> existing, List<UserRead> incoming) {
    final seen = <String>{};
    final out = <UserRead>[];
    for (final u in existing) {
      if (seen.add(u.uid)) out.add(u);
    }
    for (final u in incoming) {
      if (seen.add(u.uid)) out.add(u);
    }
    return out;
  }

  @override
  ProfileSuperAdminMembersState build() {
    if (!_scheduledBootstrap) {
      _scheduledBootstrap = true;
      Future.microtask(_initialLoad);
    }
    return const ProfileSuperAdminMembersState();
  }

  Future<void> _initialLoad() async {
    await reload(silent: false);
  }

  /// 당김 새로고침 등. [silent] 이면 헤더 스피너·큐 로딩 플래그를 올리지 않고 목록만 갱신합니다.
  Future<void> reload({bool silent = false}) async {
    await Future.wait([
      fetchActiveMembers(state.appliedActiveTrim, silent: silent),
      _fetchQueueBundle(silent: silent),
    ]);
  }

  Future<void> fetchActiveMembers(String trimForQuery,
      {bool silent = false}) async {
    final gen = ++_activeFetchGen;
    final qTrim = trimForQuery.trim();
    final q = qTrim.isEmpty ? null : qTrim;

    if (!silent) {
      state = state.copyWith(
        busyActive: true,
        errorActive: null,
        activeLoadingMore: false,
        clearActiveNextCursor: true,
        clearActiveTotalCount: true,
      );
    }

    try {
      final page = await _uc.usersSearchPage(
        approvalStatus: 'approved',
        isActive: true,
        q: q,
      );
      if (!ref.mounted || gen != _activeFetchGen) return;
      state = state.copyWith(
        activeMembers: _noProtectedAdmins(page.items),
        appliedActiveTrim: qTrim,
        activeHasMore: page.canLoadMore,
        activeNextCursor: page.nextCursor,
        activeTotalCount: page.totalCount,
        busyActive: silent ? null : false,
        errorActive: null,
      );
    } catch (e, st) {
      if (!ref.mounted || gen != _activeFetchGen) return;
      debugPrint('_fetchActiveMembers: $e\n$st');
      state = state.copyWith(
        errorActive: e,
        busyActive: silent ? null : false,
      );
    }
  }

  Future<void> loadMoreActiveMembers() async {
    if (!state.activeHasMore || state.activeLoadingMore || state.busyActive) {
      return;
    }
    if (_activeLoadMoreInFlight != null) return _activeLoadMoreInFlight;

    final cursor = state.activeNextCursor;
    if (cursor == null || cursor.isEmpty) return;

    _activeLoadMoreInFlight = _loadMoreActiveBody(cursor);
    try {
      await _activeLoadMoreInFlight;
    } finally {
      _activeLoadMoreInFlight = null;
    }
  }

  Future<void> _loadMoreActiveBody(String cursor) async {
    final gen = _activeFetchGen;
    state = state.copyWith(activeLoadingMore: true, errorActive: null);
    try {
      final qTrim = state.appliedActiveTrim.trim();
      final page = await _uc.usersSearchPage(
        approvalStatus: 'approved',
        isActive: true,
        q: qTrim.isEmpty ? null : qTrim,
        cursor: cursor,
      );
      if (!ref.mounted || gen != _activeFetchGen) return;
      final merged = _mergeUsersByUid(
        state.activeMembers,
        _noProtectedAdmins(page.items),
      );
      state = state.copyWith(
        activeMembers: merged,
        activeHasMore: page.canLoadMore,
        activeNextCursor: page.nextCursor,
        activeTotalCount: page.totalCount ?? state.activeTotalCount,
        activeLoadingMore: false,
      );
    } catch (e, st) {
      if (!ref.mounted || gen != _activeFetchGen) return;
      debugPrint('loadMoreActiveMembers: $e\n$st');
      state = state.copyWith(activeLoadingMore: false, errorActive: e);
    }
  }

  Future<void> _fetchQueueBundle({bool silent = false}) async {
    if (silent) {
      state = state.copyWith(
        errorPending: null,
        errorSuspended: null,
        errorRejected: null,
      );
    } else {
      state = state.copyWith(
        busyQueue: true,
        errorPending: null,
        errorSuspended: null,
        errorRejected: null,
      );
    }
    try {
      await Future.wait([
        _loadPending(),
        _loadSuspended(),
        _loadRejected(),
      ]);
    } finally {
      if (ref.mounted && !silent) {
        state = state.copyWith(busyQueue: false);
      }
    }
  }

  Future<void> _loadPending() async {
    try {
      final page = await _uc.usersPendingPage();
      if (!ref.mounted) return;
      state = state.copyWith(pendingMembers: _noProtectedAdmins(page.items));
    } catch (e, st) {
      debugPrint('_loadPending: $e\n$st');
      if (!ref.mounted) return;
      state = state.copyWith(errorPending: e);
    }
  }

  Future<void> _loadSuspended() async {
    try {
      final page = await _uc.usersSearchPage(
        approvalStatus: 'approved',
        isActive: false,
      );
      if (!ref.mounted) return;
      state = state.copyWith(suspendedMembers: _noProtectedAdmins(page.items));
    } catch (e, st) {
      debugPrint('_loadSuspended: $e\n$st');
      if (!ref.mounted) return;
      state = state.copyWith(errorSuspended: e);
    }
  }

  Future<void> _loadRejected() async {
    try {
      final page = await _uc.usersSearchPage(approvalStatus: 'rejected');
      if (!ref.mounted) return;
      state = state.copyWith(rejectedMembers: _noProtectedAdmins(page.items));
    } catch (e, st) {
      debugPrint('_loadRejected: $e\n$st');
      if (!ref.mounted) return;
      state = state.copyWith(errorRejected: e);
    }
  }

  Future<void> userApprove(String uid, {String? note}) async {
    await _uc.userApprove(uid, note: note);
    try {
      final user = await _uc.userGet(uid);
      await ref
          .read(workerRankWageSettingsUseCaseProvider)
          .applyDefaultWageForUser(user);
    } catch (_) {}
    await reload(silent: true);
  }

  Future<void> userReject(String uid, {String? note}) async {
    await _uc.userReject(uid, note: note);
    await reload(silent: true);
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
    await reload(silent: true);
  }

  Future<void> userActivate(String uid) async {
    await _uc.userActivate(uid);
    await reload(silent: true);
  }

  Future<void> userChangeRole(
    String uid,
    UserRole role, {
    required String adminActionToken,
  }) async {
    await _uc.userChangeRole(uid, role, adminActionToken: adminActionToken);
    await reload(silent: true);
  }

  Future<void> userDelete(String uid) async {
    await _uc.userDelete(uid);
    await reload(silent: true);
  }
}

Future<void> reloadProfileSuperAdminMembers(WidgetRef ref) async {
  await Future.wait<void>([
    ref.read(profileSuperAdminMembersProvider.notifier).reload(),
    ref
        .read(workerMgmtHumanDirectoryProvider.notifier)
        .loadAllHumans(blocking: false),
  ]);
}

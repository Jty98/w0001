import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/data/model/remote/super_admin_dtos.dart';
import 'package:w0001/domain/use_case/super_admin_remote_use_case.dart';
import 'package:w0001/presentation/viewmodel/super_admin_remote_providers.dart';

typedef WorkerMgmtTroublePairVm = ({int partnerHid, int? pairId});

// ─── 인력 디렉터리 (메모 허브·상세·트러블·회원 시트 공통) ───

class WorkerMgmtHumanDirectoryState {
  const WorkerMgmtHumanDirectoryState({
    required this.humans,
    required this.initialLoading,
    required this.refreshing,
    this.error,
  });

  final List<HumanRead> humans;
  final bool initialLoading;
  final bool refreshing;
  final Object? error;

  WorkerMgmtHumanDirectoryState copyWith({
    List<HumanRead>? humans,
    bool? initialLoading,
    bool? refreshing,
    Object? error,
    bool clearError = false,
  }) {
    return WorkerMgmtHumanDirectoryState(
      humans: humans ?? this.humans,
      initialLoading: initialLoading ?? this.initialLoading,
      refreshing: refreshing ?? this.refreshing,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

final workerMgmtHumanDirectoryProvider = NotifierProvider<
    WorkerMgmtHumanDirectoryNotifier,
    WorkerMgmtHumanDirectoryState>(WorkerMgmtHumanDirectoryNotifier.new);

class WorkerMgmtHumanDirectoryNotifier
    extends Notifier<WorkerMgmtHumanDirectoryState> {
  SuperAdminRemoteUseCase get _uc => ref.read(superAdminRemoteUseCaseProvider);

  @override
  WorkerMgmtHumanDirectoryState build() {
    Future.microtask(() => reload(blocking: true));
    return const WorkerMgmtHumanDirectoryState(
      humans: [],
      initialLoading: true,
      refreshing: false,
      error: null,
    );
  }

  /// 최초 빌드 외에 명시적으로 불러올 때(시트 진입 등).
  Future<void> ensureLoaded() async {
    if (state.humans.isNotEmpty || state.initialLoading || state.refreshing) {
      return;
    }
    await reload(blocking: false);
  }

  /// [blocking]: 목록이 비었을 때 전체 로딩 플래그.
  /// 그 외에는 [refreshing]만 올려 깜빡임을 줄인다.
  Future<void> reload({required bool blocking}) async {
    final hasData = state.humans.isNotEmpty;
    if (blocking && !hasData) {
      state = state.copyWith(
        initialLoading: true,
        refreshing: false,
        clearError: true,
      );
    } else {
      state = state.copyWith(
        refreshing: true,
        initialLoading: false,
        clearError: true,
      );
    }

    try {
      final list = await _uc.humansList();
      state = state.copyWith(
        humans: list,
        initialLoading: false,
        refreshing: false,
        clearError: true,
      );
    } catch (e, st) {
      debugPrint('workerMgmtHumanDirectory $e $st');
      state = state.copyWith(
        initialLoading: false,
        refreshing: false,
        error: e,
      );
    }
  }
}

// ─── 작업자별 메모·트러블 페어 요약 ───

class WorkerMgmtHidVmState {
  const WorkerMgmtHidVmState({
    required this.notes,
    required this.troublePairs,
    required this.initialLoading,
    required this.refreshing,
    this.loadError,
  });

  final List<WorkerMgmtNoteRead> notes;
  final List<WorkerMgmtTroublePairVm> troublePairs;
  final bool initialLoading;
  final bool refreshing;
  final Object? loadError;

  WorkerMgmtHidVmState copyWith({
    List<WorkerMgmtNoteRead>? notes,
    List<WorkerMgmtTroublePairVm>? troublePairs,
    bool? initialLoading,
    bool? refreshing,
    Object? loadError,
    bool clearLoadError = false,
  }) {
    return WorkerMgmtHidVmState(
      notes: notes ?? this.notes,
      troublePairs: troublePairs ?? this.troublePairs,
      initialLoading: initialLoading ?? this.initialLoading,
      refreshing: refreshing ?? this.refreshing,
      loadError: clearLoadError ? null : (loadError ?? this.loadError),
    );
  }
}

final workerMgmtHidVmProvider =
    NotifierProvider.family<WorkerMgmtHidVmNotifier, WorkerMgmtHidVmState, int>(
        WorkerMgmtHidVmNotifier.new);

class WorkerMgmtHidVmNotifier extends Notifier<WorkerMgmtHidVmState> {
  WorkerMgmtHidVmNotifier(this.workerHid);

  final int workerHid;

  SuperAdminRemoteUseCase get _uc => ref.read(superAdminRemoteUseCaseProvider);

  @override
  WorkerMgmtHidVmState build() {
    Future.microtask(() => reload(silent: false));
    return const WorkerMgmtHidVmState(
      notes: [],
      troublePairs: [],
      initialLoading: true,
      refreshing: false,
      loadError: null,
    );
  }

  Future<void> reload({required bool silent}) async {
    final everLoaded = state.notes.isNotEmpty || state.troublePairs.isNotEmpty;

    if (silent) {
      state = state.copyWith(refreshing: true, clearLoadError: true);
    } else if (!everLoaded) {
      state = state.copyWith(
        initialLoading: true,
        refreshing: false,
        clearLoadError: true,
      );
    } else {
      state = state.copyWith(
        refreshing: true,
        initialLoading: false,
        clearLoadError: true,
      );
    }

    try {
      final notes = await _uc.workerMgmtNotesList(workerHid);
      final conflicts = await _uc.workerMgmtConflictsList(activeOnly: true);
      final pairs = <WorkerMgmtTroublePairVm>[];
      for (final c in conflicts) {
        if (!c.involves(workerHid)) continue;
        final o = c.partnerHid(workerHid);
        if (o != null) pairs.add((partnerHid: o, pairId: c.pairId));
      }
      pairs.sort((a, b) => a.partnerHid.compareTo(b.partnerHid));
      state = state.copyWith(
        notes: notes,
        troublePairs: pairs,
        initialLoading: false,
        refreshing: false,
        clearLoadError: true,
      );
    } catch (e, st) {
      debugPrint('workerMgmtHidVm $e $st');
      state = state.copyWith(
        initialLoading: false,
        refreshing: false,
        loadError: e,
      );
    }
  }
}

// ─── 트러블 허브 ───

class WorkerMgmtConflictsHubState {
  const WorkerMgmtConflictsHubState({
    required this.conflicts,
    required this.activeOnly,
    required this.initialLoading,
    required this.refreshing,
    this.error,
  });

  final List<WorkerMgmtConflictRead> conflicts;
  final bool activeOnly;
  final bool initialLoading;
  final bool refreshing;
  final Object? error;

  WorkerMgmtConflictsHubState copyWith({
    List<WorkerMgmtConflictRead>? conflicts,
    bool? activeOnly,
    bool? initialLoading,
    bool? refreshing,
    Object? error,
    bool clearError = false,
  }) {
    return WorkerMgmtConflictsHubState(
      conflicts: conflicts ?? this.conflicts,
      activeOnly: activeOnly ?? this.activeOnly,
      initialLoading: initialLoading ?? this.initialLoading,
      refreshing: refreshing ?? this.refreshing,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

final workerMgmtConflictsHubProvider = NotifierProvider<
    WorkerMgmtConflictsHubNotifier,
    WorkerMgmtConflictsHubState>(WorkerMgmtConflictsHubNotifier.new);

class WorkerMgmtConflictsHubNotifier
    extends Notifier<WorkerMgmtConflictsHubState> {
  SuperAdminRemoteUseCase get _uc => ref.read(superAdminRemoteUseCaseProvider);

  @override
  WorkerMgmtConflictsHubState build() {
    Future.microtask(() => reload(silent: false));
    return const WorkerMgmtConflictsHubState(
      conflicts: [],
      activeOnly: true,
      initialLoading: true,
      refreshing: false,
      error: null,
    );
  }

  Future<void> setActiveOnly(bool activeOnly) async {
    state = state.copyWith(activeOnly: activeOnly);
    await reload(silent: false);
  }

  Future<void> reload({required bool silent}) async {
    final hasData = state.conflicts.isNotEmpty;
    if (silent) {
      state = state.copyWith(refreshing: true, clearError: true);
    } else if (!hasData && state.initialLoading) {
      state = state.copyWith(
        initialLoading: true,
        refreshing: false,
        clearError: true,
      );
    } else {
      state = state.copyWith(
        refreshing: true,
        initialLoading: false,
        clearError: true,
      );
    }

    try {
      final list =
          await _uc.workerMgmtConflictsList(activeOnly: state.activeOnly);
      state = state.copyWith(
        conflicts: list,
        initialLoading: false,
        refreshing: false,
        clearError: true,
      );
    } catch (e, st) {
      debugPrint('workerMgmtConflictsHub $e $st');
      state = state.copyWith(
        initialLoading: false,
        refreshing: false,
        error: e,
      );
    }
  }
}

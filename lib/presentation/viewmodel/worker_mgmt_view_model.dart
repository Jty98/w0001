import 'dart:async' show Timer, unawaited;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/data/datasources/remote/list_query.dart';
import 'package:w0001/data/datasources/remote/remote_list_pages.dart';
import 'package:w0001/data/model/paged_result.dart' show mergePagedItems;
import 'package:w0001/data/model/remote/super_admin_dtos.dart';
import 'package:w0001/domain/use_case/super_admin_remote_use_case.dart';
import 'package:w0001/presentation/viewmodel/super_admin_remote_providers.dart';

typedef WorkerMgmtTroublePairVm = ({int partnerHid, int? pairId});

/// 작업자 관리 인력 디렉터리 API 페이지 크기 — [kListPageSize]와 동일.
const int kWorkerMgmtHumanPageSize = kListPageSize;

// ─── 인력 디렉터리 (메모 허브·상세·트러블·회원 시트 공통) ───

class WorkerMgmtHumanDirectoryState {
  const WorkerMgmtHumanDirectoryState({
    required this.humans,
    required this.initialLoading,
    required this.refreshing,
    required this.searchQuery,
    required this.hasMore,
    required this.isLoadingMore,
    required this.fullyLoaded,
    this.nextCursor,
    this.totalCount,
    this.error,
  });

  final List<HumanRead> humans;
  final bool initialLoading;
  final bool refreshing;
  final String searchQuery;
  final bool hasMore;
  final bool isLoadingMore;
  final bool fullyLoaded;
  final String? nextCursor;
  final int? totalCount;
  final Object? error;

  WorkerMgmtHumanDirectoryState copyWith({
    List<HumanRead>? humans,
    bool? initialLoading,
    bool? refreshing,
    String? searchQuery,
    bool? hasMore,
    bool? isLoadingMore,
    bool? fullyLoaded,
    String? nextCursor,
    bool clearNextCursor = false,
    int? totalCount,
    bool clearTotalCount = false,
    Object? error,
    bool clearError = false,
  }) {
    return WorkerMgmtHumanDirectoryState(
      humans: humans ?? this.humans,
      initialLoading: initialLoading ?? this.initialLoading,
      refreshing: refreshing ?? this.refreshing,
      searchQuery: searchQuery ?? this.searchQuery,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      fullyLoaded: fullyLoaded ?? this.fullyLoaded,
      nextCursor: clearNextCursor ? null : (nextCursor ?? this.nextCursor),
      totalCount: clearTotalCount ? null : (totalCount ?? this.totalCount),
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

  Timer? _searchDebounce;
  Future<void>? _loadMoreInFlight;

  ListQuery _buildQuery({String? cursor}) {
    final q = state.searchQuery.trim();
    return ListQuery(
      hdelete: 0,
      q: q.isEmpty ? null : q,
      limit: kWorkerMgmtHumanPageSize,
      cursor: cursor,
    );
  }

  List<HumanRead> _sortActiveHumans(List<HumanRead> list) {
    final active = list.where((h) => h.hdelete == 0).toList()
      ..sort((a, b) => a.hname.compareTo(b.hname));
    return active;
  }

  void _setLoadingFlags({required bool blocking, required bool hasData}) {
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
  }

  @override
  WorkerMgmtHumanDirectoryState build() {
    ref.onDispose(() => _searchDebounce?.cancel());
    Future.microtask(() => reload(blocking: true));
    return const WorkerMgmtHumanDirectoryState(
      humans: [],
      initialLoading: true,
      refreshing: false,
      searchQuery: '',
      hasMore: false,
      isLoadingMore: false,
      fullyLoaded: false,
      nextCursor: null,
      totalCount: null,
      error: null,
    );
  }

  HumanRead? humanByHid(int hid) {
    for (final h in state.humans) {
      if (h.hid == hid) return h;
    }
    return null;
  }

  /// 트러블 페어 등 — 캐시된 인력 이름 (없으면 생략).
  Map<int, String> namesByHids(Iterable<int> hids) {
    final out = <int, String>{};
    for (final hid in hids) {
      final h = humanByHid(hid);
      if (h != null && h.hname.trim().isNotEmpty) {
        out[hid] = h.hname.trim();
      }
    }
    return out;
  }

  /// 최초 빌드 외에 명시적으로 불러올 때(시트 진입 등). 회원–인력 매칭용 전체 로드.
  Future<void> ensureLoaded() async {
    if (state.fullyLoaded && state.humans.isNotEmpty) return;
    if (state.initialLoading || state.refreshing) return;
    await loadAllHumans(blocking: false);
  }

  void setSearchQuery(String query) {
    if (query == state.searchQuery) return;
    state = state.copyWith(searchQuery: query, fullyLoaded: false);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!ref.mounted) return;
      unawaited(reload(blocking: false));
    });
  }

  /// 첫 페이지부터 다시 조회 (검색·pull-to-refresh).
  Future<void> reload({required bool blocking}) async {
    final hasData = state.humans.isNotEmpty;
    _setLoadingFlags(blocking: blocking, hasData: hasData);
    state = state.copyWith(
      isLoadingMore: false,
      clearNextCursor: true,
      clearTotalCount: true,
      fullyLoaded: false,
    );

    try {
      final page = await _uc.humansQueryPage(_buildQuery());
      state = state.copyWith(
        humans: _sortActiveHumans(page.items),
        hasMore: page.hasMore,
        nextCursor: page.nextCursor,
        totalCount: page.totalCount,
        fullyLoaded: !page.hasMore,
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

  /// 스크롤 하단 — 다음 cursor 페이지.
  Future<void> loadMore() async {
    if (state.fullyLoaded || !state.hasMore || state.isLoadingMore) return;
    if (state.initialLoading || state.refreshing) return;
    if (_loadMoreInFlight != null) return _loadMoreInFlight;

    final cursor = state.nextCursor;
    if (cursor == null || cursor.isEmpty) return;

    _loadMoreInFlight = _loadMoreBody();
    try {
      await _loadMoreInFlight;
    } finally {
      _loadMoreInFlight = null;
    }
  }

  Future<void> _loadMoreBody() async {
    state = state.copyWith(isLoadingMore: true, clearError: true);
    try {
      final page = await _uc.humansQueryPage(
        _buildQuery(cursor: state.nextCursor),
      );
      final merged = mergePagedItems(
        state.humans,
        page.items,
        (h) => h.hid,
      );
      state = state.copyWith(
        humans: _sortActiveHumans(merged),
        hasMore: page.hasMore,
        nextCursor: page.nextCursor,
        totalCount: page.totalCount ?? state.totalCount,
        fullyLoaded: !page.hasMore,
      );
    } catch (e, st) {
      debugPrint('workerMgmtHumanDirectory loadMore $e $st');
    } finally {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  /// 트러블 페어·회원 매칭 등 전체 인력이 필요할 때 cursor로 모두 수집.
  Future<void> loadAllHumans({required bool blocking}) async {
    final hasData = state.humans.isNotEmpty;
    _setLoadingFlags(blocking: blocking, hasData: hasData);
    state = state.copyWith(
      isLoadingMore: false,
      clearNextCursor: true,
      clearTotalCount: true,
    );

    try {
      final list = await fetchAllListPages(
        _uc.humansQueryPage,
        _buildQuery(),
      );
      state = state.copyWith(
        humans: _sortActiveHumans(list),
        hasMore: false,
        fullyLoaded: true,
        totalCount: list.length,
        initialLoading: false,
        refreshing: false,
        clearError: true,
      );
    } catch (e, st) {
      debugPrint('workerMgmtHumanDirectory loadAll $e $st');
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
    required this.partnerNameByHid,
    required this.initialLoading,
    required this.refreshing,
    required this.troublePairsLoading,
    required this.notesHasMore,
    required this.notesLoadingMore,
    this.notesNextCursor,
    this.loadError,
  });

  final List<WorkerMgmtNoteRead> notes;
  final List<WorkerMgmtTroublePairVm> troublePairs;
  final Map<int, String> partnerNameByHid;
  final bool initialLoading;
  final bool refreshing;
  final bool troublePairsLoading;
  final bool notesHasMore;
  final bool notesLoadingMore;
  final String? notesNextCursor;
  final Object? loadError;

  WorkerMgmtHidVmState copyWith({
    List<WorkerMgmtNoteRead>? notes,
    List<WorkerMgmtTroublePairVm>? troublePairs,
    Map<int, String>? partnerNameByHid,
    bool? initialLoading,
    bool? refreshing,
    bool? troublePairsLoading,
    bool? notesHasMore,
    bool? notesLoadingMore,
    String? notesNextCursor,
    bool clearNotesNextCursor = false,
    Object? loadError,
    bool clearLoadError = false,
  }) {
    return WorkerMgmtHidVmState(
      notes: notes ?? this.notes,
      troublePairs: troublePairs ?? this.troublePairs,
      partnerNameByHid: partnerNameByHid ?? this.partnerNameByHid,
      initialLoading: initialLoading ?? this.initialLoading,
      refreshing: refreshing ?? this.refreshing,
      troublePairsLoading: troublePairsLoading ?? this.troublePairsLoading,
      notesHasMore: notesHasMore ?? this.notesHasMore,
      notesLoadingMore: notesLoadingMore ?? this.notesLoadingMore,
      notesNextCursor: clearNotesNextCursor
          ? null
          : (notesNextCursor ?? this.notesNextCursor),
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

  Future<void>? _notesLoadMoreInFlight;

  @override
  WorkerMgmtHidVmState build() {
    Future.microtask(() => reload(silent: false));
    return const WorkerMgmtHidVmState(
      notes: [],
      troublePairs: [],
      partnerNameByHid: {},
      initialLoading: true,
      refreshing: false,
      troublePairsLoading: false,
      notesHasMore: false,
      notesLoadingMore: false,
      notesNextCursor: null,
      loadError: null,
    );
  }

  Future<List<WorkerMgmtConflictRead>> _conflictsForWorker() async {
    final hub = ref.read(workerMgmtConflictsHubProvider);
    if (hub.conflicts.isNotEmpty) {
      return hub.conflicts
          .where((c) => c.active && c.involves(workerHid))
          .toList();
    }

    final out = <WorkerMgmtConflictRead>[];
    String? cursor;
    var guard = 0;
    while (guard++ < 100) {
      final page = await _uc.workerMgmtConflictsPage(
        activeOnly: true,
        cursor: cursor,
      );
      for (final c in page.items) {
        if (c.involves(workerHid)) out.add(c);
      }
      if (!page.canLoadMore) break;
      final next = page.nextCursor?.trim();
      if (next == null || next.isEmpty) break;
      cursor = next;
    }
    return out;
  }

  Future<Map<int, String>> _resolvePartnerNames(Set<int> partnerIds) async {
    if (partnerIds.isEmpty) return {};

    final dir = ref.read(workerMgmtHumanDirectoryProvider.notifier);
    final names = dir.namesByHids(partnerIds);
    final missing = partnerIds
        .where((hid) => !names.containsKey(hid))
        .toList(growable: false);
    if (missing.isEmpty) return names;

    final fetched = await Future.wait(
      missing.map((hid) async {
        try {
          final h = await _uc.humanGet(hid);
          return MapEntry(hid, h.hname.trim());
        } catch (_) {
          return MapEntry<int, String>(hid, '');
        }
      }),
    );
    return {
      ...names,
      for (final e in fetched)
        if (e.value.isNotEmpty) e.key: e.value,
    };
  }

  Future<void> reload({required bool silent}) async {
    final everLoaded = state.notes.isNotEmpty || state.troublePairs.isNotEmpty;

    if (silent) {
      state = state.copyWith(
        refreshing: true,
        troublePairsLoading: true,
        clearLoadError: true,
      );
    } else if (!everLoaded) {
      state = state.copyWith(
        initialLoading: true,
        refreshing: false,
        troublePairsLoading: true,
        clearLoadError: true,
      );
    } else {
      state = state.copyWith(
        refreshing: true,
        initialLoading: false,
        troublePairsLoading: true,
        clearLoadError: true,
      );
    }

    try {
      final notesPage = await _uc.workerMgmtNotesPage(workerHid);
      state = state.copyWith(
        notes: notesPage.items,
        notesHasMore: notesPage.canLoadMore,
        notesNextCursor: notesPage.nextCursor,
        initialLoading: false,
        notesLoadingMore: false,
        clearLoadError: true,
      );

      final conflicts = await _conflictsForWorker();
      final pairs = <WorkerMgmtTroublePairVm>[];
      for (final c in conflicts) {
        final o = c.partnerHid(workerHid);
        if (o != null) pairs.add((partnerHid: o, pairId: c.pairId));
      }
      pairs.sort((a, b) => a.partnerHid.compareTo(b.partnerHid));
      final partnerNames =
          await _resolvePartnerNames(pairs.map((e) => e.partnerHid).toSet());

      state = state.copyWith(
        troublePairs: pairs,
        partnerNameByHid: partnerNames,
        refreshing: false,
        troublePairsLoading: false,
      );
    } catch (e, st) {
      debugPrint('workerMgmtHidVm $e $st');
      state = state.copyWith(
        initialLoading: false,
        refreshing: false,
        troublePairsLoading: false,
        notesLoadingMore: false,
        loadError: e,
      );
    }
  }

  Future<void> loadMoreNotes() async {
    if (!state.notesHasMore || state.notesLoadingMore) return;
    if (_notesLoadMoreInFlight != null) return _notesLoadMoreInFlight;

    final cursor = state.notesNextCursor;
    if (cursor == null || cursor.isEmpty) return;

    _notesLoadMoreInFlight = _loadMoreNotesBody(cursor);
    try {
      await _notesLoadMoreInFlight;
    } finally {
      _notesLoadMoreInFlight = null;
    }
  }

  Future<void> _loadMoreNotesBody(String cursor) async {
    state = state.copyWith(notesLoadingMore: true, clearLoadError: true);
    try {
      final page = await _uc.workerMgmtNotesPage(
        workerHid,
        cursor: cursor,
      );
      final merged = mergePagedItems(
        state.notes,
        page.items,
        (n) => n.noteId,
      );
      state = state.copyWith(
        notes: merged,
        notesHasMore: page.canLoadMore,
        notesNextCursor: page.nextCursor,
        notesLoadingMore: false,
      );
    } catch (e, st) {
      debugPrint('workerMgmtHidVm loadMoreNotes $e $st');
      state = state.copyWith(notesLoadingMore: false, loadError: e);
    }
  }
}

// ─── 트러블 허브 ───

class WorkerMgmtConflictsHubState {
  const WorkerMgmtConflictsHubState({
    required this.conflicts,
    required this.nameByHid,
    required this.initialLoading,
    required this.refreshing,
    required this.hasMore,
    required this.isLoadingMore,
    this.nextCursor,
    this.totalCount,
    this.error,
  });

  final List<WorkerMgmtConflictRead> conflicts;
  final Map<int, String> nameByHid;
  final bool initialLoading;
  final bool refreshing;
  final bool hasMore;
  final bool isLoadingMore;
  final String? nextCursor;
  final int? totalCount;
  final Object? error;

  WorkerMgmtConflictsHubState copyWith({
    List<WorkerMgmtConflictRead>? conflicts,
    Map<int, String>? nameByHid,
    bool? initialLoading,
    bool? refreshing,
    bool? hasMore,
    bool? isLoadingMore,
    String? nextCursor,
    bool clearNextCursor = false,
    int? totalCount,
    Object? error,
    bool clearError = false,
  }) {
    return WorkerMgmtConflictsHubState(
      conflicts: conflicts ?? this.conflicts,
      nameByHid: nameByHid ?? this.nameByHid,
      initialLoading: initialLoading ?? this.initialLoading,
      refreshing: refreshing ?? this.refreshing,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      nextCursor: clearNextCursor ? null : (nextCursor ?? this.nextCursor),
      totalCount: totalCount ?? this.totalCount,
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
  Future<void>? _loadMoreInFlight;

  @override
  WorkerMgmtConflictsHubState build() {
    Future.microtask(() => reload(silent: false));
    return const WorkerMgmtConflictsHubState(
      conflicts: [],
      nameByHid: {},
      initialLoading: true,
      refreshing: false,
      hasMore: false,
      isLoadingMore: false,
      nextCursor: null,
      totalCount: null,
      error: null,
    );
  }

  Future<Map<int, String>> _resolveHumanNames(
    Iterable<WorkerMgmtConflictRead> conflicts,
  ) async {
    final hids = <int>{};
    for (final c in conflicts) {
      if (c.workerAHid > 0) hids.add(c.workerAHid);
      if (c.workerBHid > 0) hids.add(c.workerBHid);
    }
    if (hids.isEmpty) return {};

    final dir = ref.read(workerMgmtHumanDirectoryProvider.notifier);
    final names = dir.namesByHids(hids);
    final missing =
        hids.where((hid) => !names.containsKey(hid)).toList(growable: false);
    if (missing.isEmpty) return names;

    final entries = await Future.wait(
      missing.map((hid) async {
        try {
          final h = await _uc.humanGet(hid);
          return MapEntry(hid, h.hname);
        } catch (_) {
          return MapEntry<int, String>(hid, '');
        }
      }),
    );
    return {
      ...names,
      for (final e in entries)
        if (e.value.trim().isNotEmpty) e.key: e.value.trim(),
    };
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
        isLoadingMore: false,
        clearNextCursor: true,
      );
    }

    try {
      final page = await _uc.workerMgmtConflictsPage(activeOnly: false);
      final names = await _resolveHumanNames(page.items);
      state = state.copyWith(
        conflicts: page.items,
        nameByHid: names,
        hasMore: page.canLoadMore,
        nextCursor: page.nextCursor,
        totalCount: page.totalCount,
        initialLoading: false,
        refreshing: false,
        clearError: true,
      );
    } catch (e, st) {
      debugPrint('workerMgmtConflictsHub $e $st');
      state = state.copyWith(
        initialLoading: false,
        refreshing: false,
        isLoadingMore: false,
        error: e,
      );
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore || state.initialLoading) return;
    if (_loadMoreInFlight != null) return _loadMoreInFlight;

    final cursor = state.nextCursor;
    if (cursor == null || cursor.isEmpty) return;

    _loadMoreInFlight = _loadMoreBody(cursor);
    try {
      await _loadMoreInFlight;
    } finally {
      _loadMoreInFlight = null;
    }
  }

  Future<void> _loadMoreBody(String cursor) async {
    state = state.copyWith(isLoadingMore: true, clearError: true);
    try {
      final page = await _uc.workerMgmtConflictsPage(
        activeOnly: false,
        cursor: cursor,
      );
      final merged = mergePagedItems(
        state.conflicts,
        page.items,
        (c) => c.pairId,
      );
      final names = await _resolveHumanNames(page.items);
      state = state.copyWith(
        conflicts: merged,
        nameByHid: {...state.nameByHid, ...names},
        hasMore: page.canLoadMore,
        nextCursor: page.nextCursor,
        totalCount: page.totalCount ?? state.totalCount,
        isLoadingMore: false,
      );
    } catch (e, st) {
      debugPrint('workerMgmtConflictsHub loadMore $e $st');
      state = state.copyWith(isLoadingMore: false, error: e);
    }
  }
}

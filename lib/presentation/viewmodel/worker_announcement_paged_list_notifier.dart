import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/data/model/paged_result.dart';
import 'package:w0001/data/model/worker_announcement_models.dart';
import 'package:w0001/presentation/viewmodel/worker_announcement_providers.dart';

enum WorkerAnnouncementPagedSource { manage, inbox }

enum WorkerAnnouncementPagedScopeFilter {
  all,
  globalOnly,
  placeOnly,
}

@immutable
class WorkerAnnouncementPagedQuery {
  const WorkerAnnouncementPagedQuery({
    required this.source,
    this.placeId,
    this.scopeFilter = WorkerAnnouncementPagedScopeFilter.all,
    this.placeComplete,
  });

  final WorkerAnnouncementPagedSource source;

  /// inbox/manage: 특정 현장 공지만.
  final int? placeId;

  /// `scope=global|place`. inbox·manage 공통.
  final WorkerAnnouncementPagedScopeFilter scopeFilter;

  /// 현장 공지 조회 시 `pcomplete` (0=진행, 1=완료). 전체 공지 탭에서는 무시.
  final int? placeComplete;

  @override
  bool operator ==(Object other) =>
      other is WorkerAnnouncementPagedQuery &&
      other.source == source &&
      other.placeId == placeId &&
      other.scopeFilter == scopeFilter &&
      other.placeComplete == placeComplete;

  @override
  int get hashCode => Object.hash(source, placeId, scopeFilter, placeComplete);
}

class WorkerAnnouncementPagedListState {
  const WorkerAnnouncementPagedListState({
    this.items = const [],
    this.initialLoading = false,
    this.refreshing = false,
    this.isLoadingMore = false,
    this.hasMore = false,
    this.nextCursor,
    this.totalCount,
    this.error,
  });

  final List<WorkerAnnouncementRead> items;
  final bool initialLoading;
  final bool refreshing;
  final bool isLoadingMore;
  final bool hasMore;
  final String? nextCursor;
  final int? totalCount;
  final Object? error;

  WorkerAnnouncementPagedListState copyWith({
    List<WorkerAnnouncementRead>? items,
    bool? initialLoading,
    bool? refreshing,
    bool? isLoadingMore,
    bool? hasMore,
    String? nextCursor,
    bool clearNextCursor = false,
    int? totalCount,
    bool clearTotalCount = false,
    Object? error,
    bool clearError = false,
  }) {
    return WorkerAnnouncementPagedListState(
      items: items ?? this.items,
      initialLoading: initialLoading ?? this.initialLoading,
      refreshing: refreshing ?? this.refreshing,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      nextCursor: clearNextCursor ? null : (nextCursor ?? this.nextCursor),
      totalCount: clearTotalCount ? null : (totalCount ?? this.totalCount),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

final workerAnnouncementPagedListProvider = NotifierProvider.autoDispose.family<
    WorkerAnnouncementPagedListNotifier,
    WorkerAnnouncementPagedListState,
    WorkerAnnouncementPagedQuery>(WorkerAnnouncementPagedListNotifier.new);

class WorkerAnnouncementPagedListNotifier
    extends Notifier<WorkerAnnouncementPagedListState> {
  WorkerAnnouncementPagedListNotifier(this._query);

  final WorkerAnnouncementPagedQuery _query;
  Future<void>? _loadMoreInFlight;
  var _disposed = false;

  @override
  WorkerAnnouncementPagedListState build() {
    ref.onDispose(() {
      _disposed = true;
    });
    Future.microtask(() async {
      if (!_isAlive) return;
      await reload(silent: false);
    });
    return const WorkerAnnouncementPagedListState(initialLoading: true);
  }

  Future<void> reload({required bool silent}) async {
    if (!_isAlive) return;
    final hasData = state.items.isNotEmpty;
    if (silent) {
      state = state.copyWith(refreshing: true, clearError: true);
    } else if (!hasData) {
      state = state.copyWith(
        initialLoading: true,
        refreshing: false,
        clearError: true,
        isLoadingMore: false,
        clearNextCursor: true,
        clearTotalCount: true,
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
      final page = await _fetchPage(clearCursor: true, hydrate: true);
      if (!_isAlive) return;
      state = state.copyWith(
        items: page.items,
        hasMore: page.canLoadMore,
        nextCursor: page.nextCursor,
        totalCount: page.totalCount,
        initialLoading: false,
        refreshing: false,
        clearError: true,
      );
    } catch (e, st) {
      debugPrint('workerAnnouncementPaged reload $e\n$st');
      if (!_isAlive) return;
      state = state.copyWith(
        initialLoading: false,
        refreshing: false,
        error: e,
      );
    }
  }

  Future<void> loadMore() async {
    if (!_isAlive) return;
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
    if (!_isAlive) return;
    state = state.copyWith(isLoadingMore: true, clearError: true);
    try {
      final page = await _fetchPage(cursor: cursor, hydrate: false);
      if (!_isAlive) return;
      final merged = mergePagedItems(
        state.items,
        page.items,
        (a) => a.id,
      );
      state = state.copyWith(
        items: merged,
        hasMore: page.canLoadMore,
        nextCursor: page.nextCursor,
        totalCount: page.totalCount ?? state.totalCount,
        isLoadingMore: false,
      );
    } catch (e, st) {
      debugPrint('workerAnnouncementPaged loadMore $e\n$st');
      if (!_isAlive) return;
      state = state.copyWith(isLoadingMore: false, error: e);
    }
  }

  Future<PagedResult<WorkerAnnouncementRead>> _fetchPage({
    String? cursor,
    bool clearCursor = false,
    bool hydrate = false,
  }) {
    if (!_isAlive) {
      throw StateError('workerAnnouncementPaged notifier disposed');
    }
    final uc = ref.read(workerAnnouncementUseCaseProvider);
    if (_query.source == WorkerAnnouncementPagedSource.manage) {
      return uc.manageListPage(
        placeId: _query.placeId,
        scopeFilter: _query.scopeFilter,
        placeComplete: _query.placeComplete,
        cursor: clearCursor ? null : cursor,
        hydrateFirstPage: hydrate,
      );
    }
    return uc.inboxPage(
      placeId: _query.placeId,
      scopeFilter: _query.scopeFilter,
      placeComplete: _query.placeComplete,
      cursor: clearCursor ? null : cursor,
      hydrateFirstPage: hydrate,
    );
  }

  bool get _isAlive => !_disposed && ref.mounted;
}

/// 대시보드 전체 공지 미리보기 — 탭 전환 시 캐시 유지(autoDispose 아님).
final workerDashboardGlobalAnnouncementPreviewProvider = NotifierProvider<
    WorkerDashboardGlobalAnnouncementPreviewNotifier,
    WorkerAnnouncementPagedListState>(
  WorkerDashboardGlobalAnnouncementPreviewNotifier.new,
);

class WorkerDashboardGlobalAnnouncementPreviewNotifier
    extends Notifier<WorkerAnnouncementPagedListState> {
  static const _query = WorkerAnnouncementPagedQuery(
    source: WorkerAnnouncementPagedSource.inbox,
    scopeFilter: WorkerAnnouncementPagedScopeFilter.globalOnly,
  );

  var _disposed = false;

  @override
  WorkerAnnouncementPagedListState build() {
    ref.onDispose(() {
      _disposed = true;
    });
    Future.microtask(() async {
      if (!_isAlive) return;
      await reload(silent: false);
    });
    return const WorkerAnnouncementPagedListState(initialLoading: true);
  }

  Future<void> reload({required bool silent}) async {
    if (!_isAlive) return;
    final hasData = state.items.isNotEmpty;
    if (silent) {
      state = state.copyWith(refreshing: true, clearError: true);
    } else if (!hasData) {
      state = state.copyWith(
        initialLoading: true,
        refreshing: false,
        clearError: true,
        isLoadingMore: false,
        clearNextCursor: true,
        clearTotalCount: true,
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
      final uc = ref.read(workerAnnouncementUseCaseProvider);
      final page = await uc.inboxPage(
        scopeFilter: _query.scopeFilter,
        cursor: null,
        hydrateFirstPage: true,
      );
      if (!_isAlive) return;
      state = state.copyWith(
        items: page.items,
        hasMore: page.canLoadMore,
        nextCursor: page.nextCursor,
        totalCount: page.totalCount,
        initialLoading: false,
        refreshing: false,
        clearError: true,
      );
    } catch (e, st) {
      debugPrint('workerDashboardGlobalAnnouncementPreview reload $e\n$st');
      if (!_isAlive) return;
      state = state.copyWith(
        initialLoading: false,
        refreshing: false,
        error: e,
      );
    }
  }

  bool get _isAlive => !_disposed && ref.mounted;
}

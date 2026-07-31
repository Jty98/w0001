import 'package:w0001/data/datasources/remote/list_query.dart';
import 'package:w0001/data/model/paged_result.dart';
import 'package:w0001/data/model/worker_announcement_models.dart';
import 'package:w0001/domain/repository/worker_announcement_repository.dart';
import 'package:w0001/presentation/viewmodel/worker_announcement_paged_list_notifier.dart';
import 'package:w0001/ui/screen/announcements/worker_announcement_quill_codec.dart';

class WorkerAnnouncementUseCase {
  WorkerAnnouncementUseCase(this._repository);

  final WorkerAnnouncementRepository _repository;

  List<WorkerAnnouncementRead>? _manageListCache;
  List<WorkerAnnouncementRead>? _inboxCache;
  final Map<int, WorkerAnnouncementRead> _detailById = {};

  void clearCaches() {
    _manageListCache = null;
    _inboxCache = null;
    _detailById.clear();
  }

  void invalidateManageListCache() {
    _manageListCache = null;
  }

  void putCachedDetail(WorkerAnnouncementRead item) {
    if (item.id <= 0) return;
    _detailById[item.id] = item;
  }

  void removeCachedDetail(int id) {
    _detailById.remove(id);
    if (_manageListCache == null) return;
    _manageListCache =
        _manageListCache!.where((a) => a.id != id).toList(growable: false);
  }

  void upsertManageListItem(WorkerAnnouncementRead item) {
    putCachedDetail(item);
    if (_manageListCache == null) return;
    final idx = _manageListCache!.indexWhere((a) => a.id == item.id);
    if (idx >= 0) {
      final next = List<WorkerAnnouncementRead>.from(_manageListCache!);
      next[idx] = _enrichListItem(item);
      _manageListCache = next;
    } else {
      _manageListCache = [_enrichListItem(item), ..._manageListCache!];
    }
  }

  Future<List<WorkerAnnouncementRead>> inbox({int? placeId}) =>
      _repository.inbox(placeId: placeId);

  Future<PagedResult<WorkerAnnouncementRead>> inboxPage({
    int? placeId,
    WorkerAnnouncementPagedScopeFilter scopeFilter =
        WorkerAnnouncementPagedScopeFilter.all,
    int? placeComplete,
    int limit = kListPageSize,
    String? cursor,
    bool hydrateFirstPage = false,
  }) async {
    final page = await _repository.inboxPage(
      placeId: placeId,
      scopeFilter: scopeFilter,
      placeComplete: placeComplete,
      limit: limit,
      cursor: cursor,
    );
    if (!hydrateFirstPage || cursor != null) return page;
    final items = await _mergeListWithCachedDetails(page.items);
    return page.copyWith(items: items);
  }

  /// 수신함 — 목록 API가 blocks를 비우면 캐시·단건 조회로 본문을 채운다.
  Future<List<WorkerAnnouncementRead>> inboxWithBodies({
    int? placeId,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && placeId == null && _inboxCache != null) {
      return _inboxCache!;
    }
    final list = await inbox(placeId: placeId);
    final hydrated = await _mergeListWithCachedDetails(list);
    if (placeId == null) {
      _inboxCache = hydrated;
    }
    return hydrated;
  }

  Future<List<WorkerAnnouncementRead>> manageList() => _repository.manageList();

  Future<PagedResult<WorkerAnnouncementRead>> manageListPage({
    int? placeId,
    WorkerAnnouncementPagedScopeFilter scopeFilter =
        WorkerAnnouncementPagedScopeFilter.all,
    int? placeComplete,
    int limit = kListPageSize,
    String? cursor,
    bool hydrateFirstPage = false,
  }) async {
    final page = await _repository.manageListPage(
      placeId: placeId,
      scopeFilter: scopeFilter,
      placeComplete: placeComplete,
      limit: limit,
      cursor: cursor,
    );
    if (!hydrateFirstPage || cursor != null) return page;
    final items = await _mergeListWithCachedDetails(page.items);
    return page.copyWith(items: items);
  }

  /// 관리 목록 — 목록 API가 blocks를 비우면 캐시·단건 조회로 보강. [forceRefresh]가 false면 캐시 우선.
  Future<List<WorkerAnnouncementRead>> manageListWithBodies({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _manageListCache != null) {
      return _manageListCache!;
    }
    final list = await manageList();
    final hydrated = await _mergeListWithCachedDetails(list);
    _manageListCache = hydrated;
    return hydrated;
  }

  /// 편집·상세 — 목록/캐시에 본문이 있으면 API 재호출 없음.
  Future<WorkerAnnouncementRead> resolveDetail(
    WorkerAnnouncementRead summary, {
    bool forceRefresh = false,
  }) async {
    if (summary.id <= 0) return summary;
    if (!forceRefresh) {
      if (WorkerAnnouncementQuillCodec.blocksHaveDisplayableBody(
          summary.blocks)) {
        putCachedDetail(summary);
        return summary;
      }
      final cached = _detailById[summary.id];
      if (cached != null &&
          WorkerAnnouncementQuillCodec.blocksHaveDisplayableBody(
              cached.blocks)) {
        return cached;
      }
    }
    final full = await getById(summary.id);
    putCachedDetail(full);
    return full;
  }

  Future<List<WorkerAnnouncementRead>> _mergeListWithCachedDetails(
    List<WorkerAnnouncementRead> list,
  ) async {
    final toFetch = <int>{};
    for (final a in list) {
      if (a.id <= 0) continue;
      if (_enrichedFromCache(a) != null) continue;
      toFetch.add(a.id);
    }

    if (toFetch.isNotEmpty) {
      await Future.wait(
        toFetch.map((id) async {
          if (_detailById.containsKey(id) &&
              WorkerAnnouncementQuillCodec.blocksHaveDisplayableBody(
                _detailById[id]!.blocks,
              )) {
            return;
          }
          try {
            _detailById[id] = await getById(id);
          } catch (_) {}
        }),
      );
    }

    return list.map(_enrichListItem).toList(growable: false);
  }

  WorkerAnnouncementRead? _enrichedFromCache(WorkerAnnouncementRead a) {
    if (WorkerAnnouncementQuillCodec.blocksHaveDisplayableBody(a.blocks)) {
      putCachedDetail(a);
      return a;
    }
    final cached = _detailById[a.id];
    if (cached != null &&
        WorkerAnnouncementQuillCodec.blocksHaveDisplayableBody(cached.blocks)) {
      return a.copyWith(
        blocks: cached.blocks,
        title: a.title.isEmpty ? cached.title : a.title,
      );
    }
    return null;
  }

  WorkerAnnouncementRead _enrichListItem(WorkerAnnouncementRead a) {
    final enriched = _enrichedFromCache(a);
    return enriched ?? a;
  }

  Future<WorkerAnnouncementRead> getById(int id) => _repository.getById(id);

  Future<WorkerAnnouncementRead> create(
      WorkerAnnouncementWriteBody body) async {
    final created = await _repository.create(body);
    upsertManageListItem(created);
    return created;
  }

  Future<WorkerAnnouncementRead> update(
    int id,
    WorkerAnnouncementWriteBody body,
  ) async {
    final updated = await _repository.update(id, body);
    upsertManageListItem(updated);
    return updated;
  }

  Future<void> delete(int id) async {
    await _repository.delete(id);
    removeCachedDetail(id);
  }

  Future<WorkerAnnouncementRead> pin(int id) async {
    final pinned = await _repository.pin(id);
    upsertManageListItem(pinned);
    invalidateManageListCache();
    return pinned;
  }

  Future<WorkerAnnouncementRead> unpin(int id) async {
    final unpinned = await _repository.unpin(id);
    upsertManageListItem(unpinned);
    invalidateManageListCache();
    return unpinned;
  }
}

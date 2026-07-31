import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/data/datasources/remote/list_query.dart';
import 'package:w0001/data/datasources/remote/worker_announcements_remote_api.dart';
import 'package:w0001/data/model/paged_result.dart';
import 'package:w0001/data/model/worker_announcement_models.dart';
import 'package:w0001/data/repository/worker_announcement_list_query.dart';
import 'package:w0001/domain/repository/worker_announcement_repository.dart';
import 'package:w0001/presentation/viewmodel/worker_announcement_paged_list_notifier.dart';

final class WorkerAnnouncementRepositoryImpl
    implements WorkerAnnouncementRepository {
  WorkerAnnouncementRepositoryImpl(this._api);

  final WorkerAnnouncementsRemoteApi _api;

  @override
  Future<List<WorkerAnnouncementRead>> inbox({int? placeId}) async {
    try {
      return await _api.inbox(pid: placeId);
    } on HttpStatusException catch (e) {
      if (e.statusCode == 404) return [];
      rethrow;
    }
  }

  @override
  Future<PagedResult<WorkerAnnouncementRead>> inboxPage({
    int? placeId,
    WorkerAnnouncementPagedScopeFilter scopeFilter =
        WorkerAnnouncementPagedScopeFilter.all,
    int? placeComplete,
    int limit = kListPageSize,
    String? cursor,
  }) async {
    final params = resolveWorkerAnnouncementListQuery(
      placeId: placeId,
      scopeFilter: scopeFilter,
      placeComplete: placeComplete,
    );
    try {
      return await _api.inboxPage(
        pid: placeId,
        scope: params.scope,
        pcomplete: params.pcomplete,
        limit: limit,
        cursor: cursor,
      );
    } on HttpStatusException catch (e) {
      if (e.statusCode == 404) {
        return const PagedResult(items: [], hasMore: false);
      }
      rethrow;
    }
  }

  @override
  Future<List<WorkerAnnouncementRead>> manageList() async {
    try {
      return await _api.manageList();
    } on HttpStatusException catch (e) {
      if (e.statusCode == 404) return [];
      rethrow;
    }
  }

  @override
  Future<PagedResult<WorkerAnnouncementRead>> manageListPage({
    int? placeId,
    WorkerAnnouncementPagedScopeFilter scopeFilter =
        WorkerAnnouncementPagedScopeFilter.all,
    int? placeComplete,
    int limit = kListPageSize,
    String? cursor,
  }) async {
    final params = resolveWorkerAnnouncementListQuery(
      placeId: placeId,
      scopeFilter: scopeFilter,
      placeComplete: placeComplete,
    );
    try {
      return await _api.manageListPage(
        pid: placeId,
        scope: params.scope,
        pcomplete: params.pcomplete,
        limit: limit,
        cursor: cursor,
      );
    } on HttpStatusException catch (e) {
      if (e.statusCode == 404) {
        return const PagedResult(items: [], hasMore: false);
      }
      rethrow;
    }
  }

  @override
  Future<WorkerAnnouncementRead> getById(int id) => _api.getById(id);

  @override
  Future<WorkerAnnouncementRead> create(WorkerAnnouncementWriteBody body) =>
      _api.create(body);

  @override
  Future<WorkerAnnouncementRead> update(
          int id, WorkerAnnouncementWriteBody body) =>
      _api.patch(id, body);

  @override
  Future<void> delete(int id) => _api.delete(id);

  @override
  Future<WorkerAnnouncementRead> pin(int id) => _api.pin(id);

  @override
  Future<WorkerAnnouncementRead> unpin(int id) => _api.unpin(id);
}

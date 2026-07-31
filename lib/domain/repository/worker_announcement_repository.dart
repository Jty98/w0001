import 'package:w0001/data/datasources/remote/list_query.dart';
import 'package:w0001/data/model/paged_result.dart';
import 'package:w0001/data/model/worker_announcement_models.dart';
import 'package:w0001/presentation/viewmodel/worker_announcement_paged_list_notifier.dart';

abstract class WorkerAnnouncementRepository {
  Future<List<WorkerAnnouncementRead>> inbox({int? placeId});

  Future<PagedResult<WorkerAnnouncementRead>> inboxPage({
    int? placeId,
    WorkerAnnouncementPagedScopeFilter scopeFilter =
        WorkerAnnouncementPagedScopeFilter.all,
    int? placeComplete,
    int limit = kListPageSize,
    String? cursor,
  });

  Future<List<WorkerAnnouncementRead>> manageList();

  Future<PagedResult<WorkerAnnouncementRead>> manageListPage({
    int? placeId,
    WorkerAnnouncementPagedScopeFilter scopeFilter =
        WorkerAnnouncementPagedScopeFilter.all,
    int? placeComplete,
    int limit = kListPageSize,
    String? cursor,
  });

  Future<WorkerAnnouncementRead> getById(int id);

  Future<WorkerAnnouncementRead> create(WorkerAnnouncementWriteBody body);

  Future<WorkerAnnouncementRead> update(
      int id, WorkerAnnouncementWriteBody body);

  Future<void> delete(int id);

  Future<WorkerAnnouncementRead> pin(int id);

  Future<WorkerAnnouncementRead> unpin(int id);
}

import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/data/datasources/remote/worker_announcements_remote_api.dart';
import 'package:w0001/data/model/worker_announcement_models.dart';
import 'package:w0001/domain/repository/worker_announcement_repository.dart';

final class WorkerAnnouncementRepositoryImpl implements WorkerAnnouncementRepository {
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
  Future<List<WorkerAnnouncementRead>> manageList() async {
    try {
      return await _api.manageList();
    } on HttpStatusException catch (e) {
      if (e.statusCode == 404) return [];
      rethrow;
    }
  }

  @override
  Future<WorkerAnnouncementRead> getById(int id) => _api.getById(id);

  @override
  Future<WorkerAnnouncementRead> create(WorkerAnnouncementWriteBody body) =>
      _api.create(body);

  @override
  Future<WorkerAnnouncementRead> update(int id, WorkerAnnouncementWriteBody body) =>
      _api.patch(id, body);

  @override
  Future<void> delete(int id) => _api.delete(id);

  @override
  Future<WorkerAnnouncementRead> pin(int id) => _api.pin(id);

  @override
  Future<WorkerAnnouncementRead> unpin(int id) => _api.unpin(id);
}

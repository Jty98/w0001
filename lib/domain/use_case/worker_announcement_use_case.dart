import 'package:w0001/data/model/worker_announcement_models.dart';
import 'package:w0001/domain/repository/worker_announcement_repository.dart';

class WorkerAnnouncementUseCase {
  WorkerAnnouncementUseCase(this._repository);

  final WorkerAnnouncementRepository _repository;

  Future<List<WorkerAnnouncementRead>> inbox({int? placeId}) =>
      _repository.inbox(placeId: placeId);

  Future<List<WorkerAnnouncementRead>> manageList() => _repository.manageList();

  Future<WorkerAnnouncementRead> getById(int id) => _repository.getById(id);

  Future<WorkerAnnouncementRead> create(WorkerAnnouncementWriteBody body) =>
      _repository.create(body);

  Future<WorkerAnnouncementRead> update(int id, WorkerAnnouncementWriteBody body) =>
      _repository.update(id, body);

  Future<void> delete(int id) => _repository.delete(id);

  Future<WorkerAnnouncementRead> pin(int id) => _repository.pin(id);

  Future<WorkerAnnouncementRead> unpin(int id) => _repository.unpin(id);
}

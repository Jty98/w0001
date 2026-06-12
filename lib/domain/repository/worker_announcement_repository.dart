import 'package:w0001/data/model/worker_announcement_models.dart';

abstract class WorkerAnnouncementRepository {
  Future<List<WorkerAnnouncementRead>> inbox({int? placeId});

  Future<List<WorkerAnnouncementRead>> manageList();

  Future<WorkerAnnouncementRead> getById(int id);

  Future<WorkerAnnouncementRead> create(WorkerAnnouncementWriteBody body);

  Future<WorkerAnnouncementRead> update(int id, WorkerAnnouncementWriteBody body);

  Future<void> delete(int id);

  Future<WorkerAnnouncementRead> pin(int id);

  Future<WorkerAnnouncementRead> unpin(int id);
}

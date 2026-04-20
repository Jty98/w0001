import 'package:w0001/data/datasources/local/human_local_data_source.dart';
import 'package:w0001/domain/repository/human_abst.dart';
import 'package:w0001/data/model/human_model.dart';

class HumanRepositoryImpl implements HumanRepository {
  HumanRepositoryImpl(this._localDataSource);

  final HumanLocalDataSource _localDataSource;

  @override
  Future<List<HumanModel>> getAllWorkers() {
    return _localDataSource.getAllWorkers();
  }

  @override
  Future<HumanModel> addWorker(HumanModel worker) async {
    final hid = await _localDataSource.addWorker(worker);
    return HumanModel(
      hid: hid,
      hname: worker.hname,
      hnumber: worker.hnumber,
      hmemo: worker.hmemo,
      hdailyWage: worker.hdailyWage,
      hdefaultRole: worker.hdefaultRole,
      hstar: worker.hstar,
      hdelete: worker.hdelete,
    );
  }

  @override
  Future<void> updateWorker(HumanModel humanModel) {
    return _localDataSource.updateWorker(humanModel);
  }

  @override
  Future<void> toggleWorkerStarStatus(int hid, bool isStarred) {
    return _localDataSource.toggleWorkerStarStatus(hid, isStarred);
  }

  @override
  Future<void> deleteWorker(int hid) {
    return _localDataSource.deleteWorker(hid);
  }

  @override
  Future<void> upsertPlaceWorkerRecent(int pid, int hid) {
    return _localDataSource.upsertPlaceWorkerRecent(pid, hid);
  }

  @override
  Future<List<int>> getPlaceWorkerRecentHids(int pid) {
    return _localDataSource.getPlaceWorkerRecentHids(pid);
  }

  @override
  Future<void> deletePlaceWorkerRecent(int pid, int hid) {
    return _localDataSource.deletePlaceWorkerRecent(pid, hid);
  }
}


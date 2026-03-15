import 'package:w0001/data/datasources/local/dbhelper.dart';
import 'package:w0001/data/model/human_model.dart';

/// 작업자(Human) 관련 로컬 데이터소스 (SQLite)
abstract class HumanLocalDataSource {
  Future<List<HumanModel>> getAllWorkers();
  Future<void> addWorker(HumanModel worker);
  Future<void> updateWorker(HumanModel humanModel);
  Future<void> toggleWorkerStarStatus(int hid, bool isStarred);
  Future<void> deleteWorker(int hid);
}

class HumanLocalDataSourceImpl implements HumanLocalDataSource {
  HumanLocalDataSourceImpl(this._dbHelper);

  final DbHelper _dbHelper;

  @override
  Future<List<HumanModel>> getAllWorkers() {
    return _dbHelper.getAllWorkers();
  }

  @override
  Future<void> addWorker(HumanModel worker) {
    return _dbHelper.addWorker(worker);
  }

  @override
  Future<void> updateWorker(HumanModel humanModel) {
    return _dbHelper.updateWorker(humanModel);
  }

  @override
  Future<void> toggleWorkerStarStatus(int hid, bool isStarred) {
    return _dbHelper.toggleWorkerStarStatus(hid, isStarred);
  }

  @override
  Future<void> deleteWorker(int hid) {
    return _dbHelper.deleteWorker(hid);
  }
}


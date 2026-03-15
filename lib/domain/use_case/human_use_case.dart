import 'package:w0001/domain/repository/human_abst.dart';
import 'package:w0001/data/model/human_model.dart';

class HumanUseCase {
  HumanUseCase(this._repository);

  final HumanRepository _repository;

  Future<List<HumanModel>> getAllWorkers() {
    return _repository.getAllWorkers();
  }

  Future<HumanModel> addWorker(HumanModel worker) {
    return _repository.addWorker(worker);
  }

  Future<void> updateWorker(HumanModel humanModel) {
    return _repository.updateWorker(humanModel);
  }

  Future<void> toggleWorkerStarStatus(int hid, bool isStarred) {
    return _repository.toggleWorkerStarStatus(hid, isStarred);
  }

  Future<void> deleteWorker(int hid) {
    return _repository.deleteWorker(hid);
  }
}


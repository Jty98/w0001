import 'package:w0001/data/model/human_model.dart';

/// 작업자(Human) 도메인 저장소 추상
abstract class HumanRepository {
  Future<List<HumanModel>> getAllWorkers();
  Future<HumanModel> addWorker(HumanModel worker);
  Future<void> updateWorker(HumanModel humanModel);
  Future<void> toggleWorkerStarStatus(int hid, bool isStarred);
  Future<void> deleteWorker(int hid);
}

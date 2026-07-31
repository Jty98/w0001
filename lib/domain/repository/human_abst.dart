import 'package:w0001/data/datasources/remote/list_query.dart';
import 'package:w0001/data/model/human_model.dart';
import 'package:w0001/data/model/human_private_models.dart';
import 'package:w0001/data/model/paged_result.dart';

/// 작업자(Human) 도메인 저장소 추상
abstract class HumanRepository {
  Future<List<HumanModel>> getAllWorkers();
  Future<PagedResult<HumanModel>> fetchWorkersPage(ListQuery query);
  Future<List<HumanModel>> fetchAllWorkers(ListQuery query);
  Future<List<HumanModel>> searchWorkers(
      {required String q, int limit = kListPageSize});
  Future<PagedResult<HumanModel>> searchWorkersPage({
    required String q,
    int limit = kListPageSize,
    String? cursor,
  });
  Future<List<HumanModel>> getWorkersByHids(Iterable<int> hids);
  Future<HumanModel> addWorker(HumanModel worker);
  Future<HumanModel> updateWorker(HumanModel humanModel);
  Future<void> toggleWorkerStarStatus(int hid, bool isStarred);
  Future<void> deleteWorker(int hid);

  Future<void> upsertPlaceWorkerRecent(int pid, int hid);
  Future<void> upsertPlaceWorkersRecent(int pid, Iterable<int> hids);
  Future<List<int>> getPlaceWorkerRecentHids(int pid);
  Future<void> deletePlaceWorkerRecent(int pid, int hid);

  /// 현장에서 최근 작업한 인원 목록 조회 (통합 API, 최적화)
  Future<List<HumanModel>> getPlaceRecentWorkers(int pid,
      {int limit = 100, int offset = 0});

  Future<HumanPrivateRead> getHumanPrivate(int hid);
  Future<HumanPrivateRead> saveHumanPrivate({
    required int hid,
    String? rrn,
    String? bankAccount,
    String? bankOwner,
    String? bankName,
    String? hphone,
  });
  Future<String> revealHumanRrn({required int hid, required String reason});
  Future<String> revealHumanHphone({required int hid, required String reason});
  Future<String> revealHumanLinkedPhone(
      {required int hid, required String reason});
  Future<String> revealHumanBankAccount(
      {required int hid, required String reason});
}

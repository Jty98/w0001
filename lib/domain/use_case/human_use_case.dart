import 'package:w0001/data/datasources/remote/list_query.dart';
import 'package:w0001/data/model/human_private_models.dart';
import 'package:w0001/data/model/paged_result.dart';
import 'package:w0001/domain/repository/human_abst.dart';
import 'package:w0001/data/model/human_model.dart';

class HumanUseCase {
  HumanUseCase(this._repository);

  final HumanRepository _repository;

  Future<List<HumanModel>> getAllWorkers() {
    return _repository.getAllWorkers();
  }

  Future<PagedResult<HumanModel>> fetchWorkersPage(ListQuery query) {
    return _repository.fetchWorkersPage(query);
  }

  Future<List<HumanModel>> fetchAllWorkers(ListQuery query) {
    return _repository.fetchAllWorkers(query);
  }

  Future<List<HumanModel>> getWorkersByHids(Iterable<int> hids) {
    return _repository.getWorkersByHids(hids);
  }

  Future<List<HumanModel>> searchWorkers({
    required String q,
    int limit = kListPageSize,
  }) {
    return _repository.searchWorkers(q: q, limit: limit);
  }

  Future<PagedResult<HumanModel>> searchWorkersPage({
    required String q,
    int limit = kListPageSize,
    String? cursor,
  }) {
    return _repository.searchWorkersPage(q: q, limit: limit, cursor: cursor);
  }

  Future<HumanModel> addWorker(HumanModel worker) {
    return _repository.addWorker(worker);
  }

  Future<HumanModel> updateWorker(HumanModel humanModel) {
    return _repository.updateWorker(humanModel);
  }

  Future<void> toggleWorkerStarStatus(int hid, bool isStarred) {
    return _repository.toggleWorkerStarStatus(hid, isStarred);
  }

  Future<void> deleteWorker(int hid) {
    return _repository.deleteWorker(hid);
  }

  Future<void> rememberPlaceWorker(int pid, int hid) {
    return _repository.upsertPlaceWorkerRecent(pid, hid);
  }

  Future<void> rememberPlaceWorkers(int pid, Iterable<int> hids) {
    return _repository.upsertPlaceWorkersRecent(pid, hids);
  }

  Future<List<int>> getPlaceWorkerRecentHids(int pid) {
    return _repository.getPlaceWorkerRecentHids(pid);
  }

  Future<void> deletePlaceWorkerRecent(int pid, int hid) {
    return _repository.deletePlaceWorkerRecent(pid, hid);
  }

  /// 현장에서 최근 작업한 인원 목록 조회 (통합 API, 최적화)
  Future<List<HumanModel>> getPlaceRecentWorkers(int pid,
      {int limit = 100, int offset = 0}) async {
    print('📚 [USE CASE] getPlaceRecentWorkers 진입');
    print('   - PID: $pid, Limit: $limit, Offset: $offset');

    final startTime = DateTime.now();
    final result = await _repository.getPlaceRecentWorkers(pid,
        limit: limit, offset: offset);
    final duration = DateTime.now().difference(startTime).inMilliseconds;

    print(
        '📚 [USE CASE] getPlaceRecentWorkers 완료: ${duration}ms, ${result.length}명');
    return result;
  }

  Future<HumanPrivateRead> getHumanPrivate(int hid) =>
      _repository.getHumanPrivate(hid);

  Future<HumanPrivateRead> saveHumanPrivate({
    required int hid,
    String? rrn,
    String? bankAccount,
    String? bankOwner,
    String? bankName,
    String? hphone,
  }) =>
      _repository.saveHumanPrivate(
        hid: hid,
        rrn: rrn,
        bankAccount: bankAccount,
        bankOwner: bankOwner,
        bankName: bankName,
        hphone: hphone,
      );

  Future<String> revealHumanRrn({required int hid, required String reason}) =>
      _repository.revealHumanRrn(hid: hid, reason: reason);

  Future<String> revealHumanHphone(
          {required int hid, required String reason}) =>
      _repository.revealHumanHphone(hid: hid, reason: reason);

  Future<String> revealHumanLinkedPhone({
    required int hid,
    required String reason,
  }) =>
      _repository.revealHumanLinkedPhone(hid: hid, reason: reason);

  Future<String> revealHumanBankAccount({
    required int hid,
    required String reason,
  }) =>
      _repository.revealHumanBankAccount(hid: hid, reason: reason);
}

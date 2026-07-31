import 'package:w0001/data/datasources/remote/list_query.dart';
import 'package:w0001/data/datasources/remote/remote_list_pages.dart';
import 'package:w0001/data/mappers/remote_mappers.dart';
import 'package:w0001/data/model/human_model.dart';
import 'package:w0001/data/model/human_private_models.dart';
import 'package:w0001/data/model/paged_result.dart';
import 'package:w0001/data/model/remote/super_admin_dtos.dart';
import 'package:w0001/data/repository/remote_entity_lookup.dart';
import 'package:w0001/domain/repository/human_abst.dart';
import 'package:w0001/domain/repository/super_admin_remote_abst.dart';
import 'package:w0001/util/career_input.dart';
import 'package:w0001/util/phone_number_format.dart';
import 'package:w0001/util/resident_registration_format.dart';

class HumanRepositoryImpl implements HumanRepository {
  HumanRepositoryImpl(this._remote);

  final SuperAdminRemoteRepository _remote;

  List<PlaceWorkerRecentRead>? _recentsCache;
  DateTime? _recentsCacheAt;
  static const _recentsCacheTtl = Duration(seconds: 60);

  Future<List<PlaceWorkerRecentRead>> _loadRecents({bool force = false}) async {
    final now = DateTime.now();
    if (!force &&
        _recentsCache != null &&
        _recentsCacheAt != null &&
        now.difference(_recentsCacheAt!) < _recentsCacheTtl) {
      return _recentsCache!;
    }
    final all = await _remote.placeWorkerRecentsList();
    _recentsCache = all;
    _recentsCacheAt = now;
    return all;
  }

  void _invalidateRecentsCache() {
    _recentsCache = null;
    _recentsCacheAt = null;
  }

  List<HumanModel> _sortAndMapHumans(List<HumanRead> list) {
    final active = list.where((h) => h.hdelete == 0).toList();
    active.sort((a, b) {
      final c = b.hstar.compareTo(a.hstar);
      if (c != 0) return c;
      return a.hname.compareTo(b.hname);
    });
    return active.map(humanReadToModel).toList();
  }

  @override
  Future<List<HumanModel>> getAllWorkers() async {
    final list = await _remote.humansQuery(const ListQuery(hdelete: 0));
    return _sortAndMapHumans(list);
  }

  @override
  Future<List<HumanModel>> fetchAllWorkers(ListQuery query) async {
    final q = query.hdelete == null ? query.copyWith(hdelete: 0) : query;
    final items = await fetchAllListPages(fetchWorkersPage, q);
    items.sort((a, b) {
      final c = b.hstar.compareTo(a.hstar);
      if (c != 0) return c;
      return a.hname.compareTo(b.hname);
    });
    return items;
  }

  @override
  Future<PagedResult<HumanModel>> fetchWorkersPage(ListQuery query) async {
    final q = query.hdelete == null ? query.copyWith(hdelete: 0) : query;
    final page = await _remote.humansQueryPage(q);
    return PagedResult(
      items: _sortAndMapHumans(page.items),
      nextCursor: page.nextCursor,
      hasMore: page.hasMore,
      totalCount: page.totalCount,
    );
  }

  @override
  Future<List<HumanModel>> searchWorkers({
    required String q,
    int limit = kListPageSize,
  }) async {
    final page = await searchWorkersPage(q: q, limit: limit);
    return page.items;
  }

  @override
  Future<PagedResult<HumanModel>> searchWorkersPage({
    required String q,
    int limit = kListPageSize,
    String? cursor,
  }) async {
    final trimmed = q.trim();
    return fetchWorkersPage(
      ListQuery(
        q: trimmed.isEmpty ? null : trimmed,
        hdelete: 0,
        limit: limit,
        cursor: cursor,
      ),
    );
  }

  @override
  Future<List<HumanModel>> getWorkersByHids(Iterable<int> hids) async {
    final map = await loadHumanMapForHids(_remote, hids);
    return _sortAndMapHumans(map.values.toList());
  }

  Map<String, dynamic> _humanWriteBody(
    HumanModel worker, {
    int? hdelete,
    bool forUpdate = false,
  }) {
    final body = <String, dynamic>{
      'hname': worker.hname,
      'hmemo': worker.hmemo,
      'hdailywage': worker.hdailyWage,
      'hdefaultrole': worker.hdefaultRole,
      'hstar': worker.hstar,
      if (hdelete != null) 'hdelete': hdelete,
    };
    body['primary_specialty'] = worker.primarySpecialty?.trim() ?? '';
    body['worker_rank'] = worker.workerRank.trim();
    body['career'] = CareerInputUtils.careerForApi(worker.career);

    final hnumber = residentRegistrationForWrite(worker.hnumber);
    if (hnumber != null) {
      body['hnumber'] = hnumber;
    } else if (!forUpdate) {
      // 신규 등록 — 마스킹 값은 없고, 미완성 입력은 서버 검증에 맡긴다.
      body['hnumber'] = worker.hnumber.trim();
    }
    // 수정 시 마스킹·미완성 주민번호는 필드를 보내지 않아 기존 값을 유지한다.

    final manualPhone = worker.hphone?.trim() ?? '';
    body['hphone'] =
        manualPhone.isEmpty ? '' : formatKoreanMobilePhoneDisplay(manualPhone);

    return body;
  }

  @override
  Future<HumanModel> addWorker(HumanModel worker) async {
    final created = await _remote.humanCreate(
      _humanWriteBody(worker, hdelete: 0),
    );
    if (created.hid > 0) {
      final fresh = await _remote.humanGet(created.hid);
      return humanReadToModel(fresh);
    }
    return humanReadToModel(created);
  }

  @override
  Future<HumanModel> updateWorker(HumanModel humanModel) async {
    if (humanModel.hid == null) return humanModel;
    await _remote.humanPatch(
      humanModel.hid!,
      _humanWriteBody(humanModel, forUpdate: true),
    );
    final fresh = await _remote.humanGet(humanModel.hid!);
    return humanReadToModel(fresh);
  }

  @override
  Future<void> toggleWorkerStarStatus(int hid, bool isStarred) {
    return _remote
        .humanPatch(hid, <String, dynamic>{'hstar': isStarred ? 1 : 0});
  }

  @override
  Future<void> deleteWorker(int hid) {
    return _remote.humanDelete(hid);
  }

  @override
  Future<void> upsertPlaceWorkerRecent(int pid, int hid) {
    return upsertPlaceWorkersRecent(pid, [hid]);
  }

  @override
  Future<void> upsertPlaceWorkersRecent(int pid, Iterable<int> hids) async {
    final unique = hids.toSet();
    if (unique.isEmpty) return;
    final ms = DateTime.now().millisecondsSinceEpoch;
    final all = await _loadRecents();
    final existing = {
      for (final e in all) '${e.pid}|${e.hid}': true,
    };
    await Future.wait(
      unique.map((hid) {
        if (existing.containsKey('$pid|$hid')) {
          return _remote.placeWorkerRecentPatch(
            pid,
            hid,
            <String, dynamic>{'lastusedms': ms},
          );
        }
        return _remote.placeWorkerRecentCreate(<String, dynamic>{
          'pid': pid,
          'hid': hid,
          'lastusedms': ms,
        });
      }),
    );
    _invalidateRecentsCache();
  }

  @override
  Future<List<int>> getPlaceWorkerRecentHids(int pid) async {
    final all = await _loadRecents();
    final hids = all.where((e) => e.pid == pid).map((e) => e.hid).toSet();
    if (hids.isEmpty) return const [];
    final hMap = await loadHumanMapForHids(_remote, hids);
    final rows = hids
        .map((id) => hMap[id])
        .whereType<HumanRead>()
        .where((h) => h.hdelete == 0)
        .toList();
    rows.sort((a, b) => a.hname.compareTo(b.hname));
    return rows.map((h) => h.hid).toList();
  }

  @override
  Future<void> deletePlaceWorkerRecent(int pid, int hid) async {
    await _remote.placeWorkerRecentDelete(pid, hid);
    _invalidateRecentsCache();
  }

  @override
  Future<List<HumanModel>> getPlaceRecentWorkers(int pid,
      {int limit = 100, int offset = 0}) async {
    print('💾 [REPOSITORY] getPlaceRecentWorkers 진입');
    print('   - PID: $pid, Limit: $limit, Offset: $offset');

    final apiStartTime = DateTime.now();
    final workers = await _remote.humanGetPlaceRecentWorkers(
      pid: pid,
      limit: limit,
      offset: offset,
    );
    final apiDuration = DateTime.now().difference(apiStartTime).inMilliseconds;
    print('💾 [REPOSITORY] API 호출 완료: ${apiDuration}ms, ${workers.length}명');

    final mappingStartTime = DateTime.now();
    final result = workers.map(humanReadToModel).toList();
    final mappingDuration =
        DateTime.now().difference(mappingStartTime).inMilliseconds;
    print('💾 [REPOSITORY] 모델 매핑 완료: ${mappingDuration}ms');

    return result;
  }

  @override
  Future<HumanPrivateRead> getHumanPrivate(int hid) =>
      _remote.humanGetPrivate(hid);

  @override
  Future<HumanPrivateRead> saveHumanPrivate({
    required int hid,
    String? rrn,
    String? bankAccount,
    String? bankOwner,
    String? bankName,
    String? hphone,
  }) {
    return _remote.humanPatchPrivate(
      hid,
      humanPrivatePatchBody(
        rrn: rrn,
        bankAccount: bankAccount,
        bankOwner: bankOwner,
        bankName: bankName,
        hphone: hphone,
      ),
    );
  }

  @override
  Future<String> revealHumanRrn({required int hid, required String reason}) =>
      _remote.humanRevealRrn(hid: hid, reason: reason);

  @override
  Future<String> revealHumanHphone(
          {required int hid, required String reason}) =>
      _remote.humanRevealHphone(hid: hid, reason: reason);

  @override
  Future<String> revealHumanLinkedPhone({
    required int hid,
    required String reason,
  }) =>
      _remote.humanRevealLinkedPhone(hid: hid, reason: reason);

  @override
  Future<String> revealHumanBankAccount({
    required int hid,
    required String reason,
  }) =>
      _remote.humanRevealBankAccount(hid: hid, reason: reason);
}

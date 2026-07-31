import 'package:w0001/data/datasources/remote/list_query.dart';
import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/data/datasources/remote/place/place_work_day_fields.dart';
import 'package:w0001/data/model/place_dropdown_model.dart';
import 'package:w0001/data/model/remote/super_admin_dtos.dart';
import 'package:w0001/data/model/paged_result.dart';
import 'package:w0001/data/model/total_workcost_model.dart';
import 'package:w0001/data/model/work_cost_period_totals.dart';
import 'package:w0001/data/model/work_cost_worker_summary.dart';
import 'package:w0001/data/model/workcost_model.dart';
import 'package:w0001/data/repository/remote_entity_lookup.dart';
import 'package:w0001/domain/repository/super_admin_remote_abst.dart';
import 'package:w0001/domain/repository/workcost_abst.dart';
import 'package:w0001/ui/screen/2_add/work_role_presets.dart';
import 'package:w0001/util/funtions.dart';

class WorkCostRepositoryImpl implements WorkCostRepository {
  WorkCostRepositoryImpl(this._remote);

  final SuperAdminRemoteRepository _remote;

  ListQuery _dateRangeQuery(DateTime startDate, DateTime endDate) =>
      listQueryForDateRange(startDate, endDate);

  @override
  Future<List<TotalWorkCostModel>> getWorkCostsByDateRange(
    DateTime startDate,
    DateTime endDate, {
    int? wcomplete,
    int? hid,
    int? pid,
  }) async {
    final rangeQ = _dateRangeQuery(startDate, endDate).copyWith(
      wcomplete: wcomplete,
      hid: hid,
      pid: pid,
    );
    final wcFuture = _remote.workCostsQuery(rangeQ);
    final pwdFuture = _remote.placeWorkDaysQuery(rangeQ);
    final wcs = await wcFuture;
    final pwdList = await pwdFuture;
    final pwdByKey = buildPlaceWorkDayByKey(pwdList);
    final maps = await Future.wait([
      loadPlaceMapForPids(_remote, wcs.map((w) => w.wpid)),
      loadHumanMapForHids(_remote, wcs.map((w) => w.whid)),
    ]);
    final pMap = maps[0] as Map<int, PlaceRead>;
    final hMap = maps[1] as Map<int, HumanRead>;

    final out = <TotalWorkCostModel>[];
    for (final w in wcs) {
      final h = hMap[w.whid];
      final p = pMap[w.wpid];
      if (h == null || p == null) continue;
      if (h.hdelete != 0) continue;
      if (p.pcomplete == 2) continue;
      final dateKey = normalizeToIsoDateString(w.wdate);
      final pwd = pwdByKey['${w.whid}|${w.wpid}|$dateKey'];
      final role = pwd != null && pwd.workrole.trim().isNotEmpty
          ? pwd.workrole.trim()
          : w.wrole.trim();
      out.add(
        TotalWorkCostModel(
          hname: h.hname,
          hid: h.hid,
          hstar: h.hstar,
          hnumber: h.hnumber,
          pname: p.pname,
          wpid: w.wpid,
          wid: w.wid,
          pcomplete: p.pcomplete,
          wcomplete: w.wcomplete,
          date: dateKey,
          price: w.wprice,
          wcompletedAt: w.wcompletedAt,
          workrole: role,
          hdailyWage: h.hdailywage,
          hdefaultRole: h.hdefaultrole,
          workerRank: h.workerRank,
          primarySpecialty: h.primarySpecialty,
          specialties: h.specialties,
        ),
      );
    }
    out.sort((a, b) {
      final c = b.hstar.compareTo(a.hstar);
      if (c != 0) return c;
      final d = a.hname.compareTo(b.hname);
      if (d != 0) return d;
      return a.date.compareTo(b.date);
    });
    return out;
  }

  @override
  Future<WorkCostPeriodTotals?> getWorkCostPeriodTotals(
    DateTime startDate,
    DateTime endDate, {
    String? q,
    int? pid,
  }) {
    final qq = q?.trim();
    final rangeQ = _dateRangeQuery(startDate, endDate).copyWith(
      q: qq != null && qq.isNotEmpty ? qq : null,
      pid: pid,
    );
    return _remote.workCostsPeriodTotals(rangeQ);
  }

  @override
  Future<PagedResult<WorkCostWorkerSummary>?> getWorkCostWorkerSummariesPage(
    ListQuery query,
  ) {
    return _remote.workCostsWorkerSummariesPage(query);
  }

  @override
  Future<List<WorkCost2Model>> getWorkCostsByPlaceAndDate(
    int hid,
    DateTime startDate,
    DateTime endDate,
    int pid,
  ) async {
    final q = listQueryForDateRange(startDate, endDate,
        hid: hid, pid: pid == 0 ? null : pid);
    final pwdFuture = _remote.placeWorkDaysQuery(q);
    final wcFuture = _remote.workCostsQuery(q);
    final list = await pwdFuture;
    final wcs = await wcFuture;

    final wcByPlaceDate = <String, WorkCostRead>{};
    for (final w in wcs) {
      if (w.whid != hid) continue;
      if (pid != 0 && w.wpid != pid) continue;
      final key = '${w.wpid}|${normalizeToIsoDateString(w.wdate)}';
      wcByPlaceDate[key] = w;
    }

    final pMap = await loadPlaceMapForPids(_remote, list.map((e) => e.pid));

    final out = <WorkCost2Model>[];
    for (final pwd in list) {
      if (pid != 0 && pwd.pid != pid) continue;
      final p = pMap[pwd.pid];
      if (p == null || p.pcomplete == 2) continue;
      final dateKey = normalizeToIsoDateString(pwd.workdate);
      final wc = wcByPlaceDate['${pwd.pid}|$dateKey'];
      out.add(
        WorkCost2Model(
          wdate: pwd.workdate,
          wprice: wc?.wprice ?? pwd.dailywage,
          wcomplete: wc?.wcomplete ?? pwd.paid,
          pname: p.pname,
        ),
      );
    }
    out.sort((a, b) => b.wdate.compareTo(a.wdate));
    return out;
  }

  ListQuery _queryForWorkCostBatch(List<WorkCostModel> wCostList) {
    var min = wCostList.first.wdate;
    var max = wCostList.first.wdate;
    for (final w in wCostList) {
      final dk = normalizeToIsoDateString(w.wdate);
      if (dk.compareTo(min) < 0) min = dk;
      if (dk.compareTo(max) > 0) max = dk;
    }
    return ListQuery(from: min, to: max);
  }

  @override
  Future<bool> addWorkCosts(
    List<WorkCostModel> wCostList, {
    bool acknowledgeTroublePair = false,
  }) async {
    if (wCostList.isEmpty) return true;
    final batchQ = _queryForWorkCostBatch(wCostList);
    final wcs = await _remote.workCostsQuery(batchQ);

    await Future.wait(
      wCostList.map(
        (w) => _upsertOneWorkCost(
          w,
          existingList: wcs,
          acknowledgeTroublePair: acknowledgeTroublePair,
        ),
      ),
    );
    return true;
  }

  Future<void> _upsertOneWorkCost(
    WorkCostModel w, {
    required List<WorkCostRead> existingList,
    required bool acknowledgeTroublePair,
  }) async {
    final wd = normalizeToIsoDateString(w.wdate);
    final role =
        w.wrole.trim().isEmpty ? kWorkRoleManualAddDefault : w.wrole.trim();

    WorkCostRead? existing;
    final hid = w.whid ?? 0;
    for (final c in existingList) {
      if (c.whid == hid &&
          c.wpid == w.wpid &&
          normalizeToIsoDateString(c.wdate) == wd) {
        existing = c;
        break;
      }
    }
    if (existing != null) {
      await _remote.workCostPatch(
        existing.wid,
        <String, dynamic>{
          'wprice': w.wprice,
          'wrole': role,
        },
      );
      return;
    }

    final body = <String, dynamic>{
      'wpid': w.wpid,
      'whid': w.whid ?? 0,
      'wdate': wd,
      'wprice': w.wprice,
      'wcomplete': w.wcomplete,
      'wrole': role,
    };
    if (acknowledgeTroublePair) {
      body[PlaceWorkDayFields.acknowledgeTroublePair] = true;
    }
    await _remote.workCostCreate(body);
  }

  @override
  Future<void> updateWorkCostItem(WorkCostModel workCost) async {
    if (workCost.wid == null) return;
    await _remote.workCostPatch(
      workCost.wid!,
      <String, dynamic>{
        'wprice': workCost.wprice,
        'wdate': workCost.wdate,
      },
    );
  }

  @override
  Future<void> toggleWorkCostCompletionStatus(int wcomplete, int wid) async {
    final next = wcomplete == 1 ? 0 : 1;
    try {
      await _remote.workCostCompletePatch(wid, next);
      return;
    } catch (e) {
      final status = unwrapHttpClientException(e)?.statusCode;
      // 서버 배포 전/롤백 등으로 전용 엔드포인트가 없을 때만 기존 patch로 폴백.
      if (status != 404 && status != 405) rethrow;
    }
    await _remote.workCostPatch(wid, <String, dynamic>{'wcomplete': next});
  }

  @override
  Future<void> updateWorkCostsToComplete(List<int> widList) async {
    await Future.wait(
      widList.map(
        (wid) => _remote.workCostPatch(wid, <String, dynamic>{'wcomplete': 1}),
      ),
    );
  }

  @override
  Future<void> updateWorkCostPrice(int wid, int newPrice) async {
    await _remote.workCostPatch(wid, <String, dynamic>{'wprice': newPrice});
  }

  @override
  Future<void> deleteWorkCost(int wid) {
    return _remote.workCostDelete(wid);
  }

  @override
  Future<int?> findPlaceWorkDayPwdid({
    required int pid,
    required int hid,
    required String dateKey,
  }) async {
    final key = normalizeToIsoDateString(dateKey);
    final list = await _remote.placeWorkDaysQuery(
      ListQuery(pid: pid, hid: hid, from: key, to: key),
    );
    for (final p in list) {
      if (normalizeToIsoDateString(p.workdate) == key) {
        return p.pwdid;
      }
    }
    return null;
  }

  @override
  Future<void> ensureWorkCostForPlaceWorkDay({
    required int pid,
    required int hid,
    required String dateKey,
    required int wprice,
    required String wrole,
  }) async {
    final wd = normalizeToIsoDateString(dateKey);
    final role =
        wrole.trim().isEmpty ? kWorkRoleManualAddDefault : wrole.trim();
    final wcs = await _remote.workCostsQuery(
      ListQuery(pid: pid, hid: hid, from: wd, to: wd),
    );
    for (final c in wcs) {
      if (normalizeToIsoDateString(c.wdate) == wd) {
        await _remote.workCostPatch(
          c.wid,
          <String, dynamic>{'wprice': wprice, 'wrole': role},
        );
        return;
      }
    }
    await _remote.workCostCreate(<String, dynamic>{
      'wpid': pid,
      'whid': hid,
      'wdate': wd,
      'wprice': wprice,
      'wcomplete': 0,
      'wrole': role,
    });
  }

  @override
  Future<void> deleteWorkCostLinked({
    required int wid,
    int? pwdid,
  }) async {
    await _remote.workCostDelete(wid);
    if (pwdid != null) {
      await _remote.placeWorkDayDelete(pwdid);
    }
  }

  Future<List<Map<String, dynamic>>> _workDayCsvRows(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final rangeQ = _dateRangeQuery(startDate, endDate);
    final pwdFuture = _remote.placeWorkDaysQuery(rangeQ);
    final wcFuture = _remote.workCostsQuery(rangeQ);
    final list = await pwdFuture;
    final wcs = await wcFuture;

    final wcByKey = <String, WorkCostRead>{};
    for (final w in wcs) {
      final key = '${w.whid}|${w.wpid}|${normalizeToIsoDateString(w.wdate)}';
      wcByKey[key] = w;
    }

    final pMap = await loadPlaceMapForPids(_remote, list.map((e) => e.pid));
    final hMap = await loadHumanMapForHids(_remote, list.map((e) => e.hid));

    final out = <Map<String, dynamic>>[];
    for (final pwd in list) {
      final p = pMap[pwd.pid];
      final h = hMap[pwd.hid];
      if (p == null || h == null) continue;
      if (h.hdelete != 0) continue;
      if (p.pcomplete == 2) continue;
      final dateKey = normalizeToIsoDateString(pwd.workdate);
      final wc = wcByKey['${pwd.hid}|${pwd.pid}|$dateKey'];
      final amount = wc?.wprice ?? pwd.dailywage;
      final deduct = (amount * 0.967).toInt();
      out.add(<String, dynamic>{
        '이름': h.hname,
        '현장': p.pname,
        '주민등록번호': h.hnumber,
        '날짜': pwd.workdate,
        '금액': amount,
        '공제금액': deduct,
      });
    }
    return out;
  }

  @override
  Future<List<Map<String, dynamic>>> getWorkCostDetailsForCsv(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final out = await _workDayCsvRows(startDate, endDate);
    out.sort((a, b) {
      final c = '${a['이름']}'.compareTo('${b['이름']}');
      if (c != 0) return c;
      return '${a['날짜']}'.compareTo('${b['날짜']}');
    });
    return out;
  }

  @override
  Future<List<Map<String, dynamic>>> getWorkCostTotalsForCsv(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final rows = await _workDayCsvRows(startDate, endDate);
    final byKey =
        <String, (String name, String number, int total, int deduct)>{};
    for (final row in rows) {
      final name = '${row['이름']}';
      final number = '${row['주민등록번호']}';
      final key = '$name|$number';
      final add = row['금액'] as int? ?? 0;
      final dAdd = row['공제금액'] as int? ?? 0;
      final prev = byKey[key];
      if (prev == null) {
        byKey[key] = (name, number, add, dAdd);
      } else {
        byKey[key] = (name, number, prev.$3 + add, prev.$4 + dAdd);
      }
    }
    final out = byKey.values
        .map(
          (e) => <String, dynamic>{
            '이름': e.$1,
            '주민등록번호': e.$2,
            '총금액': e.$3,
            '총공제금액': e.$4,
          },
        )
        .toList();
    out.sort((a, b) => '${a['이름']}'.compareTo('${b['이름']}'));
    return out;
  }

  Future<List<PlaceDropDownModel>> _placesFromPlaceWorkDays(
    List<PlaceWorkDayRead> list,
  ) async {
    final whole = PlaceDropDownModel(pname: '전체 현장', pid: 0);
    final pMap = await loadPlaceMapForPids(
      _remote,
      list.map((e) => e.pid),
    );
    final seen = <int, PlaceRead>{};
    for (final pwd in list) {
      final p = pMap[pwd.pid];
      if (p == null || p.pcomplete == 2) continue;
      seen[p.pid] = p;
    }
    final sorted = seen.values.toList()
      ..sort((a, b) => a.pname.compareTo(b.pname));
    return [
      whole,
      for (final p in sorted) PlaceDropDownModel(pname: p.pname, pid: p.pid),
    ];
  }

  @override
  Future<List<PlaceDropDownModel>> getPlacesForWorkCost(int hid) async {
    final list = await _remote.placeWorkDaysQuery(ListQuery(hid: hid));
    return _placesFromPlaceWorkDays(list);
  }

  @override
  Future<List<PlaceDropDownModel>> getPlacesForWorkCostInPeriod(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final list = await _remote.placeWorkDaysQuery(
      _dateRangeQuery(startDate, endDate),
    );
    return _placesFromPlaceWorkDays(list);
  }

  @override
  Future<List<int>> getSavedWorkDayHidsForPlaceDate({
    required int pid,
    required String dateKey,
  }) async {
    final key = normalizeToIsoDateString(dateKey);
    final list = await _remote.placeWorkDaysQuery(
      ListQuery(pid: pid, from: key, to: key),
    );
    return list.map((e) => e.hid).toList();
  }
}

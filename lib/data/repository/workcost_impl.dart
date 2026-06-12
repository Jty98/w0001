import 'package:w0001/data/mappers/remote_mappers.dart';
import 'package:w0001/data/model/place_dropdown_model.dart';
import 'package:w0001/data/model/remote/super_admin_dtos.dart';
import 'package:w0001/data/model/total_workcost_model.dart';
import 'package:w0001/data/model/workcost_model.dart';
import 'package:w0001/data/datasources/remote/place/place_work_day_fields.dart';
import 'package:w0001/domain/repository/super_admin_remote_abst.dart';
import 'package:w0001/domain/repository/workcost_abst.dart';
import 'package:w0001/ui/screen/2_add/work_role_presets.dart';
import 'package:w0001/util/funtions.dart';

class WorkCostRepositoryImpl implements WorkCostRepository {
  WorkCostRepositoryImpl(this._remote);

  final SuperAdminRemoteRepository _remote;

  DateTime _endExclusive(DateTime endDate) => endDate.add(const Duration(days: 1));

  @override
  Future<List<TotalWorkCostModel>> getWorkCostsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final endN = _endExclusive(endDate);
    final wcs = await _remote.workCostsList();
    final pwdList = await _remote.placeWorkDaysList();
    final places = await _remote.placesList();
    final humans = await _remote.humansList();
    final pMap = {for (final p in places) p.pid: p};
    final hMap = {for (final h in humans) h.hid: h};

    final pwdByKey = <String, PlaceWorkDayRead>{};
    for (final pwd in pwdList) {
      final key =
          '${pwd.hid}|${pwd.pid}|${normalizeToIsoDateString(pwd.workdate)}';
      final prev = pwdByKey[key];
      if (prev == null ||
          (prev.workrole.trim().isEmpty && pwd.workrole.trim().isNotEmpty)) {
        pwdByKey[key] = pwd;
      }
    }

    final out = <TotalWorkCostModel>[];
    for (final w in wcs) {
      if (!inDateRangeYmd(w.wdate, startDate, endN)) continue;
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
  Future<List<WorkCost2Model>> getWorkCostsByPlaceAndDate(
    int hid,
    DateTime startDate,
    DateTime endDate,
    int pid,
  ) async {
    final endN = _endExclusive(endDate);
    final list = await _remote.placeWorkDaysList();
    final places = await _remote.placesList();
    final pMap = {for (final p in places) p.pid: p};

    final out = <WorkCost2Model>[];
    for (final pwd in list) {
      if (pwd.hid != hid) continue;
      if (pid != 0 && pwd.pid != pid) continue;
      if (!inDateRangeYmd(pwd.workdate, startDate, endN)) continue;
      final p = pMap[pwd.pid];
      if (p == null || p.pcomplete == 2) continue;
      out.add(
        WorkCost2Model(
          wdate: pwd.workdate,
          wprice: pwd.dailywage,
          wcomplete: pwd.paid,
          pname: p.pname,
        ),
      );
    }
    out.sort((a, b) => b.wdate.compareTo(a.wdate));
    return out;
  }

  @override
  Future<bool> addWorkCosts(
    List<WorkCostModel> wCostList, {
    bool acknowledgeTroublePair = false,
  }) async {
    if (wCostList.isEmpty) return true;
    final pwdList = await _remote.placeWorkDaysList();
    final wcs = await _remote.workCostsList();

    for (final w in wCostList) {
      final wd = w.wdate.length >= 10 ? w.wdate.substring(0, 10) : w.wdate;
      final role = w.wrole.trim().isEmpty
          ? kWorkRoleManualAddDefault
          : w.wrole.trim();

      if (w.whid != null) {
        final hasPwd = pwdList.any(
          (p) =>
              p.pid == w.wpid &&
              p.hid == w.whid &&
              normalizeToIsoDateString(p.workdate) == wd,
        );
        if (!hasPwd) {
          final pwdBody = <String, dynamic>{
            'pid': w.wpid,
            'hid': w.whid,
            'workdate': wd,
            'dailywage': w.wprice,
            'paid': w.wcomplete,
            'workrole': role,
          };
          if (acknowledgeTroublePair) {
            pwdBody[PlaceWorkDayFields.acknowledgeTroublePair] = true;
          }
          await _remote.placeWorkDayCreate(pwdBody);
        }
      }

      WorkCostRead? existing;
      final hid = w.whid ?? 0;
      for (final c in wcs) {
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
      } else {
        await _remote.workCostCreate(<String, dynamic>{
          'wpid': w.wpid,
          'whid': w.whid ?? 0,
          'wdate': w.wdate,
          'wprice': w.wprice,
          'wcomplete': w.wcomplete,
          'wrole': role,
        });
      }
    }
    return true;
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
    await _remote.workCostPatch(wid, <String, dynamic>{'wcomplete': next});
  }

  @override
  Future<void> updateWorkCostsToComplete(List<int> widList) async {
    for (final wid in widList) {
      await _remote.workCostPatch(wid, <String, dynamic>{'wcomplete': 1});
    }
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
    final list = await _remote.placeWorkDaysList();
    final key = normalizeToIsoDateString(dateKey);
    for (final p in list) {
      if (p.pid == pid &&
          p.hid == hid &&
          normalizeToIsoDateString(p.workdate) == key) {
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
    final role = wrole.trim().isEmpty ? kWorkRoleManualAddDefault : wrole.trim();
    final wcs = await _remote.workCostsList();
    for (final c in wcs) {
      if (c.whid == hid &&
          c.wpid == pid &&
          normalizeToIsoDateString(c.wdate) == wd) {
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

  @override
  Future<List<Map<String, dynamic>>> getWorkCostDetailsForCsv(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final endN = _endExclusive(endDate);
    final list = await _remote.placeWorkDaysList();
    final places = await _remote.placesList();
    final humans = await _remote.humansList();
    final pMap = {for (final p in places) p.pid: p};
    final hMap = {for (final h in humans) h.hid: h};

    final out = <Map<String, dynamic>>[];
    for (final pwd in list) {
      if (!inDateRangeYmd(pwd.workdate, startDate, endN)) continue;
      final p = pMap[pwd.pid];
      final h = hMap[pwd.hid];
      if (p == null || h == null) continue;
      if (h.hdelete != 0) continue;
      if (p.pcomplete == 2) continue;
      final deduct = (pwd.dailywage * 0.967).toInt();
      out.add(<String, dynamic>{
        '이름': h.hname,
        '현장': p.pname,
        '주민등록번호': h.hnumber,
        '날짜': pwd.workdate,
        '금액': pwd.dailywage,
        '공제금액': deduct,
      });
    }
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
    final endN = _endExclusive(endDate);
    final list = await _remote.placeWorkDaysList();
    final places = await _remote.placesList();
    final humans = await _remote.humansList();
    final pMap = {for (final p in places) p.pid: p};
    final hMap = {for (final h in humans) h.hid: h};

    final byKey = <String, (HumanRead, int, int)>{};
    for (final pwd in list) {
      if (!inDateRangeYmd(pwd.workdate, startDate, endN)) continue;
      final p = pMap[pwd.pid];
      final h = hMap[pwd.hid];
      if (p == null || h == null) continue;
      if (h.hdelete != 0) continue;
      if (p.pcomplete == 2) continue;
      final key = '${h.hname}|${h.hnumber}';
      final prev = byKey[key];
      final add = pwd.dailywage;
      final dAdd = (pwd.dailywage * 0.967).toInt();
      if (prev == null) {
        byKey[key] = (h, add, dAdd);
      } else {
        byKey[key] = (h, prev.$2 + add, prev.$3 + dAdd);
      }
    }
    final out = byKey.values
        .map(
          (e) => <String, dynamic>{
            '이름': e.$1.hname,
            '주민등록번호': e.$1.hnumber,
            '총금액': e.$2,
            '총공제금액': e.$3,
          },
        )
        .toList();
    out.sort(
      (a, b) => '${a['이름']}'.compareTo('${b['이름']}'),
    );
    return out;
  }

  @override
  Future<List<PlaceDropDownModel>> getPlacesForWorkCost(int hid) async {
    final whole = PlaceDropDownModel(pname: '전체 현장', pid: 0);
    final list = await _remote.placeWorkDaysList();
    final places = await _remote.placesList();
    final pMap = {for (final p in places) p.pid: p};
    final seen = <int, PlaceRead>{};
    for (final pwd in list) {
      if (pwd.hid != hid) continue;
      final p = pMap[pwd.pid];
      if (p == null || p.pcomplete == 2) continue;
      seen[p.pid] = p;
    }
    final out = <PlaceDropDownModel>[whole];
    for (final p in seen.values) {
      out.add(PlaceDropDownModel(pname: p.pname, pid: p.pid));
    }
    return out;
  }

  @override
  Future<List<int>> getSavedWorkDayHidsForPlaceDate({
    required int pid,
    required String dateKey,
  }) async {
    final list = await _remote.placeWorkDaysList();
    return list
        .where((e) => e.pid == pid && e.workdate == dateKey)
        .map((e) => e.hid)
        .toList();
  }
}

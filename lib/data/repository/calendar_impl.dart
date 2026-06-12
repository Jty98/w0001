import 'package:w0001/data/mappers/remote_mappers.dart';
import 'package:w0001/data/model/remote/super_admin_dtos.dart';
import 'package:w0001/data/model/total_cost_model.dart';
import 'package:w0001/domain/repository/calendar_abst.dart';
import 'package:w0001/util/funtions.dart' show normalizeToIsoDateString;
import 'package:w0001/domain/repository/dashboard_remote_abst.dart';
import 'package:w0001/domain/repository/super_admin_remote_abst.dart';

class CalendarRepositoryImpl implements CalendarRepository {
  CalendarRepositoryImpl(this._sa, this._dashboard);

  final SuperAdminRemoteRepository _sa;
  final DashboardRemoteRepository _dashboard;

  @override
  Future<Map<DateTime, List<String>>> getAllEvents() {
    return _dashboard.calendarEvents();
  }

  @override
  Future<List<TotalCostModel>> getTotalCostsByDate(DateTime dateTime) async {
    final key = dateKeyYmd(dateTime);
    final wcs = await _sa.workCostsList();
    final pwdList = await _sa.placeWorkDaysList();
    final mcs = await _sa.materialCostsList();
    final places = await _sa.placesList();
    final humans = await _sa.humansList();
    final pMap = {for (final p in places) p.pid: p};
    final hMap = {for (final h in humans) h.hid: h};

    final pwdByKey = <String, PlaceWorkDayRead>{};
    for (final pwd in pwdList) {
      final k =
          '${pwd.hid}|${pwd.pid}|${normalizeToIsoDateString(pwd.workdate)}';
      final prev = pwdByKey[k];
      if (prev == null ||
          (prev.workrole.trim().isEmpty && pwd.workrole.trim().isNotEmpty)) {
        pwdByKey[k] = pwd;
      }
    }

    final out = <TotalCostModel>[];
    for (final w in wcs) {
      final wk = w.wdate.length >= 10 ? w.wdate.substring(0, 10) : w.wdate;
      if (wk != key) continue;
      final p = pMap[w.wpid];
      final h = hMap[w.whid];
      if (p == null || p.pcomplete == 2) continue;
      if (h == null || h.hdelete != 0) continue;
      final pwd = pwdByKey['${w.whid}|${w.wpid}|$wk'];
      final role = pwd != null && pwd.workrole.trim().isNotEmpty
          ? pwd.workrole.trim()
          : w.wrole.trim();
      out.add(
        TotalCostModel(
          pname: p.pname,
          pcomplete: p.pcomplete,
          name: h.hname,
          date: w.wdate,
          price: w.wprice,
          category: 'w',
          id: w.wid,
          wcomplete: w.wcomplete,
          wcompletedAt: w.wcompletedAt,
          whid: w.whid,
          wpid: w.wpid,
          workrole: role,
        ),
      );
    }
    for (final m in mcs) {
      final mk = m.mdate.length >= 10 ? m.mdate.substring(0, 10) : m.mdate;
      if (mk != key) continue;
      final p = pMap[m.mpid];
      if (p == null || p.pcomplete == 2) continue;
      out.add(
        TotalCostModel(
          pname: p.pname,
          pcomplete: p.pcomplete,
          name: m.mname,
          date: m.mdate,
          price: m.mprice,
          category: m.mcategory,
          id: m.mid,
          wcomplete: -1,
        ),
      );
    }
    out.sort((a, b) {
      final c = a.category.compareTo(b.category);
      if (c != 0) return c;
      return a.name.compareTo(b.name);
    });
    return out;
  }
}

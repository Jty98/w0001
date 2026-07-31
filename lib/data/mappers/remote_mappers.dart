import 'package:w0001/data/model/human_model.dart';
import 'package:w0001/data/model/place_info_model.dart';
import 'package:w0001/data/model/place_model.dart';
import 'package:w0001/data/model/remote/super_admin_dtos.dart';
import 'package:w0001/data/model/revenue_model.dart';
import 'package:w0001/data/model/schedule_memo_model.dart';

PlaceModel placeReadToModel(PlaceRead p) {
  return PlaceModel(
    pid: p.pid,
    pname: p.pname,
    pstart: p.pstart,
    pend: p.pend,
    paddress: p.paddress,
    pcomplete: p.pcomplete,
    prevenue: p.prevenue,
    pcontractTotal: p.pcontracttotal,
    pcontractDate: p.pcontractdate,
  );
}

/// `/places` 응답으로만 채울 때 집계 필드는 0(상세/비용 API에서 보완).
PlaceInfoModel placeReadToPlaceInfoSummaryZeros(PlaceRead p) {
  return PlaceInfoModel(
    pid: p.pid,
    pname: p.pname,
    pcomplete: p.pcomplete,
    pstart: p.pstart,
    pend: p.pend,
    paddress: p.paddress,
    pfirstrevenue: p.prevenue,
    pcontractTotal: p.pcontracttotal,
    workerCount: 0,
    totalAdditionalRevenue: 0,
    mTotal: 0,
    woodTotal: 0,
    metalTotal: 0,
    electricTotal: 0,
    lightingTotal: 0,
    cleaningTotal: 0,
    filmTotal: 0,
    landscapeTotal: 0,
    hardwareTotal: 0,
    paintTotal: 0,
    facilityTotal: 0,
    tileTotal: 0,
    glassTotal: 0,
    fuelTotal: 0,
    accommodationTotal: 0,
    foodTotal: 0,
    personalExpensesTotal: 0,
    firefightingTotal: 0,
    signageTotal: 0,
    airConditioningTotal: 0,
    demolitionTotal: 0,
    customMadeTotal: 0,
    otherExpensesTotal: 0,
    wTotal: 0,
    wIncomplete: 0,
  );
}

Map<String, dynamic> placeModelToCreateBody(
    PlaceModel p, String pcontractdate) {
  return <String, dynamic>{
    'pname': p.pname,
    'pstart': p.pstart,
    'pend': p.pend,
    'paddress': p.paddress,
    'pcomplete': p.pcomplete,
    'prevenue': p.prevenue,
    'pcontracttotal': p.pcontractTotal,
    'pcontractdate': pcontractdate,
  };
}

Map<String, dynamic> placeModelToPatchBody(PlaceModel p, String pcontractdate) {
  return placeModelToCreateBody(p, pcontractdate);
}

HumanModel humanReadToModel(HumanRead h) {
  return HumanModel(
    hid: h.hid,
    uid: h.uid,
    hname: h.hname,
    hnumber: h.hnumber,
    hmemo: h.hmemo,
    hdailyWage: h.hdailywage,
    hdefaultRole: h.hdefaultrole,
    primarySpecialty: h.primarySpecialty,
    specialties: h.specialties,
    career: h.career,
    workerRank: h.workerRank,
    canBePlaceMember: h.canBePlaceMember,
    linkedUserName: h.linkedUserName,
    hphone: h.hphone,
    linkedPhone: h.linkedPhone,
    linkedUserIsActive: h.linkedUserIsActive,
    linkedUserApprovalStatus: h.linkedUserApprovalStatus,
    hstar: h.hstar,
    hdelete: h.hdelete,
  );
}

RevenueModel revenueReadToModel(PlaceRevenueRead r) {
  return RevenueModel(
    rid: r.rid,
    rpid: r.rpid,
    rname: r.rname,
    rorder: r.rorder,
    rprice: r.rprice,
    rdate: r.rdate,
  );
}

String contractDateKey(String pcontractDate, String pstart) {
  final t = pcontractDate.trim();
  if (t.length >= 10) return t.substring(0, 10);
  if (pstart.length >= 10) return pstart.substring(0, 10);
  return DateTime.now().toIso8601String().substring(0, 10);
}

String dateKeyYmd(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

DateTime dateOnlyYmd(String s) {
  if (s.length < 10) return DateTime.now();
  final p = s.substring(0, 10).split('-');
  if (p.length != 3) return DateTime.now();
  return DateTime(
    int.tryParse(p[0]) ?? 0,
    int.tryParse(p[1]) ?? 1,
    int.tryParse(p[2]) ?? 1,
  );
}

/// `wdate` / `mdate` 앞 10자리 기준, [inclusive, exclusive) 구간
bool inDateRangeYmd(
  String rawDate,
  DateTime startInclusive,
  DateTime endExclusive,
) {
  if (rawDate.isEmpty) return false;
  final k = rawDate.length >= 10 ? rawDate.substring(0, 10) : rawDate;
  return k.compareTo(dateKeyYmd(startInclusive)) >= 0 &&
      k.compareTo(dateKeyYmd(endExclusive)) < 0;
}

ScheduleMemoModel scheduleMemoReadToModel(ScheduleMemoRead r) {
  return ScheduleMemoModel(
    sid: r.sid,
    taskDate: r.taskdate,
    taskTime: r.tasktime,
    title: r.title,
    memo: r.memo,
    done: r.done,
    alarmEnabled: r.alarmenabled,
    alarmOffsetMinutes: r.alarmoffsetminutes ?? 0,
    sortOrder: r.sortorder,
    createdAtMs: r.createdatms,
  );
}

Map<String, dynamic> scheduleMemoToCreateBody(ScheduleMemoModel m) {
  return <String, dynamic>{
    'taskdate': m.taskDate,
    'tasktime': m.taskTime,
    'title': m.title,
    'memo': m.memo,
    'done': m.done,
    'alarmenabled': m.alarmEnabled,
    'alarmoffsetminutes': m.alarmOffsetMinutes,
    'sortorder': m.sortOrder,
    'createdatms': m.createdAtMs,
  };
}

Map<String, dynamic> scheduleMemoToPatchBody(ScheduleMemoModel m) {
  return scheduleMemoToCreateBody(m);
}

List<PlaceInfoModel> sortPlacesInfoByPidDesc(List<PlaceInfoModel> list) {
  final out = List<PlaceInfoModel>.from(list);
  out.sort((a, b) => (b.pid ?? 0).compareTo(a.pid ?? 0));
  return out;
}

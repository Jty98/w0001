import 'package:w0001/domain/same_day_work_cost.dart';

class TotalWorkCostModel {
  final String hname;
  final int hid;
  final int hstar;
  final String hnumber;
  final String pname;
  final int wpid;
  final String date;
  final int wid;
  final int pcomplete;
  final int wcomplete;
  final int price;
  final String? wcompletedAt;

  /// 같은 날 투입된 모든 현장. 비어 있으면 [wpid]/[pname]만 사용.
  final List<SameDayPlaceRef> sameDayPlaces;

  /// 해당 일 작업지시·공정표 연동 공정명 (`place-work-days.workrole` 우선).
  final String workrole;
  final int hdailyWage;
  final String hdefaultRole;

  /// 연결 워커 프로필 현장 역할 (`GET /humans/:hid` → `worker_rank`).
  final String workerRank;

  /// 대표 주특기 (`primary_specialty`).
  final String? primarySpecialty;

  /// 추가 가능 작업.
  final List<String> specialties;

  TotalWorkCostModel({
    required this.hname,
    required this.hid,
    required this.hstar,
    required this.hnumber,
    required this.pname,
    required this.wpid,
    required this.wid,
    required this.pcomplete,
    required this.wcomplete,
    required this.date,
    required this.price,
    this.wcompletedAt,
    this.workrole = '',
    this.hdailyWage = 0,
    this.hdefaultRole = '',
    this.workerRank = '',
    this.primarySpecialty,
    this.specialties = const [],
    this.sameDayPlaces = const [],
  });

  TotalWorkCostModel.fromMap(Map<String, dynamic> res)
      : hname = res['이름'],
        hid = res['hid'],
        hnumber = res['주민등록번호'],
        hstar = res['hstar'],
        pname = res['현장'],
        wpid = res['wpid'] ?? 0,
        wid = res['wid'],
        pcomplete = res['pcomplete'],
        wcomplete = res['wcomplete'],
        date = res['날짜'],
        price = res['금액'],
        wcompletedAt = res['wcompleted_at'],
        workrole = (res['workrole'] ?? res['wrole'] ?? '').toString(),
        hdailyWage = (res['hdailyWage'] as num?)?.toInt() ?? 0,
        hdefaultRole = (res['hdefaultRole'] ?? '').toString(),
        workerRank = (res['workerRank'] ?? res['worker_rank'] ?? '').toString(),
        primarySpecialty = res['primarySpecialty'] as String? ??
            res['primary_specialty'] as String?,
        specialties = const [],
        sameDayPlaces = const [];

  TotalWorkCostModel copyWith({
    String? hname,
    int? hid,
    int? hstar,
    String? hnumber,
    String? pname,
    int? wpid,
    String? date,
    int? wid,
    int? pcomplete,
    int? wcomplete,
    int? price,
    String? wcompletedAt,
    String? workrole,
    int? hdailyWage,
    String? hdefaultRole,
    String? workerRank,
    String? primarySpecialty,
    List<String>? specialties,
    List<SameDayPlaceRef>? sameDayPlaces,
  }) {
    return TotalWorkCostModel(
      hname: hname ?? this.hname,
      hid: hid ?? this.hid,
      hstar: hstar ?? this.hstar,
      hnumber: hnumber ?? this.hnumber,
      pname: pname ?? this.pname,
      wpid: wpid ?? this.wpid,
      date: date ?? this.date,
      wid: wid ?? this.wid,
      pcomplete: pcomplete ?? this.pcomplete,
      wcomplete: wcomplete ?? this.wcomplete,
      price: price ?? this.price,
      wcompletedAt: wcompletedAt ?? this.wcompletedAt,
      workrole: workrole ?? this.workrole,
      hdailyWage: hdailyWage ?? this.hdailyWage,
      hdefaultRole: hdefaultRole ?? this.hdefaultRole,
      workerRank: workerRank ?? this.workerRank,
      primarySpecialty: primarySpecialty ?? this.primarySpecialty,
      specialties: specialties ?? this.specialties,
      sameDayPlaces: sameDayPlaces ?? this.sameDayPlaces,
    );
  }

  bool involvesPlace(int pid) {
    if (wpid == pid) return true;
    for (final p in sameDayPlaces) {
      if (p.pid == pid) return true;
    }
    return false;
  }

  get dotDate => date.replaceAll('-', '.');
}

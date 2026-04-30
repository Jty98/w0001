import 'package:w0001/data/model/auth_models.dart';
import 'package:w0001/data/model/remote/super_admin_json.dart';

// ---------------------------------------------------------------------------
// 1) Users
// ---------------------------------------------------------------------------

class UserCreateBody {
  /// 슈퍼관리자 `POST /users` 직접 생성 용도. 공개 회원가입은 [signupRequestBody]·`/auth/signup`.
  const UserCreateBody({
    required this.uid,
    required this.upw,
    required this.uname,
    this.role,
  });

  final String uid;
  final String upw;
  final String uname;
  /// 서버가 허용할 때만 (선택).
  final String? role;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'uid': uid,
        'upw': upw,
        'uname': uname,
        if (role != null) 'role': role,
      };
}

// ---------------------------------------------------------------------------
// 2) Places
// ---------------------------------------------------------------------------

class PlaceRead {
  const PlaceRead({
    required this.pid,
    required this.pname,
    required this.pstart,
    required this.pend,
    required this.paddress,
    required this.pcomplete,
    required this.prevenue,
    required this.pcontracttotal,
    required this.pcontractdate,
  });

  final int pid;
  final String pname;
  final String pstart;
  final String pend;
  final String paddress;
  final int pcomplete;
  final int prevenue;
  final int pcontracttotal;
  final String pcontractdate;

  factory PlaceRead.fromJson(Map<String, dynamic> m) {
    return PlaceRead(
      pid: saInt(m['pid']) ?? 0,
      pname: saString(m['pname']) ?? '',
      pstart: saString(m['pstart']) ?? '',
      pend: saString(m['pend']) ?? '',
      paddress: saString(m['paddress']) ?? '',
      pcomplete: saInt(m['pcomplete']) ?? 0,
      prevenue: saInt(m['prevenue']) ?? 0,
      pcontracttotal: saInt(m['pcontracttotal'] ?? m['pcontractTotal']) ?? 0,
      pcontractdate: saString(m['pcontractdate'] ?? m['pcontractDate']) ?? '',
    );
  }
}

// ---------------------------------------------------------------------------
// 3) Humans
// ---------------------------------------------------------------------------

class HumanRead {
  const HumanRead({
    required this.hid,
    required this.hname,
    required this.hnumber,
    this.hmemo,
    required this.hdailywage,
    required this.hdefaultrole,
    required this.hstar,
    required this.hdelete,
  });

  final int hid;
  final String hname;
  final String hnumber;
  final String? hmemo;
  final int hdailywage;
  final String hdefaultrole;
  final int hstar;
  final int hdelete;

  factory HumanRead.fromJson(Map<String, dynamic> m) {
    return HumanRead(
      hid: saInt(m['hid']) ?? 0,
      hname: saString(m['hname']) ?? '',
      hnumber: saString(m['hnumber']) ?? '',
      hmemo: saString(m['hmemo']),
      hdailywage: saInt(m['hdailywage'] ?? m['hdailyWage']) ?? 0,
      hdefaultrole: saString(m['hdefaultrole'] ?? m['hdefaultRole']) ?? '',
      hstar: saInt(m['hstar']) ?? 0,
      hdelete: saInt(m['hdelete']) ?? 0,
    );
  }
}

// ---------------------------------------------------------------------------
// 4) Place work days
// ---------------------------------------------------------------------------

class PlaceWorkDayRead {
  const PlaceWorkDayRead({
    required this.pwdid,
    required this.pid,
    required this.hid,
    required this.workdate,
    required this.dailywage,
    required this.paid,
    required this.workrole,
  });

  final int pwdid;
  final int pid;
  final int hid;
  final String workdate;
  final int dailywage;
  final int paid;
  final String workrole;

  factory PlaceWorkDayRead.fromJson(Map<String, dynamic> m) {
    return PlaceWorkDayRead(
      pwdid: saInt(m['pwdid']) ?? 0,
      pid: saInt(m['pid']) ?? 0,
      hid: saInt(m['hid']) ?? 0,
      workdate: saString(m['workdate']) ?? '',
      dailywage: saInt(m['dailywage']) ?? 0,
      paid: saInt(m['paid']) ?? 0,
      workrole: saString(m['workrole']) ?? '',
    );
  }
}

// ---------------------------------------------------------------------------
// 5) Work costs
// ---------------------------------------------------------------------------

class WorkCostRead {
  const WorkCostRead({
    required this.wid,
    required this.whid,
    required this.wdate,
    required this.wprice,
    required this.wpid,
    required this.wcomplete,
    required this.wrole,
  });

  final int wid;
  final int whid;
  final String wdate;
  final int wprice;
  final int wpid;
  final int wcomplete;
  final String wrole;

  factory WorkCostRead.fromJson(Map<String, dynamic> m) {
    return WorkCostRead(
      wid: saInt(m['wid']) ?? 0,
      whid: saInt(m['whid']) ?? 0,
      wdate: saString(m['wdate']) ?? '',
      wprice: saInt(m['wprice']) ?? 0,
      wpid: saInt(m['wpid']) ?? 0,
      wcomplete: saInt(m['wcomplete']) ?? 0,
      wrole: saString(m['wrole']) ?? '',
    );
  }
}

// ---------------------------------------------------------------------------
// 6) Material costs
// ---------------------------------------------------------------------------

class MaterialCostRead {
  const MaterialCostRead({
    required this.mid,
    required this.mpid,
    required this.mname,
    required this.mdate,
    required this.mprice,
    required this.mcategory,
  });

  final int mid;
  final int mpid;
  final String mname;
  final String mdate;
  final int mprice;
  final String mcategory;

  factory MaterialCostRead.fromJson(Map<String, dynamic> m) {
    return MaterialCostRead(
      mid: saInt(m['mid']) ?? 0,
      mpid: saInt(m['mpid']) ?? 0,
      mname: saString(m['mname']) ?? '',
      mdate: saString(m['mdate']) ?? '',
      mprice: saInt(m['mprice']) ?? 0,
      mcategory: saString(m['mcategory']) ?? '',
    );
  }
}

// ---------------------------------------------------------------------------
// 7) Place revenues
// ---------------------------------------------------------------------------

class PlaceRevenueRead {
  const PlaceRevenueRead({
    required this.rid,
    required this.rpid,
    required this.rname,
    required this.rorder,
    required this.rprice,
    required this.rdate,
  });

  final int rid;
  final int rpid;
  final String rname;
  final int rorder;
  final int rprice;
  final String rdate;

  factory PlaceRevenueRead.fromJson(Map<String, dynamic> m) {
    return PlaceRevenueRead(
      rid: saInt(m['rid']) ?? 0,
      rpid: saInt(m['rpid']) ?? 0,
      rname: saString(m['rname']) ?? '',
      rorder: saInt(m['rorder']) ?? 0,
      rprice: saInt(m['rprice']) ?? 0,
      rdate: saString(m['rdate']) ?? '',
    );
  }
}

// ---------------------------------------------------------------------------
// 8) Place collections
// ---------------------------------------------------------------------------

class PlaceCollectionRead {
  const PlaceCollectionRead({
    required this.cid,
    required this.pid,
    required this.cdate,
    required this.ckind,
    required this.camount,
    this.cnote,
    this.revenueid,
  });

  final int cid;
  final int pid;
  final String cdate;
  final String ckind;
  final int camount;
  final String? cnote;
  final int? revenueid;

  factory PlaceCollectionRead.fromJson(Map<String, dynamic> m) {
    return PlaceCollectionRead(
      cid: saInt(m['cid']) ?? 0,
      pid: saInt(m['pid']) ?? 0,
      cdate: saString(m['cdate']) ?? '',
      ckind: saString(m['ckind']) ?? '',
      camount: saInt(m['camount']) ?? 0,
      cnote: saString(m['cnote']),
      revenueid: saInt(m['revenueid']),
    );
  }
}

// ---------------------------------------------------------------------------
// 9) Place worker recents
// ---------------------------------------------------------------------------

class PlaceWorkerRecentRead {
  const PlaceWorkerRecentRead({
    required this.pid,
    required this.hid,
    required this.lastusedms,
  });

  final int pid;
  final int hid;
  final int lastusedms;

  factory PlaceWorkerRecentRead.fromJson(Map<String, dynamic> m) {
    return PlaceWorkerRecentRead(
      pid: saInt(m['pid']) ?? 0,
      hid: saInt(m['hid']) ?? 0,
      lastusedms: saInt(m['lastusedms']) ?? 0,
    );
  }
}

// ---------------------------------------------------------------------------
// 10) Schedule memos
// ---------------------------------------------------------------------------

class ScheduleMemoRead {
  const ScheduleMemoRead({
    required this.sid,
    required this.taskdate,
    required this.tasktime,
    required this.title,
    required this.memo,
    required this.done,
    required this.alarmenabled,
    this.alarmoffsetminutes,
    required this.sortorder,
    required this.createdatms,
  });

  final int sid;
  final String taskdate;
  final String tasktime;
  final String title;
  final String memo;
  final bool done;
  final bool alarmenabled;
  final int? alarmoffsetminutes;
  final int sortorder;
  final int createdatms;

  factory ScheduleMemoRead.fromJson(Map<String, dynamic> m) {
    return ScheduleMemoRead(
      sid: saInt(m['sid']) ?? 0,
      taskdate: saString(m['taskdate']) ?? '',
      tasktime: saString(m['tasktime']) ?? '',
      title: saString(m['title']) ?? '',
      memo: saString(m['memo']) ?? '',
      done: saBool(m['done']) ?? false,
      alarmenabled: saBool(m['alarmenabled']) ?? false,
      alarmoffsetminutes: saInt(m['alarmoffsetminutes']),
      sortorder: saInt(m['sortorder']) ?? 0,
      createdatms: saInt(m['createdatms']) ?? 0,
    );
  }
}

// ---------------------------------------------------------------------------
// 11) Place photo groups
// ---------------------------------------------------------------------------

class PlacePhotoGroupRead {
  const PlacePhotoGroupRead({
    required this.pgid,
    required this.pid,
    required this.photodate,
    required this.phototype,
    required this.title,
    required this.sortorder,
    required this.createdatms,
  });

  final int pgid;
  final int pid;
  final String photodate;
  final String phototype;
  final String title;
  final int sortorder;
  final int createdatms;

  factory PlacePhotoGroupRead.fromJson(Map<String, dynamic> m) {
    return PlacePhotoGroupRead(
      pgid: saInt(m['pgid']) ?? 0,
      pid: saInt(m['pid']) ?? 0,
      photodate: saString(m['photodate']) ?? '',
      phototype: saString(m['phototype']) ?? '',
      title: saString(m['title']) ?? '',
      sortorder: saInt(m['sortorder']) ?? 0,
      createdatms: saInt(m['createdatms']) ?? 0,
    );
  }
}

// ---------------------------------------------------------------------------
// 12) Place photos
// ---------------------------------------------------------------------------

class PlacePhotoRead {
  const PlacePhotoRead({
    required this.phid,
    required this.pgid,
    required this.photourl,
    this.originalname,
    required this.sortorder,
    required this.createdatms,
  });

  final int phid;
  final int pgid;
  final String photourl;
  final String? originalname;
  final int sortorder;
  final int createdatms;

  factory PlacePhotoRead.fromJson(Map<String, dynamic> m) {
    final displayUrl = saString(m['display_url']);
    final originalUrl = saString(m['original_url']);
    final legacyPhoto = saString(m['photourl']) ?? '';
    final resolved = (displayUrl != null && displayUrl.isNotEmpty)
        ? displayUrl
        : (legacyPhoto.isNotEmpty
            ? legacyPhoto
            : (originalUrl ?? ''));
    return PlacePhotoRead(
      phid: saInt(m['phid']) ?? 0,
      pgid: saInt(m['pgid']) ?? 0,
      photourl: resolved,
      originalname: saString(m['originalname']),
      sortorder: saInt(m['sortorder']) ?? 0,
      createdatms: saInt(m['createdatms']) ?? 0,
    );
  }
}

// ---------------------------------------------------------------------------
// UserRead (목록) — [auth_models.UserRead]와 동일 필드, 서버 `role` 문자열
// ---------------------------------------------------------------------------

UserRead userReadFromJson(Map<String, dynamic> m) {
  return UserRead.fromJson(m);
}

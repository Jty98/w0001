import 'package:w0001/data/model/auth_models.dart';
import 'package:w0001/data/model/place_site_guide_model.dart';
import 'package:w0001/data/model/remote/super_admin_json.dart';
import 'package:w0001/data/model/worker_announcement_models.dart';
import 'package:w0001/util/career_input.dart';
import 'package:w0001/util/human_work_assignability.dart';
import 'package:w0001/util/place_photo/place_document_classify.dart';
import 'package:w0001/util/work_instruction_layers_merge.dart';
import 'package:w0001/util/worker_skills_parse.dart';

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
    this.siteGuideSummary,
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
  final PlaceSiteGuideSummary? siteGuideSummary;

  factory PlaceRead.fromJson(Map<String, dynamic> m) {
    PlaceSiteGuideSummary? summary;
    final raw = m['siteGuideSummary'];
    if (raw is Map) {
      summary = PlaceSiteGuideSummary.fromJson(Map<String, dynamic>.from(raw));
    }
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
      siteGuideSummary: summary,
    );
  }
}

// ---------------------------------------------------------------------------
// 3) Humans
// ---------------------------------------------------------------------------

class HumanRead {
  const HumanRead({
    required this.hid,
    required this.uid,
    required this.hname,
    required this.hnumber,
    this.hmemo,
    required this.hdailywage,
    required this.hdefaultrole,
    required this.hstar,
    required this.hdelete,
    this.primarySpecialty,
    this.specialties = const [],
    this.career = '',
    this.workerRank = '',
    this.canBePlaceMember = false,
    this.linkedUserName,
    this.hphone,
    this.linkedPhone,
    this.linkedUserIsActive = true,
    this.linkedUserApprovalStatus = UserApprovalStatus.approved,
  });

  final int hid;
  final String uid;
  final String hname;
  final String hnumber;
  final String? hmemo;
  final int hdailywage;
  final String hdefaultrole;
  final int hstar;
  final int hdelete;

  /// 작업자 프로필과 동기화된 대표 주특기 (`GET /humans` 등).
  final String? primarySpecialty;

  /// 주특기 외 가능 작업.
  final List<String> specialties;

  /// 워커 프로필 경력.
  final String career;

  /// 현장 역할 (`worker_rank`).
  final String workerRank;

  /// 현장 멤버로 추가 가능 여부 (app_user 계정 연결 여부)
  final bool canBePlaceMember;

  /// 연결된 app_user의 이름
  final String? linkedUserName;

  /// 외주 인력 연락처
  final String? hphone;

  /// 앱 계정 연결 전화번호 (마스킹)
  final String? linkedPhone;

  /// 연결된 app_user 활동 여부.
  final bool linkedUserIsActive;

  /// 연결된 app_user 승인 상태.
  final UserApprovalStatus linkedUserApprovalStatus;

  factory HumanRead.fromJson(Map<String, dynamic> m) {
    final primarySpecialty = parseWorkerPrimarySpecialtyFromMap(m);
    final hnumberRaw =
        m['hnumber'] ?? m['hnumber_masked'] ?? m['hnumberMasked'];
    final linkedAccount = parseLinkedUserAccountFromMap(m);
    return HumanRead(
      hid: saInt(m['hid']) ?? 0,
      uid: saString(m['uid'] ?? m['user_uid']) ?? '',
      hname: saString(m['hname']) ?? '',
      hnumber: saString(hnumberRaw) ?? '',
      hmemo: saString(m['hmemo']),
      hdailywage: saInt(m['hdailywage'] ?? m['hdailyWage']) ?? 0,
      hdefaultrole: saString(m['hdefaultrole'] ?? m['hdefaultRole']) ?? '',
      hstar: saInt(m['hstar']) ?? 0,
      hdelete: saInt(m['hdelete']) ?? 0,
      primarySpecialty: primarySpecialty,
      specialties: const [],
      career: CareerInputUtils.parseWireField(
        m['career'] ?? m['career_years'] ?? m['careerYears'],
      ),
      workerRank: pickWorkerRankFromMap(m),
      canBePlaceMember: m['can_be_place_member'] == true,
      linkedUserName: saString(m['linked_user_name']),
      hphone: saString(m['hphone']),
      linkedPhone: saString(m['linked_phone'] ?? m['linkedPhone']),
      linkedUserIsActive: linkedAccount.isActive,
      linkedUserApprovalStatus: linkedAccount.approval,
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
    this.instructionBlocks = const [],
    this.siteInstructionBlocks = const [],
    this.processInstructionBlocks = const [],
    this.individualInstructionBlocks = const [],
  });

  final int pwdid;
  final int pid;
  final int hid;
  final String workdate;
  final int dailywage;
  final int paid;
  final String workrole;

  /// 서버가 합성해 내려주는 병합본(레거시 서버는 여기만 존재).
  final List<WorkerAnnouncementBlock> instructionBlocks;

  /// 현장·일자 전체 작업지시.
  final List<WorkerAnnouncementBlock> siteInstructionBlocks;

  /// 이 행 [workrole]에 해당하는 공정별 작업지시.
  final List<WorkerAnnouncementBlock> processInstructionBlocks;

  /// 인력별 개별 작업지시 — [POST]/[PATCH] 시 이 레이어만 저장.
  final List<WorkerAnnouncementBlock> individualInstructionBlocks;

  /// 표시·FCM 미리보기용 — 레이어가 있으면 병합, 없으면 [instructionBlocks].
  List<WorkerAnnouncementBlock> get resolvedInstructionBlocks =>
      mergeWorkInstructionLayers(
        site: siteInstructionBlocks,
        process: processInstructionBlocks,
        individual: individualInstructionBlocks,
        mergedFallback: instructionBlocks,
      );

  factory PlaceWorkDayRead.fromJson(Map<String, dynamic> m) {
    final hasExplicitIndividual =
        m.containsKey('individual_instruction_blocks') ||
            m.containsKey('individualInstructionBlocks');
    final individual = hasExplicitIndividual
        ? parseIndividualInstructionBlocks(m)
        : const <WorkerAnnouncementBlock>[];
    final site = parseSiteInstructionBlocks(m);
    final process = parseProcessInstructionBlocks(m);
    final merged = parseWorkerAnnouncementBlockList(
      m['instruction_blocks'] ??
          m['work_instruction_blocks'] ??
          m['instructionBlocks'],
    );

    return PlaceWorkDayRead(
      pwdid: saInt(m['pwdid']) ?? 0,
      pid: saInt(m['pid']) ?? 0,
      hid: saInt(m['hid']) ?? 0,
      workdate: saString(m['workdate']) ?? '',
      dailywage: saInt(m['dailywage']) ?? 0,
      paid: saInt(m['paid']) ?? 0,
      workrole: saString(m['workrole']) ??
          saString(m['wrole']) ??
          saString(m['work_role']) ??
          '',
      instructionBlocks: merged,
      siteInstructionBlocks: site,
      processInstructionBlocks: process,
      individualInstructionBlocks: hasExplicitIndividual
          ? individual
          : (site.isEmpty && process.isEmpty ? merged : individual),
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
    this.wcompletedAt,
  });

  final int wid;
  final int whid;
  final String wdate;
  final int wprice;
  final int wpid;
  final int wcomplete;
  final String wrole;
  final String? wcompletedAt;

  factory WorkCostRead.fromJson(Map<String, dynamic> m) {
    return WorkCostRead(
      wid: saInt(m['wid']) ?? 0,
      whid: saInt(m['whid']) ?? 0,
      wdate: saString(m['wdate']) ?? '',
      wprice: saInt(m['wprice']) ?? 0,
      wpid: saInt(m['wpid']) ?? 0,
      wcomplete: saInt(m['wcomplete']) ?? 0,
      wrole: saString(m['wrole']) ?? '',
      wcompletedAt: saString(m['wcompleted_at']),
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
    this.sourceType = 'manual',
    this.workrole = '',
    this.pwdid,
    this.placePid,
    this.instructionBlocks = const [],
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

  /// `manual` | `assignment` (현장투입 자동 — 워커는 수정·삭제 불가)
  final String sourceType;

  /// 현장투입 행의 역할(목공·전기 등). 서버가 내려줄 때 표시.
  final String workrole;

  /// 원천 `place_work_days` PK (선택).
  final int? pwdid;

  /// 현장 ID (`pid` 등). 배정 목록 등에서 넘어오면 동료 목록 조회에 사용.
  final int? placePid;

  /// 배정 일정의 작업 내용(리치). 없으면 빈 목록.
  final List<WorkerAnnouncementBlock> instructionBlocks;

  bool get isAssignment => sourceType == 'assignment';

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
      sourceType:
          saString(m['source_type']) ?? saString(m['sourceType']) ?? 'manual',
      workrole: saString(m['workrole'] ?? m['work_role']) ?? '',
      pwdid: saInt(m['pwdid'] ?? m['pwd_id']),
      placePid: () {
        final v = saInt(m['pid'] ?? m['place_id'] ?? m['placePid']);
        return v != null && v > 0 ? v : null;
      }(),
      instructionBlocks: parseWorkerAnnouncementBlockList(
        m['instruction_blocks'] ??
            m['work_instruction_blocks'] ??
            m['instructionBlocks'],
      ),
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
    this.originalUrl,
    this.mediakind,
    required this.sortorder,
    required this.createdatms,
    this.createdByUid,
    this.title,
    this.uploaderDisplayName,
    this.memo,
    this.pid = 0,
    this.photodate = '',
    this.phototype = '',
  });

  final int phid;
  final int pgid;
  final String photourl;
  final String? originalname;
  final String? originalUrl;
  final String? mediakind;
  final int sortorder;
  final int createdatms;
  final String? createdByUid;

  /// 묶음(`pgid`)·일자별 작업 이름 — REST `POST /place-photos`의 `title` 등.
  final String? title;

  /// 서버가 내려주는 업로더 표시명 (`GET /users/{uid}` 없이 표시 가능).
  final String? uploaderDisplayName;

  /// 장당 현장 메모 (`PATCH /place-photos/{phid}`의 `memo` 등).
  final String? memo;
  final int pid;
  final String photodate;
  final String phototype;

  factory PlacePhotoRead.fromJson(Map<String, dynamic> m) {
    final displayUrl = saString(m['display_url']) ?? saString(m['displayUrl']);
    final originalUrl =
        saString(m['original_url']) ?? saString(m['originalUrl']);
    final legacyPhoto = saString(m['photourl']) ?? '';
    final resolved = (displayUrl != null && displayUrl.isNotEmpty)
        ? displayUrl
        : (legacyPhoto.isNotEmpty ? legacyPhoto : (originalUrl ?? ''));
    var originalname =
        saString(m['originalname']) ?? saString(m['original_name']);
    if (originalname == null || originalname.trim().isEmpty) {
      originalname = fileNameHintFromUrl(originalUrl);
    }
    final mediakind = saString(m['mediakind']) ?? saString(m['media_kind']);

    /// 서버 권장: 스냅샷 즉시 표시 → 없으면 `created_by_uname`(조인)·기타 별칭.
    final uploaderName = saString(m['created_by_uname_snapshot']) ??
        saString(m['createdByUnameSnapshot']) ??
        saString(m['created_by_uname']) ??
        saString(m['createdByUname']) ??
        saString(m['uploader_display_name']) ??
        saString(m['uploaderDisplayName']) ??
        saString(m['created_by_name']) ??
        saString(m['createdByName']) ??
        saString(m['uploader_name']) ??
        saString(m['author_name']) ??
        saString(m['author_display_name']) ??
        saString(m['authorDisplayName']);
    String? workTitle = saString(m['title']) ??
        saString(m['photo_title']) ??
        saString(m['photoTitle']) ??
        saString(m['work_title']) ??
        saString(m['workTitle']) ??
        saString(m['task_title']) ??
        saString(m['task_name']) ??
        saString(m['job_title']) ??
        saString(m['caption']) ??
        saString(m['label']) ??
        saString(m['group_title']);
    if (workTitle == null || workTitle.trim().isEmpty) {
      final pgg = m['place_photo_group'];
      if (pgg is Map) {
        final pg = Map<String, dynamic>.from(pgg);
        workTitle = saString(pg['title']) ??
            saString(pg['name']) ??
            saString(pg['work_title']);
      }
    }
    final memoVal = saString(m['memo']) ??
        saString(m['photo_memo']) ??
        saString(m['photoMemo']);
    return PlacePhotoRead(
      phid: saInt(m['phid']) ?? 0,
      pgid: saInt(m['pgid']) ?? 0,
      photourl: resolved,
      originalname: originalname,
      originalUrl: originalUrl,
      mediakind: mediakind,
      sortorder: saInt(m['sortorder']) ?? 0,
      createdatms: saInt(m['createdatms']) ?? 0,
      createdByUid:
          saString(m['created_by_uid']) ?? saString(m['createdByUid']),
      title: workTitle,
      uploaderDisplayName: uploaderName,
      memo: memoVal,
      pid: saInt(m['pid']) ?? 0,
      photodate: saString(m['photodate']) ?? saString(m['photo_date']) ?? '',
      phototype: saString(m['phototype']) ?? saString(m['photo_type']) ?? '',
    );
  }
}

// ---------------------------------------------------------------------------
// Worker management (admin: 메모·트러블 페어) — 응답 필드 유연 파싱
// ---------------------------------------------------------------------------

/// `GET/POST /worker-management/notes` — 서버 `WorkerNoteRead`.
class WorkerMgmtNoteRead {
  const WorkerMgmtNoteRead({
    this.noteId,
    this.workerHid,
    this.noteType = 'memo',
    this.rating,
    required this.memo,
    this.authorUid,
    this.createdAtMs,
  });

  final int? noteId;
  final int? workerHid;

  /// `memo` | `evaluation`
  final String noteType;
  final int? rating;
  final String memo;
  final String? authorUid;
  final int? createdAtMs;

  bool get hasMemoText => memo.trim().isNotEmpty;

  factory WorkerMgmtNoteRead.fromJson(Map<String, dynamic> m) {
    final noteId = saInt(m['note_id']) ??
        saInt(m['noteId']) ??
        saInt(m['id']) ??
        saInt(m['nid']);
    final workerHid = saInt(m['worker_hid']) ?? saInt(m['workerHid']);
    final rawType = saString(m['note_type']) ?? saString(m['noteType']);
    var noteType = (rawType ?? 'memo').trim().toLowerCase();
    if (noteType.isEmpty) noteType = 'memo';
    final rating = saInt(m['rating']);
    final memo = saString(m['memo']) ??
        saString(m['body']) ??
        saString(m['text']) ??
        saString(m['content']) ??
        '';
    final authorUid = saString(m['author_uid']) ?? saString(m['authorUid']);
    final ts = saInt(m['created_at_ms']) ??
        saInt(m['createdatms']) ??
        saInt(m['createdAtMs']) ??
        saInt(m['created_at']);
    return WorkerMgmtNoteRead(
      noteId: noteId,
      workerHid: workerHid,
      noteType: noteType.isEmpty ? 'memo' : noteType,
      rating: rating,
      memo: memo,
      authorUid: authorUid,
      createdAtMs: ts,
    );
  }
}

/// `GET/POST /worker-management/conflicts` — 서버 `WorkerConflictPairRead`.
class WorkerMgmtConflictRead {
  const WorkerMgmtConflictRead({
    this.pairId,
    required this.workerAHid,
    required this.workerBHid,
    this.severity = 2,
    this.note = '',
    this.active = true,
    this.createdByUid,
  });

  final int? pairId;
  final int workerAHid;
  final int workerBHid;
  final int severity;
  final String note;
  final bool active;
  final String? createdByUid;

  int? partnerHid(int selfHid) {
    if (workerAHid == selfHid) {
      return workerBHid == selfHid ? null : workerBHid;
    }
    if (workerBHid == selfHid) return workerAHid;
    return null;
  }

  bool involves(int hid) => workerAHid == hid || workerBHid == hid;

  factory WorkerMgmtConflictRead.fromJson(Map<String, dynamic> m) {
    int? pickHid(Iterable<String> keys) {
      for (final k in keys) {
        final v = saInt(m[k]);
        if (v != null && v > 0) return v;
      }
      return null;
    }

    final a = pickHid(['worker_a_hid', 'workerAHid', 'hid_a', 'hidA']);
    final b = pickHid(['worker_b_hid', 'workerBHid', 'hid_b', 'hidB']);
    final pairId = saInt(m['pair_id']) ??
        saInt(m['pairId']) ??
        saInt(m['id']) ??
        saInt(m['cid']);
    final severity = saInt(m['severity']) ?? 2;
    final note = saString(m['note']) ?? '';
    final createdByUid =
        saString(m['created_by_uid']) ?? saString(m['createdByUid']);
    final activeRaw = m['active'] ?? m['is_active'] ?? m['isActive'];
    var active = true;
    if (activeRaw is bool) {
      active = activeRaw;
    } else if (activeRaw is num) {
      active = activeRaw != 0;
    } else if (activeRaw is String) {
      final s = activeRaw.toLowerCase();
      active = s == 'true' || s == '1';
    }
    return WorkerMgmtConflictRead(
      pairId: pairId,
      workerAHid: a ?? 0,
      workerBHid: b ?? 0,
      severity: severity,
      note: note,
      active: active,
      createdByUid: createdByUid,
    );
  }

  bool get isValid =>
      workerAHid > 0 && workerBHid > 0 && workerAHid != workerBHid;
}

// ---------------------------------------------------------------------------
// UserRead (목록) — [auth_models.UserRead]와 동일 필드, 서버 `role` 문자열
// ---------------------------------------------------------------------------

UserRead userReadFromJson(Map<String, dynamic> m) {
  return UserRead.fromJson(m);
}

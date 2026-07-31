/// Human Table Default Model
import 'package:w0001/data/model/auth_models.dart';
import 'package:w0001/util/career_input.dart';
import 'package:w0001/util/human_work_assignability.dart';

class HumanModel {
  final int? hid;
  final String? uid;
  final String hname;
  final String hnumber;
  final String? hmemo;
  final int hdailyWage;

  /// 인건비 탭 등에서 기본으로 쓸 역할(전기·목수 등 또는 직접 입력 문자열)
  final String hdefaultRole;

  /// 워커 프로필 대표 주특기 (서버 [humans] 응답).
  final String? primarySpecialty;

  /// 워커 프로필 추가 가능 작업. (서버 스키마 제거 — 항상 빈 목록)
  final List<String> specialties;

  /// 워커 프로필 경력 (`GET /humans` 동기화).
  final String career;

  /// 현장 역할 (`worker_rank` — 조공·준기공·기공·반장·감리).
  final String workerRank;

  /// 현장 멤버로 추가 가능 여부 (app_user 계정 연결 여부)
  final bool canBePlaceMember;

  /// 연결된 app_user의 이름
  final String? linkedUserName;

  /// 외주 인력 연락처 (user_uid 없을 때 사용)
  final String? hphone;

  /// 앱 계정 연결된 전화번호 (user_uid 있을 때 사용, 마스킹됨)
  final String? linkedPhone;

  /// 연결된 app_user 활동 여부 (`is_active`). 비회원이면 true.
  final bool linkedUserIsActive;

  /// 연결된 app_user 승인 상태. 비회원이면 approved.
  final UserApprovalStatus linkedUserApprovalStatus;

  int hstar;
  int hdelete;

  HumanModel({
    this.hid,
    this.uid,
    required this.hname,
    required this.hnumber,
    this.hmemo,
    this.hdailyWage = 0,
    this.hdefaultRole = '',
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
    required this.hstar,
    required this.hdelete,
  });

  HumanModel.fromMap(Map<String, dynamic> res)
      : hid = res['hid'],
        uid = res['uid'] as String? ?? res['user_uid'] as String?,
        hname = res['hname'],
        hnumber = res['hnumber'],
        hmemo = res['hmemo'],
        hdailyWage = (res['hdailyWage'] as int?) ?? 0,
        hdefaultRole = (res['hdefaultRole'] as String?) ?? '',
        primarySpecialty = res['primarySpecialty'] as String?,
        specialties = const [],
        career = CareerInputUtils.parseWireField(
          res['career'] ?? res['career_years'] ?? res['careerYears'],
        ),
        workerRank = (res['workerRank'] as String?)?.trim() ??
            (res['worker_rank'] as String?)?.trim() ??
            '',
        canBePlaceMember = res['can_be_place_member'] == true,
        linkedUserName = res['linked_user_name'] as String?,
        hphone = res['hphone'] as String?,
        linkedPhone = res['linked_phone'] as String?,
        linkedUserIsActive = parseLinkedUserAccountFromMap(res).isActive,
        linkedUserApprovalStatus = parseLinkedUserAccountFromMap(res).approval,
        hstar = res['hstar'],
        hdelete = res['hdelete'];
}

/// 앱 회원가입 계정과 연결된 인력 — 인력관리에서 삭제 불가(회원관리에서 처리).
bool humanIsLinkedAppMember(HumanModel human) {
  if (human.canBePlaceMember) return true;
  final uid = human.uid?.trim();
  return uid != null && uid.isNotEmpty;
}

/// 앱 계정(uid) 없이 직접 등록한 인력 — 삭제 가능.
bool humanIsNonMember(HumanModel human) {
  final uid = human.uid?.trim();
  return uid == null || uid.isEmpty;
}

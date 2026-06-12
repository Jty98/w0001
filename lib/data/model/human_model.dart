/// Human Table Default Model
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

  /// 워커 프로필 추가 가능 작업.
  final List<String> specialties;

  /// 워커 프로필 경력 (`GET /humans` 동기화).
  final String career;
  
  /// 현장 멤버로 추가 가능 여부 (app_user 계정 연결 여부)
  final bool canBePlaceMember;
  
  /// 연결된 app_user의 이름
  final String? linkedUserName;
  
  /// 외주 인력 연락처 (user_uid 없을 때 사용)
  final String? hphone;
  
  /// 앱 계정 연결된 전화번호 (user_uid 있을 때 사용, 마스킹됨)
  final String? linkedPhone;

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
    this.canBePlaceMember = false,
    this.linkedUserName,
    this.hphone,
    this.linkedPhone,
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
        specialties = (res['specialties'] as List<dynamic>?)
                ?.map((e) => '$e'.trim())
                .where((e) => e.isNotEmpty)
                .toList() ??
            const [],
        career = (res['career'] as String?)?.trim() ?? '',
        canBePlaceMember = res['can_be_place_member'] == true,
        linkedUserName = res['linked_user_name'] as String?,
        hphone = res['hphone'] as String?,
        linkedPhone = res['linked_phone'] as String?,
        hstar = res['hstar'],
        hdelete = res['hdelete'];
}

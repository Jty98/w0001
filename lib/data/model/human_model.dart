/// Human Table Default Model
class HumanModel {
  final int? hid;
  final String hname;
  final String hnumber;
  final String? hmemo;
  final int hdailyWage;
  /// 인건비 탭 등에서 기본으로 쓸 역할(전기·목수 등 또는 직접 입력 문자열)
  final String hdefaultRole;
  int hstar;
  int hdelete;

  HumanModel({
    this.hid,
    required this.hname,
    required this.hnumber,
    this.hmemo,
    this.hdailyWage = 0,
    this.hdefaultRole = '',
    required this.hstar,
    required this.hdelete,
  });

  HumanModel.fromMap(Map<String, dynamic> res)
      : hid = res['hid'],
        hname = res['hname'],
        hnumber = res['hnumber'],
        hmemo = res['hmemo'],
        hdailyWage = (res['hdailyWage'] as int?) ?? 0,
        hdefaultRole = (res['hdefaultRole'] as String?) ?? '',
        hstar = res['hstar'],
        hdelete = res['hdelete'];
}


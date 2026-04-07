/// Human Table Default Model
class HumanModel {
  final int? hid;
  final String hname;
  final String hnumber;
  final String? hmemo;
  final int hdailyWage;
  int hstar;
  int hdelete;

  HumanModel({
    this.hid,
    required this.hname,
    required this.hnumber,
    this.hmemo,
    this.hdailyWage = 0,
    required this.hstar,
    required this.hdelete,
  });

  HumanModel.fromMap(Map<String, dynamic> res)
      : hid = res['hid'],
        hname = res['hname'],
        hnumber = res['hnumber'],
        hmemo = res['hmemo'],
        hdailyWage = (res['hdailyWage'] as int?) ?? 0,
        hstar = res['hstar'],
        hdelete = res['hdelete'];
}


/// Human Table Default Model
class HumanModel {
  final int? hid;
  final String hname;
  final String hnumber;
  final String? hmemo;
  int hstar;
  int hdelete;

  HumanModel({
    this.hid,
    required this.hname,
    required this.hnumber,
    this.hmemo,
    required this.hstar,
    required this.hdelete,
  });

  HumanModel.fromMap(Map<String, dynamic> res)
      : hid = res['hid'],
        hname = res['hname'],
        hnumber = res['hnumber'],
        hmemo = res['hmemo'],
        hstar = res['hstar'],
        hdelete = res['hdelete'];
}


class TotalWorkCostModel {
  final String hname;
  final int hid;
  final int hstar;
  final String hnumber;
  final String pname;
  final String date;
  final int wid;
  final int pcomplete;
  final int wcomplete;
  final int price;

  TotalWorkCostModel({
    required this.hname,
    required this.hid,
    required this.hstar,
    required this.hnumber,
    required this.pname,
    required this.wid,
    required this.pcomplete,
    required this.wcomplete,
    required this.date,
    required this.price,
  });

  TotalWorkCostModel.fromMap(Map<String, dynamic> res)
      : hname = res['이름'],
        hid = res['hid'],
        hnumber = res['주민등록번호'],
        hstar = res['hstar'],
        pname = res['현장'],
        wid = res['wid'],
        pcomplete = res['pcomplete'],
        wcomplete = res['wcomplete'],
        date = res['날짜'],
        price = res['금액'];

  get dotDate => date.replaceAll('-', '.');
}

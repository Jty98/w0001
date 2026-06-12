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

  /// 해당 일 작업지시·공정표 연동 공정명 (`place-work-days.workrole` 우선).
  final String workrole;

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
        workrole = (res['workrole'] ?? res['wrole'] ?? '').toString();

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
    );
  }

  get dotDate => date.replaceAll('-', '.');
}

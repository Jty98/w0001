class WorkCostModel {
  final String? hname;
  final String? pname;
  final int? whid;
  final int? wid;
  final String wdate;
  final int wcomplete;
  final int wprice;
  final int wpid;
  /// 현장 투입 역할(전기·목수 등)
  final String wrole;

  WorkCostModel({
    this.hname,
    this.pname,
    this.whid,
    this.wid,
    required this.wcomplete,
    required this.wdate,
    required this.wprice,
    required this.wpid,
    this.wrole = '',
  });

  WorkCostModel.fromMap(Map<String, dynamic> res)
      : pname = '',
        hname = '',
        wid = res['wid'],
        whid = res['whid'],
        wcomplete = res['wcomplete'],
        wdate = res['wdate'],
        wprice = res['wprice'],
        wpid = res['wpid'],
        wrole = res['wrole'] as String? ?? '';

  WorkCostModel copyWith({
    String? hname,
    String? pname,
    int? whid,
    int? wid,
    int? wcomplete,
    String? wdate,
    int? wprice,
    int? wpid,
    String? wrole,
  }) {
    return WorkCostModel(
      hname: hname ?? this.hname,
      pname: pname ?? this.pname,
      whid: whid ?? this.whid,
      wid: wid ?? this.wid,
      wcomplete: wcomplete ?? this.wcomplete,
      wdate: wdate ?? this.wdate,
      wprice: wprice ?? this.wprice,
      wpid: wpid ?? this.wpid,
      wrole: wrole ?? this.wrole,
    );
  }
}

class WorkCost2Model {
  final String wdate;
  final int wprice;
  final int wcomplete;
  final String pname;

  WorkCost2Model(
      {required this.wdate, required this.wprice, required this.pname, required this.wcomplete});

  WorkCost2Model.fromMap(Map<String, dynamic> res)
      : wdate = res['wdate'],
        wprice = res['wprice'],
        wcomplete = res['wcomplete'],
        pname = res['pname'];
}

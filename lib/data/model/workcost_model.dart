class WorkCostModel {
  final String? hname;
  final String? pname;
  final int? whid;
  final int? wid;
  final String wdate;
  final int wcomplete;
  final int wprice;
  final int wpid;

  WorkCostModel(
      {this.hname,
      this.pname,
      this.whid,
      this.wid,
      required this.wcomplete,
      required this.wdate,
      required this.wprice,
      required this.wpid});

  WorkCostModel.fromMap(Map<String, dynamic> res)
      : pname = '',
        hname = '',
        wid = res['wid'],
        whid = res['whid'],
        wcomplete = res['wcomplete'],
        wdate = res['wdate'],
        wprice = res['wprice'],
        wpid = res['wpid'];
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

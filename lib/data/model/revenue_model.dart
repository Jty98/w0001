class RevenueModel {
  final int rid;
  final int rpid;
  final String rname;
  final int rprice;
  final int rorder;

  RevenueModel({
    required this.rid,
    required this.rpid,
    required this.rname,
    required this.rprice,
    required this.rorder,
  });

  // fromMap 메서드
  factory RevenueModel.fromMap(Map<String, dynamic> map) {
    return RevenueModel(
      rid: map['rid'],
      rpid: map['rpid'],
      rname: map['rname'],
      rprice: map['rprice'],
      rorder: map['rorder'],
    );
  }
}

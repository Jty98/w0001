/// MaterialCost Table Default Model
class MaterialCostModel {
  final String? pname;
  final int? mid;
  final int? mpid;
  final String mname;
  final String mdate;
  final String mcategory;
  final int mprice;

  MaterialCostModel(
      {this.pname,
      this.mid,
      this.mpid,
      required this.mname,
      required this.mdate,
      required this.mcategory,
      required this.mprice});

  MaterialCostModel.fromMap(Map<String, dynamic> res)
      : pname = '',
        mid = res['mid'],
        mpid = res['mpid'],
        mname = res['mname'],
        mdate = res['mdate'],
        mcategory = res['mcategory'],
        mprice = res['mprice'];
}

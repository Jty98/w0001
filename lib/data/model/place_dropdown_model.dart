/// only for dropdownSearch
class PlaceDropDownModel {
  final String pname;
  final int pid;
  
  PlaceDropDownModel({
    required this.pname,
    required this.pid,
  });

  PlaceDropDownModel.fromMap(Map<String, dynamic> res)
      : pname = res['pname'],
        pid = res['pid'];
}

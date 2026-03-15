/// Place Table Default Model
class PlaceModel {
  final int? pid;
  final String pname;
  final String pstart;
  final String pend;
  int pcomplete;
  final int prevenue;

  PlaceModel({
    this.pid,
    required this.pname,
    required this.pcomplete,
    required this.pstart,
    required this.pend,
    required this.prevenue
  });

  PlaceModel.fromMap(Map<String, dynamic> res)
      : pid = res['pid'],
        pname = res['pname'], // null 대신 빈 문자열 할당
        pcomplete = res['pcomplete'] ?? 0,
        pstart = res['pstart'],
        pend = res['pend'],
        prevenue = res['prevenue'];
}


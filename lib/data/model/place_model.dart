/// Place Table Default Model
class PlaceModel {
  final int? pid;
  final String pname;
  final String pstart;
  final String pend;
  final String paddress;
  int pcomplete;
  final int prevenue;
  final int pcontractTotal;
  /// 공사금액 확정일 yyyy-MM-dd. 비어 있으면 대시보드·집계에서 `pstart` 앞 10자를 사용합니다.
  final String pcontractDate;

  PlaceModel({
    this.pid,
    required this.pname,
    required this.pcomplete,
    required this.pstart,
    required this.pend,
    this.paddress = '',
    required this.prevenue,
    this.pcontractTotal = 0,
    this.pcontractDate = '',
  });

  PlaceModel.fromMap(Map<String, dynamic> res)
      : pid = res['pid'],
        pname = res['pname'], // null 대신 빈 문자열 할당
        pcomplete = res['pcomplete'] ?? 0,
        pstart = res['pstart'],
        pend = res['pend'],
        paddress = res['paddress'] ?? '',
        prevenue = res['prevenue'],
        pcontractTotal = res['pcontractTotal'] ?? 0,
        pcontractDate = res['pcontractDate'] ?? '';
}


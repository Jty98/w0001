import 'package:w0001/util/funtions.dart';

/// TotalCost Model (WorkCost + MaterialCost)
class TotalCostModel {
  final String pname;
  final int pcomplete;
  final String name;
  final String date;
  final int price;
  final int id;
  final String category;
  final int wcomplete;
  final String? wcompletedAt;

  /// 인건비(`category == 'w'`)일 때만 채움 — 삭제·작업지시 연동용.
  final int? whid;
  final int? wpid;
  final String workrole;

  TotalCostModel({
    required this.pname,
    required this.pcomplete,
    required this.name,
    required this.date,
    required this.price,
    required this.category,
    required this.id,
    required this.wcomplete,
    this.wcompletedAt,
    this.whid,
    this.wpid,
    this.workrole = '',
  });

  TotalCostModel.fromMap(Map<String, dynamic> res)
      : pname = res['pname'],
        pcomplete = res['pcomplete'],
        name = res['name'],
        date = res['date'],
        price = res['price'],
        id = res['id'],
        wcomplete = res['wcomplete'],
        wcompletedAt = res['wcompleted_at'] as String?,
        category = res['category'] ?? '',
        whid = res['whid'] as int?,
        wpid = res['wpid'] as int?,
        workrole = (res['workrole'] ?? res['wrole'] ?? '').toString();

  String get getDay => formatDateTimeToStringByDot(DateTime.parse(date));
  DateTime get getDateTime => DateTime.parse(date);
}

import 'package:w0001/domain/place_archive.dart';
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
      : pcomplete = _asInt(res['pcomplete']) ?? 0,
        pname = formatPlaceDisplayName(
          '${res['pname'] ?? ''}',
          pcomplete: _asInt(res['pcomplete']) ?? 0,
        ),
        name = '${res['name'] ?? ''}',
        date = '${res['date'] ?? ''}',
        price = _asInt(res['price']) ?? 0,
        id = _asInt(res['id']) ?? 0,
        wcomplete = _asInt(res['wcomplete']) ?? -1,
        wcompletedAt = _optionalString(
          res['wcompletedAt'] ?? res['wcompleted_at'],
        ),
        category = '${res['category'] ?? ''}',
        whid = _asInt(res['whid']),
        wpid = _asInt(res['wpid']),
        workrole = (res['workrole'] ?? res['wrole'] ?? '').toString();

  static int? _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v.trim());
    return null;
  }

  static String? _optionalString(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  String get getDay => formatDateTimeToStringByDot(DateTime.parse(date));
  DateTime get getDateTime => DateTime.parse(date);
}

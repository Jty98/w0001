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

  TotalCostModel({
    required this.pname, 
    required this.pcomplete,
    required this.name, 
    required this.date, 
    required this.price,
    required this.category,
    required this.id,
    required this.wcomplete,
    });

  TotalCostModel.fromMap(Map<String, dynamic> res) 
        : pname = res['pname'],
        pcomplete = res['pcomplete'],
        name = res['name'],
        date = res['date'],
        price = res['price'],
        id = res['id'],
        wcomplete = res['wcomplete'],
        category = res['category'] ?? '';


  String get getDay => formatDateTimeToStringByDot(DateTime.parse(date));
  DateTime get getDateTime => DateTime.parse(date);
  
}
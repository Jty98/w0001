import 'package:w0001/data/datasources/local/dbhelper.dart';
import 'package:w0001/data/model/total_cost_model.dart';

/// 캘린더 관련 로컬 데이터소스 (SQLite)
abstract class CalendarLocalDataSource {
  Future<Map<DateTime, List<String>>> getAllEvents();
  Future<List<TotalCostModel>> getTotalCostsByDate(DateTime dateTime);
}

class CalendarLocalDataSourceImpl implements CalendarLocalDataSource {
  CalendarLocalDataSourceImpl(this._dbHelper);

  final DbHelper _dbHelper;

  @override
  Future<Map<DateTime, List<String>>> getAllEvents() {
    return _dbHelper.getAllEvents();
  }

  @override
  Future<List<TotalCostModel>> getTotalCostsByDate(DateTime dateTime) {
    return _dbHelper.getTotalCostsByDate(dateTime);
  }
}


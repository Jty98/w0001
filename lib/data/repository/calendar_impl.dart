import 'package:w0001/data/datasources/local/calendar_local_data_source.dart';
import 'package:w0001/domain/repository/calendar_abst.dart';
import 'package:w0001/data/model/total_cost_model.dart';

class CalendarRepositoryImpl implements CalendarRepository {
  CalendarRepositoryImpl(this._localDataSource);

  final CalendarLocalDataSource _localDataSource;

  @override
  Future<Map<DateTime, List<String>>> getAllEvents() {
    return _localDataSource.getAllEvents();
  }

  @override
  Future<List<TotalCostModel>> getTotalCostsByDate(DateTime dateTime) {
    return _localDataSource.getTotalCostsByDate(dateTime);
  }
}


import 'package:w0001/data/datasources/remote/list_query.dart';
import 'package:w0001/data/model/calendar_day_cost_totals.dart';
import 'package:w0001/data/model/dashboard_calendar_workforce_dots.dart';
import 'package:w0001/data/model/total_cost_model.dart';
import 'package:w0001/domain/repository/calendar_abst.dart';

class CalendarUseCase {
  CalendarUseCase(this._repository);

  final CalendarRepository _repository;

  Future<DashboardCalendarWorkforceDots> getCalendarMarkers({
    required String from,
    required String to,
  }) {
    return _repository.getCalendarMarkers(from: from, to: to);
  }

  Future<List<TotalCostModel>> getTotalCostsByDate(DateTime dateTime) {
    return _repository.getTotalCostsByDate(dateTime);
  }

  Future<CalendarDayCostPageResult> getTotalCostsByDatePage(
    DateTime dateTime, {
    String? cursor,
    int limit = kListPageSize,
  }) {
    return _repository.getTotalCostsByDatePage(
      dateTime,
      cursor: cursor,
      limit: limit,
    );
  }
}

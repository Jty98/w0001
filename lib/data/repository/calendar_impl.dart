import 'package:w0001/data/datasources/remote/list_query.dart';
import 'package:w0001/data/model/calendar_day_cost_totals.dart';
import 'package:w0001/data/model/dashboard_calendar_workforce_dots.dart';
import 'package:w0001/data/model/total_cost_model.dart';
import 'package:w0001/domain/repository/calendar_abst.dart';
import 'package:w0001/domain/repository/dashboard_remote_abst.dart';

/// 캘린더는 집계·스코프 조회가 있는 `/dashboard/calendar-*` 만 사용한다.
class CalendarRepositoryImpl implements CalendarRepository {
  CalendarRepositoryImpl(this._dashboard);

  final DashboardRemoteRepository _dashboard;

  @override
  Future<DashboardCalendarWorkforceDots> getCalendarMarkers({
    required String from,
    required String to,
  }) async {
    final unified = await _dashboard.calendarMarkers(from: from, to: to);
    if (unified != null) return unified;
    return _dashboard.calendarWorkforceDots(from: from, to: to);
  }

  @override
  Future<List<TotalCostModel>> getTotalCostsByDate(DateTime dateTime) async {
    final page = await getTotalCostsByDatePage(dateTime);
    return page.items;
  }

  @override
  Future<CalendarDayCostPageResult> getTotalCostsByDatePage(
    DateTime dateTime, {
    String? cursor,
    int limit = kListPageSize,
  }) {
    final dayQ = listQueryForSingleDay(dateTime);
    return _dashboard.calendarDayCostsPage(
      from: dayQ.from!,
      to: dayQ.to!,
      limit: limit,
      cursor: cursor,
    );
  }
}

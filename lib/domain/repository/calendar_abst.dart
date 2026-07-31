import 'package:w0001/data/datasources/remote/list_query.dart';
import 'package:w0001/data/model/calendar_day_cost_totals.dart';
import 'package:w0001/data/model/dashboard_calendar_workforce_dots.dart';
import 'package:w0001/data/model/total_cost_model.dart';

/// 캘린더 도메인 저장소 추상
abstract class CalendarRepository {
  /// 경량 일별 마커. `/dashboard/calendar-markers` 우선, 없으면 workforce-dots.
  Future<DashboardCalendarWorkforceDots> getCalendarMarkers({
    required String from,
    required String to,
  });

  Future<List<TotalCostModel>> getTotalCostsByDate(DateTime dateTime);

  Future<CalendarDayCostPageResult> getTotalCostsByDatePage(
    DateTime dateTime, {
    String? cursor,
    int limit = kListPageSize,
  });
}

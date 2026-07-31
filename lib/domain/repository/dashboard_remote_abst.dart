import 'package:w0001/data/datasources/remote/list_query.dart';
import 'package:w0001/data/model/calendar_day_cost_totals.dart';
import 'package:w0001/data/model/dashboard_calendar_workforce_dots.dart';
import 'package:w0001/data/model/dashboard_models.dart';
import 'package:w0001/data/model/monthly_summary_model.dart';
import 'package:w0001/data/model/paged_result.dart';
import 'package:w0001/data/model/place_info_model.dart';
import 'package:w0001/data/model/total_cost_model.dart';

/// 서버 `/dashboard/*` (Bearer + super_admin) 집계.
abstract class DashboardRemoteRepository {
  Future<DashboardKpiSnapshot> kpi({required int year, required int month});

  Future<List<YearlyDashboardPoint>> yearly({
    required int fromYear,
    required int toYear,
  });

  Future<List<DashboardPlaceRow>> placesRows();

  Future<List<MonthlySummaryModel>> monthly({required int year});

  Future<DashboardDataBundle> loadBundle({
    required int selectedYear,
    int? kpiYear,
    int? kpiMonth,
  });

  /// 캘린더 점(마커)용: 날짜 → 현장명 목록.
  Future<Map<DateTime, List<String>>> calendarEvents({
    String? from,
    String? to,
  });

  /// 캘린더 하단 도트: 공정·투입·비용 플래그 (`pid` 없이 기간만).
  Future<DashboardCalendarWorkforceDots> calendarWorkforceDots({
    required String from,
    required String to,
  });

  /// 경량 일별 마커. 미구현 시 null — [calendarWorkforceDots] 폴백.
  Future<DashboardCalendarWorkforceDots?> calendarMarkers({
    required String from,
    required String to,
  });

  /// 캘린더 선택 일자 비용 목록 (인건비·자재비 join, UI 바로 사용).
  Future<List<TotalCostModel>> calendarDayCosts({
    required String from,
    required String to,
  });

  Future<CalendarDayCostPageResult> calendarDayCostsPage({
    required String from,
    required String to,
    int limit = kListPageSize,
    String? cursor,
  });

  /// [getAllPlaces] SQL 대응: 현장 + 자재·인건비 등 합계.
  Future<List<PlaceInfoModel>> placesInfo();

  Future<PagedResult<PlaceInfoModel>> placesInfoPage(ListQuery query);
}

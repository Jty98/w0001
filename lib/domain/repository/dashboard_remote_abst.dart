import 'package:w0001/data/model/dashboard_models.dart';
import 'package:w0001/data/model/monthly_summary_model.dart';
import 'package:w0001/data/model/place_info_model.dart';

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
  Future<Map<DateTime, List<String>>> calendarEvents();

  /// [getAllPlaces] SQL 대응: 현장 + 자재·인건비 등 합계.
  Future<List<PlaceInfoModel>> placesInfo();
}

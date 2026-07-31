import 'package:w0001/data/datasources/remote/list_query.dart';
import 'package:w0001/data/datasources/remote/dashboard/dashboard_api.dart';
import 'package:w0001/data/model/calendar_day_cost_totals.dart';
import 'package:w0001/data/model/dashboard_calendar_workforce_dots.dart';
import 'package:w0001/data/model/dashboard_models.dart';
import 'package:w0001/data/model/monthly_summary_model.dart';
import 'package:w0001/data/model/paged_result.dart';
import 'package:w0001/data/model/place_info_model.dart';
import 'package:w0001/data/model/total_cost_model.dart';
import 'package:w0001/domain/repository/dashboard_remote_abst.dart';

class DashboardRemoteRepositoryImpl implements DashboardRemoteRepository {
  DashboardRemoteRepositoryImpl(this._api);

  final DashboardRemoteApi _api;

  @override
  Future<DashboardKpiSnapshot> kpi(
      {required int year, required int month}) async {
    final j = await _api.kpi(year: year, month: month);
    return DashboardKpiSnapshot.fromJson(_unwrapKpiMap(j));
  }

  @override
  Future<List<YearlyDashboardPoint>> yearly({
    required int fromYear,
    required int toYear,
  }) async {
    final rows = await _api.yearly(fromYear: fromYear, toYear: toYear);
    return rows.map(YearlyDashboardPoint.fromJson).toList();
  }

  @override
  Future<List<DashboardPlaceRow>> placesRows() async {
    final rows = await _api.placesRows();
    return rows.map(DashboardPlaceRow.fromJson).toList();
  }

  @override
  Future<List<MonthlySummaryModel>> monthly({required int year}) async {
    final rows = await _api.monthly(year: year);
    return rows.map(MonthlySummaryModel.fromJson).toList();
  }

  @override
  Future<DashboardDataBundle> loadBundle({
    required int selectedYear,
    int? kpiYear,
    int? kpiMonth,
  }) async {
    final raw = await _api.bundle(
      selectedYear: selectedYear,
      kpiYear: kpiYear,
      kpiMonth: kpiMonth,
      includePlaces: true,
    );
    return DashboardDataBundle.fromJson(_unwrapBundleMap(raw));
  }

  @override
  Future<Map<DateTime, List<String>>> calendarEvents({
    String? from,
    String? to,
  }) {
    return _api.calendarEvents(from: from, to: to);
  }

  @override
  Future<DashboardCalendarWorkforceDots> calendarWorkforceDots({
    required String from,
    required String to,
  }) {
    return _api.calendarWorkforceDots(from: from, to: to);
  }

  @override
  Future<DashboardCalendarWorkforceDots?> calendarMarkers({
    required String from,
    required String to,
  }) {
    return _api.calendarMarkers(from: from, to: to);
  }

  @override
  Future<List<TotalCostModel>> calendarDayCosts({
    required String from,
    required String to,
  }) {
    return _api.calendarDayCosts(from: from, to: to);
  }

  @override
  Future<CalendarDayCostPageResult> calendarDayCostsPage({
    required String from,
    required String to,
    int limit = kListPageSize,
    String? cursor,
  }) {
    return _api.calendarDayCostsPage(
      from: from,
      to: to,
      limit: limit,
      cursor: cursor,
    );
  }

  @override
  Future<List<PlaceInfoModel>> placesInfo() async {
    final rows = await _api.placesInfoAll(const ListQuery());
    return rows.map(PlaceInfoModel.fromJson).toList();
  }

  @override
  Future<PagedResult<PlaceInfoModel>> placesInfoPage(ListQuery query) async {
    final raw = await _api.placesInfoPage(query);
    return PagedResult(
      items: raw.items.map(PlaceInfoModel.fromJson).toList(),
      nextCursor: raw.nextCursor,
      hasMore: raw.hasMore,
      totalCount: raw.totalCount,
    );
  }
}

Map<String, dynamic> _unwrapKpiMap(Map<String, dynamic> raw) {
  if (raw.containsKey('year') && raw.containsKey('monthlyContract')) {
    return raw;
  }
  final inner = raw['kpi'] ?? raw['data'];
  if (inner is Map) return Map<String, dynamic>.from(inner);
  return raw;
}

Map<String, dynamic> _unwrapBundleMap(Map<String, dynamic> raw) {
  if (raw.containsKey('kpi') && raw['monthly'] is List) {
    return raw;
  }
  final inner = raw['data'] ?? raw['bundle'];
  if (inner is Map) return Map<String, dynamic>.from(inner);
  return raw;
}

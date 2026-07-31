import 'package:dio/dio.dart';
import 'package:w0001/data/datasources/remote/dashboard/dashboard_calendar_day_costs_json.dart';
import 'package:w0001/data/datasources/remote/dashboard/dashboard_calendar_json.dart';
import 'package:w0001/data/datasources/remote/dashboard/dashboard_calendar_workforce_dots_json.dart';
import 'package:w0001/data/model/dashboard_calendar_workforce_dots.dart';
import 'package:w0001/data/model/calendar_day_cost_totals.dart';
import 'package:w0001/data/model/total_cost_model.dart';
import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/data/datasources/remote/list_query.dart';
import 'package:w0001/data/datasources/remote/remote_list_pages.dart';
import 'package:w0001/data/datasources/remote/super_admin/super_admin_api_common.dart';
import 'package:w0001/data/model/paged_result.dart';
import 'package:w0001/util/api_endpoint.dart';

/// 대시보드 집계·캘린더 마커·현장 요약 (서버: `super_admin` + Bearer).
final class DashboardRemoteApi {
  DashboardRemoteApi(this._http);

  final AppHttpClient _http;

  Future<Map<String, dynamic>> kpi({
    required int year,
    required int month,
  }) async {
    final r = await _http.get<dynamic>(
      ApiEndpoint.dashboardKpi,
      queryParameters: <String, dynamic>{
        'year': year,
        'month': month,
      },
    );
    return saParseObject(r.data);
  }

  Future<List<Map<String, dynamic>>> yearly({
    required int fromYear,
    required int toYear,
  }) async {
    final r = await _http.get<dynamic>(
      ApiEndpoint.dashboardYearly,
      queryParameters: <String, dynamic>{
        'fromYear': fromYear,
        'toYear': toYear,
      },
    );
    return _listOfMaps(_unwrapListPayload(r.data));
  }

  Future<List<Map<String, dynamic>>> placesRows() async {
    final r = await _http.get<dynamic>(ApiEndpoint.dashboardPlaces);
    return _listOfMaps(_unwrapListPayload(r.data));
  }

  Future<List<Map<String, dynamic>>> monthly({required int year}) async {
    final r = await _http.get<dynamic>(
      ApiEndpoint.dashboardMonthly,
      queryParameters: <String, dynamic>{'year': year},
    );
    return _listOfMaps(_unwrapListPayload(r.data));
  }

  Future<Map<String, dynamic>> bundle({
    required int selectedYear,
    int? kpiYear,
    int? kpiMonth,
    bool includePlaces = false,
  }) async {
    final q = <String, dynamic>{
      'selectedYear': selectedYear,
      'includePlaces': includePlaces,
    };
    if (kpiYear != null) q['kpiYear'] = kpiYear;
    if (kpiMonth != null) q['kpiMonth'] = kpiMonth;
    final r = await _http.get<dynamic>(ApiEndpoint.dashboardBundle,
        queryParameters: q);
    return saParseObject(r.data);
  }

  /// [parseDashboardCalendarEvents]로 도메인 맵으로 변환할 Raw(`dynamic`).
  Future<dynamic> calendarEventsRaw({
    String? from,
    String? to,
  }) async {
    final q = <String, dynamic>{};
    final f = from?.trim();
    if (f != null && f.isNotEmpty) q['from'] = f;
    final t = to?.trim();
    if (t != null && t.isNotEmpty) q['to'] = t;
    final r = await _http.get<dynamic>(
      ApiEndpoint.dashboardCalendarEvents,
      queryParameters: q.isEmpty ? null : q,
    );
    return r.data;
  }

  Future<Map<DateTime, List<String>>> calendarEvents({
    String? from,
    String? to,
  }) async {
    final raw = await calendarEventsRaw(from: from, to: to);
    return parseDashboardCalendarEvents(raw);
  }

  Future<DashboardCalendarWorkforceDots> calendarWorkforceDots({
    required String from,
    required String to,
  }) async {
    final r = await _http.get<dynamic>(
      ApiEndpoint.dashboardCalendarWorkforceDots,
      queryParameters: <String, dynamic>{
        'from': from,
        'to': to,
      },
    );
    return parseDashboardCalendarWorkforceDots(r.data);
  }

  /// 경량 마커 (`has_cost`, `has_workforce` 등). 미배포(404) 시 null.
  Future<DashboardCalendarWorkforceDots?> calendarMarkers({
    required String from,
    required String to,
  }) async {
    try {
      final r = await _http.get<dynamic>(
        ApiEndpoint.dashboardCalendarMarkers,
        queryParameters: <String, dynamic>{
          'from': from,
          'to': to,
        },
      );
      return parseDashboardCalendarWorkforceDots(r.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  /// 선택 일자 인건비·자재비 상세 (현장·인력 join 완료).
  Future<List<TotalCostModel>> calendarDayCosts({
    required String from,
    required String to,
  }) async {
    final page = await calendarDayCostsPage(from: from, to: to);
    return page.items;
  }

  Future<CalendarDayCostPageResult> calendarDayCostsPage({
    required String from,
    required String to,
    int limit = kListPageSize,
    String? cursor,
  }) async {
    final q = <String, dynamic>{
      'from': from,
      'to': to,
      'limit': limit,
    };
    final c = cursor?.trim();
    if (c != null && c.isNotEmpty) q['cursor'] = c;
    final r = await _http.get<dynamic>(
      ApiEndpoint.dashboardCalendarDayCosts,
      queryParameters: q,
    );
    return parseDashboardCalendarDayCostsPage(r.data);
  }

  Future<List<Map<String, dynamic>>> placesInfoAll(ListQuery query) =>
      fetchAllListPages(placesInfoPage, query);

  Future<List<Map<String, dynamic>>> placesInfo() =>
      placesInfoAll(const ListQuery());

  Future<PagedResult<Map<String, dynamic>>> placesInfoPage(
      ListQuery query) async {
    final r = await _http.get<dynamic>(
      ApiEndpoint.dashboardPlacesInfo,
      queryParameters: query.toQueryParameters(),
    );
    return saParsePagedList(
      r.data,
      (m) => Map<String, dynamic>.from(m),
    );
  }
}

/// 본문이 `[{...}]` 이거나 `{ "places": [...] }` 인 경우.
dynamic _unwrapListPayload(dynamic data) {
  if (data is List) return data;
  if (data is Map) {
    final m = Map<String, dynamic>.from(data);
    final inner = m['places'] ?? m['items'] ?? m['data'] ?? m['list'];
    if (inner is List) return inner;
  }
  return const [];
}

List<Map<String, dynamic>> _listOfMaps(dynamic data) {
  if (data is! List) return const [];
  return data
      .map(
        (e) => Map<String, dynamic>.from(e as Map<dynamic, dynamic>),
      )
      .toList();
}

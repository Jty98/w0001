import 'package:w0001/data/datasources/remote/dashboard/dashboard_calendar_json.dart';
import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/data/datasources/remote/super_admin/super_admin_api_common.dart';
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
  }) async {
    final q = <String, dynamic>{'selectedYear': selectedYear};
    if (kpiYear != null) q['kpiYear'] = kpiYear;
    if (kpiMonth != null) q['kpiMonth'] = kpiMonth;
    final r = await _http.get<dynamic>(ApiEndpoint.dashboardBundle, queryParameters: q);
    return saParseObject(r.data);
  }

  /// [parseDashboardCalendarEvents]로 도메인 맵으로 변환할 Raw(`dynamic`).
  Future<dynamic> calendarEventsRaw() async {
    final r = await _http.get<dynamic>(ApiEndpoint.dashboardCalendarEvents);
    return r.data;
  }

  Future<Map<DateTime, List<String>>> calendarEvents() async {
    final raw = await calendarEventsRaw();
    return parseDashboardCalendarEvents(raw);
  }

  Future<List<Map<String, dynamic>>> placesInfo() async {
    final r = await _http.get<dynamic>(ApiEndpoint.dashboardPlacesInfo);
    return _listOfMaps(_unwrapListPayload(r.data));
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

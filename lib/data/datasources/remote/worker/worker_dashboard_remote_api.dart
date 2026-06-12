import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/data/datasources/remote/super_admin/super_admin_api_common.dart';
import 'package:w0001/data/model/worker_dashboard_models.dart';
import 'package:w0001/util/api_endpoint.dart';

final class WorkerDashboardRemoteApi {
  WorkerDashboardRemoteApi(this._http);

  final AppHttpClient _http;

  static dynamic _unwrapData(dynamic raw) {
    if (raw is Map && raw['data'] is Map) {
      return raw['data'];
    }
    return raw;
  }

  /// [month] 없으면 서버 규약상 해당 연도 전체.
  Future<WorkerDashboardSummary> fetchSummary({
    int? year,
    int? month,
  }) async {
    final qp = <String, dynamic>{
      if (year != null) 'year': year,
      if (month != null) 'month': month,
    };
    final r = await _http.get<dynamic>(
      ApiEndpoint.workerDashboardSummary,
      queryParameters: qp.isEmpty ? null : qp,
    );
    final body = saParseObject(_unwrapData(r.data));
    return WorkerDashboardSummary.fromJson(body);
  }

  /// [workdate]: `YYYY-MM-DD` 권장
  Future<List<CoworkerOnSite>> fetchCoworkers(int pid, String workdate) async {
    final r = await _http.get<dynamic>(
      ApiEndpoint.workerPlaceCoworkersByDate(pid),
      queryParameters: {'workdate': workdate},
    );
    final raw = r.data;
    if (raw is! List) return [];
    return saMapList(raw, CoworkerOnSite.fromJson);
  }
}
